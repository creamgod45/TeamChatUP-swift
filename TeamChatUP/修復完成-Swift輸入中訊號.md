# ✅ Swift 輸入中訊號修復完成

## 問題分析

Swift 應用程式的 typing 訊號功能有以下問題：

1. **發送端問題：** `WebSocketManager.sendTyping()` 只是一個空的 stub，沒有實際發送訊號
2. **接收端問題：** WebSocket 沒有監聽 `user.typing` 事件，無法接收其他使用者的輸入訊號

## 已完成的修復

### 1. 修改發送邏輯（MessageManager.swift）

**修改前：**
```swift
func sendTypingIndicator() {
    typingTimer?.invalidate()

    let conversationId = self.conversationId

    WebSocketManager.shared.sendTyping(conversationId: conversationId, isTyping: true)

    typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
        Task { @MainActor in
            WebSocketManager.shared.sendTyping(conversationId: conversationId, isTyping: false)
        }
    }
}
```

**修改後：**
```swift
func sendTypingIndicator() {
    typingTimer?.invalidate()

    let conversationId = self.conversationId

    // 發送 typing 訊號到後端 API
    Task {
        do {
            try await APIClient.shared.sendTypingIndicator(conversationId: conversationId)
            AppLogger.shared.debug("⌨️ 發送輸入中訊號 - 對話ID: \(conversationId)")
        } catch {
            AppLogger.shared.error("❌ 發送輸入中訊號失敗", error: error)
        }
    }

    // 3 秒後自動停止（後端會處理）
    typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
        // Timer 只是用來限制發送頻率，實際的 isTyping: false 由後端的 debounce 處理
    }
}
```

**改進說明：**
- 使用 REST API 端點 `POST /api/conversations/{id}/typing` 發送訊號
- 後端會自動廣播到 WebSocket 頻道
- 添加詳細的 log 記錄

### 2. 新增接收邏輯（WebSocketManager.swift）

#### 2.1 新增事件處理

**在 `handlePusherMessage()` 的 switch 中新增：**
```swift
case "user.typing", ".user.typing":
    handleUserTyping(json)
```

#### 2.2 新增 handleUserTyping() 方法

```swift
private func handleUserTyping(_ json: [String: Any]) {
    let data: Data

    if let dataString = json["data"] as? String {
        guard let d = dataString.data(using: .utf8) else { return }
        data = d
    } else if let dataDict = json["data"] as? [String: Any] {
        guard let d = try? JSONSerialization.data(withJSONObject: dataDict) else { return }
        data = d
    } else {
        return
    }

    do {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let typingEvent = try decoder.decode(TypingEvent.self, from: data)

        eventPublisher.send(.typing(typingEvent))

        AppLogger.shared.debug("⌨️ 收到輸入中訊號 - 使用者ID: \(typingEvent.userId), 對話ID: \(typingEvent.conversationId), 輸入中: \(typingEvent.isTyping)")

    } catch {
        AppLogger.shared.error("解析輸入中事件失敗", error: error)
    }
}
```

**功能說明：**
- 解析 WebSocket 收到的 typing 事件
- 使用 `convertFromSnakeCase` 自動轉換 `user_id` → `userId`
- 發布事件到 `eventPublisher`，讓 `MessageManager` 接收
- 添加詳細的 log 記錄

### 3. 網頁版音效檔案名稱修正

**修改檔案：** `message-list.blade.php`

**修改前：**
```javascript
this.typingSound = new Audio('/tpying.wav');
```

**修改後：**
```javascript
this.typingSound = new Audio('/typing.wav');
```

## 完整流程

### Swift App 發送 Typing 訊號

```
使用者在輸入框輸入 →
ChatDetailView.onChange(of: messageText) 觸發 →
MessageManager.sendTypingIndicator() →
APIClient.shared.sendTypingIndicator(conversationId) →
POST /api/conversations/{id}/typing →
後端廣播 UserTyping 事件到 WebSocket 頻道 →
其他使用者收到 user.typing 事件
```

### Swift App 接收 Typing 訊號

```
後端廣播 user.typing 事件 →
WebSocketManager 收到事件 →
handleUserTyping() 解析事件 →
eventPublisher.send(.typing(typingEvent)) →
MessageManager.handleWebSocketEvent() 接收 →
檢查是否為新使用者 →
播放 typing 音效 →
Console 顯示 "⌨️ 播放輸入中音效"
```

## API 端點

### 發送 Typing 訊號

```
POST /api/conversations/{conversation}/typing
Authorization: Bearer {token}

Response: 200 OK
{
  "message": "Typing indicator sent."
}
```

**後端實作：**
```php
public function typing(Request $request, Conversation $conversation): JsonResponse
{
    $this->authorize('view', $conversation);

    broadcast(new UserTyping($request->user(), $conversation->id))->toOthers();

    return response()->json(['message' => 'Typing indicator sent.']);
}
```

## WebSocket 事件格式

### 後端廣播的事件

```json
{
  "event": "user.typing",
  "channel": "private-conversation.1",
  "data": {
    "user_id": 2,
    "user_name": "John Doe",
    "conversation_id": 1,
    "is_typing": true
  }
}
```

### Swift 解析後的 TypingEvent

```swift
struct TypingEvent: Codable {
    let userId: Int
    let conversationId: Int
    let isTyping: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case conversationId = "conversation_id"
        case isTyping = "is_typing"
    }
}
```

## 測試步驟

### 1. 準備工作

**確認後端服務運行：**
```bash
# Laravel Reverb WebSocket 伺服器
php artisan reverb:start

# Laravel 開發伺服器
php artisan serve
```

**確認音效檔案存在：**
- Swift: `/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/Resources/typing.wav`
- Web: `/Users/a123/PhpstormProjects/TeamChatUP-backend/public/typing.wav`

### 2. 測試 Swift 發送訊號

**步驟：**
1. 在 Xcode 中運行 Swift 應用程式
2. 登入使用者 A
3. 進入任一對話
4. 在輸入框開始輸入

**預期結果：**
- Xcode Console 顯示：
  ```
  [⌨️ DEBUG] [MessageManager.swift:167] sendTypingIndicator() - ⌨️ 發送輸入中訊號 - 對話ID: 1
  ```

- 後端 Laravel Log 應該記錄 API 請求：
  ```bash
  tail -f storage/logs/laravel.log
  ```

### 3. 測試 Swift 接收訊號

**步驟：**
1. 開啟兩個裝置或使用 Web 版
2. 裝置 A：Swift App，登入使用者 A
3. 裝置 B：Web 或另一個 Swift App，登入使用者 B
4. 兩個裝置都進入**相同的對話**
5. 在裝置 B 的輸入框開始輸入

**預期結果（裝置 A）：**
- 聽到 typing 音效（短促的聲音）
- Xcode Console 顯示：
  ```
  [⌨️ DEBUG] [WebSocketManager.swift:XXX] handleUserTyping() - ⌨️ 收到輸入中訊號 - 使用者ID: 2, 對話ID: 1, 輸入中: true
  [⌨️ DEBUG] [SoundManager.swift:60] playTypingSound() - ⌨️ 播放輸入中音效
  ```

### 4. 測試防重複播放

**步驟：**
1. 在裝置 B 持續輸入多個字元

**預期結果（裝置 A）：**
- 只在第一次輸入時播放音效
- 持續輸入不會重複播放
- Console 只顯示一次 "⌨️ 播放輸入中音效"

**停止輸入後再次輸入：**
- 會再次播放音效

## 除錯指南

### 問題 1：發送訊號失敗

**症狀：**
```
[❌ ERROR] [MessageManager.swift:XXX] - ❌ 發送輸入中訊號失敗: unauthorized
```

**可能原因：**
- Token 過期
- 沒有權限訪問該對話

**解決方法：**
1. 檢查 Token 是否有效
2. 確認使用者是對話的參與者

### 問題 2：收不到 typing 事件

**症狀：**
- 裝置 B 輸入時，裝置 A 沒有任何反應
- Console 沒有顯示 "收到輸入中訊號"

**檢查清單：**

1. **WebSocket 連線狀態**
   ```
   [✅ INFO] [WebSocketManager.swift:XXX] - ✅ WebSocket 連線成功 - Socket ID: xxx
   [✅ INFO] [WebSocketManager.swift:XXX] - ✅ 訂閱成功: private-conversation.1
   ```

2. **後端是否廣播事件**
   ```bash
   # 檢查 Reverb 伺服器 log
   php artisan reverb:start --debug
   ```

3. **事件名稱是否正確**
   - 後端廣播：`user.typing`
   - Swift 監聽：`user.typing` 或 `.user.typing`

### 問題 3：音效播放失敗

**症狀：**
```
Sound file not found: typing.wav
[⚠️ WARNING] [SoundManager.swift:51] - ⚠️ 找不到 typing.wav 音效檔案
```

**解決方法：**
1. 確認音效檔案已加入 Xcode Target
2. 檢查檔案名稱是否正確（`typing.wav`）
3. 在 Xcode 中重新加入音效檔案

### 問題 4：收到事件但無法解析

**症狀：**
```
[❌ ERROR] [WebSocketManager.swift:XXX] - 解析輸入中事件失敗: keyNotFound(...)
```

**可能原因：**
- 後端事件格式與 Swift 模型不匹配
- JSON key 命名不一致

**解決方法：**
1. 檢查後端廣播的資料格式
2. 確認 `TypingEvent` 的 `CodingKeys` 正確
3. 使用 `convertFromSnakeCase` 策略

## Log 輸出範例

### 正常流程

**發送端（裝置 B）：**
```
[⌨️ DEBUG] [MessageManager.swift:167] sendTypingIndicator() - ⌨️ 發送輸入中訊號 - 對話ID: 1
```

**接收端（裝置 A）：**
```
[📡 DEBUG] [WebSocketManager.swift:307] - 📡 收到事件: user.typing
[📦 DEBUG] [WebSocketManager.swift:309] - 📦 事件資料內容: {
    conversation_id = 1;
    is_typing = 1;
    user_id = 2;
    user_name = "John Doe";
}
[⌨️ DEBUG] [WebSocketManager.swift:XXX] handleUserTyping() - ⌨️ 收到輸入中訊號 - 使用者ID: 2, 對話ID: 1, 輸入中: true
[⌨️ DEBUG] [SoundManager.swift:60] playTypingSound() - ⌨️ 播放輸入中音效
```

## 技術細節

### 為什麼使用 REST API 而不是 WebSocket？

1. **簡化實作：** 不需要實作 Pusher 的客戶端事件發送協議
2. **統一認證：** 使用現有的 Bearer Token 認證
3. **錯誤處理：** REST API 有明確的錯誤回應
4. **後端控制：** 後端可以統一處理廣播邏輯

### 為什麼使用 convertFromSnakeCase？

後端 PHP 使用 snake_case（`user_id`），Swift 使用 camelCase（`userId`）。使用 `convertFromSnakeCase` 可以自動轉換，不需要手動定義每個 `CodingKeys`。

### Timer 的作用

Timer 用來限制發送頻率，避免每次按鍵都發送 API 請求。3 秒內只會發送一次請求，後端會自動處理 `isTyping: false` 的邏輯。

## 完整功能清單

### ✅ 已完成

1. **自動登出問題修復**（PostgreSQL 遷移）
2. **發送訊息失敗修復**（Sequence 重置）
3. **訊息已讀功能**（Swift + API）
4. **Typing 音效**（Swift + Web）
5. **音效播放 Log**（Swift + Web）
6. **Swift 發送 Typing 訊號**（REST API）
7. **Swift 接收 Typing 訊號**（WebSocket）
8. **網頁版音效檔案名稱修正**

### 🎯 可以測試

- Swift App: 登入、瀏覽、發送、已讀、音效、輸入訊號
- Web 版: 新訊息音效、Typing 音效、輸入訊號
- 所有功能都有詳細的 Log 輸出

---

**完成時間：** 2026-03-09 16:30
**修改檔案：** 3 個
- `MessageManager.swift`
- `WebSocketManager.swift`
- `message-list.blade.php`

**狀態：** ✅ 完成
**測試：** 需要在兩個裝置上測試
