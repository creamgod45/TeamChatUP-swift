# 網頁版 Typing 音效測試指南

## 測試前準備

1. **確認 Laravel Reverb 正在運行**
   ```bash
   php artisan reverb:start
   ```

2. **確認音效檔案存在**
   - 檔案位置：`/public/tpying.wav`
   - 檔案大小：372KB

## 測試步驟

### 1. 開啟兩個瀏覽器視窗

**視窗 A（觀察者）：**
- 開啟 Chrome/Edge
- 登入使用者 A
- 進入對話頁面
- **開啟 DevTools (F12) → Console 標籤**

**視窗 B（輸入者）：**
- 開啟另一個瀏覽器（或無痕模式）
- 登入使用者 B
- 進入**相同的對話**

### 2. 測試 Typing 音效

**在視窗 B 的輸入框開始輸入：**
```
開始輸入任何文字...
```

**在視窗 A 應該看到/聽到：**
- ✅ 聽到短促的 typing 音效（wav 檔案）
- ✅ Console 顯示：`⌨️ 播放輸入中音效`

**繼續在視窗 B 輸入：**
- ❌ 不會重複播放音效（防重複機制）

**停止輸入 500ms 後再次輸入：**
- ✅ 會再次播放音效

### 3. 測試新訊息音效（對比）

**在視窗 B 發送訊息：**
```
按 Enter 發送訊息
```

**在視窗 A 應該看到/聽到：**
- ✅ 聽到新訊息音效（mp3 檔案，音調不同）
- ✅ Console 顯示：`🔊 播放新訊息音效`

## 常見問題排查

### 問題 1：沒有聽到任何音效

**可能原因：**
1. 瀏覽器阻止自動播放音效
2. 音量設定為 0
3. WebSocket 連線失敗

**解決方法：**
```javascript
// 在 Console 執行以下指令測試音效
const sound = new Audio('/tpying.wav');
sound.volume = 0.3;
sound.play();
```

如果出現錯誤：
```
DOMException: play() failed because the user didn't interact with the document first.
```

**解決：** 先點擊頁面任何地方（與頁面互動），然後再測試。

### 問題 2：Console 沒有顯示 Log

**檢查項目：**
1. 確認 DevTools Console 沒有過濾 log
2. 確認兩個視窗都在**相同的對話**中
3. 確認 WebSocket 連線正常

**檢查 WebSocket 連線：**
```javascript
// 在 Console 執行
Echo.connector.pusher.connection.state
// 應該顯示: "connected"
```

### 問題 3：只有新訊息音效，沒有 Typing 音效

**可能原因：**
- Livewire 的 `typing()` 方法沒有被觸發
- 後端沒有廣播 typing 事件

**檢查後端 Log：**
```bash
tail -f storage/logs/laravel.log
```

**手動測試 API：**
```bash
curl -X POST https://teamchatup-backend.test/api/conversations/1/typing \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### 問題 4：音效播放失敗

**Console 顯示：**
```
❌ 無法播放輸入音效: NotAllowedError: play() failed...
```

**原因：** 瀏覽器的自動播放政策

**解決方法：**
1. 先與頁面互動（點擊、輸入等）
2. 在瀏覽器設定中允許該網站自動播放音效
3. Chrome: `chrome://settings/content/sound`

## 預期行為

### 正常流程

**視窗 B 輸入時：**
```
使用者 B 開始輸入 →
Livewire 觸發 typing() →
後端廣播 UserTyping 事件 →
視窗 A 收到 .user.typing 事件 →
檢查是否為新使用者 →
播放 typing 音效 →
Console 顯示 "⌨️ 播放輸入中音效"
```

**視窗 B 繼續輸入：**
```
使用者 B 繼續輸入 →
後端廣播 UserTyping 事件 →
視窗 A 收到事件 →
檢查：使用者已在 typingUsers Set 中 →
不播放音效（防重複）
```

**視窗 B 停止輸入 500ms：**
```
使用者 B 停止輸入 →
Livewire debounce 結束 →
後端廣播 is_typing: false →
視窗 A 從 typingUsers 移除該使用者
```

**視窗 B 再次輸入：**
```
使用者 B 再次輸入 →
檢查：使用者不在 typingUsers Set 中 →
播放音效 →
Console 顯示 "⌨️ 播放輸入中音效"
```

## 音效檔案資訊

**Typing 音效：**
- 檔案：`/public/tpying.wav`
- 大小：372KB
- 音量：30%
- 格式：WAV

**新訊息音效：**
- 檔案：`/public/tethys.mp3`
- 大小：14KB
- 音量：50%
- 格式：MP3

## 瀏覽器相容性

✅ Chrome/Edge - 完全支援
✅ Firefox - 完全支援
✅ Safari - 完全支援（可能需要使用者互動）
✅ Opera - 完全支援

## 除錯技巧

### 1. 監聽所有 WebSocket 事件

```javascript
// 在 Console 執行
Echo.private('conversation.1')
    .listen('.user.typing', (e) => {
        console.log('收到 typing 事件:', e);
    });
```

### 2. 手動播放音效測試

```javascript
// 測試 typing 音效
const typingSound = new Audio('/tpying.wav');
typingSound.volume = 0.3;
typingSound.play().then(() => {
    console.log('✅ Typing 音效播放成功');
}).catch(err => {
    console.error('❌ Typing 音效播放失敗:', err);
});

// 測試新訊息音效
const messageSound = new Audio('/tethys.mp3');
messageSound.volume = 0.5;
messageSound.play().then(() => {
    console.log('✅ 新訊息音效播放成功');
}).catch(err => {
    console.error('❌ 新訊息音效播放失敗:', err);
});
```

### 3. 檢查 Alpine.js 狀態

```javascript
// 在 Console 執行（在訊息列表元素上）
$el.__x.$data.typingUsers
// 應該顯示 Set 物件
```

## 成功標準

✅ 視窗 A 聽到 typing 音效
✅ Console 顯示 "⌨️ 播放輸入中音效"
✅ 同一使用者持續輸入不會重複播放
✅ 停止後再次輸入會再次播放
✅ 新訊息音效與 typing 音效不同

---

**測試完成後請回報：**
1. 是否聽到 typing 音效？
2. Console 是否顯示正確的 log？
3. 是否有任何錯誤訊息？
