# Typing Sound 除錯指南

## 問題描述
網頁端輸入時，Swift App 不會播放輸入音效

## 除錯步驟

### 步驟 1: 檢查 Laravel 後端日誌

```bash
cd /Users/a123/PhpstormProjects/TeamChatUP-backend
tail -f storage/logs/laravel.log
```

**預期看到的日誌：**
- `🔔 網頁版發送 typing 訊號` (來自 message-input.blade.php)
- `📡 UserTyping 事件建立` (來自 UserTyping.php)

**如果沒看到：** 表示 Livewire 的 `typing()` 方法沒有被觸發

### 步驟 2: 檢查 Swift App 日誌

在 Xcode 中：
1. 開啟 Console (Cmd + Shift + Y)
2. 在網頁端輸入文字
3. 觀察 Console 輸出

**預期看到的日誌：**
```
📺 收到事件: user.typing
📺 事件頻道: private-conversation.{id}
⌨️ 收到輸入中訊號 - 使用者ID: X, 當前使用者ID: Y, 對話ID: Z, 輸入中: true
✅ 使用者ID不同，檢查 isTyping 狀態
🔊 準備播放輸入中音效
🎵 playTypingSound() 被呼叫
✅ 找到音效檔案: /path/to/typing.wav
🔊 播放輸入中音效 - 成功: true
```

**如果沒看到 `📺 收到事件: user.typing`：**
- WebSocket 連線可能有問題
- 檢查是否看到 `✅ WebSocket 連線成功` 和 `✅ 訂閱成功: private-conversation.X`

**如果看到事件但沒有播放音效：**
- 檢查 `使用者ID不同` 是否為 true
- 檢查 `isTyping` 是否為 true
- 檢查音效檔案是否找到

### 步驟 3: 檢查 WebSocket 連線狀態

在 Swift App Console 中搜尋：
```
✅ WebSocket 連線成功
✅ 訂閱成功: private-conversation
```

**如果沒看到：** WebSocket 連線失敗，需要先修復連線問題

### 步驟 4: 檢查網頁端 Console

在瀏覽器中：
1. 開啟 Developer Tools (F12)
2. 切換到 Console 標籤
3. 在輸入框輸入文字

**預期看到：**
```
Livewire typing event triggered
```

**如果沒看到：** Livewire 的 keydown 事件沒有觸發

### 步驟 5: 手動測試 WebSocket 事件

在瀏覽器 Console 中執行：
```javascript
Echo.private('conversation.1')
    .listen('.user.typing', (e) => {
        console.log('收到 typing 事件:', e);
    });
```

然後在另一個瀏覽器或 Swift App 中輸入，看是否收到事件。

## 常見問題排查

### 問題 1: Swift 收不到事件
**可能原因：**
- WebSocket 未連線
- 未訂閱正確的頻道
- 頻道名稱不匹配

**解決方法：**
檢查 Swift Console 中的頻道訂閱日誌

### 問題 2: 事件收到但不播放音效
**可能原因：**
- `userId` 判斷錯誤（自己的事件）
- `isTyping` 為 false
- 音效檔案找不到

**解決方法：**
查看詳細的日誌輸出，確認每個條件

### 問題 3: Laravel 沒有廣播事件
**可能原因：**
- Livewire `typing()` 方法沒有被呼叫
- `wire:keydown.debounce.500ms` 沒有觸發
- Broadcasting 設定錯誤

**解決方法：**
檢查 Laravel 日誌和 `.env` 中的 `BROADCAST_DRIVER`

## 已知問題

### UserTyping 事件只發送 `is_typing: true`

目前 `UserTyping.php` 的 `broadcastWith()` 方法固定回傳：
```php
'is_typing' => true,
```

這表示：
- ✅ 開始輸入時會發送事件
- ❌ 停止輸入時不會發送 `is_typing: false`

**影響：**
- Swift App 只會在第一次收到事件時播放音效
- 如果需要在停止後再次播放，需要實作 timeout 機制

**建議修復：**
在 Livewire component 中加入停止輸入的偵測，並發送 `is_typing: false` 事件。

## 測試檢查清單

- [ ] Laravel 日誌顯示 `🔔 網頁版發送 typing 訊號`
- [ ] Laravel 日誌顯示 `📡 UserTyping 事件建立`
- [ ] Swift Console 顯示 `✅ WebSocket 連線成功`
- [ ] Swift Console 顯示 `✅ 訂閱成功: private-conversation.X`
- [ ] Swift Console 顯示 `📺 收到事件: user.typing`
- [ ] Swift Console 顯示 `⌨️ 收到輸入中訊號`
- [ ] Swift Console 顯示 `🔊 準備播放輸入中音效`
- [ ] Swift Console 顯示 `🎵 playTypingSound() 被呼叫`
- [ ] Swift Console 顯示 `🔊 播放輸入中音效 - 成功: true`
- [ ] 實際聽到音效播放

## 下一步

完成上述檢查後，請回報：
1. 哪些日誌有出現
2. 哪些日誌沒有出現
3. 在哪個步驟卡住

這樣我們就能精確定位問題所在。
