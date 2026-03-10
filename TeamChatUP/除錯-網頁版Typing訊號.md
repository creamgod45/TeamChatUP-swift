# 網頁版 Typing 訊號除錯指南

## 測試步驟

### 1. 啟動 Log 監控

已啟動後端 log 監控，現在請執行以下步驟：

### 2. 測試網頁版發送訊號

1. **開啟網頁版**
   - 瀏覽器開啟：https://teamchatup-backend.test/chat
   - 登入使用者 A
   - 進入任一對話

2. **開啟瀏覽器 Console**
   - 按 F12 開啟 DevTools
   - 切換到 Console 標籤

3. **在輸入框輸入文字**
   - 開始輸入任何文字
   - 觀察 Console 是否有錯誤

### 3. 檢查後端 Log

在終端機中應該會看到：

```
[📡 DEBUG] UserTyping 事件建立 - user_id: X, conversation_id: Y
[🔔 DEBUG] 網頁版發送 typing 訊號 - user_id: X, conversation_id: Y
```

### 4. 測試 Swift 接收

1. **開啟 Swift App**
   - 在 Xcode 中運行應用程式
   - 登入使用者 B（不同於網頁版的使用者）
   - 進入**相同的對話**

2. **觀察 Xcode Console**
   - 應該看到：
     ```
     [📡 DEBUG] 收到事件: user.typing
     [⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: X, 對話ID: Y
     [⌨️ DEBUG] 播放輸入中音效
     ```

### 5. 如果沒有收到事件

檢查以下項目：

#### A. WebSocket 連線狀態

在 Xcode Console 搜尋：
```
✅ WebSocket 連線成功
✅ 訂閱成功: private-conversation.X
```

#### B. 檢查頻道名稱

確認兩邊使用相同的對話 ID：
- 網頁版 log：`conversation_id: X`
- Swift 訂閱：`private-conversation.X`

#### C. 檢查事件名稱

後端廣播：`user.typing`
Swift 監聽：`user.typing` 或 `.user.typing`

## 常見問題

### 問題 1: 後端沒有 log

**可能原因：**
- Livewire 的 `wire:keydown` 沒有觸發
- `typing()` 方法沒有被調用

**解決方法：**
在瀏覽器 Console 執行：
```javascript
Livewire.find('message-input-component-id').call('typing')
```

### 問題 2: 後端有 log，但 Swift 沒收到

**可能原因：**
- Swift 沒有訂閱該頻道
- WebSocket 連線斷開
- 事件名稱不匹配

**解決方法：**
1. 檢查 Swift Console 的訂閱狀態
2. 重新連線 WebSocket
3. 確認事件名稱

### 問題 3: Swift 收到事件但沒播放音效

**可能原因：**
- 音效檔案不存在
- 使用者 ID 過濾錯誤
- 防重複邏輯問題

**解決方法：**
檢查 Swift Console 的完整 log 輸出

## 停止 Log 監控

在終端機按 `Ctrl+C` 停止監控

---

**下一步：** 請按照上述步驟測試，並回報看到的 log 內容
