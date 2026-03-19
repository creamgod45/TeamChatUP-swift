# Typing Sound 測試說明

## 已完成的修改

### Swift 端 ✅
**檔案**: `TeamChatUP/WebSocketManager.swift`
- 加強日誌追蹤，顯示詳細的事件處理流程
- 記錄使用者 ID 比對過程
- 記錄音效播放狀態

**檔案**: `TeamChatUP/SoundManager.swift`
- 加強日誌追蹤，顯示音效檔案載入狀態
- 記錄播放成功/失敗狀態

### 網頁端 ✅
**檔案**: `message-list.blade.php`
- 已實作 `typingTimeouts` 物件
- 已實作 3 秒 timeout 自動清理機制

### 測試工具 ✅
**檔案**: `test-typing.blade.php`
- 手動觸發 typing 事件的測試頁面
- 可以測試 `is_typing: true` 和 `is_typing: false`
- 可以測試音效播放

## 測試步驟

### 1. 編譯並執行 Swift App

```bash
cd /Users/a123/Documents/Xcode/TeamChatUP
xcodebuild -scheme TeamChatUP -destination 'platform=iOS Simulator,name=iPhone 17' build
```

在 Xcode 中按 Cmd + R 執行 App

### 2. 開啟測試頁面

在瀏覽器中訪問：
```
http://your-backend-url/test-typing
```

### 3. 觀察日誌

#### Swift App Console (Xcode)
開啟 Console (Cmd + Shift + Y)，應該看到：
```
📺 收到事件: user.typing
⌨️ 收到輸入中訊號 - 使用者ID: X, 當前使用者ID: Y
✅ 使用者ID不同，檢查 isTyping 狀態
🔊 準備播放輸入中音效
🎵 playTypingSound() 被呼叫
✅ 找到音效檔案: /path/to/typing.wav
🔊 播放輸入中音效 - 成功: true
```

#### Laravel 後端日誌
```bash
cd /Users/a123/PhpstormProjects/TeamChatUP-backend
tail -f storage/logs/laravel.log
```

應該看到：
```
📡 UserTyping 事件建立
user_id: X
conversation_id: Y
channel: private-conversation.Y
```

### 4. 測試場景

#### 場景 A: 網頁 → Swift
1. 在測試頁面點擊「發送 is_typing: true」
2. 觀察 Swift App Console
3. 確認是否播放音效

#### 場景 B: Swift → 網頁
1. 在 Swift App 的聊天輸入框輸入文字
2. 觀察網頁端 Console
3. 確認是否播放音效

#### 場景 C: 重複播放測試
1. 點擊「發送 is_typing: true」
2. 等待 3 秒
3. 再次點擊「發送 is_typing: true」
4. 確認音效再次播放

## 問題排查

### 問題 1: Swift 收不到事件

**檢查項目：**
- [ ] WebSocket 是否連線成功？搜尋 `✅ WebSocket 連線成功`
- [ ] 是否訂閱頻道成功？搜尋 `✅ 訂閱成功: private-conversation`
- [ ] 是否收到事件？搜尋 `📺 收到事件: user.typing`

**如果都沒有：**
- 檢查網路連線
- 檢查 Laravel Reverb 是否運行
- 檢查 `.env` 中的 WebSocket 設定

### 問題 2: 收到事件但不播放音效

**檢查項目：**
- [ ] 使用者 ID 是否不同？查看 `使用者ID不同` 日誌
- [ ] `isTyping` 是否為 true？查看日誌
- [ ] 音效檔案是否找到？查看 `✅ 找到音效檔案`
- [ ] 播放是否成功？查看 `成功: true`

**如果音效檔案找不到：**
```bash
ls -la /Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/Resource/typing.wav
```

### 問題 3: Laravel 沒有廣播事件

**檢查項目：**
- [ ] Laravel Reverb 是否運行？
- [ ] `.env` 中 `BROADCAST_DRIVER=reverb`？
- [ ] 是否看到 `📡 UserTyping 事件建立` 日誌？

**啟動 Reverb：**
```bash
cd /Users/a123/PhpstormProjects/TeamChatUP-backend
php artisan reverb:start
```

## 已知限制

### UserTyping 事件只發送 `is_typing: true`

目前 `UserTyping.php` 固定回傳 `is_typing: true`，不會發送停止輸入的事件。

**影響：**
- 音效只會在第一次輸入時播放
- 停止輸入後再次輸入，需要等待 3 秒 timeout 才會再次播放

**未來改進：**
實作停止輸入偵測，發送 `is_typing: false` 事件。

## 相關文件

- `TYPING_SOUND_DEBUG_GUIDE.md` - 詳細除錯指南
- `TYPING_SOUND_FIX.md` - Swift 端修復說明
- `TYPING_SOUND_WEB_FIX.md` - 網頁端修復說明（如果存在）

## 需要協助？

如果測試後仍有問題，請提供：
1. Swift App Console 的完整日誌
2. Laravel 後端日誌
3. 瀏覽器 Console 日誌
4. 在哪個步驟卡住

這樣我們可以更精確地定位問題。
