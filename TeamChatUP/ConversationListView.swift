//
//  ConversationListView.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var conversationManager = ConversationManager.shared
    @State private var showNewConversation = false
    
    var body: some View {
        NavigationView {
            Group {
                if conversationManager.isLoading && conversationManager.conversations.isEmpty {
                    ProgressView("載入中...")
                } else if let errorMessage = conversationManager.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("重試") {
                            Task {
                                await conversationManager.refresh()
                            }
                        }
                    }
                    .padding()
                } else if conversationManager.conversations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "message")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("還沒有對話")
                            .foregroundColor(.secondary)
                        Button("開始新對話") {
                            showNewConversation = true
                        }
                    }
                } else {
                    List {
                        ForEach(conversationManager.conversations) { conversation in
                            NavigationLink(destination: ChatDetailView(conversation: conversation)) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                    }
                    .refreshable {
                        await conversationManager.refresh()
                    }
                }
            }
            .navigationTitle("對話")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showNewConversation = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationView()
            }
        }
        .task {
            if conversationManager.conversations.isEmpty {
                await conversationManager.loadConversations()
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(conversation.name?.prefix(1).uppercased() ?? "?")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name ?? "未命名對話")
                        .font(.headline)
                    
                    Spacer()
                    
                    if let lastMessage = conversation.lastMessage {
                        Text(formatDate(lastMessage.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount) 則未讀")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            formatter.dateStyle = .short
        }
        
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("建立新對話功能開發中...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("新對話")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

