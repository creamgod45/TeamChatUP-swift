//
//  ContentView.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = PKCEAuthManager.shared
    @State private var selectedConversation: Conversation?

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainView
            } else {
                LoginView()
            }
        }
        .alert("授權已過期", isPresented: $authManager.showTokenExpiredAlert) {
            Button("重新登入", role: .none) {
                Task {
                    await authManager.handleTokenExpiration(shouldRelogin: true)
                }
            }
            Button("取消", role: .cancel) {
                Task {
                    await authManager.handleTokenExpiration(shouldRelogin: false)
                }
            }
        } message: {
            Text("您的登入憑證已過期，需要重新登入才能繼續使用。")
        }
    }
    
    private var mainView: some View {
        NavigationSplitView {
            ChatRoomListView(selectedConversation: $selectedConversation)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            if let user = authManager.currentUser {
                                Text(user.name)
                                Text(user.email!)
                                    .font(.caption)
                                Divider()
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    await authManager.logout()
                                }
                            } label: {
                                Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Label("帳號", systemImage: "person.circle")
                        }
                    }
                }
#if os(macOS)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
#endif
        } detail: {
            if let conversation = selectedConversation {
                ChatDetailView(conversation: conversation)
            } else {
                ContentUnavailableView(
                    "選擇聊天室",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("從左側選擇或新增一個聊天室開始聊天")
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChatRoom.self, Message.self], inMemory: true)
}
