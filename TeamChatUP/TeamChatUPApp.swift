import SwiftUI
import SwiftData

@main
struct TeamChatUPApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            ChatRoom.self,
            Message.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @State private var authManager = PKCEAuthManager.shared
    @State private var webSocketManager = WebSocketManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onOpenURL { url in
            AppLogger.shared.info("🔗 收到系統 URL: \(url.absoluteString)")
            AppLogger.shared.debug("🔍 URL Scheme: \(url.scheme ?? "none")")
            
            if url.scheme == "teamchatup" {
                AppLogger.shared.info("✅ 識別為 teamchatup scheme，開始處理回調")
                Task {
                    await authManager.handleCallback(url: url)
                }
            } else {
                AppLogger.shared.warning("⚠️ 收到非預期的 URL Scheme: \(url.scheme ?? "none")")
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // 登入成功後連接 WebSocket
                webSocketManager.connect()
                AppLogger.shared.info("使用者已登入，啟動 WebSocket 連線")
            } else {
                // 登出後斷開 WebSocket
                webSocketManager.disconnect()
                AppLogger.shared.info("使用者已登出，關閉 WebSocket 連線")
            }
        }
        .task {
            // App 啟動時，如果已登入就連接 WebSocket
            if authManager.isAuthenticated {
                webSocketManager.connect()
                AppLogger.shared.info("App 啟動，WebSocket 連線中...")
            }
        }
    }
}

struct MainTabView: View {
    @State private var authManager = PKCEAuthManager.shared
    
    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Label("對話", systemImage: "message")
                }
            
            DevicesView()
                .tabItem {
                    Label("設備", systemImage: "iphone")
                }
            
            ProfileView()
                .tabItem {
                    Label("個人", systemImage: "person")
                }
        }
    }
}

struct ProfileView: View {
    @State private var authManager = PKCEAuthManager.shared
    
    var body: some View {
        NavigationView {
            List {
                if let user = authManager.currentUser {
                    Section {
                        HStack {
                            if let avatar = user.avatar {
                                AsyncImage(url: URL(string: avatar)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text(user.name.prefix(1).uppercased())
                                            .font(.title)
                                            .foregroundColor(.blue)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email!)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            await authManager.logout()
                        }
                    } label: {
                        Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("個人資料")
        }
    }
}
