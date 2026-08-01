# AGENTS.md — AI Agent Technical Specification & Reference for LogBird

This document serves as the primary technical specification for AI coding agents (LLMs, pair programmers, autonomous software agents) operating on, maintaining, or integrating the **LogBird** Swift library.

---

## 1. Executive Overview

**LogBird** is a lightweight, thread-safe, privacy-conscious Swift logging framework for Apple platforms (iOS 15+, macOS 12+, tvOS 15+, watchOS 8+). It operates with **zero external dependencies** and bridges in-memory log history, real-time Combine event streams, native Apple `OSLog` system mirroring, automatic privacy redaction, structured multi-format log exporting, and an optional SwiftUI debug viewer.

---

## 2. Directory Structure & File Map

```
LogBird/
├── Package.swift                             # SPM package manifest (Swift 6 / Swift 5.9 modes)
├── README.md                                 # User-facing library documentation
├── CONTRIBUTING.md                           # Developer contribution guidelines
├── AGENTS.md                                 # AI Agent technical specification (this file)
├── .agents/
│   └── skill/
│       └── logbird/
│           └── SKILL.md                      # Agent skill for LogBird integration & context
├── Sources/
│   ├── LogBird/                              # Core Logging Target (No SwiftUI dependencies)
│   │   ├── LogBird.swift                     # Public facade (static API & instance class)
│   │   ├── LBManager.swift                   # Underlying engine, thread-safety queues & OSLog
│   │   ├── LBRedactor.swift                  # Key normalization & value redaction engine
│   │   ├── Models/
│   │   │   ├── LBLog.swift                   # Main log record model (Codable, Identifiable, Sendable)
│   │   │   ├── LBLogLevel.swift              # Severity enum (.debug, .info, .warning, .error, .critical)
│   │   │   ├── LBLogMessage.swift            # Privacy-aware string interpolation (LBLogMessage & LBPrivacy)
│   │   │   ├── LBValue.swift                 # Typed metadata enum (.string, .int, .double, .bool, .url, .array, .dictionary)
│   │   │   ├── LBError.swift                 # Struct capturing error details & DecodingError context
│   │   │   ├── LBExtraMessage.swift          # Labeled section string model
│   │   │   ├── LBLocation.swift              # Call-site source location (#fileID, #function, #line)
│   │   │   ├── LBSource.swift                # OSLog subsystem & category metadata
│   │   │   └── LBLogEvent.swift              # Combine event enum (.recorded(LBLog), .cleared)
│   │   └── Export/
│   │       ├── LBLogExporter.swift           # Encoding engine for JSON, JSONLines, & PlainText
│   │       ├── LBExportContent.swift         # Scope enum (.all, .logs([LBLog]))
│   │       ├── LBExportDestination.swift     # Output destination (.data, .file(URL?))
│   │       ├── LBExportFormat.swift          # Format enum (.json, .jsonLines, .plainText)
│   │       └── LBExportOutput.swift          # Export result (.data(Data), .file(URL, Data))
│   └── LogBirdUI/                            # SwiftUI Debug UI Target (Depends on LogBird)
│       ├── LBLogsView.swift                  # Main SwiftUI container view with toolbar & search
│       ├── LogsViewModel.swift               # @MainActor view model mirroring & filtering history
│       ├── LBLogRowView.swift                # Tinted row view component
│       ├── LBLogExport.swift                 # Platform export presentations (macOS SavePanel, iOS ShareSheet)
│       └── LBLogLevel+Color.swift            # SwiftUI Color extension mapping for LBLogLevel
└── Tests/
    ├── LogBirdTests/                         # Comprehensive core logic unit tests (100+ tests)
    └── LogBirdUITests/                       # Comprehensive UI view model unit tests
```

---

## 3. Core Architectural Invariants

When modifying or extending LogBird, AI agents MUST preserve the following invariants:

### 3.1 Concurrency & Thread-Safety Model
1. **Dual Queue Isolation in `LBManager`**:
   - `dispatchQueue` (`com.logbird.accessQueue`): Serial queue protecting state reads and mutations (`logs`, `storedMaxLogs`, `storedIdentifier`, `storedRedactSensitiveFields`, `storedSensitiveKeys`, `storedIsEnabled`, `storedMinLogLevel`).
   - `publishQueue` (`com.logbird.publishQueue`): Serial queue dedicated exclusively to asynchronous Combine event dispatch (`publishQueue.async { logsSubject.send(event) }`).
   - **CRITICAL RE-ENTRANCY RULE**: Never publish Combine events while holding a lock on `dispatchQueue`. Subscribers may perform logging calls in response to `.recorded` events, which would cause a re-entrancy deadlock if `dispatchQueue` were locked.
2. **`@unchecked Sendable` Decorator on `LogBird` and `LBManager`**:
   - `LogBird` and `LBManager` are marked `@unchecked Sendable` because internal synchronization is handled explicitly via `dispatchQueue`. All internal mutations MUST remain guarded by `dispatchQueue`.
3. **`@MainActor` Isolation in UI Layer**:
   - `LBLogsView` and `LogsViewModel` are isolated to `@MainActor`. Combine subscriber events received from `publishQueue` are bounced to `DispatchQueue.main` before updating view state.

### 3.2 Recording Gate (`isEnabled` / `minLogLevel`)
1. **First thing in `LBManager.log(...)`**: snapshot `storedIsEnabled` and `storedMinLogLevel` in a single `dispatchQueue.sync`, then `return` early when `isEnabled == false` or `level < minLogLevel`. The gate MUST run before building the `LBLog`, forwarding to OSLog, mutating history or publishing — the disabled path performs no work.
2. **`isEnabled` (master switch)** defaults to `LogBird.defaultIsEnabled`, a compile-time constant resolved via `#if DEBUG` (`true` under DEBUG, `false` otherwise). Because the package is compiled with the host app, the flag reflects the integrator's build configuration. It is a settable `Bool` so integrators can drive it from their own flags/macros or force it on at init.
3. **`minLogLevel` (severity floor)** defaults to `.debug` (everything passes when enabled). Requires `LBLogLevel: Comparable`, ordered by declaration severity (`.debug < .info < .warning < .error < .critical`) via an internal `severityRank` — NOT the alphabetical raw value.
4. **NOT gated**: `clearLogs()` and `export()` always operate on recorded history regardless of `isEnabled`/`minLogLevel`. Only `log(...)` recording is gated.

### 3.3 Privacy & Sensitive Data Redaction
1. **Automatic Field Redaction (`LBRedactor`)**:
   - Scans keys in `additionalInfo`, `extraMessages`, and `error.userInfo`.
   - Keys and needles are normalized (lowercased, stripping `_`, `-`, and whitespace).
   - If a normalized key contains any configured needle in `sensitiveKeys` (default: `"password"`, `"token"`, `"authorization"`, `"auth"`, `"secret"`, `"apiKey"`, `"cookie"`, `"bearer"`, `"credentials"`, `"privateKey"`), the value is swapped for `LBRedactor.placeholder` (`"<redacted>"`).
   - Substring matching ensures variants like `access_token`, `refresh_token`, `set-cookie`, `x-api-key`, and `private_key` are automatically matched.
2. **Inline Interpolation Privacy (`LBLogMessage`)**:
   - Uses Swift String Interpolation to replace `.private` interpolations with `LBRedactor.placeholder` during message assembly.
   - Example: `LogBird.log("User \(username, privacy: .private) logged in")`.

### 3.4 Zero Third-Party Dependencies
- `LogBird` core MUST only rely on `Foundation`, `Combine`, and `OSLog`.
- `LogBirdUI` MUST only rely on `SwiftUI` and `LogBird`.
- Do NOT introduce SPM package dependencies.

---

## 4. Public API Reference & Type Signatures

### 4.1 `LogBird` Class
```swift
public class LogBird: @unchecked Sendable {
    // Shared singleton instance
    public static let shared: LogBird

    // Constructor with defaults
    public init(
        subsystem: String = resolvedSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier),
        category: String? = nil,
        fileID: String = #fileID,
        maxLogs: Int = 1000,
        isEnabled: Bool = LogBird.defaultIsEnabled,
        minLogLevel: LBLogLevel = .debug
    )

    // Configuration Properties
    public var maxLogs: Int { get set }
    public var redactSensitiveFields: Bool { get set }
    public static let defaultSensitiveKeys: Set<String>
    public static var sensitiveKeys: Set<String> { get set }
    public var sensitiveKeys: Set<String> { get set }
    public var identifier: String? { get set }
    public var isEnabled: Bool { get set }            // Recording master switch; default: defaultIsEnabled
    public var minLogLevel: LBLogLevel { get set }    // Minimum severity recorded; default: .debug

    // Build default
    public static let defaultIsEnabled: Bool          // true under DEBUG, false otherwise (via #if DEBUG)

    // Synchronous Read & Combine Stream
    public var logs: [LBLog] { get }
    public var logsPublisher: AnyPublisher<LBLogEvent, Never> { get }

    // Logging Methods
    public func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line)
    public func log(_ message: LBLogMessage, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line)

    // Clear & Export
    public func clearLogs()
    @discardableResult
    public func export(_ content: LBExportContent = .all, format: LBExportFormat = .json, destination: LBExportDestination = .data) throws -> LBExportOutput
}
```

---

## 5. Key Data Models

| Model | Conformances | Description |
| :--- | :--- | :--- |
| `LBLog` | `Codable, Identifiable, Hashable, Sendable` | Core record: `id`, `level`, `message`, `extraMessages`, `additionalInfo`, `error`, `createdAt`, `location`, `source`. |
| `LBLogLevel` | `String, Codable, CaseIterable, Comparable, Sendable` | Severities: `.debug`, `.info`, `.warning`, `.error`, `.critical`. Ordered by severity (not alphabetically) and maps to `OSLogType` & emojis. |
| `LBValue` | `Codable, Hashable, CustomStringConvertible, Sendable` | Typed metadata: `.string`, `.int`, `.double`, `.bool`, `.url`, `.array`, `.dictionary`. Expressible by literals. |
| `LBLogMessage` | `ExpressibleByStringInterpolation, Hashable, Sendable` | Custom interpolation wrapper supporting `\(value, privacy: .private)`. |
| `LBError` | `Codable, Hashable, Sendable` | Captures domain, code, type, localizedDescription, and stringified `userInfo` (merged with `DecodingError` / `EncodingError` context). |
| `LBExportFormat` | `String, Codable, CaseIterable, Sendable` | Encoding formats: `.json`, `.jsonLines` (NDJSON), `.plainText`. |
| `LBExportOutput` | `Sendable, Equatable` | Result enum: `.data(Data)` or `.file(URL, data: Data)`. |

---

## 6. Rules for AI Agents Modifying Code

1. **Test Execution**: Always run `swift test` (using `BypassSandbox: true` if sandboxed) to verify clean execution.
2. **Preserve SwiftDoc Comments**: Retain all docstrings (`///`). When adding or altering methods, update SwiftDoc comments accordingly.
3. **No Unsafe State Access**: Do not access `logs` array or internal variables in `LBManager` outside `dispatchQueue.sync` or `dispatchQueue.async`.
4. **Swift 6 Compatibility**: Keep all types conformant to `Sendable` where appropriate.

---

## 7. Integration Recipe for Agents Integrating LogBird

When an AI agent is instructed to integrate LogBird into a host iOS/macOS app:
1. Add `LogBird` dependency in `Package.swift` or Xcode target.
2. Replace print statements or un-structured logs with `LogBird.log(...)`.
3. Use `privacy: .private` for user credentials, tokens, or PII.
4. Pass `error` parameter in `catch` blocks to automatically capture error context.
5. In debug settings views, embed `LBLogsView()`.
