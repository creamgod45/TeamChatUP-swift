//
//  ChatDetailView.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation
    @State private var messageManager: MessageManager?
    @State private var messageText = ""
    @State private var showingError = false
    
    init(conversation: Conversation) {
        self.conversation = conversation
        // 延遲到 task/onAppear 初始化
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 訊息區域
            Group {
                if let messageManager = messageManager {
                    if messageManager.isLoading && messageManager.messages.isEmpty {
                        ProgressView("正在載入對話...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        messageListView(messageManager: messageManager)
                    }
                } else {
                    // 尚未初始化時顯示空白對話區，保持佈局穩定
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // 輸入與狀態區域 (永遠顯示，提供穩定的 UI 回饋)
            VStack(spacing: 0) {
                if let messageManager = messageManager, let typingText = messageManager.typingIndicatorText {
                    HStack {
                        Text(typingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Divider()
                
                if let messageManager = messageManager {
                    messageInputView(messageManager: messageManager)
                } else {
                    // 顯示一個已禁用的佔位輸入框
                    placeholderInputView
                }
            }
        }
        .animation(.default, value: messageManager?.typingUsers)
        .navigationTitle(conversationTitle)
        .task {
            if messageManager == nil {
                let manager = MessageManager(conversationId: conversation.id)
                messageManager = manager
                await manager.loadMessages(refresh: true)
            }
            // 標記對話為已讀
            await markConversationAsRead()
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") {
                messageManager?.errorMessage = nil
            }
        } message: {
            if let error = messageManager?.errorMessage {
                Text(error)
            }
        }
        .onChange(of: messageManager?.errorMessage) { _, newValue in
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
    
    private func messageListView(messageManager: MessageManager) -> some View {
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
    
    private func messageInputView(messageManager: MessageManager) -> some View {
        HStack(spacing: 12) {
            TextField("輸入訊息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(8)
#if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
#else
                .background(Color(.systemGray6))
#endif
                .clipShape(.rect(cornerRadius: 8))
                .lineLimit(1...5)
                .onChange(of: messageText) { _, _ in
                    messageManager.sendTypingIndicator()
                }

            Button {
                sendMessage(messageManager: messageManager)
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(messageText.isEmpty ? Color.gray : Color.accentColor)
                    .clipShape(.rect(cornerRadius: 8))
            }
            .disabled(messageText.isEmpty || messageManager.isSending)
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private func sendMessage(messageManager: MessageManager) {
        let content = messageText
        messageText = ""

        Task {
            await messageManager.sendMessage(content: content)
        }
    }
    
    // 🔗 佔位輸入框：在 MessageManager 初始化前顯示，保持視圖穩定
    private var placeholderInputView: some View {
        HStack(spacing: 12) {
            TextField("正在準備中...", text: .constant(""))
                .textFieldStyle(.plain)
                .padding(8)
                .disabled(true)
#if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
#else
                .background(Color(.systemGray6))
#endif
                .clipShape(.rect(cornerRadius: 8))
            
            Button { } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.gray)
                    .clipShape(.rect(cornerRadius: 8))
            }
            .disabled(true)
        }
        .padding()
        .opacity(0.6)
    }

    private func markConversationAsRead() async {
        await ConversationManager.shared.markAsRead(conversationId: conversation.id)
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
                    .clipShape(.rect(cornerRadius: 16))
                
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
