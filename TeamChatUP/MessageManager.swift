//
//  MessageManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class MessageManager: ObservableObject {
    @Published var messages: [MessageResponse] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasMorePages = true
    @Published var typingUsers: Set<Int> = []
    
    private var conversationId: Int
    private var messageIds = Set<Int>()
    private var typingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(conversationId: Int) {
        self.conversationId = conversationId
        setupWebSocketListener()
        
        // 訂閱對話頻道以接收即時訊息
        WebSocketManager.shared.subscribeToConversation(conversationId)
    }
    
    private func setupWebSocketListener() {
        WebSocketManager.shared.eventPublisher
            .sink { [weak self] (event: WebSocketEvent) in
                guard let self = self else { return }
                self.handleWebSocketEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event {
        case .newMessage(let message):
            if message.conversationId == conversationId {
                addReceivedMessage(message)
            }
            
        case .typing(let typingEvent):
            if typingEvent.conversationId == conversationId {
                if typingEvent.isTyping {
                    // 只在新增使用者時播放音效（避免重複播放）
                    let isNewTypingUser = !typingUsers.contains(typingEvent.userId)
                    typingUsers.insert(typingEvent.userId)

                    // 播放 typing 音效
                    if isNewTypingUser {
                        SoundManager.shared.playTypingSound()
                    }
                } else {
                    typingUsers.remove(typingEvent.userId)
                }
            }
            
        case .messageRead(let readEvent):
            if readEvent.conversationId == conversationId {
                // 處理已讀狀態
            }
            
        default:
            break
        }
    }
    
    func loadMessages(refresh: Bool = false) async {
        guard !isLoading else { return }
        
        if refresh {
            currentPage = 1
            hasMorePages = true
            messageIds.removeAll()
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.getMessages(
                conversationId: conversationId,
                page: currentPage,
                perPage: 50
            )
            
            let newMessages = response.data.filter { !messageIds.contains($0.id) }
            
            if refresh {
                // 首次載入：API 回傳的是最新的訊息（降序），需要反轉成升序（最舊在前）
                messages = newMessages.reversed()
            } else {
                // 載入更多歷史訊息：插入到陣列開頭（因為是更舊的訊息）
                // API 回傳降序，反轉後變升序，插入到開頭
                messages.insert(contentsOf: newMessages.reversed(), at: 0)
            }
            
            newMessages.forEach { messageIds.insert($0.id) }
            
            hasMorePages = response.data.count >= 50
            currentPage += 1
            
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "載入訊息失敗"
        }
        
        isLoading = false
    }
    
    func sendMessage(content: String) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        let tempMessage = createTempMessage(content: content)
        let tempId = tempMessage.id
        messages.append(tempMessage)
        
        isSending = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.sendMessage(
                conversationId: conversationId,
                content: content
            )
            
            // Remove the temp message
            messages.removeAll(where: { $0.id == tempId })
            
            // Add real message only if it doesn't exist yet (might have arrived via WebSocket)
            if !messageIds.contains(response.data.id) {
                messages.append(response.data)
                messageIds.insert(response.data.id)
            }
            
            isSending = false
            return true
            
        } catch {
            // Remove temp message on error
            messages.removeAll(where: { $0.id == tempId })
            
            errorMessage = (error as? APIError)?.errorDescription ?? "發送訊息失敗"
            isSending = false
            return false
        }
    }
    
    func sendTypingIndicator() {
        typingTimer?.invalidate()

        let conversationId = self.conversationId

        // 發送 typing 訊號到後端 API
        Task {
            do {
                try await APIClient.shared.sendTypingIndicator(conversationId: conversationId)
                AppLogger.shared.debug("⌨️ 發送輸入中訊號 - 對話ID: \(conversationId)")
            } catch {
                AppLogger.shared.error("❌ 發送輸入中訊號失敗", error: error)
            }
        }

        // 3 秒後自動停止（後端會處理）
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            // Timer 只是用來限制發送頻率，實際的 isTyping: false 由後端的 debounce 處理
        }
    }
    
    func addReceivedMessage(_ message: MessageResponse) {
        guard !messageIds.contains(message.id) else { return }
        messages.append(message)
        messageIds.insert(message.id)
    }
    
    private func createTempMessage(content: String) -> MessageResponse {
        let currentUser = PKCEAuthManager.shared.currentUser ?? User(
            id: 0,
            name: "Unknown",
            email: "",
            avatar: nil,
            role: "user"
        )
        
        // Use negative timestamp as unique temp ID to avoid conflicts
        let tempId = -Int(Date().timeIntervalSince1970 * 1000)
        
        return MessageResponse(
            id: tempId,
            content: content,
            type: .text,
            user: currentUser,
            conversationId: conversationId,
            createdAt: Date()
        )
    }
    
    func refresh() async {
        await loadMessages(refresh: true)
    }
}
