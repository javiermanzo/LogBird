---
name: logbird
description: Comprehensive integration skill and context loader for LogBird, a lightweight, thread-safe, privacy-conscious Swift logging library for Apple platforms (iOS, macOS, tvOS, watchOS).
---

# LogBird Integration Skill

This skill provides complete architectural context, API reference, and integration patterns for **LogBird** — a lightweight, thread-safe, privacy-conscious Swift logging library for iOS, macOS, tvOS, and watchOS.

---

## 1. Quick Overview & Key Capabilities

- **Zero External Dependencies**: Built exclusively on native Apple frameworks (`Foundation`, `Combine`, `OSLog`, `SwiftUI`).
- **Thread-Safe Architecture**: Serial queue dispatch guarantees safety without re-entrancy deadlocks.
- **Privacy First**: Automatic redaction of sensitive field keys (`password`, `token`, `secret`, `apiKey`) + explicit inline privacy interpolation (`\(secret, privacy: .private)`).
- **Apple OSLog Mirroring**: Mirroring to `os.Logger` for macOS Console.app & `log stream` CLI debugging.
- **Combine Real-Time Publisher**: Stream history events live via `logsPublisher` (`.recorded`, `.cleared`).
- **Multi-Format Exporting**: Export logs to `.json`, `.jsonLines` (NDJSON), or `.plainText` as `Data` or written to file `URL`.
- **SwiftUI Debug Viewer**: Ready-made `LBLogsView` with search, level filtering, and platform export triggers.
- **Build-Aware Recording**: Logging is enabled by default only under `DEBUG`; toggle at runtime via `isEnabled` or filter by minimum severity via `minLogLevel`.

---

## 2. Installation & Package Setup

Add package dependency in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/javiermanzo/LogBird.git", from: "2.0.0")
]
```

### Products:
- **`LogBird`**: Core logging engine. Use for business logic, SDKs, CLI, or backend modules.
- **`LogBirdUI`**: SwiftUI debug viewer (`LBLogsView`). Add only where UI debug tools are needed.

---

## 3. Core API Reference & Usage Patterns

### 3.1 Static Logging (Shared Logger)

```swift
import LogBird

// Simple Info log
LogBird.log("Application started")

// Severity Levels (.debug, .info, .warning, .error, .critical)
LogBird.log("Network operation failed", level: .warning)
```

### 3.2 Scoped Custom Logger Instance

```swift
let logger = LogBird(subsystem: "com.myapp.network", category: "HTTPClient", maxLogs: 500)
logger.log("GET /users 200 OK", level: .info)
```

### 3.3 Enabling & Filtering Logs

Recording is **on by default only under `DEBUG`** (via `#if DEBUG`, centralized in `LBConfig.init`). Two independent controls shape when and what gets recorded:

```swift
// Centralized configuration via LBConfig
LogBird.config = LBConfig(maxLogs: 500, isEnabled: true, minLogLevel: .warning, identifier: "SESSION-123")

// Master switch (runtime on/off). Default: enabled under DEBUG, off otherwise.
LogBird.isEnabled = true                 // force on in release / field builds
LogBird.isEnabled = FeatureFlags.verbose // drive from your own flags or macros

// Severity threshold (inclusive). Ordered .debug < .info < .warning < .error < .critical
LogBird.minLogLevel = .warning           // keep warning, error, critical only
```

Both are settable per-instance and via `LBConfig`. `minLogLevel` is also exposed on the convenience init; `isEnabled` is flipped at runtime through the property (or pinned at construction via `config: LBConfig(isEnabled:)`). Changes apply to the next `log(...)` call. When disabled, `log(...)` is a no-op (no OSLog, no storage, no publish). `clearLogs()` and `export()` are **not** gated — they always work on recorded history.

### 3.4 Privacy & Data Redaction

#### Key-Based Automatic Redaction
```swift
// Global app defaults (LogBird.setDefaultSensitiveKeys) & per-instance actions (.add, .set, .reset, .clear)
LogBird.sensitiveKeys(.add(["ssn", "creditCard"]))

// Automatically redacts matching keys in additionalInfo, extraMessages, and error.userInfo
LogBird.log("Login payload", additionalInfo: [
    "username": "alice",
    "authToken": "secret_12345" // Stored as "<redacted>"
])
```

#### Call-Site Interpolation Redaction
```swift
let token = "bearer_token_abc"
LogBird.log("Authenticated with token \(token, privacy: .private)")
// Stored & displayed as: "Authenticated with token <redacted>"
```

### 3.5 Rich Context: Metadata, Labeled Sections, & Errors

```swift
let extraMessages = [
    LBExtraMessage(key: "Headers", value: "Content-Type: application/json")
]

let additionalInfo: [String: LBValue] = [
    "userId": 101,
    "isVIP": true,
    "latency": 0.24,
    "url": .url(URL(string: "https://api.example.com")!)
]

do {
    try processOrder()
} catch {
    LogBird.log(
        "Order processing error",
        extraMessages: extraMessages,
        additionalInfo: additionalInfo,
        error: error,
        level: .error
    )
}
```

### 3.6 Combine Real-Time Event Subscription

```swift
import Combine

var cancellables = Set<AnyCancellable>()

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

### 3.7 Exporting Recorded Logs

```swift
// Export all logs as JSON Data
let output = try LogBird.export(.all, format: .json, destination: .data)
let jsonData: Data = output.data

// Export filtered logs to a temporary file in JSONLines (NDJSON) format
let fileOutput = try LogBird.export(.all, format: .jsonLines, destination: .file(nil))
if let fileURL = fileOutput.fileURL {
    print("Export file created at: \(fileURL.path)")
}
```

### 3.8 Embedding SwiftUI Debug Viewer (`LogBirdUI`)

```swift
import SwiftUI
import LogBirdUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            LBLogsView() // Observes LogBird.shared by default
        }
    }
}
```

---

## 4. Technical Specifications & Integrator Best Practices

1. **Thread Safety**: Safe to call `LogBird.log(...)` concurrently from any background thread or queue.
2. **In-Memory Capping**: Controlled by `maxLogs` (default `1000`). Setting `maxLogs = 0` disables in-memory retention while maintaining live Combine event streaming.
3. **OSLog Subsystem & Category**: Automatically inferred if not explicitly specified. `subsystem` defaults to `Bundle.main.bundleIdentifier`, and `category` defaults to the caller module derived from `#fileID`.
4. **Recording Gate**: `log(...)` checks `isEnabled` and `minLogLevel` first and is a complete no-op when disabled or below the severity floor. By default `isEnabled` is on only under `DEBUG` (resolved via `#if DEBUG` in `LBConfig.init`); flip it at runtime, or pin it at construction via `config: LBConfig(isEnabled: true)`. `clearLogs()`/`export()` are never gated.

---

## 5. Upgrading from LogBird v1.x

For projects migrating from LogBird 1.x to 2.0.0, refer to the dedicated migration skill at `[.agents/skills/logbird-v1-to-v2/SKILL.md](../logbird-v1-to-v2/SKILL.md)` for detailed breaking change checklists and side-by-side refactoring recipes.

