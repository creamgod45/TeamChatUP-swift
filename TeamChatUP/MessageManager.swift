//
//  MessageManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import SwiftUI
import Combine
import Observation

@Observable @MainActor
final class MessageManager {
    var messages: [MessageResponse] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var currentPage = 1
    var hasMorePages = true
    var typingUsers: [Int: String] = [:]
    
    var typingIndicatorText: String? {
        guard !typingUsers.isEmpty else { return nil }
        let names = typingUsers.values.sorted()
        if names.count == 1 {
            return "\(names[0]) 正在輸入中..."
        } else if names.count == 2 {
            return "\(names[0]) 和 \(names[1]) 正在輸入中..."
        } else {
            return "\(names[0]) 等 \(names.count) 人正在輸入中..."
        }
    }
    
    private var conversationId: Int
    private var messageIds = Set<Int>()
    private var typingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 記錄每個使用者上次播放輸入音效的時間，用於冷卻重複播放
    private var lastTypingSoundTime: [Int: Date] = [:]
    // 記錄每個使用者上次收到輸入訊號的時間，用於自動清理超時狀態
    private var lastTypingEventTime: [Int: Date] = [:]
    // 記錄每個使用者上次收到訊息的時間，用於避免訊息與輸入音效重疊
    private var lastMessageReceivedTime: [Int: Date] = [:]
    // 定期清理超時輸入狀態的計時器
    private var statusCleanupTimer: Timer?
    
    init(conversationId: Int) {
        self.conversationId = conversationId
        setupWebSocketListener()
        startStatusCleanupTimer()
        
        // 訂閱對話頻道以接收即時訊息
        WebSocketManager.shared.subscribeToConversation(conversationId)
    }
    
    private func startStatusCleanupTimer() {
        statusCleanupTimer?.invalidate()
        statusCleanupTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.cleanupExpiredTypingStatus()
            }
        }
    }
    
    private func cleanupExpiredTypingStatus() {
        let now = Date()
        let timeout: TimeInterval = 6.0 // 如果 6 秒沒收到訊號，視為停止輸入
        
        var usersToRemove: [Int] = []
        for (userId, lastTime) in lastTypingEventTime {
            if now.timeIntervalSince(lastTime) > timeout {
                usersToRemove.append(userId)
            }
        }
        
        for userId in usersToRemove {
            if typingUsers.keys.contains(userId) {
                AppLogger.shared.debug("⏱️ 使用者 \(userId) 輸入超時，自動從列表移除")
                typingUsers.removeValue(forKey: userId)
            }
            lastTypingEventTime.removeValue(forKey: userId)
        }
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
                
                let now = Date()
                lastMessageReceivedTime[message.user.id] = now
                
                // 收到訊息後，通常對方也停止輸入了，清除相關狀態
                typingUsers.removeValue(forKey: message.user.id)
                lastTypingEventTime.removeValue(forKey: message.user.id)
                // 同時將打字聲冷卻設為現在，防止剛收到訊息又立刻播打字聲
                lastTypingSoundTime[message.user.id] = now
            }
            
        case .typing(let typingEvent):
            guard typingEvent.conversationId == conversationId else { return }
            
            // 🛑 核心修復：忽略自己的輸入訊號，只處理其他人的
            let currentUserId = PKCEAuthManager.shared.currentUser?.id ?? 0
            guard typingEvent.userId != currentUserId else { return }
            
            if typingEvent.isTyping {
                let now = Date()
                
                // 🛑 核心修復：如果最近 1.5 秒內才收到這個人的訊息，忽略這個打字聲
                if let lastMsgTime = lastMessageReceivedTime[typingEvent.userId],
                   now.timeIntervalSince(lastMsgTime) < 1.5 {
                    AppLogger.shared.debug("🔇 忽略殘留打字聲 (剛收到使用者的訊息)")
                    return
                }
                
                lastTypingEventTime[typingEvent.userId] = now
                let isNewTyping = !typingUsers.keys.contains(typingEvent.userId)
                
                // 檢查上次播放聲音的時間，如果超過 8 秒，允許再次播放
                let lastSoundTime = lastTypingSoundTime[typingEvent.userId] ?? .distantPast
                let shouldRepeatSound = now.timeIntervalSince(lastSoundTime) > 8.0
                
                if isNewTyping || shouldRepeatSound {
                    AppLogger.shared.debug("🎵 \(isNewTyping ? "開始輸入" : "持續輸入中")，準備播放音效...")
                    SoundManager.shared.playTypingSound()
                    lastTypingSoundTime[typingEvent.userId] = now
                    
                    if isNewTyping {
                        typingUsers[typingEvent.userId] = typingEvent.userName ?? "未知使用者"
                    }
                }
            } else {
                typingUsers.removeValue(forKey: typingEvent.userId)
                lastTypingEventTime.removeValue(forKey: typingEvent.userId)
                lastTypingSoundTime.removeValue(forKey: typingEvent.userId)
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
