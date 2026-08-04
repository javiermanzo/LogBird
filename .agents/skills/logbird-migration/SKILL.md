---
name: logbird-migration
description: Unified migration guide and technical reference for upgrading LogBird integrations across major and minor breaking releases (v1.0.0 → v2.0.0 → v2.1.0), covering all breaking changes, API refactoring recipes, and new architectural patterns.
---

# LogBird Migration Guide

This skill is the single source of truth for migrating codebase integrations forward across LogBird breaking releases. It currently covers two upgrade hops:

- **Hop A — v1.0.0 → v2.0.0**: package split, typed metadata, Combine event stream, identifier API.
- **Hop B — v2.0.0 → v2.1.0**: centralized `LBConfig`, recording gate (`isEnabled` + `minLogLevel`), layered sensitive-keys API.

Apply only the hop matching your current version. Each hop is self-contained.

---

## Hop A — v1.0.0 → v2.0.0

### A.1 Summary of Breaking Changes

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

### A.2 Migration Recipes

#### A.2.1 Package & Product Dependencies

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

#### A.2.2 File Imports

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

#### A.2.3 Metadata (`additionalInfo`)

In v2.0.0, `additionalInfo` requires typed `LBValue` dictionary values (`[String: LBValue]`) for thread-safety, `Sendable` compliance, and `Codable` export support.

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

#### A.2.4 Combine Event Publisher (`logsPublisher`)

In v1.x, `logsPublisher` re-emitted the complete array of all logs on every log call. In v2.0.0, it streams granular `LBLogEvent` instances.

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

#### A.2.5 `LBExtraMessage`

```swift
// BEFORE (v1.x)
let section = LBExtraMessage(title: "Request Body", message: "{\"status\": \"active\"}")

// AFTER (v2.0.0)
let section = LBExtraMessage(key: "Request Body", value: "{\"status\": \"active\"}")
```

#### A.2.6 Identifier API

```swift
// BEFORE (v1.x)
LogBird.shared.setIdentifier("session-9912")
let currentID = LogBird.shared.currentIdentifier

// AFTER (v2.0.0)
LogBird.shared.identifier = "session-9912"
let currentID = LogBird.shared.identifier
```

---

## Hop B — v2.0.0 → v2.1.0

### B.1 Summary of Breaking Changes

| Area | LogBird 2.0.0 | LogBird 2.1.0 | Action Required |
| :--- | :--- | :--- | :--- |
| **`LogBird.init`** | `init(..., maxLogs: Int = 1000)` | `init(..., config: LBConfig = LBConfig())` | Pass a `LBConfig` (or use the new convenience init). |
| **`sensitiveKeys` property** | Read-write `[String]` (`get`/`set`) | Read-only `Set<String>` view | Replace assignment with `sensitiveKeys(_:)` taking an `LBSensitiveKeysAction`. |
| **`defaultSensitiveKeys`** | Per-instance `[String]` `static let` | Global `Set<String>` `static var` (thread-safe) | Read via `LogBird.defaultSensitiveKeys`; set globals via `LogBird.setDefaultSensitiveKeys(_:)`. |
| **`LBManager` state** | Scattered `storedMaxLogs`, `storedRedactSensitiveFields`, `storedSensitiveKeys`, `storedIdentifier` | Single `storedConfig: LBConfig` | No source change for integrators; internal-only. |
| **`LBSensitiveKeysState`** | (did not exist) | Internal-only backing type | Do not reference; not part of the public surface. |

> **Non-breaking additions in 2.1.0**: `LBConfig` struct, `isEnabled` + `minLogLevel` recording gate, `LBSensitiveKeysAction` enum, `LBLogLevel: Comparable`, global default sensitive keys API, convenience initializer, static `LogBird.config` accessor. See `CHANGELOG.md` for the full list.

### B.2 Migration Recipes

#### B.2.1 Initializer Signature (`maxLogs:` → `config:`)

```swift
// BEFORE (v2.0.0)
let logger = LogBird(subsystem: "com.example.app", category: "network", maxLogs: 500)

// AFTER (v2.1.0) - Option 1: dedicated config
let logger = LogBird(
    subsystem: "com.example.app",
    category: "network",
    config: LBConfig(maxLogs: 500)
)

// AFTER (v2.1.0) - Option 2: convenience init (common knobs only)
let logger = LogBird(
    subsystem: "com.example.app",
    category: "network",
    maxLogs: 500,
    minLogLevel: .info
)
```

> Note: `isEnabled` is intentionally **not** a convenience-init parameter. It defaults to the build configuration (`#if DEBUG`) and is flipped at runtime via `logger.isEnabled = false`. Pass it explicitly through `LBConfig(isEnabled: true)` when you need to force it at construction.

#### B.2.2 Sensitive Keys: Property Setter → Action API

Direct assignment no longer compiles. Use `LBSensitiveKeysAction` (`.add`, `.set`, `.reset`, `.clear`).

```swift
// BEFORE (v2.0.0)
LogBird.sensitiveKeys = ["password", "token", "ssn"]          // ❌ no longer compiles in 2.1.0
logger.sensitiveKeys.append("creditCard")                      // ❌ no longer compiles in 2.1.0

// AFTER (v2.1.0)
LogBird.sensitiveKeys(.set(["password", "token", "ssn"]))     // Override shared instance keys
logger.sensitiveKeys(.add(["creditCard"]))                    // Extend this instance's keys
logger.sensitiveKeys(.reset)                                   // Back to pure global defaults
logger.sensitiveKeys(.clear)                                   // Disable key redaction here

// Read-only view (type is now Set<String>)
let current: Set<String> = LogBird.sensitiveKeys
```

#### B.2.3 Global Default Sensitive Keys (new layer)

The notion of "default sensitive keys" is now **global and app-wide**, not per-instance. Loggers that have not called `.set(...)`/`.clear(...)` inherit these globals (plus any `.add(...)` extensions).

```swift
// v2.1.0 — set once at app launch
LogBird.setDefaultSensitiveKeys(["password", "token", "secret", "my_app_secret"])
let globals: Set<String> = LogBird.defaultSensitiveKeys

// A fresh logger then inherits globals automatically:
let logger = LogBird()
logger.sensitiveKeys(.add(["ssn"]))           // globals ∪ {"ssn"}
logger.sensitiveKeys(.reset)                   // back to pure globals
```

#### B.2.4 New: Recording Gate (`isEnabled` + `minLogLevel`)

Two independent, runtime-tunable controls shape what gets recorded. Both default to permissive behavior under `DEBUG`.

```swift
// isEnabled: master switch (default: true under DEBUG, false otherwise)
LogBird.isEnabled = false                       // silence everything (no-op in log(...))
LogBird.isEnabled = true

// minLogLevel: severity floor (default: .debug — everything passes)
LogBird.minLogLevel = .warning                  // keep only .warning, .error, .critical

// Per-instance equivalents
logger.isEnabled = false
logger.minLogLevel = .error
```

Behavioral notes:
- The gate runs **first** inside `log(...)`, after a single config snapshot. When disabled or below threshold, nothing is forwarded to OSLog, stored, or published.
- `clearLogs()` and `export()` are **not** gated; they always operate on recorded history.

#### B.2.5 New: Centralized `LBConfig`

All configuration now lives in one `Hashable, Sendable` struct. You can read or replace it atomically.

```swift
// Read
let cfg: LBConfig = LogBird.config

// Replace atomically
LogBird.config = LBConfig(
    maxLogs: 2000,
    isEnabled: true,
    minLogLevel: .info,
    redactSensitiveFields: true,
    sensitiveKeys: ["password", "token"],        // explicit override (bypasses globals)
    identifier: "network-logger"
)

// Mutate a single field via the property (still atomic at the LBManager level)
LogBird.config.maxLogs = 3000
```

---

## 3. Feature Adoption Checklist (post-migration)

After reaching the current release, adopt these capabilities:

1. **Call-Site Inline Privacy**: `LogBird.log("User \(username, privacy: .private) logged in")`.
2. **Layered Redaction**: set app-wide defaults via `LogBird.setDefaultSensitiveKeys(_:)`; extend per-instance via `.add`; override via `.set`.
3. **Recording Gate**: drive `isEnabled` from your own build flags or remote config; raise `minLogLevel` to silence noisy levels in production.
4. **Structured Export**: `try LogBird.export(.all, format: .jsonLines, destination: .file(nil))`.
5. **Zero-Retention Mode**: `LogBird.shared.maxLogs = 0` keeps events streaming with no in-memory history.

---

## 4. Reference

- Full per-release detail: [`CHANGELOG.md`](../../../CHANGELOG.md).
- Architectural invariants and public API surface: [`AGENTS.md`](../../../AGENTS.md).
- Integration context and patterns: [`../logbird/SKILL.md`](../logbird/SKILL.md).
