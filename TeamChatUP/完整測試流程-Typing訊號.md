# 🔍 完整測試流程：網頁版 → Swift Typing 訊號

## 測試目標

驗證網頁版發送的 typing 訊號是否能被 Swift 接收並播放音效。

## 測試步驟

### 步驟 1: 準備 Swift App

1. **在 Xcode 中運行應用程式**
2. **登入使用者 B**（例如：user_id = 2）
3. **進入對話 ID = 1**
4. **保持 Xcode Console 開啟**

### 步驟 2: 準備網頁版

1. **開啟瀏覽器**：https://teamchatup-backend.test/chat
2. **登入使用者 A**（例如：user_id = 1，不同於 Swift 的使用者）
3. **進入相同的對話 ID = 1**
4. **開啟 DevTools (F12) → Console 標籤**

### 步驟 3: 檢查 Swift 訂閱狀態

在 Xcode Console 中應該看到：

```
[✅ INFO] WebSocket 連線成功 - Socket ID: xxx
[✅ INFO] 訂閱成功: private-conversation.1
```

**如果沒看到訂閱成功：**
- Swift 沒有訂閱該頻道
- 需要確認 `MessageManager` 是否調用了 `WebSocketManager.shared.subscribeToConversation(1)`

### 步驟 4: 網頁版發送 typing 訊號

1. **在網頁版的輸入框開始輸入**
2. **觀察瀏覽器 Console**，應該看到：
   ```
   ⌨️ 播放輸入中音效
   ```

3. **同時觀察 Xcode Console**，應該看到：
   ```
   [📡 DEBUG] 收到事件: user.typing
   [📺 DEBUG] 事件頻道: private-conversation.1
   [📦 DEBUG] 事件資料內容: {...}
   [⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: 1, 對話ID: 1, 輸入中: true
   [⌨️ DEBUG] 播放輸入中音效
   ```

### 步驟 5: 分析結果

#### 情況 A: Swift 完全沒有收到任何事件

**Xcode Console 沒有任何 "收到事件" log**

**可能原因：**
1. Swift 沒有訂閱該頻道
2. WebSocket 連線斷開
3. 頻道名稱不匹配

**解決方法：**
- 檢查訂閱狀態
- 重新連線 WebSocket
- 確認頻道名稱是否為 `private-conversation.1`

#### 情況 B: Swift 收到事件但不是 user.typing

**Xcode Console 顯示：**
```
[📡 DEBUG] 收到事件: message.sent
```

**說明：** Swift 能收到其他事件，但沒收到 user.typing

**可能原因：**
1. 後端沒有廣播 user.typing 事件
2. 事件名稱不匹配

**解決方法：**
- 檢查後端 log 是否有 "📡 UserTyping 事件建立"
- 確認事件名稱

#### 情況 C: Swift 收到 user.typing 但沒有處理

**Xcode Console 顯示：**
```
[📡 DEBUG] 收到事件: user.typing
[📺 DEBUG] 事件頻道: private-conversation.1
[📦 DEBUG] 事件資料內容: {...}
未處理的事件: user.typing
```

**說明：** Swift 收到事件但 switch 沒有匹配到

**可能原因：**
- case 語句寫錯
- 事件名稱有前綴（例如 `.user.typing`）

**解決方法：**
- 檢查 WebSocketManager.swift 的 switch 語句
- 確認 case 包含 `"user.typing", ".user.typing"`

#### 情況 D: Swift 收到並處理但沒播放音效

**Xcode Console 顯示：**
```
[📡 DEBUG] 收到事件: user.typing
[⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: 1, 對話ID: 1, 輸入中: true
```

**但沒有 "播放輸入中音效" log**

**可能原因：**
1. 使用者 ID 過濾錯誤（過濾掉了自己的事件）
2. 防重複邏輯問題
3. MessageManager 沒有收到事件

**解決方法：**
- 檢查 MessageManager.handleWebSocketEvent() 的邏輯
- 確認 typingUsers Set 的狀態

#### 情況 E: Swift 播放音效但沒聲音

**Xcode Console 顯示：**
```
[⌨️ DEBUG] 播放輸入中音效
```

**但沒有聽到聲音**

**可能原因：**
1. 音效檔案不存在
2. 音量設定為 0
3. 系統音量關閉

**解決方法：**
- 檢查音效檔案是否存在
- 確認音量設定
- 測試系統音量

## 快速除錯指令

### 在 Xcode Console 中搜尋

```
訂閱成功
收到事件
user.typing
播放輸入中音效
```

### 在後端 Terminal 中執行

```bash
tail -f storage/logs/laravel.log | grep -E "UserTyping|typing"
```

然後在網頁版輸入，應該看到：
```
[📡 DEBUG] UserTyping 事件建立
```

## 預期的完整 Log 流程

### 後端 (Laravel Log)

```
[🔔 DEBUG] 網頁版發送 typing 訊號 - user_id: 1, conversation_id: 1
[📡 DEBUG] UserTyping 事件建立 - user_id: 1, conversation_id: 1, channel: private-conversation.1
```

### 網頁版 (Browser Console)

```
⌨️ 播放輸入中音效
```

### Swift (Xcode Console)

```
[📡 DEBUG] 收到事件: user.typing
[📺 DEBUG] 事件頻道: private-conversation.1
[📦 DEBUG] 事件資料內容: {conversation_id = 1; is_typing = 1; user_id = 1; user_name = "User A";}
[⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: 1, 對話ID: 1, 輸入中: true
[⌨️ DEBUG] 播放輸入中音效
```

---

**下一步：** 請按照上述步驟測試，並回報在哪個步驟出現問題
