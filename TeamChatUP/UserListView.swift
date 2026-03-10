//
//  UserListView.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import SwiftUI

struct UserListView: View {
    @StateObject private var userManager = UserManager()
    @Binding var selectedUserIds: Set<Int>
    let selectionMode: SelectionMode
    @Environment(\.dismiss) private var dismiss
    
    enum SelectionMode {
        case single
        case multiple
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $userManager.searchQuery, onSearch: {
                    Task {
                        await userManager.searchUsers(query: userManager.searchQuery)
                    }
                })
                
                if userManager.isLoading && userManager.users.isEmpty {
                    ProgressView("載入中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = userManager.errorMessage {
                    ErrorView(message: error, retry: {
                        Task { await userManager.loadUsers() }
                    })
                } else if userManager.users.isEmpty {
                    ContentUnavailableView(
                        "沒有使用者",
                        systemImage: "person.2.slash",
                        description: Text("找不到符合條件的使用者")
                    )
                } else {
                    List {
                        ForEach(userManager.users) { user in
                            UserRow(
                                user: user,
                                isSelected: selectedUserIds.contains(user.id),
                                selectionMode: selectionMode
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(user: user)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("選擇參與者")
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
                    Button("完成") {
                        dismiss()
                    }
                    .disabled(selectedUserIds.isEmpty)
                }
            }
            .task {
                await userManager.loadUsers()
            }
        }
    }
    
    private func toggleSelection(user: User) {
        if selectionMode == .single {
            selectedUserIds = [user.id]
            AppLogger.shared.debug("選擇使用者 (單選): \(user.name)")
        } else {
            if selectedUserIds.contains(user.id) {
                selectedUserIds.remove(user.id)
                AppLogger.shared.debug("取消選擇使用者: \(user.name)")
            } else {
                selectedUserIds.insert(user.id)
                AppLogger.shared.debug("選擇使用者: \(user.name)")
            }
        }
    }
}

struct UserRow: View {
    let user: User
    let isSelected: Bool
    let selectionMode: UserListView.SelectionMode
    
    var body: some View {
        HStack(spacing: 12) {
            if let avatarUrl = user.avatar, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            Text(user.name.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.blue)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.body)
                Text(user.email!)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: selectionMode == .single ? "checkmark.circle.fill" : "checkmark.square.fill")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            } else {
                Image(systemName: selectionMode == .single ? "circle" : "square")
                    .foregroundColor(.gray)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜尋使用者...", text: $text)
                .textFieldStyle(.plain)
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty {
                        onSearch()
                    }
                }
                .onSubmit {
                    onSearch()
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
#if os(iOS)
        .background(Color(.systemGray6))
#elseif os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
#endif
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("重試", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
