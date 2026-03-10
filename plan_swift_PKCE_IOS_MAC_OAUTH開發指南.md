# TeamChatUP iOS/macOS PKCE OAuth 開發指南

## 概述

本指南說明如何在 iOS/macOS 應用程式中實作 PKCE (Proof Key for Code Exchange) 授權流程，與 TeamChatUP 後端 API 整合。

### 授權流程架構

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  iOS/macOS  │         │  Web Browser │         │   Backend   │
│     App     │         │              │         │     API     │
└──────┬──────┘         └──────┬───────┘         └──────┬──────┘
       │                       │                        │
       │ 1. Generate PKCE      │                        │
       │    verifier/challenge │                        │
       │                       │                        │
       │ 2. Open authorization │                        │
       │    URL with challenge │                        │
       ├──────────────────────>│                        │
       │                       │                        │
       │                       │ 3. User login & auth   │
       │                       ├───────────────────────>│
       │                       │                        │
       │                       │ 4. Generate auth code  │
       │                       │<───────────────────────┤
       │                       │                        │
       │ 5. Deep link callback │                        │
       │    with auth code     │                        │
       │<──────────────────────┤                        │
       │                       │                        │
       │ 6. Exchange code for token                     │
       │    (with verifier)                             │
       ├────────────────────────────────────────────────>│
       │                       │                        │
       │ 7. Return access token                         │
       │<────────────────────────────────────────────────┤
       │                       │                        │
       │ 8. Store token in Keychain                     │
       │                       │                        │
       │ 9. Use token for API calls                     │
       ├────────────────────────────────────────────────>│
       │                       │                        │
```

## 後端 API 端點

### 1. Web 授權頁面
```
GET https://teamchatup.test/device/authorize?challenge={code_challenge}
```

### 2. 交換 Token
```
POST https://teamchatup.test/api/device-auth/token
Content-Type: application/json

{
  "authorization_code": "string (64 chars)",
  "code_verifier": "string (43-128 chars)",
  "device_name": "My iPhone",
  "device_type": "ios",
  "device_model": "iPhone 15 Pro",
  "os_version": "18.0"
}

Response:
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "user": {
    "id": 1,
    "name": "...",
    "email": "...",
    "avatar": "...",
    "role": "..."
  }
}
```

### 3. 驗證 Token
```
GET https://teamchatup.test/api/auth/me
Authorization: Bearer {access_token}
```

### 4. 列出已授權設備
```
GET https://teamchatup.test/api/device-auth/devices
Authorization: Bearer {access_token}
```

### 5. 撤銷設備
```
DELETE https://teamchatup.test/api/device-auth/devices/{device_id}
Authorization: Bearer {access_token}
```

## Swift 實作

### 1. 專案配置

#### Info.plist 設定

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>teamchatup</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.teamchatup.app</string>
    </dict>
</array>

<!-- 允許開啟外部瀏覽器 -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
    <string>http</string>
</array>
```

### 2. PKCE Manager 實作

```swift
import Foundation
import CryptoKit

class PKCEManager {
    /// 生成 code_verifier (43-128 字元的隨機字串)
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// 從 verifier 計算 code_challenge (SHA256 + Base64URL)
    static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            return ""
        }

        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)

        return hashData
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// 驗證 verifier 和 challenge 是否匹配（用於測試）
    static func verifyChallenge(_ challenge: String, verifier: String) -> Bool {
        let computedChallenge = generateCodeChallenge(from: verifier)
        return computedChallenge == challenge
    }
}
```

### 3. Keychain Manager 實作

```swift
import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unexpectedStatus(OSStatus)
}

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.teamchatup.app"

    private init() {}

    /// 儲存 access token
    func saveToken(_ token: String, forKey key: String = "access_token") throws {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // 先刪除舊的
        SecItemDelete(query as CFDictionary)

        // 新增
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 讀取 access token
    func getToken(forKey key: String = "access_token") throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return token
    }

    /// 刪除 token
    func deleteToken(forKey key: String = "access_token") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 檢查是否有 token
    func hasToken(forKey key: String = "access_token") -> Bool {
        return (try? getToken(forKey: key)) != nil
    }
}
```

### 4. Auth Manager 實作

```swift
import Foundation
import UIKit

enum AuthError: Error {
    case invalidCallback
    case missingVerifier
    case tokenExchangeFailed
    case invalidResponse
    case networkError(Error)
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let baseURL = "https://teamchatup.test"
    private let keychainManager = KeychainManager.shared
    private var codeVerifier: String?

    private init() {
        checkAuthStatus()
    }

    // MARK: - Authentication Status

    func checkAuthStatus() {
        isAuthenticated = keychainManager.hasToken()

        if isAuthenticated {
            Task {
                await fetchCurrentUser()
            }
        }
    }

    // MARK: - Step 1: Start Authorization

    func startAuthorization() {
        // 生成 PKCE verifier 和 challenge
        let verifier = PKCEManager.generateCodeVerifier()
        let challenge = PKCEManager.generateCodeChallenge(from: verifier)

        // 儲存 verifier 到 UserDefaults（防止 App 被關閉）
        self.codeVerifier = verifier
        UserDefaults.standard.set(verifier, forKey: "pkce_verifier")

        // 建立授權 URL
        guard let url = URL(string: "\(baseURL)/device/authorize?challenge=\(challenge)") else {
            return
        }

        // 開啟瀏覽器
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: - Step 2: Handle Callback

    func handleCallback(url: URL) async throws {
        // 解析 URL 取得 authorization code
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.invalidCallback
        }

        // 取得 code_verifier
        guard let verifier = UserDefaults.standard.string(forKey: "pkce_verifier") else {
            throw AuthError.missingVerifier
        }

        // 交換 token
        try await exchangeToken(code: code, verifier: verifier)

        // 清理
        UserDefaults.standard.removeObject(forKey: "pkce_verifier")
        self.codeVerifier = nil
    }

    // MARK: - Step 3: Exchange Token

    private func exchangeToken(code: String, verifier: String) async throws {
        let url = URL(string: "\(baseURL)/api/device-auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceInfo = getDeviceInfo()
        let body: [String: Any] = [
            "authorization_code": code,
            "code_verifier": verifier,
            "device_name": deviceInfo.name,
            "device_type": deviceInfo.type,
            "device_model": deviceInfo.model,
            "os_version": deviceInfo.osVersion
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AuthError.tokenExchangeFailed
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let token = json?["access_token"] as? String,
                  let userData = json?["user"] as? [String: Any] else {
                throw AuthError.invalidResponse
            }

            // 儲存 token 到 Keychain
            try keychainManager.saveToken(token)

            // 更新狀態
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = User(from: userData)
            }

        } catch {
            throw AuthError.networkError(error)
        }
    }

    // MARK: - API Calls

    func fetchCurrentUser() async {
        guard let token = try? keychainManager.getToken() else {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            return
        }

        let url = URL(string: "\(baseURL)/api/auth/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }

            if httpResponse.statusCode == 401 {
                // Token 過期，登出
                await logout()
                return
            }

            guard httpResponse.statusCode == 200 else {
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let userData = json?["user"] as? [String: Any] else {
                return
            }

            await MainActor.run {
                self.currentUser = User(from: userData)
            }

        } catch {
            print("Failed to fetch user: \(error)")
        }
    }

    func logout() async {
        // 刪除 token
        try? keychainManager.deleteToken()

        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }

    // MARK: - Helpers

    private func getDeviceInfo() -> (name: String, type: String, model: String, osVersion: String) {
        #if os(iOS)
        let device = UIDevice.current
        return (
            name: device.name,
            type: "ios",
            model: device.model,
            osVersion: device.systemVersion
        )
        #elseif os(macOS)
        let host = Host.current()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return (
            name: host.localizedName ?? "Mac",
            type: "macos",
            model: "Mac",
            osVersion: osVersion
        )
        #endif
    }
}

// MARK: - User Model

struct User: Codable {
    let id: Int
    let name: String
    let email: String
    let avatar: String?
    let role: String

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? Int ?? 0
        self.name = dict["name"] as? String ?? ""
        self.email = dict["email"] as? String ?? ""
        self.avatar = dict["avatar"] as? String
        self.role = dict["role"] as? String ?? "user"
    }
}
```

### 5. App Delegate / Scene Delegate 整合

#### iOS (SceneDelegate.swift)

```swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        // 處理 teamchatup:// URL scheme
        if url.scheme == "teamchatup" {
            Task {
                do {
                    try await AuthManager.shared.handleCallback(url: url)
                } catch {
                    print("Authorization failed: \(error)")
                    // 顯示錯誤訊息給用戶
                }
            }
        }
    }
}
```

#### macOS (AppDelegate.swift)

```swift
import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        if url.scheme == "teamchatup" {
            Task {
                do {
                    try await AuthManager.shared.handleCallback(url: url)
                } catch {
                    print("Authorization failed: \(error)")
                }
            }
        }
    }
}
```

### 6. SwiftUI 登入畫面

```swift
import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("TeamChatUP")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("使用您的帳號登入")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                isLoading = true
                authManager.startAuthorization()

                // 2 秒後重置 loading 狀態
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "person.circle.fill")
                    }
                    Text("使用瀏覽器登入")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
```

### 7. API Client 實作

```swift
import Foundation

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://teamchatup.test/api"
    private let keychainManager = KeychainManager.shared

    private init() {}

    // MARK: - Generic Request

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let token = try? keychainManager.getToken() else {
            throw AuthError.missingVerifier
        }

        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Token 過期，觸發登出
            await AuthManager.shared.logout()
            throw AuthError.tokenExchangeFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Device Management

    func fetchDevices() async throws -> [Device] {
        struct Response: Codable {
            let devices: [Device]
        }

        let response: Response = try await request(endpoint: "/device-auth/devices")
        return response.devices
    }

    func revokeDevice(id: Int) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await request(
            endpoint: "/device-auth/devices/\(id)",
            method: "DELETE"
        )
    }
}

// MARK: - Models

struct Device: Codable, Identifiable {
    let id: Int
    let deviceName: String
    let deviceType: String?
    let deviceModel: String?
    let osVersion: String?
    let lastUsedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case deviceType = "device_type"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }
}
```

## 測試與除錯

### 1. 測試 PKCE 生成

```swift
func testPKCE() {
    let verifier = PKCEManager.generateCodeVerifier()
    let challenge = PKCEManager.generateCodeChallenge(from: verifier)

    print("Verifier: \(verifier)")
    print("Challenge: \(challenge)")
    print("Verifier length: \(verifier.count)")
    print("Challenge length: \(challenge.count)")

    // 驗證
    let isValid = PKCEManager.verifyChallenge(challenge, verifier: verifier)
    print("Valid: \(isValid)")
}
```

### 2. 測試 Deep Link

在 Safari 中輸入：
```
teamchatup://authorize?code=test123456789
```

### 3. 常見問題

**Q: Deep link 無法開啟 App？**
- 檢查 Info.plist 中的 URL Scheme 設定
- 確認 App 已安裝且 URL Scheme 已註冊
- 在實體設備上測試（模擬器可能有問題）

**Q: Token 交換失敗？**
- 檢查 code_verifier 是否正確儲存和讀取
- 確認 authorization_code 未過期（5 分鐘）
- 檢查網路連線和 API 端點

**Q: Token 過期後如何處理？**
- API 回傳 401 時自動觸發登出
- 引導用戶重新登入

## 安全性最佳實踐

1. **永遠使用 HTTPS**：生產環境必須使用 HTTPS
2. **Token 儲存**：使用 Keychain，不要用 UserDefaults
3. **Code Verifier**：使用加密安全的隨機數生成器
4. **Deep Link 驗證**：驗證 URL scheme 和參數
5. **錯誤處理**：不要在錯誤訊息中洩漏敏感資訊
6. **Token 刷新**：Token 過期前提示用戶重新登入

## 部署檢查清單

- [ ] Info.plist 配置正確的 URL Scheme
- [ ] HTTPS 端點配置完成
- [ ] Keychain 存取權限設定
- [ ] 錯誤處理和用戶提示完整
- [ ] 在實體設備上測試完整流程
- [ ] 測試 Token 過期情境
- [ ] 測試網路錯誤處理
- [ ] 測試設備管理功能

## 參考資源

- [RFC 7636 - PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [Apple URL Scheme Documentation](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
