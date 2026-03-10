# ✅ 訊息已讀 & Typing 音效修復

## 已完成的修復

### 1. 訊息已讀功能 ✅

**修改檔案：** `ChatDetailView.swift`

**實作：**
- 在 `.task` 中載入訊息後自動調用 `markAsRead` API
- 進入對話時自動標記為已讀
- 使用 `AppLogger` 記錄成功/失敗狀態

```swift
.task {
    await messageManager.loadMessages(refresh: true)
    // 標記對話為已讀
    await markConversationAsRead()
}

private func markConversationAsRead() async {
    do {
        try await APIClient.shared.markAsRead(conversationId: conversation.id)
        AppLogger.shared.debug("✅ 對話已標記為已讀")
    } catch {
        AppLogger.shared.error("❌ 標記對話為已讀失敗: \(error)")
    }
}
```

### 2. Typing 音效 ✅

**修改檔案：**
1. `SoundManager.swift` - 新增 `playTypingSound()` 方法
2. `MessageManager.swift` - 收到 typing signal 時播放音效

**實作：**

**SoundManager.swift:**
```swift
func playTypingSound() {
    guard let soundURL = Bundle.main.url(forResource: "tpying", withExtension: "wav") else {
        print("Sound file not found: tpying.wav")
        return
    }

    do {
        audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
        audioPlayer?.volume = 0.3 // 降低音量避免太吵
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    } catch {
        print("Failed to play typing sound: \(error)")
    }
}
```

**MessageManager.swift:**
```swift
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
```

## 音效檔案

專案中已有的音效檔案：
- ✅ `Resource/tethys.mp3` - 新訊息音效
- ✅ `Resource/tpying.wav` - Typing 音效
- ✅ `Resources/typing.wav` - Typing 音效（備份）

## 功能說明

### 訊息已讀
- **觸發時機：** 進入對話時
- **API 端點：** `POST /api/conversations/{id}/read`
- **效果：** 更新 `conversation_participants.last_read_at` 為當前時間

### Typing 音效
- **觸發時機：** 收到其他使用者的 typing signal
- **音效檔案：** `tpying.wav`
- **音量：** 30%（避免太吵）
- **防重複：** 只在新使用者開始輸入時播放一次

## 測試步驟

### 測試訊息已讀

1. **開啟兩個裝置或使用 Web 版**
2. **在裝置 A 發送訊息給裝置 B**
3. **在裝置 B 進入對話**
   - 檢查 Console 應該看到：`✅ 對話已標記為已讀`
4. **在裝置 A 查看對話列表**
   - 未讀數量應該清除

### 測試 Typing 音效

1. **開啟兩個裝置**
2. **在裝置 A 進入對話**
3. **在裝置 B 開始輸入訊息**
4. **在裝置 A 應該：**
   - 聽到 typing 音效（短促的聲音）
   - 看到 typing indicator（如果有實作 UI）

## 注意事項

### 音效播放
- 音效檔案必須加入 Xcode 專案的 Target
- 檔案名稱：`tpying.wav`（注意拼字）
- 音量設定為 30% 避免太吵

### 已讀狀態
- 只在進入對話時標記一次
- 不會在背景自動標記
- 失敗時會記錄錯誤但不影響使用

### 防重複播放
- Typing 音效只在新使用者開始輸入時播放
- 同一使用者持續輸入不會重複播放
- 停止輸入後再次輸入會再次播放

## 後端 API

### 標記已讀 API
```
POST /api/conversations/{conversation}/read
Authorization: Bearer {token}

Response: 200 OK
{
  "message": "Conversation marked as read."
}
```

**後端實作：**
```php
public function markAsRead(Request $request, Conversation $conversation): JsonResponse
{
    $this->authorize('view', $conversation);
    $conversation->markAsRead($request->user());
    return response()->json(['message' => 'Conversation marked as read.']);
}
```

## 資料庫更新

標記已讀時更新：
```sql
UPDATE conversation_participants
SET last_read_at = NOW()
WHERE conversation_id = ? AND user_id = ?
```

---

**修復完成時間：** 2026-03-09 15:45
**修改檔案：** 3 個
**狀態：** ✅ 完成
**下一步：** 在 Xcode 中測試兩個功能
