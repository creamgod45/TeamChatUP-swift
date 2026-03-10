//
//  ChatView.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    let chatRoom: ChatRoom
    
    @State private var messageText = ""
    @State private var userName = "使用者"
    @State private var showingUserNameAlert = false
    
    var sortedMessages: [Message] {
        chatRoom.messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMessages) { message in
                            MessageBubble(message: message, currentUser: userName)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: sortedMessages.count) { _, _ in
                    if let lastMessage = sortedMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
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
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(messageText.isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(8)
                }
                .disabled(messageText.isEmpty)
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle(chatRoom.name)
        .toolbar {
            ToolbarItem {
                Button {
                    showingUserNameAlert = true
                } label: {
                    Label("設定名稱", systemImage: "person.circle")
                }
            }
        }
        .alert("設定使用者名稱", isPresented: $showingUserNameAlert) {
            TextField("名稱", text: $userName)
            Button("確定") {}
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        withAnimation {
            let message = Message(
                content: messageText,
                senderName: userName,
                chatRoom: chatRoom
            )
            modelContext.insert(message)
            messageText = ""
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let currentUser: String
    
    var isCurrentUser: Bool {
        message.senderName == currentUser
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
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
                
                Text(message.timestamp, format: .dateTime.hour().minute())
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
