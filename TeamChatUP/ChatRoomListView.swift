//
//  ChatRoomListView.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import SwiftUI

struct ChatRoomListView: View {
    @StateObject private var conversationManager = ConversationManager.shared
    @Binding var selectedConversation: Conversation?
    @State private var showingAddConversation = false
    @State private var showingError = false
    
    var body: some View {
        Group {
            if conversationManager.isLoading && conversationManager.conversations.isEmpty {
                ProgressView("載入對話中...")
            } else if conversationManager.conversations.isEmpty {
                emptyStateView
            } else {
                conversationListView
            }
        }
        .navigationTitle("聊天室")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddConversation = true
                } label: {
                    Label("新增對話", systemImage: "plus")
                }
            }
        }
        .task {
            await conversationManager.loadConversations(refresh: true)
        }
        .refreshable {
            await conversationManager.refresh()
        }
        .sheet(isPresented: $showingAddConversation) {
            AddConversationView()
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") {
                conversationManager.errorMessage = nil
            }
        } message: {
            if let error = conversationManager.errorMessage {
                Text(error)
            }
        }
        .onChange(of: conversationManager.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "沒有對話",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("點擊右上角的 + 按鈕建立新對話")
        )
    }
    
    private var conversationListView: some View {
        List(selection: $selectedConversation) {
            ForEach(conversationManager.conversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRowView(conversation: conversation)
                }
            }
            
            if conversationManager.hasMorePages {
                HStack {
                    Spacer()
                    if conversationManager.isLoading {
                        ProgressView()
                    } else {
                        Button("載入更多") {
                            Task {
                                await conversationManager.loadConversations()
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    private var displayName: String {
        if conversation.type == .direct {
            let currentUserId = PKCEAuthManager.shared.currentUser?.id ?? 0
            let otherUser = conversation.participants.first { $0.id != currentUserId }
            return otherUser?.name ?? "對話"
        } else {
            return conversation.name ?? "群組對話"
        }
    }
    
    private var lastMessagePreview: String {
        if let lastMessage = conversation.lastMessage {
            return lastMessage.content
        }
        return "尚無訊息"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName)
                    .font(.headline)
                
                Spacer()
                
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
            }
            
            Text(lastMessagePreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

struct AddConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var conversationManager = ConversationManager.shared
    @State private var conversationType: ConversationType = .direct
    @State private var groupName = ""
    @State private var selectedUserIds: Set<Int> = []
    @State private var isCreating = false
    @State private var showUserPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("對話類型") {
                    Picker("類型", selection: $conversationType) {
                        Text("私人對話").tag(ConversationType.direct)
                        Text("群組對話").tag(ConversationType.group)
                    }
                    .pickerStyle(.segmented)
                }

                if conversationType == .group {
                    Section("群組名稱") {
                        TextField("輸入群組名稱", text: $groupName)
                    }
                }

                Section("參與者") {
                    Button(action: {
                        showUserPicker = true
                    }) {
                        HStack {
                            Text(selectedUserIds.isEmpty ? "選擇參與者" : "已選擇 \(selectedUserIds.count) 位")
                                .foregroundColor(selectedUserIds.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    if !selectedUserIds.isEmpty {
                        Text(conversationType == .group
                            ? "已選擇 \(selectedUserIds.count) 位參與者"
                            : "已選擇 1 位參與者")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("新增對話")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        Task {
                            await createConversation()
                        }
                    }
                    .disabled(isCreating || !isValid)
                }
            }
            .sheet(isPresented: $showUserPicker) {
                UserListView(
                    selectedUserIds: $selectedUserIds,
                    selectionMode: conversationType == .direct ? .single : .multiple
                )
            }
        }
    }
    
    private var isValid: Bool {
        if conversationType == .group {
            return !groupName.isEmpty && !selectedUserIds.isEmpty
        }
        return selectedUserIds.count == 1
    }
    
    private func createConversation() async {
        isCreating = true
        
        AppLogger.shared.info("開始建立對話 - 類型: \(conversationType.rawValue)")
        
        let name = conversationType == .group ? groupName : nil
        let result = await conversationManager.createConversation(
            type: conversationType,
            name: name,
            participantIds: Array(selectedUserIds)
        )
        
        if result != nil {
            AppLogger.shared.info("✅ 對話建立成功")
            dismiss()
        } else {
            AppLogger.shared.error("❌ 對話建立失敗")
        }
        
        isCreating = false
    }
}
