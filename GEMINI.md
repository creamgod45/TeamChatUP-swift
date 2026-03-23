# TeamChatUP Project Context

TeamChatUP is a modern, cross-platform real-time chat application for iOS and macOS, built using SwiftUI and Swift 6 concurrency patterns.

## Project Overview

*   **Platform:** iOS and macOS (Universal)
*   **UI Framework:** SwiftUI (Modern patterns: `@Observable`, `NavigationStack`, `NavigationSplitView`)
*   **Persistence:** SwiftData (for local history) and REST API (for remote data)
*   **Real-time:** WebSockets using the Pusher/Laravel Reverb protocol via `URLSessionWebSocketTask`
*   **Authentication:** PKCE (Proof Key for Code Exchange) OAuth 2.0 flow
*   **Concurrency:** Swift 6 structured concurrency, `@MainActor` isolation, and safe timer handling

## Architecture & Data Flow

### Modern State Management
The project uses the `@Observable` macro (from the `Observation` framework) for almost all manager classes.
*   Use `@State` in views to own these managers (replaces `@StateObject`).
*   Managers are typically singletons (e.g., `PKCEAuthManager.shared`, `WebSocketManager.shared`).

### Core Components
*   **PKCEAuthManager:** Handles login flows (Automatic/Manual), token exchange, and keychain storage.
*   **WebSocketManager:** Manages the reverb connection, channel subscriptions, and event publishing via Combine `PassthroughSubject`.
*   **MessageManager:** Manages the state of a specific conversation, including message loading and real-time typing indicators.
*   **ConversationManager:** Manages the global list of conversations and unread counts.
*   **APIClient:** Centralized REST client with structured logging and automatic 401 (unauthorized) handling.
*   **SoundManager:** Multi-track audio player for message and typing feedback.

### Data Models
*   **API Models:** Located in `Models.swift`. These are `Codable` and used for network communication.
*   **SwiftData Models:** `ChatRoom`, `Message`, and `Item`. Defined in the app schema but currently maintained separately from API models.

## Building and Running

### Prerequisites
*   Xcode 15.0+ (Swift 5.9+)
*   macOS 14.0+ (required for `Observation` and latest SwiftData features)

### Key Commands (via xcodebuild)
```bash
# Build for iOS Simulator
xcodebuild -scheme TeamChatUP -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for macOS
xcodebuild -scheme TeamChatUP -destination 'platform=macOS' build

# Run Tests
xcodebuild -scheme TeamChatUP test
```

## Development Conventions

### Concurrency Patterns
*   **Swift 6 Mode:** The project adheres to strict concurrency checking.
*   **Timer Handling:** Always use `[weak self]` and `guard let self = self else { return }` inside `Timer` closures.
*   **MainActor:** Most Managers and Views are marked `@MainActor`. Ensure UI updates happen on the main actor using `Task { @MainActor in ... }` if called from non-isolated contexts.

### SwiftUI Style
*   **View Modifiers:** Prefer `.clipShape(.rect(cornerRadius: n))` over `.cornerRadius(n)`.
*   **Data Flow:** Avoid `ObservableObject` and `@Published` in new code; use `@Observable`.
*   **Logging:** Use `AppLogger.shared` with consistent emojis:
    *   🌐 Connection
    *   📡 Subscription
    *   📩 New Message
    *   💓 Heartbeat/Ping
    *   🔍 Debug/Trace
    *   ❌ Error

### Environment Configuration
`AppConfig.swift` handles environment switching based on `#if DEBUG`. Ensure your local backend is running at `https://teamchatup-backend.test` for development.

## Common Tasks

### Adding a New API Endpoint
1. Define response models in `Models.swift`.
2. Add a typed method in `APIClient.swift` using the `get` or `post` helpers.
3. Call the method from the appropriate Manager using `async/await`.

### Adding a New WebSocket Event
1. Add a case to the `WebSocketEvent` enum.
2. Update `init(from:)` and `encode(to:)` in `WebSocketManager.swift`.
3. Handle the event in `MessageManager` or `ConversationManager` by subscribing to `eventPublisher`.
