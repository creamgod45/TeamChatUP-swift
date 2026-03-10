# iOS/macOS 應用程式開發指南

## 概述

本文件為開發 TeamChatUP iOS/macOS 原生應用程式的 AI Agent 提供完整的開發規範與 API 端點說明。

---

## 一、認證流程 (Authentication Flow)

### 1.1 WorkOS OAuth 整合

**流程：**
```
1. 使用者在 iOS/macOS app 點擊登入
2. App 開啟 WorkOS OAuth 授權頁面（使用 ASWebAuthenticationSession）
3. 使用者完成 SSO 認證
4. WorkOS 重導向回 app 並提供 authorization_code
5. App 呼叫後端 API 交換 Sanctum token
6. App 儲存 token 到 Keychain（iOS）或 Keychain Access（macOS）
```

**關鍵端點：**
```http
POST /api/auth/token
Content-Type: application/json

{
  "authorization_code": "workos_auth_code_here",
  "device_name": "iPhone 15 Pro" // 用於識別 token
}

Response:
{
  "token": "1|xxxxx...",
  "user": {
    "id": 1,
    "name": "User Name",
    "email": "user@example.com",
    "avatar": "https://...",
    "role": "user"
  }
}
```

### 1.2 Token 管理

**儲存位置：**
- iOS: Keychain Services
- macOS: Keychain Access

**Token 使用：**
```swift
// 所有 API 請求都需要在 header 中包含 token
Authorization: Bearer {token}
```

**Token 撤銷：**
```http
POST /api/auth/logout
Authorization: Bearer {token}
```

**取得當前使用者資訊：**
```http
GET /api/auth/me
Authorization: Bearer {token}
```

---

## 二、核心 API 端點 (Core API Endpoints)

### 2.1 對話管理 (Conversations)

#### 列出所有對話
```http
GET /api/conversations
Authorization: Bearer {token}

Query Parameters:
- page: int (分頁頁碼，預設 1)
- per_page: int (每頁數量，預設 20)

Response:
{
  "data": [
    {
      "id": 1,
      "name": "Group Chat Name", // 群組對話才有
      "type": "direct|group",
      "participants": [...],
      "last_message": {...},
      "unread_count": 5,
      "created_at": "2026-03-07T10:00:00Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "total": 50
  }
}
```

#### 建立新對話
```http
POST /api/conversations
Authorization: Bearer {token}
Content-Type: application/json

{
  "type": "direct|group",
  "name": "Group Name", // type=group 時必填
  "participant_ids": [2, 3, 4] // 參與者 user IDs
}

Response:
{
  "data": {
    "id": 1,
    "name": "Group Name",
    "type": "group",
    "participants": [...],
    "created_at": "2026-03-07T10:00:00Z"
  }
}
```

#### 取得對話詳情
```http
GET /api/conversations/{id}
Authorization: Bearer {token}

Response:
{
  "data": {
    "id": 1,
    "name": "Group Name",
    "type": "group",
    "participants": [
      {
        "id": 1,
        "name": "User 1",
        "avatar": "https://..."
      }
    ],
    "last_message": {...},
    "unread_count": 5
  }
}
```

#### 標記對話為已讀
```http
POST /api/conversations/{id}/read
Authorization: Bearer {token}

Response:
{
  "message": "Conversation marked as read"
}
```

#### 新增參與者（僅群組對話）
```http
POST /api/conversations/{id}/participants
Authorization: Bearer {token}
Content-Type: application/json

{
  "user_id": 5
}
```

#### 移除參與者（僅群組對話）
```http
DELETE /api/conversations/{id}/participants/{user_id}
Authorization: Bearer {token}
```

### 2.2 訊息管理 (Messages)

#### 取得對話訊息列表
```http
GET /api/conversations/{conversation_id}/messages
Authorization: Bearer {token}

Query Parameters:
- page: int (分頁頁碼，預設 1)
- per_page: int (每頁數量，預設 50)

Response:
{
  "data": [
    {
      "id": 1,
      "content": "Hello!",
      "type": "text|system",
      "user": {
        "id": 1,
        "name": "User Name",
        "avatar": "https://..."
      },
      "conversation_id": 1,
      "created_at": "2026-03-07T10:00:00Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "total": 100
  }
}
```

#### 發送訊息
```http
POST /api/conversations/{conversation_id}/messages
Authorization: Bearer {token}
Content-Type: application/json

{
  "content": "Hello, world!",
  "type": "text" // 預設為 text
}

Response:
{
  "data": {
    "id": 1,
    "content": "Hello, world!",
    "type": "text",
    "user": {...},
    "created_at": "2026-03-07T10:00:00Z"
  }
}
```

#### 廣播輸入狀態
```http
POST /api/conversations/{conversation_id}/typing
Authorization: Bearer {token}

Response:
{
  "message": "Typing indicator sent"
}
```

**注意：** 輸入狀態應該使用 debounce（500ms），避免過度呼叫。

### 2.3 Webhook 管理 (Webhooks)

#### 列出使用者的 Webhooks
```http
GET /api/webhooks
Authorization: Bearer {token}
```

#### 建立 Webhook
```http
POST /api/webhooks
Authorization: Bearer {token}
Content-Type: application/json

{
  "url": "https://your-server.com/webhook",
  "events": ["message.sent", "conversation.created"]
}
```

#### 測試 Webhook
```http
POST /api/webhooks/{id}/test
Authorization: Bearer {token}
```

---

## 三、WebSocket 即時通訊 (Real-time Communication)

### 3.1 連線設定

**使用 Laravel Echo + Pusher JS (或 Socket.IO)**

```swift
// iOS/macOS 需要使用支援 WebSocket 的函式庫
// 推薦：Starscream (WebSocket) + 自訂 Echo 實作
// 或使用：pusher-websocket-swift

// 連線設定
let options = PusherClientOptions(
    authMethod: .authRequestBuilder(authRequestBuilder: AuthRequestBuilder()),
    host: .host("your-reverb-host.com"),
    port: 8080,
    encrypted: false // 生產環境使用 true
)

// 認證 header
class AuthRequestBuilder: AuthRequestBuilderProtocol {
    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        var request = URLRequest(url: URL(string: "https://your-api.com/broadcasting/auth")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "socket_id": socketID,
            "channel_name": channelName
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return request
    }
}
```

### 3.2 訂閱頻道

#### Private Channel - 對話訊息
```swift
// 訂閱特定對話的訊息
let channel = pusher.subscribe(channelName: "private-conversation.\(conversationId)")

// 監聽新訊息事件
channel.bind(eventName: "message.sent") { (event: PusherEvent) in
    if let data = event.data,
       let json = try? JSONSerialization.jsonObject(with: data.data(using: .utf8)!) as? [String: Any] {
        // 處理新訊息
        let message = json["message"]
        // 更新 UI
    }
}

// 監聽輸入狀態
channel.bind(eventName: "user.typing") { (event: PusherEvent) in
    if let data = event.data,
       let json = try? JSONSerialization.jsonObject(with: data.data(using: .utf8)!) as? [String: Any] {
        let userId = json["user_id"]
        let userName = json["user_name"]
        // 顯示 "XXX is typing..."
    }
}
```

#### Presence Channel - 線上狀態
```swift
// 訂閱線上使用者頻道
let presenceChannel = pusher.subscribe(channelName: "presence-chat")

// 當前線上使用者
presenceChannel.bind(eventName: "pusher:subscription_succeeded") { (event: PusherEvent) in
    if let members = presenceChannel.members {
        // 顯示線上使用者列表
    }
}

// 使用者上線
presenceChannel.bind(eventName: "pusher:member_added") { (event: PusherEvent) in
    // 更新線上使用者列表
}

// 使用者離線
presenceChannel.bind(eventName: "pusher:member_removed") { (event: PusherEvent) in
    // 更新線上使用者列表
}
```

---

## 四、平台特定功能 (Platform-Specific Features)

### 4.1 推送通知 (Push Notifications)

**iOS APNs 整合：**

1. **註冊 Device Token**
```http
POST /api/devices/register
Authorization: Bearer {token}
Content-Type: application/json

{
  "device_token": "apns_device_token_here",
  "platform": "ios",
  "device_name": "iPhone 15 Pro"
}
```

2. **處理推送通知 Payload**
```json
{
  "aps": {
    "alert": {
      "title": "New Message",
      "body": "User Name: Hello!"
    },
    "badge": 5,
    "sound": "default"
  },
  "conversation_id": 1,
  "message_id": 123,
  "type": "message"
}
```

3. **點擊通知後的處理**
```swift
// 開啟對應的對話
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse,
                           withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo

    if let conversationId = userInfo["conversation_id"] as? Int {
        // 導航到對話頁面
        navigateToConversation(id: conversationId)
    }

    completionHandler()
}
```

### 4.2 背景同步 (Background Sync)

**iOS Background Fetch：**
```swift
// 定期同步未讀訊息數量
func application(_ application: UIApplication,
                performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

    APIClient.shared.getUnreadCount { result in
        switch result {
        case .success(let count):
            UIApplication.shared.applicationIconBadgeNumber = count
            completionHandler(.newData)
        case .failure:
            completionHandler(.failed)
        }
    }
}
```

### 4.3 本地儲存 (Local Storage)

**使用 Core Data 或 Realm 快取資料：**

```swift
// 快取對話列表
struct ConversationCache {
    static func save(conversations: [Conversation]) {
        // 儲存到 Core Data
    }

    static func load() -> [Conversation] {
        // 從 Core Data 讀取
    }
}

// 快取訊息
struct MessageCache {
    static func save(messages: [Message], for conversationId: Int) {
        // 儲存到 Core Data
    }

    static func load(for conversationId: Int) -> [Message] {
        // 從 Core Data 讀取
    }
}
```

---

## 五、錯誤處理 (Error Handling)

### 5.1 HTTP 錯誤碼

| 狀態碼 | 說明 | 處理方式 |
|--------|------|----------|
| 401 | 未認證 | 清除 token，導向登入頁面 |
| 403 | 無權限 | 顯示錯誤訊息 |
| 404 | 資源不存在 | 顯示錯誤訊息 |
| 422 | 驗證失敗 | 顯示驗證錯誤訊息 |
| 429 | 請求過於頻繁 | 顯示 rate limit 錯誤，延遲重試 |
| 500 | 伺服器錯誤 | 顯示通用錯誤訊息，記錄錯誤 |

### 5.2 錯誤回應格式

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "content": [
      "The content field is required."
    ]
  }
}
```

### 5.3 網路錯誤處理

```swift
enum APIError: Error {
    case unauthorized
    case forbidden
    case notFound
    case validationError([String: [String]])
    case rateLimited
    case serverError
    case networkError(Error)
    case unknown
}

// 統一錯誤處理
func handleError(_ error: APIError) {
    switch error {
    case .unauthorized:
        // 清除 token，導向登入
        logout()
    case .rateLimited:
        // 顯示 rate limit 提示
        showAlert("請求過於頻繁，請稍後再試")
    case .networkError(let underlyingError):
        // 檢查網路連線
        if !isNetworkAvailable {
            showAlert("無網路連線")
        }
    default:
        showAlert("發生錯誤，請稍後再試")
    }
}
```

---

## 六、效能優化 (Performance Optimization)

### 6.1 分頁載入

**對話列表：**
- 初次載入：20 筆
- 下拉刷新：重新載入前 20 筆
- 上滑載入更多：每次載入 20 筆

**訊息列表：**
- 初次載入：50 筆最新訊息
- 上滑載入歷史：每次載入 50 筆
- 使用反向分頁（從最新往舊載入）

### 6.2 圖片快取

```swift
// 使用 SDWebImage 或 Kingfisher
imageView.sd_setImage(with: URL(string: user.avatar),
                      placeholderImage: UIImage(named: "avatar_placeholder"))
```

### 6.3 訊息去重

```swift
// 使用 message ID 去重
var messageIds = Set<Int>()

func addMessage(_ message: Message) {
    guard !messageIds.contains(message.id) else { return }
    messageIds.insert(message.id)
    messages.append(message)
}
```

### 6.4 樂觀更新 (Optimistic Updates)

```swift
// 發送訊息時立即顯示在 UI
func sendMessage(content: String) {
    let tempMessage = Message(
        id: -1, // 臨時 ID
        content: content,
        user: currentUser,
        createdAt: Date(),
        isSending: true
    )

    messages.append(tempMessage)
    updateUI()

    // 非同步發送到伺服器
    APIClient.shared.sendMessage(content: content) { result in
        switch result {
        case .success(let message):
            // 替換臨時訊息
            if let index = messages.firstIndex(where: { $0.id == -1 }) {
                messages[index] = message
                updateUI()
            }
        case .failure(let error):
            // 標記為失敗，允許重試
            if let index = messages.firstIndex(where: { $0.id == -1 }) {
                messages[index].isFailed = true
                updateUI()
            }
        }
    }
}
```

---

## 七、安全性考量 (Security Considerations)

### 7.1 Token 安全

- ✅ 使用 Keychain 儲存 token（不要使用 UserDefaults）
- ✅ 使用 HTTPS 進行所有 API 請求
- ✅ 實作 SSL Pinning（生產環境）
- ✅ Token 過期後自動重新認證

### 7.2 輸入驗證

```swift
// 訊息內容驗證
func validateMessage(_ content: String) -> Bool {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && trimmed.count <= 5000
}
```

### 7.3 防止 XSS

- ✅ 後端已使用 `strip_tags` 清理 HTML
- ✅ 前端顯示時使用純文字（不要使用 HTML 渲染）

---

## 八、測試策略 (Testing Strategy)

### 8.1 單元測試

```swift
// 測試 API Client
class APIClientTests: XCTestCase {
    func testGetConversations() async throws {
        let conversations = try await APIClient.shared.getConversations()
        XCTAssertFalse(conversations.isEmpty)
    }

    func testSendMessage() async throws {
        let message = try await APIClient.shared.sendMessage(
            conversationId: 1,
            content: "Test message"
        )
        XCTAssertEqual(message.content, "Test message")
    }
}
```

### 8.2 UI 測試

```swift
// 測試聊天流程
class ChatUITests: XCTestCase {
    func testSendMessage() throws {
        let app = XCUIApplication()
        app.launch()

        // 登入
        app.buttons["Login"].tap()

        // 選擇對話
        app.tables.cells.firstMatch.tap()

        // 輸入訊息
        let textField = app.textFields["Message Input"]
        textField.tap()
        textField.typeText("Hello, world!")

        // 發送
        app.buttons["Send"].tap()

        // 驗證訊息顯示
        XCTAssertTrue(app.staticTexts["Hello, world!"].exists)
    }
}
```

---

## 九、部署與監控 (Deployment & Monitoring)

### 9.1 環境設定

```swift
// 使用不同的 API endpoint
enum Environment {
    case development
    case staging
    case production

    var apiBaseURL: String {
        switch self {
        case .development:
            return "https://teamchatup-backend.test/api"
        case .staging:
            return "https://staging-api.teamchatup.com/api"
        case .production:
            return "https://api.teamchatup.com/api"
        }
    }

    var websocketURL: String {
        switch self {
        case .development:
            return "wss://teamchatup-backend.test"
        case .staging:
            return "wss://staging-ws.teamchatup.com"
        case .production:
            return "wss://ws.teamchatup.com"
        }
    }
}
```

### 9.2 錯誤追蹤

```swift
// 整合 Sentry 或 Firebase Crashlytics
import Sentry

// 記錄錯誤
SentrySDK.capture(error: error)

// 記錄自訂事件
SentrySDK.capture(message: "User sent message") { scope in
    scope.setExtra(value: conversationId, key: "conversation_id")
}
```

### 9.3 分析追蹤

```swift
// 整合 Firebase Analytics 或 Mixpanel
Analytics.logEvent("message_sent", parameters: [
    "conversation_id": conversationId,
    "message_length": content.count
])
```

---

## 十、開發檢查清單 (Development Checklist)

### 認證與授權
- [ ] 實作 WorkOS OAuth 流程
- [ ] 使用 Keychain 儲存 token
- [ ] 實作 token 過期處理
- [ ] 實作自動重新認證

### API 整合
- [ ] 實作所有核心 API 端點
- [ ] 實作錯誤處理
- [ ] 實作 rate limiting 處理
- [ ] 實作網路狀態檢測

### WebSocket
- [ ] 實作 WebSocket 連線
- [ ] 實作訊息接收
- [ ] 實作輸入狀態廣播
- [ ] 實作線上狀態追蹤
- [ ] 實作斷線重連

### UI/UX
- [ ] 實作對話列表
- [ ] 實作訊息列表（含分頁）
- [ ] 實作訊息輸入
- [ ] 實作樂觀更新
- [ ] 實作載入狀態
- [ ] 實作錯誤提示

### 效能
- [ ] 實作圖片快取
- [ ] 實作訊息去重
- [ ] 實作分頁載入
- [ ] 實作本地資料快取

### 安全性
- [ ] 使用 HTTPS
- [ ] 實作 SSL Pinning
- [ ] 驗證使用者輸入
- [ ] 防止 XSS 攻擊

### 測試
- [ ] 撰寫單元測試
- [ ] 撰寫 UI 測試
- [ ] 測試離線模式
- [ ] 測試推送通知

### 部署
- [ ] 設定環境變數
- [ ] 整合錯誤追蹤
- [ ] 整合分析工具
- [ ] 準備 App Store 提交資料

---

## 附錄：完整 API 端點列表

### 認證
- `POST /api/auth/token` - 交換 Sanctum token
- `POST /api/auth/logout` - 登出
- `GET /api/auth/me` - 取得當前使用者

### 對話
- `GET /api/conversations` - 列出對話
- `POST /api/conversations` - 建立對話
- `GET /api/conversations/{id}` - 取得對話詳情
- `PUT /api/conversations/{id}` - 更新對話
- `DELETE /api/conversations/{id}` - 刪除對話
- `POST /api/conversations/{id}/read` - 標記為已讀
- `POST /api/conversations/{id}/participants` - 新增參與者
- `DELETE /api/conversations/{id}/participants/{user_id}` - 移除參與者

### 訊息
- `GET /api/conversations/{id}/messages` - 取得訊息列表
- `POST /api/conversations/{id}/messages` - 發送訊息
- `PUT /api/messages/{id}` - 編輯訊息（5分鐘內）
- `DELETE /api/messages/{id}` - 刪除訊息
- `POST /api/conversations/{id}/typing` - 廣播輸入狀態

### Webhooks
- `GET /api/webhooks` - 列出 webhooks
- `POST /api/webhooks` - 建立 webhook
- `GET /api/webhooks/{id}` - 取得 webhook 詳情
- `PUT /api/webhooks/{id}` - 更新 webhook
- `DELETE /api/webhooks/{id}` - 刪除 webhook
- `POST /api/webhooks/{id}/test` - 測試 webhook
- `POST /api/webhooks/{id}/activate` - 啟用 webhook
- `POST /api/webhooks/{id}/deactivate` - 停用 webhook
- `GET /api/webhooks/{id}/deliveries` - 取得傳送記錄

### Broadcasting
- `POST /broadcasting/auth` - WebSocket 頻道認證

---

## 聯絡資訊

如有任何問題或需要協助，請聯絡開發團隊。

## staging 資訊

url https://teamchatup-backend.test
host teamchatup-backend.test
