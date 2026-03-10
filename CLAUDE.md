# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TeamChatUP is a SwiftUI-based real-time chat application for iOS and macOS. It uses PKCE device authorization, WebSocket for real-time messaging, and SwiftData for local persistence.

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -scheme TeamChatUP -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build for macOS
xcodebuild -scheme TeamChatUP -destination 'platform=macOS' build

# Run tests
xcodebuild -scheme TeamChatUP -destination 'platform=iOS Simulator,name=iPhone 17' test

# Clean build
xcodebuild -scheme TeamChatUP clean
```

## Architecture

### Authentication Flow

The app uses **PKCE (Proof Key for Code Exchange)** device authorization with two methods:

1. **Automatic Flow** (Deep Link):
   - User clicks "自動授權登入" → Opens browser with PKCE challenge
   - After authorization, browser redirects to `teamchatup://auth/callback?code=...`
   - App exchanges code + verifier for access token via `/device-auth/token`

2. **Manual Flow** (Code Entry):
   - User clicks "手動輸入授權碼" → Opens browser
   - User copies authorization code from browser
   - User pastes code into app → App exchanges for token

**Key Files:**
- `PKCEAuthManager.swift` - Manages auth state and token exchange
- `PKCEManager.swift` - Generates PKCE challenge/verifier
- `LoginView.swift` - Login UI with both flows

### Data Architecture

The app maintains **two separate data layers**:

1. **Local Storage (SwiftData)**:
   - `ChatRoom` and `Message` models in SwiftData
   - Used for offline-first local chat history
   - Schema defined in `TeamChatUPApp.swift`

2. **Remote API (REST + WebSocket)**:
   - `Conversation`, `MessageResponse`, `User` models in `Models.swift`
   - REST API via `APIClient` for CRUD operations
   - WebSocket via `WebSocketManager` for real-time updates

**Important**: These are separate models. Local SwiftData models are NOT synced with API models automatically.

### Real-Time Messaging

WebSocket connection managed by `WebSocketManager`:
- Connects on authentication with token in query string
- Handles events: `new_message`, `typing`, `user_online`, `user_offline`, `message_read`
- Auto-reconnection with exponential backoff (max 5 attempts)
- Publishes events via Combine `PassthroughSubject`

### Environment Configuration

`AppConfig.swift` defines three environments (dev/staging/prod):
- API Base URL
- WebSocket URL
- Device Auth URL

Environment is determined by build configuration (`#if DEBUG`).

### Token Management

- Tokens stored securely in Keychain via `KeychainManager`
- All API requests include `Authorization: Bearer <token>` header
- Token expiration detected via 401 responses → Shows re-login alert
- `APIClient` automatically triggers `showTokenExpiredAlert` on unauthorized errors

## URL Scheme

The app registers `teamchatup://` URL scheme in `Info.plist`:
- `teamchatup://auth/callback?code=...` - OAuth callback
- Handled in `RootView.onOpenURL` → calls `PKCEAuthManager.handleCallback()`

## Common Patterns

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
- Toolbar placement: Use `.automatic` instead of `.navigationBarTrailing` for macOS compatibility
- Import guards: `#if canImport(UIKit)` / `#elseif canImport(AppKit)`

## Logging

`AppLogger` (in `Logger.swift`) provides structured logging:
- `.debug()` - Development info
- `.info()` - Important events
- `.warning()` - Recoverable issues
- `.error()` - Errors with optional Error parameter
- `.critical()` - Critical failures

Logs include request/response details for API calls.
