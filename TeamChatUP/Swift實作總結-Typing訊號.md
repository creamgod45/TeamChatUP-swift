# Swift Typing 訊號接收與處理 - 實作總結

## 📋 規格說明

### 後端廣播格式

**WebSocket 事件：**
```json
{
  "event": "user.typing",
  "channel": "private-conversation.{id}",
  "data": {
    "user_id": 1,
    "user_name": "User Name",
    "conversation_id": 1,
    "is_typing": true
  }
}
```

### Swift 資料模型

**檔案：** `Models.swift`

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

## 🔧 Swift 實作（3 個檔案）

### 1. WebSocketManager.swift

#### 步驟 1：在 switch 中添加事件處理

**位置：** `handlePusherMessage()` 方法的 switch 語句

```swift
switch event {
case "pusher:connection_established":
    handleConnectionEstablished(json)

case "pusher:subscription_succeeded", "pusher_internal:subscription_succeeded":
    handleSubscriptionSucceeded(json)

case "pusher:subscription_error":
    handleSubscriptionError(json)

case "message.sent", ".message.sent":
    handleMessageSent(json)

case "user.typing", ".user.typing":  // ← 新增這行
    handleUserTyping(json)           // ← 新增這行

case "pusher:pong":
    break

default:
    AppLogger.shared.debug("未處理的事件: \(event)")
}
```

#### 步驟 2：新增 handleUserTyping() 方法

**位置：** 在 `handleMessageSent()` 方法之後

```swift
private func handleUserTyping(_ json: [String: Any]) {
    let data: Data

    // 解析 data 欄位（可能是 String 或 Dictionary）
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase  // 自動轉換 user_id → userId

        let typingEvent = try decoder.decode(TypingEvent.self, from: data)

        // 發布事件到 eventPublisher
        eventPublisher.send(.typing(typingEvent))

        AppLogger.shared.debug("⌨️ 收到輸入中訊號 - 使用者ID: \(typingEvent.userId), 對話ID: \(typingEvent.conversationId), 輸入中: \(typingEvent.isTyping)")

    } catch {
        AppLogger.shared.error("解析輸入中事件失敗", error: error)
    }
}
```

#### 步驟 3：添加頻道 log（可選，用於除錯）

**位置：** `handlePusherMessage()` 方法中，在 switch 之前

```swift
AppLogger.shared.debug("📡 收到事件: \(event)")
if let dataValue = json["data"] {
    AppLogger.shared.debug("📦 事件資料內容: \(dataValue)")
}
if let channel = json["channel"] as? String {  // ← 新增這 3 行
    AppLogger.shared.debug("📺 事件頻道: \(channel)")
}

switch event {
    // ...
}
```

### 2. MessageManager.swift

**已實作完成** ✅

**位置：** `handleWebSocketEvent()` 方法

```swift
private func handleWebSocketEvent(_ event: WebSocketEvent) {
    switch event {
    case .newMessage(let message):
        if message.conversationId == conversationId {
            addReceivedMessage(message)
        }

    case .typing(let typingEvent):
        if typingEvent.conversationId == conversationId {
            if typingEvent.isTyping {
                // 只在新增使用者時播放音效（避免重複播放）
                let isNewTypingUser = !typingUsers.contains(typingEvent.userId)
                typingUsers.insert(typingEvent.userId)

                // 播放 typing 音效
                if isNewTypingUser {
                    SoundManager.shared.playTypingSound()
                }
            } else {
                typingUsers.remove(typingEvent.userId)
            }
        }

    case .messageRead(let readEvent):
        if readEvent.conversationId == conversationId {
            // 處理已讀狀態
        }

    default:
        break
    }
}
```

**說明：**
- ✅ 檢查 `conversationId` 是否匹配
- ✅ 使用 `typingUsers` Set 防止重複播放
- ✅ 只在新使用者開始輸入時播放音效
- ✅ 停止輸入時從 Set 中移除

### 3. SoundManager.swift

**已實作完成** ✅

```swift
func playTypingSound() {
    guard let soundURL = Bundle.main.url(forResource: "typing", withExtension: "wav") else {
        print("Sound file not found: typing.wav")
        AppLogger.shared.warning("⚠️ 找不到 typing.wav 音效檔案")
        return
    }

    do {
        audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
        audioPlayer?.volume = 0.3  // 音量 30%
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        AppLogger.shared.debug("⌨️ 播放輸入中音效")
    } catch {
        print("Failed to play typing sound: \(error)")
        AppLogger.shared.error("❌ 播放輸入音效失敗: \(error)")
    }
}
```

**說明：**
- ✅ 音效檔案：`typing.wav`
- ✅ 音量：30%（避免太吵）
- ✅ 完整的錯誤處理和 log

## 🔄 完整處理流程

```
1. 網頁版使用者輸入
   ↓
2. 後端廣播 user.typing 事件到 WebSocket
   ↓
3. Swift WebSocketManager 收到事件
   ↓
4. handlePusherMessage() 識別事件類型
   ↓
5. handleUserTyping() 解析 JSON
   ↓
6. 轉換為 TypingEvent 物件
   ↓
7. eventPublisher.send(.typing(typingEvent))
   ↓
8. MessageManager.handleWebSocketEvent() 接收
   ↓
9. 檢查 conversationId 是否匹配
   ↓
10. 檢查是否為新使用者（防重複）
    ↓
11. SoundManager.playTypingSound()
    ↓
12. 🔊 播放音效
```

## 🎯 關鍵設計

### 1. 自動轉換 JSON Key

```swift
decoder.keyDecodingStrategy = .convertFromSnakeCase
```

**效果：**
- `user_id` → `userId`
- `conversation_id` → `conversationId`
- `is_typing` → `isTyping`

### 2. 防重複播放機制

```swift
let isNewTypingUser = !typingUsers.contains(typingEvent.userId)
typingUsers.insert(typingEvent.userId)

if isNewTypingUser {
    SoundManager.shared.playTypingSound()
}
```

**效果：**
- 同一使用者持續輸入不會重複播放
- 停止輸入後再次輸入會再次播放
- 多個使用者同時輸入，每個使用者只播放一次

### 3. 過濾自己的事件

**MessageManager 不需要額外過濾**，因為：
- 後端使用 `->toOthers()` 廣播
- 發送者不會收到自己的事件

## 📊 Log 輸出範例

### 正常流程

```
[📡 DEBUG] 收到事件: user.typing
[📺 DEBUG] 事件頻道: private-conversation.7
[📦 DEBUG] 事件資料內容: {
    conversation_id = 7;
    is_typing = 1;
    user_id = 12;
    user_name = "fu xian wang";
}
[⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: 12, 對話ID: 7, 輸入中: true
[⌨️ DEBUG] 播放輸入中音效
```

### 錯誤情況

**音效檔案不存在：**
```
Sound file not found: typing.wav
[⚠️ WARNING] 找不到 typing.wav 音效檔案
```

**JSON 解析失敗：**
```
[❌ ERROR] 解析輸入中事件失敗: keyNotFound(...)
```

## ✅ 驗證清單

### 程式碼檢查

- [x] WebSocketManager.swift 有 `case "user.typing", ".user.typing"`
- [x] WebSocketManager.swift 有 `handleUserTyping()` 方法
- [x] MessageManager.swift 有 `case .typing(let typingEvent)` 處理
- [x] SoundManager.swift 有 `playTypingSound()` 方法
- [x] 音效檔案 `typing.wav` 存在於 `/Resource/` 目錄

### 功能測試

- [ ] Swift 能收到 user.typing 事件
- [ ] Console 顯示 "收到輸入中訊號"
- [ ] Console 顯示 "播放輸入中音效"
- [ ] 實際聽到音效
- [ ] 持續輸入不會重複播放
- [ ] 停止後再次輸入會再次播放

## 🔧 測試步驟

1. **在 Xcode 中 Clean Build**
   ```
   Shift + Command + K
   ```

2. **運行應用程式**
   ```
   Command + R
   ```

3. **登入並進入對話**
   - 登入使用者（不是網頁版的使用者）
   - 進入對話 ID = 7

4. **在網頁版輸入**
   - 網頁版使用者在同一對話輸入文字

5. **觀察 Xcode Console**
   - 搜尋：`user.typing`
   - 搜尋：`播放輸入中音效`

6. **確認聽到音效** 🔊

---

**實作狀態：** ✅ 完成
**需要修改的檔案：** 3 個
**預計測試時間：** 5 分鐘
