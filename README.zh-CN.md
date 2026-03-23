# TeamChatUP

基于 SwiftUI 构建的现代化即时聊天应用程序，支持 iOS 和 macOS 平台。

## 概述

TeamChatUP 是一款跨平台即时通讯应用程序，提供安全的即时通讯功能，支持私人消息和群组对话。应用程序采用基于 PKCE 的设备授权、WebSocket 即时消息传递，以及离线优先的本地数据持久化。

## 功能特色

- 🔐 **安全认证**：PKCE（Proof Key for Code Exchange）设备授权流程
- 💬 **即时消息**：基于 WebSocket 的即时消息传递
- 📱 **跨平台支持**：原生支持 iOS 和 macOS
- 💾 **离线优先**：使用 SwiftData 进行本地数据持久化
- 👥 **群组聊天**：支持私人对话和群组对话
- 🔔 **即时更新**：即时输入指示器和在线状态
- 🔒 **安全存储**：基于 Keychain 的 Token 管理

## 技术栈

- **UI 框架**：SwiftUI
- **本地持久化**：SwiftData
- **网络通信**：URLSession with async/await
- **即时通信**：WebSocket (URLSessionWebSocketTask)
- **身份验证**：PKCE OAuth 2.0
- **安全存储**：Keychain Services
- **架构模式**：MVVM with Observable pattern

## 系统要求

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## 安装步骤

1. 克隆项目：
```bash
git clone https://github.com/yourusername/TeamChatUP.git
cd TeamChatUP
```

2. 在 Xcode 中打开项目：
```bash
open TeamChatUP.xcodeproj
```

3. 在 `AppConfig.swift` 中配置环境（请参阅下方配置章节）

4. 构建并运行项目

## 配置设置

### 环境设置

应用程序在 `AppConfig.swift` 中支持三种环境：

- **Development**：本地开发服务器
- **Staging**：测试环境
- **Production**：正式环境

环境会根据构建配置自动选择：
- Debug 构建 → Development
- Release 构建 → Production

### API 端点

在 `AppConfig.swift` 中配置以下 URL：

```swift
static var apiBaseURL: String {
    // REST API 基础 URL
}

static var websocketURL: String {
    // WebSocket 服务器 URL
}

static var deviceAuthURL: String {
    // 设备授权 URL
}
```

### URL Scheme

应用程序注册 `teamchatup://` URL scheme 用于 OAuth 回调。此设置在 `Info.plist` 中配置。

## 构建命令

### 构建 iOS 模拟器版本
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### 构建 macOS 版本
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=macOS' \
  build
```

### 运行测试
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

### 清理构建
```bash
xcodebuild -scheme TeamChatUP clean
```

## 架构设计

### 认证流程

TeamChatUP 实现 PKCE 设备授权，提供两种方式：

#### 1. 自动流程（Deep Link）
1. 用户点击「自动授权登录」
2. 应用程序生成 PKCE challenge 并打开浏览器
3. 用户在浏览器中授权
4. 浏览器重定向至 `teamchatup://auth/callback?code=...`
5. 应用程序使用 code + verifier 交换 access token

#### 2. 手动流程（代码输入）
1. 用户点击「手动输入授权码」
2. 应用程序打开浏览器进行授权
3. 用户从浏览器复制授权码
4. 用户将代码粘贴到应用程序
5. 应用程序交换代码以获取 access token

**核心组件：**
- `PKCEAuthManager.swift` - 管理认证状态和 token 交换
- `PKCEManager.swift` - 生成 PKCE challenge/verifier 配对
- `LoginView.swift` - 登录 UI，包含两种认证流程

### 数据架构

应用程序维护**两个独立的数据层**：

#### 1. 本地存储（SwiftData）
- 模型：`ChatRoom`、`Message`
- 用途：离线优先的本地聊天记录
- Schema：定义于 `TeamChatUPApp.swift`

#### 2. 远程 API（REST + WebSocket）
- 模型：`Conversation`、`MessageResponse`、`User`
- REST API：通过 `APIClient` 进行 CRUD 操作
- WebSocket：通过 `WebSocketManager` 进行即时更新

> **重要**：本地 SwiftData 模型和远程 API 模型是分离的，不会自动同步。

### 即时消息

WebSocket 连接由 `WebSocketManager` 管理：

- **连接方式**：使用 query string 中的 token 进行认证
- **事件类型**：
  - `new_message` - 收到新消息
  - `typing` - 用户输入指示器
  - `user_online` - 用户上线
  - `user_offline` - 用户离线
  - `message_read` - 消息已读回执
- **重新连接**：自动重连，采用指数退避策略（最多 5 次尝试）
- **事件发布**：使用 Combine `PassthroughSubject`

### Token 管理

- **存储方式**：通过 `KeychainManager` 安全存储于 Keychain
- **授权机制**：所有 API 请求包含 `Authorization: Bearer <token>` header
- **过期处理**：通过 401 响应检测
- **重新认证**：Token 过期时自动显示提示

### 日志记录

通过 `AppLogger`（位于 `Logger.swift`）进行结构化日志记录：

```swift
AppLogger.shared.debug("开发信息")
AppLogger.shared.info("重要事件")
AppLogger.shared.warning("可恢复的问题")
AppLogger.shared.error("发生错误", error: error)
AppLogger.shared.critical("严重故障")
```

## 项目结构

```
TeamChatUP/
├── TeamChatUP/
│   ├── TeamChatUPApp.swift          # 应用程序入口点、SwiftData schema
│   ├── AppConfig.swift              # 环境配置
│   ├── Models.swift                 # API 模型、APIClient、KeychainManager
│   │
│   ├── Authentication/
│   │   ├── PKCEAuthManager.swift    # 认证状态管理
│   │   ├── PKCEManager.swift        # PKCE challenge 生成
│   │   └── LoginView.swift          # 登录 UI
│   │
│   ├── Managers/
│   │   ├── WebSocketManager.swift   # WebSocket 连接
│   │   ├── ConversationManager.swift
│   │   ├── MessageManager.swift
│   │   ├── UserManager.swift
│   │   └── SoundManager.swift
│   │
│   ├── Views/
│   │   ├── ConversationListView.swift
│   │   ├── ChatDetailView.swift
│   │   ├── UserListView.swift
│   │   └── DevicesView.swift
│   │
│   ├── Models/
│   │   ├── ChatRoom.swift           # SwiftData 模型
│   │   └── Message.swift            # SwiftData 模型
│   │
│   └── Utilities/
│       └── Logger.swift              # 结构化日志
│
├── TeamChatUPTests/
└── TeamChatUPUITests/
```

## 开发指南

### 新增 API 端点

1. 在 `Models.swift` 中添加请求/响应模型
2. 在 `APIClient` 中添加方法（使用现有的 `get`/`post`/`delete` 辅助方法）
3. 从 manager 类调用（例如：`ConversationManager`、`UserManager`）

### 新增 WebSocket 事件

1. 在 `WebSocketManager.swift` 的 `WebSocketEvent` enum 中添加 case
2. 在 `init(from:)` 和 `encode(to:)` 中处理解码和编码
3. 在 views/managers 中订阅 `WebSocketManager.shared.eventPublisher`

### 跨平台考量

代码同时支持 iOS 和 macOS：
- 使用 `#if os(iOS)` / `#elseif os(macOS)` 处理平台特定代码
- 工具栏位置：使用 `.automatic` 而非 `.navigationBarTrailing`
- Import 保护：`#if canImport(UIKit)` / `#elseif canImport(AppKit)`

## API 集成

### 基础 URL

应用程序连接到后端 API，包含以下端点：

- **认证**：`/device-auth/token`、`/device-auth/devices`
- **对话**：`/conversations`、`/conversations/{id}/messages`
- **用户**：`/users`、`/users/me`
- **消息**：`/messages`、`/messages/{id}`

### WebSocket 连接

WebSocket URL 格式：
```
wss://your-server.com?token=<access_token>
```

## 安全性

- **Token 存储**：Access token 安全存储于 Keychain
- **PKCE 流程**：防止授权码拦截攻击
- **TLS/SSL**：所有网络通信通过 HTTPS/WSS
- **Token 过期**：自动检测并触发重新认证流程

## 疑难解答

### WebSocket 连接问题

1. 检查 Keychain 中的 token 有效性
2. 验证 `AppConfig.swift` 中的 WebSocket URL
3. 检查网络连接状态
4. 在 Console.app 中查看详细错误信息

### 认证失败

1. 验证设备授权 URL 是否正确
2. 检查 PKCE verifier 是否正确存储
3. 确认 URL scheme 已在 `Info.plist` 中注册
4. 查看 `PKCEAuthManager` 日志以获取详细错误信息

## 许可协议

[请在此添加许可协议]

## 联系方式

[请在此添加联系信息]
