//
//  ChatDetailView.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation
    @StateObject private var messageManager: MessageManager
    @State private var messageText = ""
    @State private var showingError = false
    
    init(conversation: Conversation) {
        self.conversation = conversation
        _messageManager = StateObject(wrappedValue: MessageManager(conversationId: conversation.id))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if messageManager.isLoading && messageManager.messages.isEmpty {
                ProgressView("載入訊息中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messageListView
            }
            
            Divider()
            
            messageInputView
        }
        .navigationTitle(conversationTitle)
        .task {
            await messageManager.loadMessages(refresh: true)
            // 標記對話為已讀
            await markConversationAsRead()
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") {
                messageManager.errorMessage = nil
            }
        } message: {
            if let error = messageManager.errorMessage {
                Text(error)
            }
        }
        .onChange(of: messageManager.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
    }
    
    private var conversationTitle: String {
        if conversation.type == .direct {
            // 找出對方的名字
            let currentUserId = PKCEAuthManager.shared.currentUser?.id ?? 0
            let otherUser = conversation.participants.first { $0.id != currentUserId }
            return otherUser?.name ?? "對話"
        } else {
            return conversation.name ?? "群組對話"
        }
    }
    
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messageManager.hasMorePages {
                        Button {
                            Task {
                                await messageManager.loadMessages()
                            }
                        } label: {
                            if messageManager.isLoading {
                                ProgressView()
                            } else {
                                Text("載入更多訊息")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    ForEach(messageManager.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messageManager.messages.count) { _, _ in
                if let lastMessage = messageManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            TextField("輸入訊息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(8)
#if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
#else
                .background(Color(.systemGray6))
#endif
                .cornerRadius(8)
                .lineLimit(1...5)
                .onChange(of: messageText) { _, _ in
                    messageManager.sendTypingIndicator()
                }
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(messageText.isEmpty ? Color.gray : Color.accentColor)
                    .cornerRadius(8)
            }
            .disabled(messageText.isEmpty || messageManager.isSending)
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private func sendMessage() {
        let content = messageText
        messageText = ""

        Task {
            await messageManager.sendMessage(content: content)
        }
    }

    private func markConversationAsRead() async {
        do {
            try await APIClient.shared.markAsRead(conversationId: conversation.id)
            AppLogger.shared.debug("✅ 對話已標記為已讀 - ID: \(conversation.id)")
        } catch {
            AppLogger.shared.error("❌ 標記對話為已讀失敗: \(error)")
        }
    }
}

struct MessageBubbleView: View {
    let message: MessageResponse

    private var isCurrentUser: Bool {
        message.user.id == PKCEAuthManager.shared.currentUser?.id
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
#if os(macOS)
                    .background(isCurrentUser ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
#else
                    .background(isCurrentUser ? Color.accentColor : Color(.systemGray6))
#endif
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 300, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}
