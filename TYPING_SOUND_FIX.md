# Typing Sound 修復說明

## 問題
Swift 端接收到 typing 事件但沒有播放音效。

## 原因
ㄅ
## 修復內容
在 `handleUserTyping` 函數中添加音效播放邏輯：

```swift
// 播放輸入中音效（只在別人開始輸入時播放）
let currentUserId = PKCEAuthManager.shared.currentUser?.id ?? 0
if typingEvent.userId != currentUserId && typingEvent.isTyping {
    SoundManager.shared.playTypingSound()
}
```

## 邏輯說明
1. 獲取當前使用者 ID
2. 檢查 typing 事件是否來自其他使用者（不是自己）
3. 檢查是否為「開始輸入」事件（`isTyping == true`）
4. 符合條件時播放 typing 音效

## 測試方式
1. 重新編譯並執行 Swift app
2. 在網頁端開始輸入訊息
3. Swift 端應該會播放 typing.wav 音效
4. 檢查日誌應該會看到：`⌨️ 播放輸入中音效`

## 對比
- **修復前**：只記錄日誌，不播放音效
- **修復後**：接收到別人的 typing 事件時會播放音效

## 相關檔案
- `/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/WebSocketManager.swift` (第 437-441 行)
- `/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/SoundManager.swift` (playTypingSound 函數)
