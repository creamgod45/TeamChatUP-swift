//
//  ConversationManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasMorePages = true
    
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
        guard !isLoading else { return }
        
        if refresh {
            isRefreshing = true
            currentPage = 1
            hasMorePages = true
        }
        
        isLoading = true
        errorMessage = nil
        
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
            // Note: 由於 Conversation 是 struct，需要重新建立來更新
            // 這裡暫時不做處理，等待 WebSocket 更新或下次刷新
            if conversations.contains(where: { $0.id == conversationId }) {
                // 標記已讀成功，等待下次刷新更新 UI
            }
        } catch {
            // 靜默失敗，不影響 UI
        }
    }
    
    func refresh() async {
        await loadConversations(refresh: true)
    }
}
