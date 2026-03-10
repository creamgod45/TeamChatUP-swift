//
//  PKCEAuthManager.swift
//  TeamChatUP
//
//  Crea/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUPted by Kiro on 2026/3/7.
//

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum AuthError: Error, LocalizedError {
    case invalidCallback
    case missingVerifier
    case tokenExchangeFailed
    case invalidResponse
    case networkError(Error)
    case emptyCode
    
    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "無效的回調 URL"
        case .missingVerifier:
            return "找不到 code verifier"
        case .tokenExchangeFailed:
            return "Token 交換失敗"
        case .invalidResponse:
            return "無效的伺服器回應"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .emptyCode:
            return "授權碼不能為空"
        }
    }
}

@MainActor
final class PKCEAuthManager: ObservableObject {
    static let shared = PKCEAuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showTokenExpiredAlert = false

    private let keychainManager = KeychainManager.shared
    private let apiClient = APIClient.shared
    private var codeVerifier: String?
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Authentication Status
    
    func checkAuthStatus() {
        isAuthenticated = keychainManager.load() != nil
        
        if isAuthenticated {
            Task {
                await fetchCurrentUser()
            }
        }
    }
    
    // MARK: - Automatic Flow (Deep Link)
    
    func startAuthorization() {
        AppLogger.shared.info("開始 PKCE 自動授權流程")
        errorMessage = nil
        
        let verifier = PKCEManager.generateCodeVerifier()
        let challenge = PKCEManager.generateCodeChallenge(from: verifier)
        
        self.codeVerifier = verifier
        UserDefaults.standard.set(verifier, forKey: "pkce_verifier")
        AppLogger.shared.debug("已儲存 code_verifier 到 UserDefaults")
        
        let baseURL = AppConfig.deviceAuthURL
        guard let url = URL(string: "\(baseURL)?challenge=\(challenge)") else {
            AppLogger.shared.error("無法建立授權 URL")
            errorMessage = "無法建立授權 URL"
            return
        }
        
        AppLogger.shared.info("開啟授權頁面: \(url.absoluteString)")
        
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    func handleCallback(url: URL) async {
        AppLogger.shared.info("收到回調 URL: \(url.absoluteString)")
        isLoading = true
        errorMessage = nil
        
        do {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw AuthError.invalidCallback
            }
            
            AppLogger.shared.debug("取得 authorization code: \(code.prefix(10))...")
            
            guard let verifier = UserDefaults.standard.string(forKey: "pkce_verifier") else {
                throw AuthError.missingVerifier
            }
            
            AppLogger.shared.debug("取得 code_verifier: \(verifier.prefix(10))...")
            
            try await exchangeToken(code: code, verifier: verifier)
            
            UserDefaults.standard.removeObject(forKey: "pkce_verifier")
            self.codeVerifier = nil
            
            AppLogger.shared.info("✅ 自動授權流程完成")
            
        } catch {
            AppLogger.shared.error("❌ 授權流程失敗", error: error)
            errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Manual Flow (Code Entry)
    
    func startManualAuthorization() {
        AppLogger.shared.info("開始 PKCE 手動授權流程")
        errorMessage = nil
        
        let verifier = PKCEManager.generateCodeVerifier()
        let challenge = PKCEManager.generateCodeChallenge(from: verifier)
        
        self.codeVerifier = verifier
        UserDefaults.standard.set(verifier, forKey: "pkce_verifier")
        AppLogger.shared.debug("已儲存 code_verifier 到 UserDefaults (手動流程)")
        
        let baseURL = AppConfig.deviceAuthURL
        guard let url = URL(string: "\(baseURL)?challenge=\(challenge)") else {
            AppLogger.shared.error("無法建立授權 URL")
            errorMessage = "無法建立授權 URL"
            return
        }
        
        AppLogger.shared.info("開啟授權頁面 (手動流程): \(url.absoluteString)")
        
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    func exchangeManualCode(code: String) async {
        AppLogger.shared.info("開始手動交換授權碼")
        isLoading = true
        errorMessage = nil
        
        do {
            guard !code.isEmpty else {
                throw AuthError.emptyCode
            }
            
            guard let verifier = UserDefaults.standard.string(forKey: "pkce_verifier") else {
                throw AuthError.missingVerifier
            }
            
            AppLogger.shared.debug("使用手動輸入的授權碼: \(code.prefix(10))...")
            AppLogger.shared.debug("使用儲存的 verifier: \(verifier.prefix(10))...")
            
            try await exchangeToken(code: code, verifier: verifier)
            
            UserDefaults.standard.removeObject(forKey: "pkce_verifier")
            self.codeVerifier = nil
            
            AppLogger.shared.info("✅ 手動授權流程完成")
            
        } catch {
            AppLogger.shared.error("❌ 手動授權失敗", error: error)
            errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Token Exchange (共用)
    
    private func exchangeToken(code: String, verifier: String) async throws {
        AppLogger.shared.info("開始交換 token")
        
        let deviceInfo = getDeviceInfo()
        
        do {
            let response = try await apiClient.exchangeDeviceToken(
                authorizationCode: code,
                codeVerifier: verifier,
                deviceInfo: deviceInfo
            )
            
            keychainManager.save(token: response.accessToken)
            
            self.isAuthenticated = true
            self.currentUser = response.user
            
            // 立即啟動 WebSocket 連線
            WebSocketManager.shared.connect(token: response.accessToken)
            
            AppLogger.shared.info("✅ Token 已儲存，使用者已登入")
            
        } catch {
            AppLogger.shared.error("Token 交換失敗", error: error)
            throw AuthError.tokenExchangeFailed
        }
    }
    
    // MARK: - API Calls
    
    func fetchCurrentUser() async {
        AppLogger.shared.debug("取得當前使用者資訊")

        do {
            let user = try await apiClient.getCurrentUser()
            self.currentUser = user
            self.showTokenExpiredAlert = false
            AppLogger.shared.info("使用者資訊已更新: \(user.name)")
        } catch {
            AppLogger.shared.error("無法取得使用者資訊", error: error)

            if let apiError = error as? APIError, case .unauthorized = apiError {
                AppLogger.shared.warning("Token 已過期，顯示重新登入提示")
                self.showTokenExpiredAlert = true
            }
        }
    }

    func handleTokenExpiration(shouldRelogin: Bool) async {
        if shouldRelogin {
            AppLogger.shared.info("使用者選擇重新登入")
            await logout()
            startAuthorization()
        } else {
            AppLogger.shared.info("使用者取消重新登入")
            await logout()
        }
        showTokenExpiredAlert = false
    }
    
    func logout() async {
        AppLogger.shared.info("使用者登出")
        
        do {
            try await apiClient.logout()
        } catch {
            AppLogger.shared.warning("登出 API 呼叫失敗: \(error.localizedDescription)，但仍會清除本地資料")
        }
        
        keychainManager.delete()
        
        self.isAuthenticated = false
        self.currentUser = nil
        
        AppLogger.shared.info("已清除本地認證資料")
    }
    
    // MARK: - Device Management
    
    func fetchDevices() async throws -> [Device] {
        AppLogger.shared.debug("取得已授權設備列表")
        return try await apiClient.getDevices()
    }
    
    func revokeDevice(id: Int) async throws {
        AppLogger.shared.info("撤銷設備 - ID: \(id)")
        try await apiClient.revokeDevice(id: id)
    }
    
    // MARK: - Helpers
    
    private func getDeviceInfo() -> DeviceInfo {
        #if os(iOS)
        let device = UIDevice.current
        return DeviceInfo(
            name: device.name,
            type: "ios",
            model: device.model,
            osVersion: device.systemVersion
        )
        #elseif os(macOS)
        let host = Host.current()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return DeviceInfo(
            name: host.localizedName ?? "Mac",
            type: "macos",
            model: "Mac",
            osVersion: osVersion
        )
        #endif
    }
}
