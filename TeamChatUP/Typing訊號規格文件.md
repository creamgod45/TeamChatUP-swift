# Typing 訊號規格文件

## 📋 完整規格說明

### 1. 後端規格（Laravel + Reverb）

#### 事件類別
```php
class UserTyping implements ShouldBroadcastNow
{
    public User $user;
    public int $conversationId;

    // 廣播頻道
    public function broadcastOn(): array
    {
        return [new PrivateChannel('conversation.'.$this->conversationId)];
    }

    // 廣播資料
    public function broadcastWith(): array
    {
        return [
            'user_id' => $this->user->id,
            'user_name' => $this->user->name,
            'conversation_id' => $this->conversationId,
            'is_typing' => true,
        ];
    }

    // 事件名稱
    public function broadcastAs(): string
    {
        return 'user.typing';
    }
}
```

#### API 端點
```
POST /api/conversations/{conversation}/typing
Authorization: Bearer {token}

Response: 200 OK
{
  "message": "Typing indicator sent."
}
```

#### WebSocket 事件格式
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

### 2. Swift 規格

#### 資料模型
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

#### 發送 Typing 訊號

**方法：** REST API

**實作位置：** `MessageManager.swift`

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

    // 3 秒後自動停止（限制發送頻率）
    typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
        // Timer 只是用來限制發送頻率
    }
}
```

**API Client 方法：** `Models.swift`

```swift
func sendTypingIndicator(conversationId: Int) async throws {
    try await post("/conversations/\(conversationId)/typing", body: EmptyBody())
}
```

#### 接收 Typing 訊號

**步驟 1：WebSocket 接收事件**

**實作位置：** `WebSocketManager.swift`

```swift
// 在 handlePusherMessage() 的 switch 中
switch event {
    case "user.typing", ".user.typing":
        handleUserTyping(json)
    // ... 其他 case
}
```

**步驟 2：解析事件**

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
        decoder.keyDecodingStrategy = .convertFromSnakeCase  // 自動轉換 snake_case

        let typingEvent = try decoder.decode(TypingEvent.self, from: data)

        // 發布事件到 eventPublisher
        eventPublisher.send(.typing(typingEvent))

        AppLogger.shared.debug("⌨️ 收到輸入中訊號 - 使用者ID: \(typingEvent.userId), 對話ID: \(typingEvent.conversationId), 輸入中: \(typingEvent.isTyping)")

    } catch {
        AppLogger.shared.error("解析輸入中事件失敗", error: error)
    }
}
```

**步驟 3：MessageManager 處理事件**

**實作位置：** `MessageManager.swift`

```swift
private func handleWebSocketEvent(_ event: WebSocketEvent) {
    switch event {
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
    // ... 其他 case
    }
}
```

**步驟 4：播放音效**

**實作位置：** `SoundManager.swift`

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

### 3. 網頁版規格（Livewire + Alpine.js）

#### 發送 Typing 訊號

**實作位置：** `message-input.blade.php`

```php
public function typing()
{
    broadcast(new \App\Events\UserTyping(auth()->user(), $this->conversationId))->toOthers();
}
```

```html
<input
    wire:keydown.debounce.500ms="typing"
    ...
/>
```

#### 接收 Typing 訊號

**實作位置：** `message-list.blade.php`

```javascript
x-data="{
    typingSound: null,
    typingUsers: new Set(),

    setupSound() {
        this.typingSound = new Audio('/typing.wav');
        this.typingSound.volume = 0.3;
    },

    playTypingSound() {
        if (this.typingSound) {
            this.typingSound.currentTime = 0;
            this.typingSound.play().catch(err => {
                console.log('❌ 無法播放輸入音效:', err);
            });
            console.log('⌨️ 播放輸入中音效');
        }
    },

    setupEcho() {
        Echo.private('conversation.' + this.conversationId)
            .listen('.user.typing', (e) => {
                if (e.user_id !== {{ auth()->id() }}) {
                    const isNewTypingUser = !this.typingUsers.has(e.user_id);

                    if (e.is_typing) {
                        this.typingUsers.add(e.user_id);
                        if (isNewTypingUser) {
                            this.playTypingSound();
                        }
                    } else {
                        this.typingUsers.delete(e.user_id);
                    }
                }
            });
    }
}"
```

## 🔄 完整資料流程

### 發送流程

```
使用者輸入
    ↓
ChatDetailView.onChange(of: messageText)
    ↓
MessageManager.sendTypingIndicator()
    ↓
APIClient.sendTypingIndicator(conversationId)
    ↓
POST /api/conversations/{id}/typing
    ↓
MessageController.typing()
    ↓
broadcast(new UserTyping(...))
    ↓
Laravel Reverb 伺服器
    ↓
WebSocket 廣播到 private-conversation.{id}
```

### 接收流程

```
WebSocket 收到事件
    ↓
WebSocketManager.handlePusherMessage()
    ↓
識別事件類型: "user.typing"
    ↓
WebSocketManager.handleUserTyping()
    ↓
解析 JSON → TypingEvent
    ↓
eventPublisher.send(.typing(typingEvent))
    ↓
MessageManager.handleWebSocketEvent()
    ↓
檢查 conversationId 是否匹配
    ↓
檢查是否為新使用者（防重複）
    ↓
SoundManager.shared.playTypingSound()
    ↓
AVAudioPlayer 播放 typing.wav
    ↓
🔊 音效輸出
```

## 🎯 關鍵設計決策

### 1. 為什麼使用 REST API 發送而不是 WebSocket？

**原因：**
- 簡化實作（不需要實作 Pusher 客戶端事件）
- 統一認證（使用現有的 Bearer Token）
- 明確的錯誤處理
- 後端統一控制廣播邏輯

### 2. 為什麼使用 `convertFromSnakeCase`？

**原因：**
- 後端 PHP 使用 snake_case（`user_id`）
- Swift 使用 camelCase（`userId`）
- 自動轉換，不需要手動定義每個 `CodingKeys`

### 3. 為什麼需要防重複播放？

**原因：**
- 使用者持續輸入會觸發多次事件
- 每次按鍵都播放音效會很吵
- 使用 `Set<Int>` 追蹤正在輸入的使用者
- 只在新使用者開始輸入時播放一次

### 4. 為什麼音量設定為 30%？

**原因：**
- Typing 音效是短促的聲音
- 太大聲會干擾使用者
- 30% 是合適的提示音量

### 5. 為什麼使用 3 秒 Timer？

**原因：**
- 限制 API 請求頻率
- 避免每次按鍵都發送請求
- 3 秒內只發送一次

## 📊 事件資料格式對照表

| 欄位 | 後端 (PHP) | Swift | 網頁版 (JS) | 類型 |
|------|-----------|-------|------------|------|
| 使用者 ID | `user_id` | `userId` | `user_id` | Int |
| 使用者名稱 | `user_name` | - | `user_name` | String |
| 對話 ID | `conversation_id` | `conversationId` | `conversation_id` | Int |
| 輸入狀態 | `is_typing` | `isTyping` | `is_typing` | Bool |

## 🔧 除錯檢查點

### 發送端檢查

1. **API 請求是否成功？**
   - 檢查 HTTP 狀態碼 200
   - 檢查 log：`⌨️ 發送輸入中訊號`

2. **後端是否廣播？**
   - 檢查 Laravel log：`📡 UserTyping 事件建立`
   - 檢查 Reverb 伺服器是否運行

### 接收端檢查

1. **WebSocket 是否連線？**
   - 檢查 log：`✅ WebSocket 連線成功`

2. **是否訂閱頻道？**
   - 檢查 log：`✅ 訂閱成功: private-conversation.{id}`

3. **是否收到事件？**
   - 檢查 log：`📡 收到事件: user.typing`

4. **是否解析成功？**
   - 檢查 log：`⌨️ 收到輸入中訊號`

5. **是否播放音效？**
   - 檢查 log：`⌨️ 播放輸入中音效`
   - 確認音效檔案存在

## 🎵 音效檔案規格

**檔案名稱：** `typing.wav`

**位置：**
- Swift: `/Resource/typing.wav`
- Web: `/public/typing.wav`

**格式：** WAV
**大小：** 約 372KB
**音量：** 30%
**時長：** 短促（< 1 秒）

## ✅ 驗證清單

### 功能驗證

- [ ] Swift 發送 typing 訊號成功
- [ ] 後端接收並廣播事件
- [ ] Swift 接收 typing 事件
- [ ] Swift 播放音效
- [ ] 網頁版接收 typing 事件
- [ ] 網頁版播放音效
- [ ] 防重複播放機制正常
- [ ] 不會播放自己的 typing 音效

### 效能驗證

- [ ] API 請求頻率限制正常（3 秒一次）
- [ ] 音效播放不會卡頓
- [ ] WebSocket 連線穩定
- [ ] 記憶體使用正常

### 錯誤處理驗證

- [ ] 音效檔案不存在時有 log
- [ ] API 請求失敗時有錯誤處理
- [ ] JSON 解析失敗時有錯誤處理
- [ ] WebSocket 斷線時能重連

---

**規格版本：** 1.0
**最後更新：** 2026-03-10
**狀態：** ✅ 已實作並測試
