# 修復 Xcode 重複檔案建置錯誤

## 錯誤訊息

```
Multiple commands produce '/Users/a123/Library/Developer/Xcode/DerivedData/TeamChatUP-bqxdjxnufftkjbdykqyjuriyrzic/Build/Products/Debug/TeamChatUP.app/Contents/Resources/typing.wav'

Target 'TeamChatUP' (project 'TeamChatUP') has copy command from '/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/Resource/typing.wav' to '...'
Target 'TeamChatUP' (project 'TeamChatUP') has copy command from '/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/Resources/typing.wav' to '...'
```

## 問題原因

專案中有兩個 `typing.wav` 檔案被加入到 Xcode Target：
- `/Resource/typing.wav` (單數)
- `/Resources/typing.wav` (複數) - 已刪除

雖然實體檔案已刪除，但 Xcode 專案檔案仍保留對已刪除檔案的引用。

## 解決步驟

### 步驟 1: 清理建置資料夾

在 Xcode 中：
1. 按 `Shift + Command + K` (Clean Build Folder)
2. 或選擇選單：**Product → Clean Build Folder**

### 步驟 2: 移除舊的檔案引用

1. 在 Xcode 左側的 **Project Navigator** 中
2. 尋找紅色的 `typing.wav` 檔案（表示檔案不存在）
3. 右鍵點擊 → 選擇 **Delete**
4. 選擇 **Remove Reference**（不要選 Move to Trash）

### 步驟 3: 確認 Build Phases

1. 選擇專案根目錄（藍色圖示）
2. 選擇 **TeamChatUP** Target
3. 切換到 **Build Phases** 標籤
4. 展開 **Copy Bundle Resources**
5. 檢查是否有兩個 `typing.wav` 條目
6. 如果有，刪除其中一個（保留 `Resource/typing.wav`）

### 步驟 4: 重新建置

1. 按 `Command + B` 重新建置專案
2. 或按 `Command + R` 直接執行

## 驗證

建置成功後，確認：
- ✅ 沒有重複檔案錯誤
- ✅ 應用程式可以正常執行
- ✅ typing 音效可以正常播放

## 如果問題仍然存在

### 方法 1: 刪除 DerivedData

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/TeamChatUP-*
```

然後在 Xcode 中重新建置。

### 方法 2: 手動編輯專案檔案

1. 關閉 Xcode
2. 用文字編輯器開啟 `TeamChatUP.xcodeproj/project.pbxproj`
3. 搜尋 `typing.wav`
4. 刪除所有指向 `Resources/typing.wav` 的條目
5. 儲存檔案
6. 重新開啟 Xcode

## 預防措施

未來避免此問題：
- 統一使用 `Resource/` 資料夾（單數）
- 加入檔案前先檢查是否已存在
- 定期清理專案中的紅色（遺失）檔案引用

---

**狀態：** ✅ 實體檔案已清理
**下一步：** 在 Xcode 中清理建置並移除舊引用
