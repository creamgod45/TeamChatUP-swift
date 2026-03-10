# ✅ Swift Typing 訊號接收功能 - 總結

## 已完成的修改

### 1. Swift 發送 Typing 訊號
- ✅ MessageManager.swift - 使用 REST API 發送
- ✅ 添加詳細 log 記錄

### 2. Swift 接收 Typing 訊號
- ✅ WebSocketManager.swift - 新增 handleUserTyping() 方法
- ✅ 添加 "user.typing" 事件處理
- ✅ 添加頻道 log 記錄

### 3. 網頁版
- ✅ 音效檔案路徑修正：typing.wav
- ✅ Livewire typing() 方法添加 log
- ✅ UserTyping 事件添加 log

### 4. Xcode 建置問題
- ✅ 刪除重複的 typing.wav 檔案
- ✅ 清除 DerivedData 快取

## 測試清單

### 測試 1: Swift → Swift (已測試)
- [x] Swift App A 發送訊號
- [x] Swift App B 接收並播放音效

### 測試 2: Web → Web (已確認正常)
- [x] 網頁版 A 發送訊號
- [x] 網頁版 B 接收並播放音效
- [x] 瀏覽器 log 顯示：⌨️ 播放輸入中音效

### 測試 3: Web → Swift (需要測試)
- [ ] 網頁版發送訊號
- [ ] Swift 接收並播放音效
- [ ] 這是目前需要驗證的部分

## 測試步驟

### 準備工作

1. **在 Xcode 中運行 Swift App**
   - 登入使用者 B
   - 進入對話 ID = 1
   - 保持 Xcode Console 開啟

2. **開啟網頁版**
   - 瀏覽器開啟：https://teamchatup-backend.test/chat
   - 登入使用者 A（不同於 Swift 的使用者）
   - 進入相同的對話 ID = 1
   - 開啟 DevTools (F12) → Console

### 執行測試

1. **檢查 Swift 訂閱狀態**

   在 Xcode Console 搜尋：
   ```
   訂閱成功: private-conversation.1
   ```

2. **網頁版輸入文字**

   在網頁版輸入框開始輸入

3. **觀察 Xcode Console**

   應該看到以下 log（按順序）：
   ```
   [📡 DEBUG] 收到事件: user.typing
   [📺 DEBUG] 事件頻道: private-conversation.1
   [📦 DEBUG] 事件資料內容: {...}
   [⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: X, 對話ID: 1
   [⌨️ DEBUG] 播放輸入中音效
   ```

4. **聽到音效**

   Swift App 應該播放 typing 音效

## 如果測試失敗

### 情況 A: 沒有看到任何 "收到事件" log

**問題：** Swift 沒有收到任何 WebSocket 事件

**檢查：**
1. WebSocket 是否連線？搜尋 "WebSocket 連線成功"
2. 是否訂閱頻道？搜尋 "訂閱成功"
3. Reverb 伺服器是否運行？

**解決：**
```bash
# 檢查 Reverb
ps aux | grep reverb

# 重啟 Reverb
php artisan reverb:restart
```

### 情況 B: 看到其他事件但沒有 user.typing

**問題：** Swift 能收到 message.sent 但收不到 user.typing

**檢查：**
1. 後端是否廣播？執行：
   ```bash
   tail -f storage/logs/laravel.log | grep UserTyping
   ```
2. 在網頁版輸入，應該看到 "UserTyping 事件建立"

**解決：**
- 如果後端沒有 log，檢查 Livewire 的 wire:keydown 是否觸發
- 在瀏覽器 Console 手動測試：
  ```javascript
  Livewire.all()[0].call('typing')
  ```

### 情況 C: 收到 user.typing 但顯示 "未處理的事件"

**問題：** Switch case 沒有匹配

**檢查：**
- 事件名稱是否完全匹配
- 是否有前綴（例如 `.user.typing`）

**解決：**
- 確認 WebSocketManager.swift 第 325 行包含：
  ```swift
  case "user.typing", ".user.typing":
  ```

### 情況 D: 處理事件但沒播放音效

**問題：** MessageManager 沒有收到或過濾掉了

**檢查：**
1. MessageManager 是否訂閱 eventPublisher？
2. 使用者 ID 過濾是否正確？
3. typingUsers Set 狀態？

**解決：**
- 檢查 MessageManager.handleWebSocketEvent() 的邏輯
- 確認不會過濾掉其他使用者的事件

### 情況 E: 播放音效但沒聲音

**問題：** 音效檔案或系統音量問題

**檢查：**
1. 音效檔案是否存在？
   ```bash
   ls -la /Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/Resource/typing.wav
   ```
2. 系統音量是否開啟？
3. Xcode 是否有音效權限？

**解決：**
- 確認音效檔案存在
- 測試系統音量
- 重新加入音效檔案到 Xcode Target

## 完整的 Log 流程（預期）

### 1. 網頁版輸入

**瀏覽器 Console：**
```
⌨️ 播放輸入中音效
```

### 2. 後端廣播

**Laravel Log：**
```
[🔔 DEBUG] 網頁版發送 typing 訊號 - user_id: 1, conversation_id: 1
[📡 DEBUG] UserTyping 事件建立 - user_id: 1, conversation_id: 1
```

### 3. Swift 接收

**Xcode Console：**
```
[📡 DEBUG] 收到事件: user.typing
[📺 DEBUG] 事件頻道: private-conversation.1
[📦 DEBUG] 事件資料內容: {
    conversation_id = 1;
    is_typing = 1;
    user_id = 1;
    user_name = "User A";
}
[⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: 1, 對話ID: 1, 輸入中: true
[⌨️ DEBUG] 播放輸入中音效
```

### 4. 聽到音效

Swift App 播放 typing.wav 音效（短促的聲音）

## 下一步

1. **在 Xcode 中重新建置並運行**
   - Clean Build Folder (Shift + Command + K)
   - Run (Command + R)

2. **按照測試步驟執行**
   - 開啟兩個裝置（Swift + Web）
   - 進入相同對話
   - 網頁版輸入文字
   - 觀察 Swift Console

3. **回報結果**
   - 如果成功：回報聽到音效
   - 如果失敗：回報在哪個步驟失敗，以及看到的 log

---

**狀態：** ✅ 所有程式碼修改完成
**待測試：** Web → Swift typing 訊號傳遞
