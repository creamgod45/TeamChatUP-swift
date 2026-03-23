//
//  ConversationManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import SwiftUI
import Combine
import Observation

@Observable @MainActor
final class ConversationManager {
    static let shared = ConversationManager()
    
    var conversations: [Conversation] = []
    var isLoading = false
    var errorMessage: String?
    var currentPage = 1
    var hasMorePages = true
    
    private var isRefreshing = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWebSocketListener()
    }
    
    private func setupWebSocketListener() {
        WebSocketManager.shared.eventPublisher
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handleWebSocketEvent(event)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event {
        case .newMessage(let message):
            updateConversationWithNewMessage(message)
        default:
            break
        }
    }
    
    private func updateConversationWithNewMessage(_ message: MessageResponse) {
        if let index = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            let oldConv = conversations[index]
                
            // 只有當新訊息 ID 與最後一則訊息不同時才更新（去重）
            if oldConv.lastMessage?.id != message.id {
                let updatedConv = Conversation(
                    id: oldConv.id,
                    name: oldConv.name,
                    type: oldConv.type,
                    participants: oldConv.participants,
                    lastMessage: message,
                    unreadCount: oldConv.unreadCount + (message.user.id != PKCEAuthManager.shared.currentUser?.id ? 1 : 0),
                    createdAt: oldConv.createdAt
                )
                
                conversations.remove(at: index)
                conversations.insert(updatedConv, at: 0)
                AppLogger.shared.debug("✅ 已同步更新對話列表訊息: \(message.content)")
            }
        }
    }
    
    func loadConversations(refresh: Bool = false) async {
        AppLogger.shared.debug("📥 loadConversations(refresh: \(refresh)) 被呼叫 (isLoading: \(isLoading), isRefreshing: \(isRefreshing))")
        
        if refresh {
            guard !isRefreshing else { 
                AppLogger.shared.warning("⚠️ 攔截重複的 refresh 請求")
                return 
            }
            isRefreshing = true
            currentPage = 1
            hasMorePages = true
        } else {
            guard !isLoading else { 
                AppLogger.shared.warning("⚠️ 攔截重複的 load 請求")
                return 
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        AppLogger.shared.info("📡 [ConversationManager] 開始從伺服器載入對話 (頁數: \(currentPage))")
        
        do {
            let response = try await APIClient.shared.getConversations(
                page: currentPage,
                perPage: 20
            )
            
            if refresh {
                conversations = response.data
            } else {
                conversations.append(contentsOf: response.data)
            }
            
            hasMorePages = response.data.count >= 20
            
            // 自動訂閱所有載入的對話頻道
            for conv in response.data {
                WebSocketManager.shared.subscribeToConversation(conv.id)
            }
            currentPage += 1
            
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "載入對話失敗"
        }
        
        isLoading = false
        isRefreshing = false
    }
    
    func createConversation(type: ConversationType, name: String?, participantIds: [Int]) async -> Conversation? {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.createConversation(
                type: type,
                name: name,
                participantIds: participantIds
            )
            
            conversations.insert(response.data, at: 0)
            isLoading = false
            return response.data
            
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "建立對話失敗"
            isLoading = false
            return nil
        }
    }
    
    func markAsRead(conversationId: Int) async {
        do {
            try await APIClient.shared.markAsRead(conversationId: conversationId)
            
            // 更新本地未讀數量為 0
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                let oldConv = conversations[index]
                if oldConv.unreadCount > 0 {
                    let updatedConv = Conversation(
                        id: oldConv.id,
                        name: oldConv.name,
                        type: oldConv.type,
                        participants: oldConv.participants,
                        lastMessage: oldConv.lastMessage,
                        unreadCount: 0,
                        createdAt: oldConv.createdAt
                    )
                    conversations[index] = updatedConv
                    AppLogger.shared.debug("✅ 已將本地對話標記為已讀: \(conversationId)")
                }
            }
        } catch {
            AppLogger.shared.error("❌ 標記對話為已讀失敗: \(error)")
        }
    }
    
    func refresh() async {
        await loadConversations(refresh: true)
    }
}
