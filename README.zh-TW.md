# TeamChatUP

基於 SwiftUI 構建的現代化即時聊天應用程式，支援 iOS 和 macOS 平台。

## 概述

TeamChatUP 是一款跨平台即時通訊應用程式，提供安全的即時通訊功能，支援私人訊息和群組對話。應用程式採用基於 PKCE 的裝置授權、WebSocket 即時訊息傳遞，以及離線優先的本地資料持久化。

## 功能特色

- 🔐 **安全認證**：PKCE（Proof Key for Code Exchange）裝置授權流程
- 💬 **即時訊息**：基於 WebSocket 的即時訊息傳遞
- 📱 **跨平台支援**：原生支援 iOS 和 macOS
- 💾 **離線優先**：使用 SwiftData 進行本地資料持久化
- 👥 **群組聊天**：支援私人對話和群組對話
- 🔔 **即時更新**：即時輸入指示器和線上狀態
- 🔒 **安全儲存**：基於 Keychain 的 Token 管理

## 技術堆疊

- **UI 框架**：SwiftUI
- **本地持久化**：SwiftData
- **網路通訊**：URLSession with async/await
- **即時通訊**：WebSocket (URLSessionWebSocketTask)
- **身份驗證**：PKCE OAuth 2.0
- **安全儲存**：Keychain Services
- **架構模式**：MVVM with Observable pattern

## 系統需求

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## 安裝步驟

1. 複製專案：
```bash
git clone https://github.com/yourusername/TeamChatUP.git
cd TeamChatUP
```

2. 在 Xcode 中開啟專案：
```bash
open TeamChatUP.xcodeproj
```

3. 在 `AppConfig.swift` 中配置環境（請參閱下方配置章節）

4. 建置並執行專案

## 配置設定

### 環境設定

應用程式在 `AppConfig.swift` 中支援三種環境：

- **Development**：本地開發伺服器
- **Staging**：測試環境
- **Production**：正式環境

環境會根據建置配置自動選擇：
- Debug 建置 → Development
- Release 建置 → Production

### API 端點

在 `AppConfig.swift` 中配置以下 URL：

```swift
static var apiBaseURL: String {
    // REST API 基礎 URL
}

static var websocketURL: String {
    // WebSocket 伺服器 URL
}

static var deviceAuthURL: String {
    // 裝置授權 URL
}
```

### URL Scheme

應用程式註冊 `teamchatup://` URL scheme 用於 OAuth 回調。此設定在 `Info.plist` 中配置。

## 建置指令

### 建置 iOS 模擬器版本
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### 建置 macOS 版本
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=macOS' \
  build
```

### 執行測試
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

### 清理建置
```bash
xcodebuild -scheme TeamChatUP clean
```

## 架構設計

### 認證流程

TeamChatUP 實作 PKCE 裝置授權，提供兩種方式：

#### 1. 自動流程（Deep Link）
1. 使用者點擊「自動授權登入」
2. 應用程式產生 PKCE challenge 並開啟瀏覽器
3. 使用者在瀏覽器中授權
4. 瀏覽器重新導向至 `teamchatup://auth/callback?code=...`
5. 應用程式使用 code + verifier 交換 access token

#### 2. 手動流程（代碼輸入）
1. 使用者點擊「手動輸入授權碼」
2. 應用程式開啟瀏覽器進行授權
3. 使用者從瀏覽器複製授權碼
4. 使用者將代碼貼入應用程式
5. 應用程式交換代碼以取得 access token

**核心元件：**
- `PKCEAuthManager.swift` - 管理認證狀態和 token 交換
- `PKCEManager.swift` - 產生 PKCE challenge/verifier 配對
- `LoginView.swift` - 登入 UI，包含兩種認證流程

### 資料架構

應用程式維護**兩個獨立的資料層**：

#### 1. 本地儲存（SwiftData）
- 模型：`ChatRoom`、`Message`
- 用途：離線優先的本地聊天記錄
- Schema：定義於 `TeamChatUPApp.swift`

#### 2. 遠端 API（REST + WebSocket）
- 模型：`Conversation`、`MessageResponse`、`User`
- REST API：透過 `APIClient` 進行 CRUD 操作
- WebSocket：透過 `WebSocketManager` 進行即時更新

> **重要**：本地 SwiftData 模型和遠端 API 模型是分離的，不會自動同步。

### 即時訊息

WebSocket 連線由 `WebSocketManager` 管理：

- **連線方式**：使用 query string 中的 token 進行認證
- **事件類型**：
  - `new_message` - 收到新訊息
  - `typing` - 使用者輸入指示器
  - `user_online` - 使用者上線
  - `user_offline` - 使用者離線
  - `message_read` - 訊息已讀回條
- **重新連線**：自動重連，採用指數退避策略（最多 5 次嘗試）
- **事件發布**：使用 Combine `PassthroughSubject`

### Token 管理

- **儲存方式**：透過 `KeychainManager` 安全儲存於 Keychain
- **授權機制**：所有 API 請求包含 `Authorization: Bearer <token>` header
- **過期處理**：透過 401 回應偵測
- **重新認證**：Token 過期時自動顯示提示

### 日誌記錄

透過 `AppLogger`（位於 `Logger.swift`）進行結構化日誌記錄：

```swift
AppLogger.shared.debug("開發資訊")
AppLogger.shared.info("重要事件")
AppLogger.shared.warning("可恢復的問題")
AppLogger.shared.error("發生錯誤", error: error)
AppLogger.shared.critical("嚴重故障")
```

## 專案結構

```
TeamChatUP/
├── TeamChatUP/
│   ├── TeamChatUPApp.swift          # 應用程式入口點、SwiftData schema
│   ├── AppConfig.swift              # 環境配置
│   ├── Models.swift                 # API 模型、APIClient、KeychainManager
│   │
│   ├── Authentication/
│   │   ├── PKCEAuthManager.swift    # 認證狀態管理
│   │   ├── PKCEManager.swift        # PKCE challenge 產生
│   │   └── LoginView.swift          # 登入 UI
│   │
│   ├── Managers/
│   │   ├── WebSocketManager.swift   # WebSocket 連線
│   │   ├── ConversationManager.swift
│   │   ├── MessageManager.swift
│   │   ├── UserManager.swift
│   │   └── SoundManager.swift
│   │
│   ├── Views/
│   │   ├── ConversationListView.swift
│   │   ├── ChatDetailView.swift
│   │   ├── UserListView.swift
│   │   └── DevicesView.swift
│   │
│   ├── Models/
│   │   ├── ChatRoom.swift           # SwiftData 模型
│   │   └── Message.swift            # SwiftData 模型
│   │
│   └── Utilities/
│       └── Logger.swift              # 結構化日誌
│
├── TeamChatUPTests/
└── TeamChatUPUITests/
```

## 開發指南

### 新增 API 端點

1. 在 `Models.swift` 中新增請求/回應模型
2. 在 `APIClient` 中新增方法（使用現有的 `get`/`post`/`delete` 輔助方法）
3. 從 manager 類別呼叫（例如：`ConversationManager`、`UserManager`）

### 新增 WebSocket 事件

1. 在 `WebSocketManager.swift` 的 `WebSocketEvent` enum 中新增 case
2. 在 `init(from:)` 和 `encode(to:)` 中處理解碼和編碼
3. 在 views/managers 中訂閱 `WebSocketManager.shared.eventPublisher`

### 跨平台考量

程式碼同時支援 iOS 和 macOS：
- 使用 `#if os(iOS)` / `#elseif os(macOS)` 處理平台特定程式碼
- 工具列位置：使用 `.automatic` 而非 `.navigationBarTrailing`
- Import 保護：`#if canImport(UIKit)` / `#elseif canImport(AppKit)`

## API 整合

### 基礎 URL

應用程式連接到後端 API，包含以下端點：

- **認證**：`/device-auth/token`、`/device-auth/devices`
- **對話**：`/conversations`、`/conversations/{id}/messages`
- **使用者**：`/users`、`/users/me`
- **訊息**：`/messages`、`/messages/{id}`

### WebSocket 連線

WebSocket URL 格式：
```
wss://your-server.com?token=<access_token>
```

## 安全性

- **Token 儲存**：Access token 安全儲存於 Keychain
- **PKCE 流程**：防止授權碼攔截攻擊
- **TLS/SSL**：所有網路通訊透過 HTTPS/WSS
- **Token 過期**：自動偵測並觸發重新認證流程

## 疑難排解

### WebSocket 連線問題

1. 檢查 Keychain 中的 token 有效性
2. 驗證 `AppConfig.swift` 中的 WebSocket URL
3. 檢查網路連線狀態
4. 在 Console.app 中查看詳細錯誤訊息

### 認證失敗

1. 驗證裝置授權 URL 是否正確
2. 檢查 PKCE verifier 是否正確儲存
3. 確認 URL scheme 已在 `Info.plist` 中註冊
4. 查看 `PKCEAuthManager` 日誌以取得詳細錯誤資訊

## 授權條款

[請在此新增授權條款]

## 聯絡方式

[請在此新增聯絡資訊]
