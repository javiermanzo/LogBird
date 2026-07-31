---
name: logbird-v1-to-v2
description: Migration guide and technical reference for upgrading LogBird from v1.0.0 to v2.0.0, covering all breaking changes, API refactoring recipes, and new architectural patterns.
---

# LogBird v1.0.0 to v2.0.0 Migration Guide

This skill provides step-by-step instructions and code transformation recipes for migrating codebase integrations from **LogBird 1.x** to **LogBird 2.0.0**.

---

## 1. Summary of Breaking Changes

| Area | LogBird 1.x | LogBird 2.0.0 | Action Required |
| :--- | :--- | :--- | :--- |
| **Package Products** | Single `LogBird` target with embedded SwiftUI views | Split into `LogBird` (core logic) and `LogBirdUI` (SwiftUI views) | Add `LogBirdUI` dependency and `import LogBirdUI` where `LBLogsView` is used. |
| **Distribution** | SPM + CocoaPods | SPM only (`LogBird.podspec` removed) | Remove CocoaPods dependency and switch to Swift Package Manager. |
| **Metadata (`additionalInfo`)** | Untyped `[String: Any]?` | Typed `[String: LBValue]?` | Wrap metadata values in `LBValue` enum or use string/int/bool literals. |
| **Combine Stream** | `AnyPublisher<[LBLog], Never>` (emitted array snapshots) | `AnyPublisher<LBLogEvent, Never>` (emitted `.recorded` and `.cleared` events) | Update `.sink` subscriber blocks to handle `LBLogEvent` enum cases. |
| **`LBExtraMessage`** | Properties `title` and `message` | Properties `key` and `value` | Rename `title:` and `message:` parameters to `key:` and `value:`. |
| **Identifier API** | `setIdentifier(_:)` / `currentIdentifier` | Unified `identifier: String?` property | Replace `setIdentifier("id")` calls with `LogBird.shared.identifier = "id"`. |
| **History Order** | Reverse chronological order (newest first) | Chronological recording order (oldest first) | Adjust custom log sorting or array reversal if relying on array index order. |
| **Direct Entity Inits** | Public initializers for `LBLog` | Package-internal initializers for `LBLog`, `LBSource`, `LBLocation`, `LBError` | Record entries via `LogBird.log(...)` APIs instead of instantiating `LBLog` directly. |

---

## 2. Migration Recipes

### 2.1 Package & Product Dependencies

#### `Package.swift` Migration
```swift
// BEFORE (v1.x)
dependencies: [
    .target(name: "MyAppTarget", dependencies: ["LogBird"])
]

// AFTER (v2.0.0)
dependencies: [
    .target(
        name: "MyAppTarget",
        dependencies: [
            .product(name: "LogBird", package: "LogBird"),   // Core logging
            .product(name: "LogBirdUI", package: "LogBird") // Optional SwiftUI views
        ]
    )
]
```

#### File Imports Migration
```swift
// BEFORE (v1.x)
import LogBird

struct DebugView: View {
    var body: some View {
        LBLogsView()
    }
}

// AFTER (v2.0.0)
import LogBird
import LogBirdUI // Separate import required for LBLogsView

struct DebugView: View {
    var body: some View {
        LBLogsView()
    }
}
```

---

### 2.2 Metadata (`additionalInfo`) Migration

In v2.0.0, `additionalInfo` requires typed `LBValue` dictionary values (`[String: LBValue]`) to ensure thread-safety, `Sendable` compliance, and `Codable` export support.

```swift
// BEFORE (v1.x)
LogBird.log("User action", additionalInfo: [
    "user_id": 123,
    "user_name": "Alice",
    "is_admin": true,
    "score": 98.5
])

// AFTER (v2.0.0) - Literal Conformances (Recommended)
LogBird.log("User action", additionalInfo: [
    "user_id": 123,
    "user_name": "Alice",
    "is_admin": true,
    "score": 98.5
])

// AFTER (v2.0.0) - Explicit Enum Constructors (for URLs, Arrays, Dictionaries)
LogBird.log("API response", additionalInfo: [
    "endpoint": .url(URL(string: "https://api.example.com")!),
    "tags": .array(["auth", "login"]),
    "headers": .dictionary(["Accept": .string("application/json")])
])
```

---

### 2.3 Combine Event Publisher (`logsPublisher`) Migration

In v1.x, `logsPublisher` re-emitted the complete array of all logs on every log call. In v2.0.0, `logsPublisher` streams granular `LBLogEvent` instances (`.recorded(LBLog)` for individual entries, `.cleared` when history is reset).

```swift
// BEFORE (v1.x)
LogBird.logsPublisher
    .sink { logs in
        print("Total log count: \(logs.count)")
        if let latestLog = logs.first {
            print("Latest log: \(latestLog.message)")
        }
    }
    .store(in: &cancellables)

// AFTER (v2.0.0)
LogBird.logsPublisher
    .receive(on: DispatchQueue.main)
    .sink { event in
        switch event {
        case .recorded(let log):
            print("New log [\(log.level)]: \(log.message ?? "")")
        case .cleared:
            print("Log history cleared")
        }
    }
    .store(in: &cancellables)
```

---

### 2.4 `LBExtraMessage` Migration

```swift
// BEFORE (v1.x)
let section = LBExtraMessage(title: "Request Body", message: "{\"status\": \"active\"}")

// AFTER (v2.0.0)
let section = LBExtraMessage(key: "Request Body", value: "{\"status\": \"active\"}")
```

---

### 2.5 Identifier API Migration

```swift
// BEFORE (v1.x)
LogBird.shared.setIdentifier("session-9912")
let currentID = LogBird.shared.currentIdentifier

// AFTER (v2.0.0)
LogBird.shared.identifier = "session-9912"
let currentID = LogBird.shared.identifier
```

---

## 3. New Features to Leverage in v2.0.0

After completing the breaking change refactoring, adopt these new v2.0.0 capabilities:

1. **Call-Site Inline Privacy**: Use `LogBird.log("User \(username, privacy: .private) logged in")` to mask inline interpolation values.
2. **Automatic Key Redaction**: Configure `LogBird.sensitiveKeys += ["passcode", "ssn"]` to automatically mask matching keys in metadata and extra messages.
3. **Structured Export**: Call `try LogBird.export(.all, format: .jsonLines, destination: .file(nil))` to export logs as NDJSON.
4. **Zero-Retention Mode**: Set `LogBird.shared.maxLogs = 0` to disable in-memory history storage while maintaining Combine event publishing.
