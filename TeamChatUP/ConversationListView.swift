//
//  ConversationListView.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import SwiftUI

struct ConversationListView: View {
    @State private var conversationManager = ConversationManager.shared
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
    @State private var conversationManager = ConversationManager.shared
    @State private var userManager = UserManager()

    @State private var conversationName = ""
    @State private var conversationType: ConversationType = .group
    @State private var selectedUserIds = Set<Int>()
    @State private var searchText = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("對話名稱", text: $conversationName)
                } header: {
                    Text("基本資訊")
                }

                Section {
                    Picker("類型", selection: $conversationType) {
                        Text("群組對話").tag(ConversationType.group)
                        Text("私人對話").tag(ConversationType.direct)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("對話類型")
                }

                Section {
                    if userManager.isLoading && userManager.users.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(filteredUsers) { user in
                            UserSelectionRow(
                                user: user,
                                isSelected: selectedUserIds.contains(user.id)
                            ) {
                                toggleUserSelection(user.id)
                            }
                        }
                    }
                } header: {
                    Text("選擇參與者 (\(selectedUserIds.count))")
                } footer: {
                    if conversationType == .direct && selectedUserIds.count > 1 {
                        Text("私人對話只能選擇一位參與者")
                            .foregroundColor(.orange)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜尋使用者")
            .navigationTitle("建立新對話")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        Task {
                            await createConversation()
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
            .task {
                await userManager.loadUsers()
            }
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    await userManager.searchUsers(query: newValue)
                }
            }
        }
    }

    private var filteredUsers: [User] {
        userManager.users
    }

    private var canCreate: Bool {
        !conversationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedUserIds.isEmpty &&
        (conversationType == .group || selectedUserIds.count == 1)
    }

    private func toggleUserSelection(_ userId: Int) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            if conversationType == .direct {
                selectedUserIds.removeAll()
            }
            selectedUserIds.insert(userId)
        }
    }

    private func createConversation() async {
        isCreating = true
        errorMessage = nil

        let name = conversationName.trimmingCharacters(in: .whitespaces)
        let participantIds = Array(selectedUserIds)

        AppLogger.shared.info("建立新對話 - 名稱: \(name), 類型: \(conversationType.rawValue), 參與者: \(participantIds)")

        if let conversation = await conversationManager.createConversation(
            type: conversationType,
            name: name,
            participantIds: participantIds
        ) {
            AppLogger.shared.info("✅ 對話建立成功: \(conversation.id)")
            dismiss()
        } else {
            errorMessage = conversationManager.errorMessage ?? "建立對話失敗"
            AppLogger.shared.error("❌ 對話建立失敗")
        }

        isCreating = false
    }
}

struct UserSelectionRow: View {
    let user: User
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let email = user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

