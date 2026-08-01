<p align="center" width="100%">
    <img width="30%" src="https://raw.githubusercontent.com/javiermanzo/LogBird/main/Resources/LogBird.png" alt="LogBird Logo"> 
</p>

<h1 align="center">LogBird</h1>

<p align="center">
    <strong>A lightweight, thread-safe, privacy-conscious Swift logging framework for iOS, macOS, tvOS, and watchOS.</strong><br>
    Features OSLog mirroring, Combine streaming, automatic sensitive field redaction, multi-format exporting, and an optional SwiftUI debug viewer.
</p>

<p align="center">
    <a href="https://github.com/javiermanzo/LogBird/releases"><img src="https://img.shields.io/github/v/release/javiermanzo/LogBird?style=flat-square" alt="Release"></a>
    <a href="https://github.com/javiermanzo/LogBird/actions/workflows/swift.yml"><img src="https://img.shields.io/github/actions/workflow/status/javiermanzo/LogBird/swift.yml?style=flat-square" alt="CI"></a>
    <a href="https://swift.org/"><img src="https://img.shields.io/badge/Swift-5.9_6.0-orange?style=flat-square" alt="Swift"></a>
    <a href="#requirements"><img src="https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-yellowgreen?style=flat-square" alt="Platforms"></a>
    <a href="https://swiftpackageindex.com/javiermanzo/LogBird"><img src="https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square" alt="SPM"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

---

## Table of Contents
- [Features](#features)
- [Architecture & Design](#architecture--design)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage Guide](#usage-guide)
  - [Static Logging](#static-logging)
  - [Instance Logging](#instance-logging)
  - [Log Severity Levels](#log-severity-levels)
  - [Enabling & Filtering Logs](#enabling--filtering-logs)
  - [Rich Metadata & Context](#rich-metadata--context)
  - [Privacy & Sensitive Data Redaction](#privacy--sensitive-data-redaction)
  - [Combine Real-Time Streaming](#combine-real-time-streaming)
  - [Exporting Logs](#exporting-logs)
  - [SwiftUI Debug Viewer (`LogBirdUI`)](#swiftui-debug-viewer-logbirdui)
  - [Clearing History](#clearing-history)
- [How It Works](#how-it-works)
- [AI Agent Support](#ai-agent-support)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

---

## Features

- ⚡ **Zero Third-Party Dependencies**: Built exclusively on native Apple frameworks (`Foundation`, `Combine`, `OSLog`, `SwiftUI`).
- 🛡️ **Thread-Safe & Non-Blocking**: Dual dispatch queue architecture guarantees safety and eliminates re-entrancy deadlocks.
- 🔒 **Two-Pronged Privacy Protection**:
  - **Automatic Field Redaction**: Automatically redacts values under sensitive key patterns (e.g. `password`, `token`, `secret`, `apiKey`).
  - **Interpolation Redaction**: Call-site privacy control with `LBLogMessage` string interpolation (`\(val, privacy: .private)`).
- 🖥️ **Apple OSLog Mirroring**: Forwards entries to `os.Logger` so logs appear in macOS Console.app and `log stream` CLI output under custom subsystem/category tags.
- 📡 **Combine Event Publisher**: Real-time `logsPublisher` stream emitting `.recorded` and `.cleared` events.
- 📤 **Multi-Format Log Exporter**: Export stored history or filtered entries to `.json`, `.jsonLines` (NDJSON), or `.plainText` as in-memory `Data` or written to `File`.
- 📱 **SwiftUI Debug Viewer (`LogBirdUI`)**: Optional, ready-to-use SwiftUI view (`LBLogsView`) with search, level filter, auto-scrolling, clear logs, and OS-native export triggers (iOS Share Sheet, macOS Save Panel).
- 🧩 **Modular Packaging**: Separate `LogBird` (core logic) and `LogBirdUI` (SwiftUI interface) SPM products.
- 🚦 **Build-Aware Recording**: Logging is enabled by default only under `DEBUG` and can be toggled at runtime or filtered by minimum severity — no code changes needed to stay silent in release.

---

## Architecture & Design

```
+-------------------------------------------------------------------------+
|                              Call Sites                                 |
|   LogBird.log("...")  /  customLogger.log(...)  /  log("... \(secret)") |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                                LogBird                                  |
|   Static Facade / Swift 6 Sendable Instance                             |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                               LBManager                                 |
|  - Serial State Queue (dispatchQueue: access state & history)          |
|  - Serial Publish Queue (publishQueue: async Combine notification)       |
+-------------------+--------------------+--------------------------------+
                    |                    |
       +------------+                    +------------+
       |                                              |
       v                                              v
+--------------+                              +---------------+
|  OSLog /     |                              |   In-Memory   |
|  os.Logger   |                              |  History      |
| (Console.app)|                              | ([LBLog])     |
+--------------+                              +-------+-------+
                                                      |
                                    +-----------------+-----------------+
                                    |                                   |
                                    v                                   v
                             +--------------+                   +---------------+
                             | Combine      |                   | SwiftUI       |
                             | Publisher    |                   | LBLogsView    |
                             | (LBLogEvent) |                   | (LogBirdUI)   |
                             +--------------+                   +---------------+
```

---

## Requirements

| Platform | Minimum Version |
| :--- | :--- |
| **Swift** | 5.9+ / Swift 6 Language Mode |
| **iOS** | 15.0+ |
| **macOS** | 12.0+ |
| **tvOS** | 15.0+ |
| **watchOS** | 8.0+ |

---

## Installation

LogBird is distributed via [Swift Package Manager](https://swift.org/package-manager/).

### 1. Add Package Dependency

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/javiermanzo/LogBird.git", from: "2.0.0")
]
```

### 2. Select Products

Depend on the product(s) appropriate for your target:

```swift
.target(
    name: "MyCoreSDK",
    dependencies: [
        .product(name: "LogBird", package: "LogBird") // Core logging only (no SwiftUI)
    ]
),
.target(
    name: "MyAppUI",
    dependencies: [
        .product(name: "LogBirdUI", package: "LogBird") // Includes LBLogsView debug interface
    ]
)
```

In Xcode, add `https://github.com/javiermanzo/LogBird.git` in **File > Add Package Dependencies...** and select `LogBird` and/or `LogBirdUI`.

---

## Usage Guide

### Static Logging

For general logging, use the static methods provided by `LogBird.shared`:

```swift
import LogBird

// Simple info log
LogBird.log("App completed launch configuration")

// Specifying severity levels
LogBird.log("User session expired", level: .warning)
```

### Instance Logging

Create distinct `LogBird` instances to scope logs by subsystem, category, or module:

```swift
let networkLogger = LogBird(subsystem: "com.myapp.network", category: "HTTPClient")
let dbLogger = LogBird(subsystem: "com.myapp.database", category: "SQLite", maxLogs: 500)

networkLogger.log("GET /api/v1/profile returned 200 OK", level: .info)
dbLogger.log("Database migration started", level: .debug)
```

*Note: Default `init()` automatically infers the subsystem from `Bundle.main.bundleIdentifier` and the category from the caller file's module (`#fileID`).*

### Log Severity Levels

Supported levels in `LBLogLevel` (ordered from lowest to highest severity):

| Level | Emoji | Symbol | Description |
| :--- | :---: | :--- | :--- |
| `.debug` | 🐞 | `ant` | Diagnostic messages useful during development. |
| `.info` | ℹ️ | `info.circle` | Informational messages reporting normal execution. |
| `.warning` | ⚠️ | `exclamationmark.triangle` | Potential issues or non-fatal anomalies. |
| `.error` | ❌ | `xmark.octagon` | Standard runtime errors and handled failures. |
| `.critical` | 🚨 | `flame` | Severe system failures requiring immediate action. |

### Enabling & Filtering Logs

LogBird is **silent by default in release builds**: recording is enabled only under `DEBUG` (via `#if DEBUG`), so no extra setup is needed to keep production quiet. Two independent controls let you shape when and what gets recorded.

#### Master Switch: `isEnabled`

A runtime on/off gate for the whole logger. When `false`, `log(...)` is a no-op — nothing is forwarded to OSLog, stored, or published.

```swift
// Default: enabled under DEBUG, disabled otherwise.
// LogBird.isEnabled            // == LogBird.defaultIsEnabled

// Force logging on permanently (e.g. field-debug builds)
LogBird.isEnabled = true

// Drive it from your own flags or custom build macros
#if INTERNAL_BETA
LogBird.isEnabled = true
#endif

LogBird.isEnabled = FeatureFlags.verboseLogging
```

Per-instance works the same way, and you can set it at construction:

```swift
let logger = LogBird(subsystem: "com.myapp.network", category: "HTTP", isEnabled: true)
```

#### Severity Threshold: `minLogLevel`

Keep only entries at or above a severity. Lower-severity entries are dropped before any work is done. `LBLogLevel` is ordered `.debug < .info < .warning < .error < .critical`.

```swift
// Silence debug & info; keep warning, error and critical
LogBird.minLogLevel = .warning

// Reset to record everything (default)
LogBird.minLogLevel = .debug
```

#### Notes

- Changes apply to the **next** `log(...)` call.
- `isEnabled` wins over `minLogLevel`: when disabled, nothing is recorded regardless of the floor.
- `clearLogs()` and `export()` are **not** gated — they always operate on the recorded history, so you can still read or reset it while logging is off.
- The DEBUG default uses the host app's build configuration, since the package is compiled together with it.

### Rich Metadata & Context

LogBird supports rich, typed metadata, labeled message sections, and detailed error capturing.

```swift
// 1. Extra Labeled Message Sections
let extraMessages: [LBExtraMessage] = [
    LBExtraMessage(key: "Request Headers", value: "Authorization: Bearer <redacted>\nContent-Type: application/json"),
    LBExtraMessage(key: "Response Body", value: "{\"status\": \"ok\"}")
]

// 2. Typed Metadata (LBValue supports String, Int, Double, Bool, URL, Array, Dictionary)
let additionalInfo: [String: LBValue] = [
    "userId": 42,
    "userRole": "administrator",
    "isPremium": true,
    "retryCount": 3,
    "endpoint": .url(URL(string: "https://api.example.com/v1/user")!)
]

// 3. Error Capturing (Automatically extracts Swift, NSError, & DecodingError/EncodingError context)
do {
    try JSONDecoder().decode(User.self, from: invalidData)
} catch {
    LogBird.log(
        "Failed to parse user profile response",
        extraMessages: extraMessages,
        additionalInfo: additionalInfo,
        error: error,
        level: .error
    )
}
```

### Privacy & Sensitive Data Redaction

LogBird provides two layers of data privacy out of the box:

#### Layer 1: Automatic Key-Based Redaction (`LBRedactor`)

Key names matching sensitive patterns are automatically redacted in `additionalInfo`, `extraMessages`, and `error.userInfo`.

Default sensitive key patterns: `"password"`, `"token"`, `"authorization"`, `"secret"`, `"apiKey"`, `"cookie"`.

```swift
// Customize global or per-instance sensitive keys
LogBird.sensitiveKeys += ["ssn", "creditCard", "passcode"]

// Logging dictionary with sensitive keys
LogBird.log("User login attempt", additionalInfo: [
    "username": "johndoe",
    "authToken": "secret_abc123" // Automatically replaced with "<redacted>"
])
```

#### Layer 2: Call-Site String Interpolation Privacy (`LBLogMessage`)

Use explicit privacy specifiers inside string interpolations to redact inline values before they are recorded:

```swift
let userEmail = "john.doe@example.com"
let sessionToken = "xyz987654"

// String interpolation with privacy controls
LogBird.log("User \(userEmail, privacy: .public) authenticated with token \(sessionToken, privacy: .private)")
// Recorded & displayed as: "User john.doe@example.com authenticated with token <redacted>"
```

### Combine Real-Time Streaming

Subscribe to `logsPublisher` to react to log events live in your application:

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
            print("Log history was cleared")
        }
    }
    .store(in: &cancellables)
```

Read the full history synchronously at any time via `LogBird.logs`.

### Exporting Logs

Export recorded entries to JSON, JSONLines (NDJSON), or Plain Text:

```swift
// 1. Export as in-memory Data (JSON format)
let output = try LogBird.export(.all, format: .json, destination: .data)
let jsonData: Data = output.data

// 2. Export to a temporary or specific file (JSONLines format)
let fileOutput = try LogBird.export(.all, format: .jsonLines, destination: .file(nil))
if let fileURL = fileOutput.fileURL {
    print("Exported logs written to: \(fileURL.path)")
}

// 3. Export filtered selection as Plain Text
let errorLogs = LogBird.logs.filter { $0.level == .error }
let textOutput = try LogBird.export(.logs(errorLogs), format: .plainText, destination: .data)
```

### SwiftUI Debug Viewer (`LogBirdUI`)

Import `LogBirdUI` to embed the ready-made debug viewer in your application:

```swift
import SwiftUI
import LogBird
import LogBirdUI

struct DeveloperSettingsView: View {
    var body: some View {
        LBLogsView() // Uses LogBird.shared by default
    }
}

// Or scope it to a specific LogBird instance:
struct NetworkDebugView: View {
    let networkLogger: LogBird
    
    var body: some View {
        LBLogsView(logBird: networkLogger)
    }
}
```

Features included in `LBLogsView`:
- Real-time auto-updating list of logs.
- Full-text search across messages, metadata, errors, locations, and sources.
- Level filter picker (`All`, `Debug`, `Info`, `Warning`, `Error`, `Critical`).
- Native macOS Save Panel & iOS Share Sheet integration for exporting.
- One-click log clearing.

### Clearing History

Empty in-memory log history whenever needed (e.g., user logout or session reset):

```swift
// Clear static instance history
LogBird.clearLogs()

// Clear custom instance history
customLogger.clearLogs()
```

---

## How It Works

- **Storage**: Entries are stored in a bounded in-memory array (`[LBLog]`) capped at `maxLogs` (default `1000`). Trimming happens automatically when the limit is exceeded. Setting `maxLogs = 0` turns off in-memory storage while keeping Combine streaming active.
- **Recording Gate**: Every `log(...)` call is checked against `isEnabled` and `minLogLevel` first. Recording is skipped entirely (no OSLog forward, no storage, no publish) when the logger is off or the entry is below the severity floor. By default `isEnabled` is on only under `DEBUG`.
- **System Logging**: Every entry is formatted into a readable block and forwarded to Apple's native `os.Logger`. View output in macOS Console.app or run `log stream --subsystem com.myapp` in Terminal.
- **Thread Safety**: All state reads and writes are guarded by an internal serial queue (`com.logbird.accessQueue`). Combine event dispatching runs asynchronously on a separate serial queue (`com.logbird.publishQueue`) to avoid re-entrancy deadlocks when subscriber callbacks trigger subsequent log calls.

---

## AI Agent Support

LogBird is designed with AI coding agents and LLM integrations in mind. It includes dedicated agent documentation and skills:

- **[AGENTS.md](AGENTS.md)**: Detailed codebase map, structural invariants, concurrency rules, and agent integration recipes.
- **[.agents/skills/logbird/SKILL.md](.agents/skills/logbird/SKILL.md)**: Agent skill file providing full library context and code patterns for AI tools.
- **[.agents/skills/logbird-v1-to-v2/SKILL.md](.agents/skills/logbird-v1-to-v2/SKILL.md)**: Migration guide and skill for upgrading integrations from LogBird v1.0.0 to v2.0.0.

---

## Contributing

We welcome contributions! Please review **[CONTRIBUTING.md](CONTRIBUTING.md)** for details on development environment setup, coding standards, test execution, and pull request workflows.

---

## Author

LogBird was created and is maintained by **[Javier Manzo](https://www.linkedin.com/in/javiermanzo/)**.

---

## License

LogBird is released under the **MIT License**. See the [LICENSE](LICENSE) file for complete details.
