# TeamChatUP

A modern, real-time chat application built with SwiftUI for iOS and macOS platforms.

## Overview

TeamChatUP is a cross-platform messaging application that provides secure, real-time communication with support for direct messages and group conversations. The app features PKCE-based device authorization, WebSocket real-time messaging, and offline-first local data persistence.

## Features

- 🔐 **Secure Authentication**: PKCE (Proof Key for Code Exchange) device authorization flow
- 💬 **Real-time Messaging**: WebSocket-based instant message delivery
- 📱 **Cross-Platform**: Native support for iOS and macOS
- 💾 **Offline-First**: Local data persistence with SwiftData
- 👥 **Group Chats**: Support for both direct and group conversations
- 🔔 **Live Updates**: Real-time typing indicators and online status
- 🔒 **Secure Storage**: Keychain-based token management

## Tech Stack

- **UI Framework**: SwiftUI
- **Local Persistence**: SwiftData
- **Networking**: URLSession with async/await
- **Real-time Communication**: WebSocket (URLSessionWebSocketTask)
- **Authentication**: PKCE OAuth 2.0
- **Secure Storage**: Keychain Services
- **Architecture**: MVVM with Observable pattern

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/TeamChatUP.git
cd TeamChatUP
```

2. Open the project in Xcode:
```bash
open TeamChatUP.xcodeproj
```

3. Configure your environment in `AppConfig.swift` (see Configuration section below)

4. Build and run the project

## Configuration

### Environment Setup

The app supports three environments configured in `AppConfig.swift`:

- **Development**: Local development server
- **Staging**: Staging environment for testing
- **Production**: Production environment

Environment is automatically selected based on build configuration:
- Debug builds → Development
- Release builds → Production

### API Endpoints

Configure the following URLs in `AppConfig.swift`:

```swift
static var apiBaseURL: String {
    // REST API base URL
}

static var websocketURL: String {
    // WebSocket server URL
}

static var deviceAuthURL: String {
    // Device authorization URL
}
```

### URL Scheme

The app registers `teamchatup://` URL scheme for OAuth callbacks. This is configured in `Info.plist`.

## Build Commands

### Build for iOS Simulator
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### Build for macOS
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=macOS' \
  build
```

### Run Tests
```bash
xcodebuild -scheme TeamChatUP \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

### Clean Build
```bash
xcodebuild -scheme TeamChatUP clean
```

## Architecture

### Authentication Flow

TeamChatUP implements PKCE device authorization with two methods:

#### 1. Automatic Flow (Deep Link)
1. User taps "自動授權登入" (Auto Login)
2. App generates PKCE challenge and opens browser
3. User authorizes in browser
4. Browser redirects to `teamchatup://auth/callback?code=...`
5. App exchanges code + verifier for access token

#### 2. Manual Flow (Code Entry)
1. User taps "手動輸入授權碼" (Manual Code Entry)
2. App opens browser for authorization
3. User copies authorization code from browser
4. User pastes code into app
5. App exchanges code for access token

**Key Components:**
- `PKCEAuthManager.swift` - Manages authentication state and token exchange
- `PKCEManager.swift` - Generates PKCE challenge/verifier pairs
- `LoginView.swift` - Login UI with both authentication flows

### Data Architecture

The app maintains **two separate data layers**:

#### 1. Local Storage (SwiftData)
- Models: `ChatRoom`, `Message`
- Purpose: Offline-first local chat history
- Schema: Defined in `TeamChatUPApp.swift`

#### 2. Remote API (REST + WebSocket)
- Models: `Conversation`, `MessageResponse`, `User`
- REST API: CRUD operations via `APIClient`
- WebSocket: Real-time updates via `WebSocketManager`

> **Important**: Local SwiftData models and remote API models are separate and not automatically synchronized.

### Real-Time Messaging

WebSocket connection managed by `WebSocketManager`:

- **Connection**: Authenticates with token in query string
- **Events**:
  - `new_message` - New message received
  - `typing` - User typing indicator
  - `user_online` - User came online
  - `user_offline` - User went offline
  - `message_read` - Message read receipt
- **Reconnection**: Automatic with exponential backoff (max 5 attempts)
- **Event Publishing**: Uses Combine `PassthroughSubject`

### Token Management

- **Storage**: Secure storage in Keychain via `KeychainManager`
- **Authorization**: All API requests include `Authorization: Bearer <token>` header
- **Expiration**: Detected via 401 responses
- **Re-authentication**: Automatic alert shown on token expiration

### Logging

Structured logging via `AppLogger` (in `Logger.swift`):

```swift
AppLogger.shared.debug("Development info")
AppLogger.shared.info("Important events")
AppLogger.shared.warning("Recoverable issues")
AppLogger.shared.error("Error occurred", error: error)
AppLogger.shared.critical("Critical failure")
```

## Project Structure

```
TeamChatUP/
├── TeamChatUP/
│   ├── TeamChatUPApp.swift          # App entry point, SwiftData schema
│   ├── AppConfig.swift              # Environment configuration
│   ├── Models.swift                 # API models, APIClient, KeychainManager
│   │
│   ├── Authentication/
│   │   ├── PKCEAuthManager.swift    # Auth state management
│   │   ├── PKCEManager.swift        # PKCE challenge generation
│   │   └── LoginView.swift          # Login UI
│   │
│   ├── Managers/
│   │   ├── WebSocketManager.swift   # WebSocket connection
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
│   │   ├── ChatRoom.swift           # SwiftData model
│   │   └── Message.swift            # SwiftData model
│   │
│   └── Utilities/
│       └── Logger.swift              # Structured logging
│
├── TeamChatUPTests/
└── TeamChatUPUITests/
```

## Development Guidelines

### Adding New API Endpoints

1. Add request/response models to `Models.swift`
2. Add method to `APIClient` (use existing `get`/`post`/`delete` helpers)
3. Call from manager class (e.g., `ConversationManager`, `UserManager`)

### Adding WebSocket Events

1. Add case to `WebSocketEvent` enum in `WebSocketManager.swift`
2. Handle decoding in `init(from:)` and encoding in `encode(to:)`
3. Subscribe to `WebSocketManager.shared.eventPublisher` in views/managers

### Cross-Platform Considerations

Code supports both iOS and macOS:
- Use `#if os(iOS)` / `#elseif os(macOS)` for platform-specific code
- Toolbar placement: Use `.automatic` instead of `.navigationBarTrailing`
- Import guards: `#if canImport(UIKit)` / `#elseif canImport(AppKit)`

## API Integration

### Base URLs

The app connects to a backend API with the following endpoints:

- **Authentication**: `/device-auth/token`, `/device-auth/devices`
- **Conversations**: `/conversations`, `/conversations/{id}/messages`
- **Users**: `/users`, `/users/me`
- **Messages**: `/messages`, `/messages/{id}`

### WebSocket Connection

WebSocket URL format:
```
wss://your-server.com?token=<access_token>
```

## Security

- **Token Storage**: Access tokens stored securely in Keychain
- **PKCE Flow**: Prevents authorization code interception attacks
- **TLS/SSL**: All network communication over HTTPS/WSS
- **Token Expiration**: Automatic detection and re-authentication flow

## Troubleshooting

### WebSocket Connection Issues

1. Check token validity in Keychain
2. Verify WebSocket URL in `AppConfig.swift`
3. Check network connectivity
4. Review logs in Console.app for detailed error messages

### Authentication Failures

1. Verify device authorization URL is correct
2. Check PKCE verifier is properly stored
3. Ensure URL scheme is registered in `Info.plist`
4. Review `PKCEAuthManager` logs for detailed error information

## License

[Add your license here]

## Contact

[Add contact information here]
