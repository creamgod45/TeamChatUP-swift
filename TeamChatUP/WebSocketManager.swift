//
//  WebSocketManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import Combine
import Observation

enum WebSocketEvent: Codable {
    case newMessage(MessageResponse)
    case typing(TypingEvent)
    case userOnline(UserStatusEvent)
    case userOffline(UserStatusEvent)
    case messageRead(MessageReadEvent)
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "new_message":
            let message = try container.decode(MessageResponse.self, forKey: .data)
            self = .newMessage(message)
        case "typing":
            let event = try container.decode(TypingEvent.self, forKey: .data)
            self = .typing(event)
        case "user_online":
            let event = try container.decode(UserStatusEvent.self, forKey: .data)
            self = .userOnline(event)
        case "user_offline":
            let event = try container.decode(UserStatusEvent.self, forKey: .data)
            self = .userOffline(event)
        case "message_read":
            let event = try container.decode(MessageReadEvent.self, forKey: .data)
            self = .messageRead(event)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown event type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .newMessage(let message):
            try container.encode("new_message", forKey: .type)
            try container.encode(message, forKey: .data)
        case .typing(let event):
            try container.encode("typing", forKey: .type)
            try container.encode(event, forKey: .data)
        case .userOnline(let event):
            try container.encode("user_online", forKey: .type)
            try container.encode(event, forKey: .data)
        case .userOffline(let event):
            try container.encode("user_offline", forKey: .type)
            try container.encode(event, forKey: .data)
        case .messageRead(let event):
            try container.encode("message_read", forKey: .type)
            try container.encode(event, forKey: .data)
        }
    }
}

struct TypingEvent: Codable {
    let userId: Int
    let userName: String?
    let conversationId: Int
    let isTyping: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userName = "user_name"
        case conversationId = "conversation_id"
        case isTyping = "is_typing"
    }
}

struct UserStatusEvent: Codable {
    let userId: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct MessageReadEvent: Codable {
    let conversationId: Int
    let userId: Int
    let lastReadMessageId: Int
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case lastReadMessageId = "last_read_message_id"
    }
}

// MARK: - Pusher WebSocket Manager

@Observable @MainActor
final class WebSocketManager: NSObject {
    static let shared = WebSocketManager()

    var isConnected = false
    var connectionError: String?
    private var pingTimer: Timer?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var socketId: String?
    private var subscribedChannels: Set<String> = []
    private var pendingSubscriptions: Set<Int> = []

    let eventPublisher = PassthroughSubject<WebSocketEvent, Never>()

    private override init() {
        super.init()
        setupURLSession()
    }

    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Connection

    func connect(token: String? = nil) {
        guard !isConnected else { return }
        
        let activeToken = token ?? KeychainManager.shared.load()

        guard activeToken != nil else {
            connectionError = "未找到認證 token"
            AppLogger.shared.error("WebSocket 連線失敗: 未找到 token")
            return
        }

        let config = AppConfig.reverbConfig

        // Pusher WebSocket URL: wss://host:port/app/{key}
        let urlString = "\(config.useTLS ? "wss" : "ws")://\(config.host):\(config.port)/app/\(config.key)?protocol=7&client=pusher-swift&version=10.1.0"

        guard let url = URL(string: urlString) else {
            connectionError = "無效的 WebSocket URL"
            AppLogger.shared.error("WebSocket URL 無效: \(urlString)")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        AppLogger.shared.info("🌐 連接 WebSocket: \(urlString)")

        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        socketId = nil
        subscribedChannels.removeAll()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        stopHeartbeat()
        reconnectAttempts = 0

        AppLogger.shared.info("🔌 WebSocket 已斷線")
    }

    // MARK: - Channel Subscription

    func subscribeToConversation(_ conversationId: Int) {
        let channelName = "private-conversation.\(conversationId)"

        guard !subscribedChannels.contains(channelName) else {
            return
        }

        guard let socketId = socketId else {
            AppLogger.shared.debug("Socket ID 尚未取得,加入待訂閱列表: \(conversationId)")
            pendingSubscriptions.insert(conversationId)
            return
        }

        Task {
            do {
                let auth = try await getChannelAuth(socketId: socketId, channelName: channelName)

                let subscribeMessage: [String: Any] = [
                    "event": "pusher:subscribe",
                    "data": [
                        "auth": auth,
                        "channel": channelName
                    ]
                ]

                try await sendMessage(subscribeMessage)
                subscribedChannels.insert(channelName)

                AppLogger.shared.info("📡 訂閱頻道: \(channelName)")
            } catch {
                AppLogger.shared.error("訂閱頻道失敗: \(channelName)", error: error)
            }
        }
    }

    private func getChannelAuth(socketId: String, channelName: String) async throws -> String {
        guard let token = KeychainManager.shared.load() else {
            throw APIError.unauthorized
        }

        let config = AppConfig.reverbConfig
        guard let url = URL(string: config.authEndpoint) else {
            throw APIError.unknown
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "socket_id": socketId,
            "channel_name": channelName
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.unauthorized
        }

        struct AuthResponse: Codable {
            let auth: String
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        return authResponse.auth
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleMessage(message)
                    self.receiveMessage()
                }

            case .failure(let error):
                Task { @MainActor in
                    AppLogger.shared.error("WebSocket 接收錯誤", error: error)
                    self.handleDisconnection()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            handlePusherMessage(data)

        case .data(let data):
            handlePusherMessage(data)

        @unknown default:
            break
        }
    }

    private func handlePusherMessage(_ data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let event = json["event"] as? String else {
                return
            }

            AppLogger.shared.debug("🔍 收到事件: \(event)")
            if let dataValue = json["data"] {
                AppLogger.shared.debug("📦 事件資料內容: \(dataValue)")
            }
            if let channel = json["channel"] as? String {
                AppLogger.shared.debug("📺 事件頻道: \(channel)")
            }

            switch event {
            case "pusher:connection_established":
                handleConnectionEstablished(json)

            case "pusher:subscription_succeeded", "pusher_internal:subscription_succeeded":
                handleSubscriptionSucceeded(json)

            case "pusher:subscription_error":
                handleSubscriptionError(json)

            case "message.sent", ".message.sent":
                handleMessageSent(json)

            case "user.typing", ".user.typing":
                handleUserTyping(json)

            case "pusher:pong":
                break

            default:
                AppLogger.shared.debug("未處理的事件: \(event)")
            }

        } catch {
            AppLogger.shared.error("解析 Pusher 訊息失敗", error: error)
        }
    }

    private func handleConnectionEstablished(_ json: [String: Any]) {
        guard let dataString = json["data"] as? String,
              let dataJson = try? JSONSerialization.jsonObject(with: dataString.data(using: .utf8)!) as? [String: Any],
              let socketId = dataJson["socket_id"] as? String else {
            return
        }

        self.socketId = socketId
        self.isConnected = true
        self.connectionError = nil
        self.reconnectAttempts = 0

        AppLogger.shared.info("✅ WebSocket 連線成功 - Socket ID: \(socketId)")
        
        // 處理待訂閱列表
        let toSubscribe = pendingSubscriptions
        pendingSubscriptions.removeAll()
        for id in toSubscribe {
            subscribeToConversation(id)
        }
        
        startHeartbeat()
    }

    private func handleSubscriptionSucceeded(_ json: [String: Any]) {
        guard let channel = json["channel"] as? String else { return }
        AppLogger.shared.info("✅ 訂閱成功: \(channel)")
    }

    private func handleSubscriptionError(_ json: [String: Any]) {
        guard let channel = json["channel"] as? String else { return }
        AppLogger.shared.error("❌ 訂閱失敗: \(channel)")
        subscribedChannels.remove(channel)
    }

    private func handleMessageSent(_ json: [String: Any]) {
        let data: Data
        
        if let dataString = json["data"] as? String {
            guard let d = dataString.data(using: .utf8) else { return }
            data = d
        } else if let dataDict = json["data"] as? [String: Any] {
            guard let d = try? JSONSerialization.data(withJSONObject: dataDict) else { return }
            data = d
        } else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct MessageEventData: Codable {
                let message: MessageResponse
            }

            let eventData = try decoder.decode(MessageEventData.self, from: data)

            eventPublisher.send(.newMessage(eventData.message))

            let currentUserId = PKCEAuthManager.shared.currentUser?.id ?? 0
            if eventData.message.user.id != currentUserId {
                SoundManager.shared.playMessageSound()
            }

            AppLogger.shared.info("📩 收到新訊息: \(eventData.message.content)")

        } catch {
            AppLogger.shared.error("解析訊息事件失敗", error: error)
        }
    }

    private func handleUserTyping(_ json: [String: Any]) {
        let data: Data

        if let dataString = json["data"] as? String {
            guard let d = dataString.data(using: .utf8) else { return }
            data = d
        } else if let dataDict = json["data"] as? [String: Any] {
            guard let d = try? JSONSerialization.data(withJSONObject: dataDict) else { return }
            data = d
        } else {
            return
        }

        do {
            let decoder = JSONDecoder()
            // 因為 TypingEvent 已經定義了 CodingKeys，不需要也不應該使用 convertFromSnakeCase
            let typingEvent = try decoder.decode(TypingEvent.self, from: data)

            eventPublisher.send(.typing(typingEvent))

            AppLogger.shared.debug("⌨️ 收到輸入中訊號 - 使用者ID: \(typingEvent.userId), 對話ID: \(typingEvent.conversationId), 輸入中: \(typingEvent.isTyping)")

        } catch {
            AppLogger.shared.error("解析輸入中事件失敗", error: error)
            if let jsonString = String(data: data, encoding: .utf8) {
                AppLogger.shared.debug("原始 JSON 內容: \(jsonString)")
            }
        }
    }

    private func handleDisconnection() {
        stopHeartbeat()
        isConnected = false
        socketId = nil
        subscribedChannels.removeAll()

        guard reconnectAttempts < maxReconnectAttempts else {
            connectionError = "連線失敗次數過多"
            AppLogger.shared.error("WebSocket 重連失敗: 超過最大嘗試次數")
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)

        AppLogger.shared.warning("⚠️ WebSocket 斷線，\(delay) 秒後重連 (嘗試 \(reconnectAttempts)/\(maxReconnectAttempts))")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.connect()
            }
        }
    }

    // MARK: - Send Message

    private func sendMessage(_ data: [String: Any]) async throws {
        guard isConnected else {
            throw NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "未連線"])
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WebSocket", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法編碼訊息"])
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webSocketTask?.send(message) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        
        // Pusher protocol typical heartbeat interval is 30 seconds
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.sendPing()
            }
        }
        AppLogger.shared.debug("💓 WebSocket 心跳計時器已啟動")
    }

    private func stopHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = nil
        AppLogger.shared.debug("💓 WebSocket 心跳計時器已停止")
    }

    private func sendPing() async {
        guard isConnected else { return }
        
        do {
            let pingMessage: [String: Any] = [
                "event": "pusher:ping",
                "data": [:]
            ]
            try await sendMessage(pingMessage)
            AppLogger.shared.debug("💓 發送 WebSocket Ping")
        } catch {
            AppLogger.shared.error("❌ 發送 WebSocket Ping 失敗", error: error)
        }
    }

    func sendTyping(conversationId: Int, isTyping: Bool) {
        // Typing events not implemented in Pusher protocol for now
        AppLogger.shared.debug("Typing event: \(isTyping) for conversation \(conversationId)")
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            self.isConnected = true
            self.connectionError = nil
            self.reconnectAttempts = 0
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            self.handleDisconnection()
        }
    }
}
