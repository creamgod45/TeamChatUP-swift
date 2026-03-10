# Token 過期機制實作說明

## 概述
實作了完整的授權憑證過期偵測與處理機制，當 Token 過期時會顯示確認對話框，讓使用者選擇是否重新登入。

## 實作內容

### 1. PKCEAuthManager 新增功能

**新增屬性：**
```swift
@Published var showTokenExpiredAlert = false
```

**新增方法：**
```swift
func handleTokenExpiration(shouldRelogin: Bool) async {
    if shouldRelogin {
        // 使用者選擇重新登入
        await logout()
        startAuthorization()
    } else {
        // 使用者取消，僅登出
        await logout()
    }
    showTokenExpiredAlert = false
}
```

**修改 fetchCurrentUser()：**
- 當收到 401 錯誤時，設定 `showTokenExpiredAlert = true`
- 不再自動登出，而是等待使用者確認

### 2. API Client 增強偵測

**Models.swift - performRequest() 方法：**

新增 HTML 回應偵測：
```swift
// 檢查是否收到 HTML 回應（可能是重定向到登入頁面）
if rawResponse.contains("<!DOCTYPE html>") || rawResponse.contains("<html") {
    // 檢查是否是 WorkOS 登入頁面
    if rawResponse.contains("workos") || rawResponse.contains("login") || rawResponse.contains("auth") {
        // 觸發過期警告
        Task { @MainActor in
            PKCEAuthManager.shared.showTokenExpiredAlert = true
        }
        throw APIError.unauthorized
    }
}
```

**偵測機制：**
1. 檢查 HTTP 401 狀態碼
2. 檢查回應是否為 HTML（而非預期的 JSON）
3. 檢查 HTML 內容是否包含 WorkOS/登入相關關鍵字

### 3. ContentView 對話框

```swift
.alert("授權已過期", isPresented: $authManager.showTokenExpiredAlert) {
    Button("重新登入", role: .none) {
        Task {
            await authManager.handleTokenExpiration(shouldRelogin: true)
        }
    }
    Button("取消", role: .cancel) {
        Task {
            await authManager.handleTokenExpiration(shouldRelogin: false)
        }
    }
} message: {
    Text("您的登入憑證已過期，需要重新登入才能繼續使用。")
}
```

### 4. 統一使用 PKCEAuthManager

已更新所有檔案，從 `AuthenticationManager` 改為 `PKCEAuthManager`：
- ✅ ContentView.swift
- ✅ ChatDetailView.swift
- ✅ MessageManager.swift
- ✅ ChatRoomListView.swift
- ✅ LoginView.swift（已經使用 PKCEAuthManager）

## 使用流程

### 正常情況
1. 使用者使用 App
2. Token 有效，API 請求正常

### Token 過期情況
1. 使用者發送 API 請求
2. 後端回傳 401 或重定向到 WorkOS 登入頁
3. API Client 偵測到過期（401 或 HTML 回應）
4. 設定 `showTokenExpiredAlert = true`
5. ContentView 顯示警告對話框
6. 使用者選擇：
   - **重新登入**：清除舊 Token → 開啟瀏覽器授權 → 取得新 Token
   - **取消**：清除舊 Token → 返回登入畫面

## 偵測方式

### 方式 1: HTTP 401 狀態碼
```
API 請求 → 401 Unauthorized → 觸發警告
```

### 方式 2: HTML 回應偵測（針對 WorkOS 重定向）
```
API 請求 → 200 OK (但內容是 HTML) → 檢查關鍵字 → 觸發警告
```

這種方式可以處理後端未正確設定 `Accept: application/json` header 時的情況。

## 安全性考量

1. **不自動重新登入**：需要使用者明確確認
2. **清除舊憑證**：無論選擇哪個選項都會清除過期的 Token
3. **防止重複觸發**：使用 `@Published` 屬性確保對話框只顯示一次

## 測試建議

1. **手動測試**：
   - 修改後端 Sanctum token 過期時間為 1 分鐘
   - 登入後等待 2 分鐘
   - 嘗試發送訊息或載入對話
   - 確認顯示過期警告

2. **模擬測試**：
   - 在 API Client 中暫時強制回傳 401
   - 確認警告正確顯示

3. **邊界測試**：
   - 連續多個 API 請求同時失敗
   - 確認只顯示一次警告（不重複）

## 後續改進建議

1. **Token 刷新機制**：
   - 在 Token 即將過期前自動刷新
   - 減少使用者需要重新登入的次數

2. **背景刷新**：
   - App 進入前景時檢查 Token 有效性
   - 提前發現過期問題

3. **優雅降級**：
   - 離線模式支援
   - 本地快取資料顯示
