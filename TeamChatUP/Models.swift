//
//  Models.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import Security

// MARK: - User Model

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let email: String?
    let avatar: String?
    let role: String?
    let workosId: String?
    let organizationId: String?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, email, avatar, role
        case workosId = "workos_id"
        case organizationId = "organization_id"
        case isActive = "is_active"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? email?.components(separatedBy: "@").first ?? "Unknown"
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "user"
        workosId = try container.decodeIfPresent(String.self, forKey: .workosId)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        
        AppLogger.shared.debug("User 解碼成功 - ID: \(id), Email: \(String(describing: email)), Name: \(name)")
    }
    
    init(id: Int, name: String, email: String?, avatar: String?, role: String?, workosId: String? = nil, organizationId: String? = nil, isActive: Bool? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.avatar = avatar
        self.role = role
        self.workosId = workosId
        self.organizationId = organizationId
        self.isActive = isActive
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Keychain Manager

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.teamchatup.token"
    private let account = "sanctum_token"
    
    private init() {}
    
    func save(token: String) {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
        
        AppLogger.shared.info("Token 已儲存到 Keychain")
    }
    
    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            AppLogger.shared.warning("無法從 Keychain 讀取 token")
            return nil
        }
        
        AppLogger.shared.debug("Token 已從 Keychain 讀取")
        return token
    }
    
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
        AppLogger.shared.info("Token 已從 Keychain 刪除")
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case validationError([String: [String]])
    case rateLimited
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case decodingError(Error, rawData: String?)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "未授權，請重新登入"
        case .forbidden:
            return "無權限執行此操作"
        case .notFound:
            return "找不到資源"
        case .validationError(let errors):
            return errors.values.flatMap { $0 }.first ?? "驗證失敗"
        case .rateLimited:
            return "請求過於頻繁，請稍後再試"
        case .serverError(let statusCode, let message):
            return "伺服器錯誤 (\(statusCode)): \(message ?? "未知錯誤")"
        case .networkError(let error):
            return "網路連線失敗: \(error.localizedDescription)"
        case .decodingError(let error, let rawData):
            var message = "資料解析失敗: \(error.localizedDescription)"
            if let rawData = rawData {
                message += "\n原始資料: \(rawData)"
            }
            return message
        case .unknown:
            return "發生未知錯誤"
        }
    }
}

// MARK: - Network Models

struct APIResponse<T: Codable>: Codable {
    let data: T
}

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let meta: PaginationMeta
}

struct PaginationMeta: Codable {
    let currentPage: Int
    let total: Int
    
    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case total
    }
}

struct Conversation: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let type: ConversationType
    let participants: [User]
    let lastMessage: MessageResponse?
    let unreadCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, participants
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case createdAt = "created_at"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}

enum ConversationType: String, Codable {
    case direct
    case group
}

struct MessageResponse: Codable, Identifiable, Hashable {
    let id: Int
    let content: String
    let type: MessageType
    let user: User
    let conversationId: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, content, type, user
        case conversationId = "conversation_id"
        case createdAt = "created_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MessageResponse, rhs: MessageResponse) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageType: String, Codable {
    case text
    case system
}

struct CreateConversationRequest: Codable {
    let type: ConversationType
    let name: String?
    let participantIds: [Int]
    
    enum CodingKeys: String, CodingKey {
        case type, name
        case participantIds = "participant_ids"
    }
}

struct SendMessageRequest: Codable {
    let content: String
    let type: MessageType
}

struct AuthTokenRequest: Codable {
    let authorizationCode: String
    let deviceName: String
    
    enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorization_code"
        case deviceName = "device_name"
    }
}

struct AuthTokenResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Device Auth Models

struct DeviceAuthTokenRequest: Codable {
    let authorizationCode: String
    let codeVerifier: String
    let deviceName: String
    let deviceType: String
    let deviceModel: String
    let osVersion: String
    
    enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorization_code"
        case codeVerifier = "code_verifier"
        case deviceName = "device_name"
        case deviceType = "device_type"
        case deviceModel = "device_model"
        case osVersion = "os_version"
    }
}

struct DeviceAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

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

// MARK: - SSL Certificate Bypass Delegate (Development Only)

final class SSLBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Only bypass SSL for development domain
        if challenge.protectionSpace.host == "teamchatup-backend.test" {
            AppLogger.shared.warning("⚠️ 繞過 SSL 憑證驗證 (僅限開發環境): \(challenge.protectionSpace.host)")
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            // For all other domains, use default handling
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let urlSession: URLSession

    private init() {
        self.baseURL = AppConfig.apiBaseURL

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        // Create custom URLSession with SSL bypass delegate for development
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: configuration, delegate: SSLBypassDelegate(), delegateQueue: nil)

        AppLogger.shared.info("APIClient 初始化完成，Base URL: \(baseURL)")
    }

    private var token: String? {
        KeychainManager.shared.load()
    }
    
    // MARK: - Device Auth
    
    func exchangeDeviceToken(authorizationCode: String, codeVerifier: String, deviceInfo: DeviceInfo) async throws -> DeviceAuthTokenResponse {
        AppLogger.shared.info("開始交換 device authorization code 為 token")
        
        let request = DeviceAuthTokenRequest(
            authorizationCode: authorizationCode,
            codeVerifier: codeVerifier,
            deviceName: deviceInfo.name,
            deviceType: deviceInfo.type,
            deviceModel: deviceInfo.model,
            osVersion: deviceInfo.osVersion
        )
        
        do {
            let response: DeviceAuthTokenResponse = try await post("/device-auth/token", body: request)
            AppLogger.shared.info("✅ Device Token 交換成功")
            AppLogger.shared.info("使用者: \(response.user.name) (\(String(describing: response.user.email)))")
            return response
        } catch {
            AppLogger.shared.error("❌ Device Token 交換失敗", error: error)
            throw error
        }
    }
    
    func getDevices() async throws -> [Device] {
        AppLogger.shared.debug("取得已授權設備列表")
        struct Response: Codable {
            let devices: [Device]
        }
        let response: Response = try await get("/device-auth/devices")
        return response.devices
    }
    
    func revokeDevice(id: Int) async throws {
        AppLogger.shared.info("撤銷設備 - ID: \(id)")
        try await delete("/device-auth/devices/\(id)")
    }
    
    // MARK: - Legacy Auth (WorkOS)
    
    func exchangeToken(authorizationCode: String, deviceName: String) async throws -> AuthTokenResponse {
        AppLogger.shared.info("開始交換 authorization code 為 token")
        let request = AuthTokenRequest(
            authorizationCode: authorizationCode,
            deviceName: deviceName
        )
        
        do {
            let response: AuthTokenResponse = try await post("/auth/token", body: request)
            AppLogger.shared.info("✅ Token 交換成功")
            return response
        } catch {
            AppLogger.shared.error("❌ Token 交換失敗", error: error)
            throw error
        }
    }
    
    func getCurrentUser() async throws -> User {
        AppLogger.shared.debug("取得當前使用者資訊")
        struct UserResponse: Codable {
            let user: User
        }
        let response: UserResponse = try await get("/auth/me")
        return response.user
    }
    
    func logout() async throws {
        AppLogger.shared.info("使用者登出")
        try await post("/auth/logout", body: EmptyBody())
    }
    
    // MARK: - Users
    
    func getUsers(search: String? = nil, page: Int = 1, perPage: Int = 50) async throws -> PaginatedResponse<User> {
        AppLogger.shared.debug("取得使用者列表 - 頁數: \(page), 每頁: \(perPage)")
        
        var components = URLComponents(string: "\(baseURL)/users")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
            AppLogger.shared.debug("搜尋關鍵字: \(search)")
        }
        
        components.queryItems = queryItems
        
        return try await get(components.url!.path + "?" + (components.query ?? ""))
    }
    
    // MARK: - Conversations
    
    func getConversations(page: Int, perPage: Int) async throws -> PaginatedResponse<Conversation> {
        AppLogger.shared.debug("取得對話列表 - 頁數: \(page), 每頁: \(perPage)")
        return try await get("/conversations?page=\(page)&per_page=\(perPage)")
    }
    
    func createConversation(type: ConversationType, name: String?, participantIds: [Int]) async throws -> APIResponse<Conversation> {
        AppLogger.shared.info("建立新對話 - 類型: \(type.rawValue), 參與者: \(participantIds)")
        let request = CreateConversationRequest(
            type: type,
            name: name,
            participantIds: participantIds
        )
        return try await post("/conversations", body: request)
    }
    
    func markAsRead(conversationId: Int) async throws {
        AppLogger.shared.debug("標記對話為已讀 - ID: \(conversationId)")
        try await post("/conversations/\(conversationId)/read", body: EmptyBody())
    }
    
    func getMessages(conversationId: Int, page: Int, perPage: Int) async throws -> PaginatedResponse<MessageResponse> {
        AppLogger.shared.debug("取得訊息列表 - 對話ID: \(conversationId), 頁數: \(page)")
        return try await get("/conversations/\(conversationId)/messages?page=\(page)&per_page=\(perPage)")
    }
    
    func sendMessage(conversationId: Int, content: String) async throws -> APIResponse<MessageResponse> {
        AppLogger.shared.debug("發送訊息 - 對話ID: \(conversationId)")
        let request = SendMessageRequest(content: content, type: .text)
        return try await post("/conversations/\(conversationId)/messages", body: request)
    }
    
    func sendTypingIndicator(conversationId: Int) async throws {
        try await post("/conversations/\(conversationId)/typing", body: EmptyBody())
    }
    
    // MARK: - HTTP Methods
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request)
    }
    
    private func post<T: Encodable, U: Decodable>(_ path: String, body: T) async throws -> U {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try encoder.encode(body)
        return try await performRequest(request)
    }
    
    private func post<T: Encodable>(_ path: String, body: T) async throws {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try encoder.encode(body)
        let _: EmptyResponse = try await performRequest(request)
    }
    
    private func delete(_ path: String) async throws {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let startTime = Date()
        AppLogger.shared.logRequest(request, startTime: startTime)

        do {
            let (data, response) = try await urlSession.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.error("回應不是 HTTPURLResponse")
                throw APIError.unknown
            }

            let rawResponse = String(data: data, encoding: .utf8) ?? "無法解析"
            AppLogger.shared.logResponse(httpResponse, data: data, error: nil, request: request, duration: duration)

            // 檢查是否收到 HTML 回應（可能是重定向到登入頁面）
            if rawResponse.contains("<!DOCTYPE html>") || rawResponse.contains("<html") {
                AppLogger.shared.warning("收到 HTML 回應而非 JSON - 可能是授權失效導致重定向")

                // 檢查是否是 WorkOS 登入頁面
                if rawResponse.contains("workos") || rawResponse.contains("login") || rawResponse.contains("auth") {
                    AppLogger.shared.error("偵測到 WorkOS 登入頁面 - Token 已過期")

                    // 通知 PKCEAuthManager 顯示過期警告
                    Task { @MainActor in
                        PKCEAuthManager.shared.showTokenExpiredAlert = true
                    }

                    throw APIError.unauthorized
                }
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let result = try decoder.decode(T.self, from: data)
                    AppLogger.shared.debug("✅ JSON 解析成功")
                    return result
                } catch {
                    AppLogger.shared.error("❌ JSON 解析失敗", error: error)
                    AppLogger.shared.critical("原始 JSON 回應:")
                    AppLogger.shared.critical(rawResponse)

                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        AppLogger.shared.critical("JSON 結構:")
                        json.forEach { key, value in
                            AppLogger.shared.critical("  - \(key): \(type(of: value))")
                        }
                    }

                    throw APIError.decodingError(error, rawData: rawResponse)
                }
            case 401:
                AppLogger.shared.warning("未授權 (401) - Token 可能已過期")

                // 通知 PKCEAuthManager 顯示過期警告
                Task { @MainActor in
                    PKCEAuthManager.shared.showTokenExpiredAlert = true
                }

                throw APIError.unauthorized
            case 403:
                AppLogger.shared.warning("無權限 (403)")
                throw APIError.forbidden
            case 404:
                AppLogger.shared.warning("找不到資源 (404)")
                throw APIError.notFound
            case 422:
                if let errorResponse = try? decoder.decode(ValidationErrorResponse.self, from: data) {
                    AppLogger.shared.warning("驗證失敗 (422): \(errorResponse.errors)")
                    throw APIError.validationError(errorResponse.errors)
                }
                throw APIError.validationError([:])
            case 429:
                AppLogger.shared.warning("請求過於頻繁 (429)")
                throw APIError.rateLimited
            case 500...599:
                AppLogger.shared.error("伺服器錯誤 (\(httpResponse.statusCode))")
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: rawResponse)
            default:
                AppLogger.shared.error("未知的狀態碼: \(httpResponse.statusCode)")
                throw APIError.unknown
            }
        } catch let error as APIError {
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            AppLogger.shared.logResponse(nil, data: nil, error: error, request: request, duration: duration)
            throw APIError.networkError(error)
        }
    }
}

struct DeviceInfo {
    let name: String
    let type: String
    let model: String
    let osVersion: String
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}

private struct ValidationErrorResponse: Decodable {
    let message: String
    let errors: [String: [String]]
}
