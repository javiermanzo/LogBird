# Changelog

All notable changes to LogBird will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-07-31

### Added
- **Privacy-Aware Message Interpolation (`LBLogMessage` & `LBPrivacy`)**: Introduced `LBLogMessage` string interpolation wrapper supporting `\(value, privacy: .private)` to redact inline sensitive content at the call site, along with `LogBird.log(_ message: LBLogMessage, ...)` method overloads.
- **Automatic Key & Field Redaction (`LBRedactor`)**: Added automatic key-normalization and redaction engine for `additionalInfo`, `extraMessages`, and `error.userInfo`. Values associated with sensitive keys matching configurable needles (default: `"password"`, `"token"`, `"authorization"`, `"secret"`, `"apiKey"`, `"cookie"`) are automatically masked with `<redacted>`.
- **Redaction Configuration Properties**: Added `redactSensitiveFields: Bool` (defaults to `true`) and `sensitiveKeys: [String]` configurable properties on static `LogBird` facade and instance objects.
- **Typed Metadata Representation (`LBValue`)**: Added `LBValue` enum (`.string`, `.int`, `.double`, `.bool`, `.url`, `.array`, `.dictionary`) conforming to `Codable`, `Hashable`, `Sendable`, and `ExpressibleByLiteral` protocols to replace untyped dictionary metadata.
- **Structured Multi-Format Log Export Engine**: Added `LBLogExporter` supporting `.json`, `.jsonLines` (NDJSON), and `.plainText` encoding formats, accessible via `LogBird.export(...)` with customizable destinations (`.data` or `.file(URL?)`) and content scopes (`.all` or `.logs([LBLog])`).
- **Zero-Retention Mode & Configurable History Cap (`maxLogs`)**: Added `maxLogs: Int` configuration property (defaults to 1000). Setting `maxLogs = 0` enables zero-retention mode (disables in-memory log history while preserving real-time Combine publisher events).
- **Structured Error Details (`LBError`)**: Added `LBError` struct capturing error domain, code, type, localized description, and stringified `userInfo`, with specialized payload extraction for Swift `DecodingError` and `EncodingError` contexts.
- **Structured Call-Site Location (`LBLocation`) & Source (`LBSource`)**: Added structured models for location tracking (`fileID`, `function`, `line`) and logger source (`subsystem`, `category`) attached to each `LBLog`.
- **Granular Publisher Events (`LBLogEvent`)**: Added `LBLogEvent` enum (`.recorded(LBLog)` and `.cleared`) for Combine event streaming.
- **Log History Clearing (`clearLogs()`)**: Added `clearLogs()` static and instance method to reset stored in-memory log history.
- **Automatic Subsystem and Category Inference**: `LogBird` now automatically infers `Bundle.main.bundleIdentifier` as subsystem (falling back to `"com.logbird.default"`) and extracts the default OSLog category from the caller's `#fileID` module name.
- **Expanded Multiplatform Support**: Added support for `tvOS 15.0+` and `watchOS 8.0+` platforms, and lowered `macOS` deployment target to `macOS 12.0+`.
- **SwiftUI Debug UI Enhancements**: Added text search bar, log level filter selector, and platform-native export UI integration (macOS SavePanel, iOS ShareSheet) to `LBLogsView`.
- **Swift 6 Strict Concurrency Compliance**: Full compliance with Swift 6 language mode (`.version("6")` and `.v5`), enforcing `Sendable` conformance and thread-safe dual-queue synchronization (`dispatchQueue` and `publishQueue`).
- **AI Agent Specification & Developer Guides**: Added `AGENTS.md` specification, `CONTRIBUTING.md` guidelines, and LogBird agent skill (`.agents/skills/logbird/SKILL.md`).

### Modified
- **Package Architecture & Dedicated `LogBirdUI` Target**: Separated SwiftUI views (`LBLogsView`, `LogsViewModel`, `LBLogRowView`) from core logging logic into a dedicated `LogBirdUI` package target and library product (`import LogBirdUI`). [Breaking]
- **Typed `additionalInfo` Metadata**: Updated `additionalInfo` parameter and property type from untyped `[String: Any]?` to typed `[String: LBValue]?`. [Breaking]
- **Combine Publisher Stream Return Type**: Changed `LogBird.logsPublisher` return type from `AnyPublisher<[LBLog], Never>` to `AnyPublisher<LBLogEvent, Never>`, streaming granular `.recorded(LBLog)` and `.cleared` events instead of full array snapshots on every log entry. [Breaking]
- **`LBExtraMessage` Structure**: Renamed `LBExtraMessage` properties `title` and `message` to `key` and `value`. [Breaking]
- **Identifier Property & API Cleanup**: Replaced `setIdentifier(_:)` method and `currentIdentifier` property with a unified `identifier: String?` read-write property on static `LogBird` facade and instance class. [Breaking]
- **Optional Log Message Parameter**: `LogBird.log(_ message: String? = nil, ...)` now accepts an optional message parameter defaulting to `nil`, allowing log entries with only an error or extra messages.
- **In-Memory Log Storage Order**: Changed internal storage order of `logs` array snapshot to preserve recording order (oldest first) instead of reverse chronological order. [Breaking]
- **MainActor Isolation for UI Layer**: Explicitly isolated `LBLogsView` and `LogsViewModel` to `@MainActor` with main-thread event dispatching for UI updates.

### Fixed
- **Concurrency Data Race & Re-Entrancy Deadlocks**: Resolved potential deadlocks when Combine subscribers trigger log calls during event notifications by executing publisher updates on a dedicated `publishQueue` outside the main state lock.
- **Log Location File Path Trimming**: Fixed log location formatting to extract and display only the clean file name instead of full absolute file system paths.
- **Flaky Unit Tests**: Fixed timing dependencies and race conditions in core log history and Combine publisher unit tests.
- **Unique Export File Naming**: Fixed temporary export file collision issues by generating unique timestamped file names (`logbird-logs-<timestamp>.<ext>`).

### Removed
- **CocoaPods Support**: Removed `LogBird.podspec` file; LogBird is now distributed exclusively via Swift Package Manager (SPM). [Breaking]
- **`setIdentifier(_:)` and `currentIdentifier` APIs**: Removed `setIdentifier(_:)` method and `currentIdentifier` property in favor of `identifier`. [Breaking]
- **Public `LBLog` Direct Instantiation**: Restricted memberwise initializers of `LBLog`, `LBSource`, `LBLocation`, and `LBError` to package-internal access level to enforce entity construction through `LogBird` logging APIs. [Breaking]
- **Direct SwiftUI Dependencies in Core Target**: Removed SwiftUI imports from the core `LogBird` module. [Breaking]

## [1.0.0] - 2024-12-18

### Added
- **Initial LogBird Library Release**: Lightweight, thread-safe Swift logging framework for Apple platforms.
- **Core Logging API (`LogBird`)**: `LogBird.shared` static singleton facade and instance logger supporting `log(_ message: String, ...)` with file, function, and line source location tracking (`#fileID`, `#function`, `#line`).
- **Log Severity Levels (`LBLogLevel`)**: `LBLogLevel` enum with `.debug`, `.info`, `.warning`, `.error`, and `.critical` severities, mapped to native Apple `OSLogType` and visual emojis.
- **Apple OSLog Mirroring**: Native integration with Apple's `OSLog` (`Logger`) for system-level console output and unified logging subsystem/category tagging.
- **In-Memory Log History**: In-memory log record history storage accessible via `LogBird.shared.logs` or instance `logs` property.
- **Combine Reactive Stream (`logsPublisher`)**: `logsPublisher` exposing `AnyPublisher<[LBLog], Never>` to observe log history changes in real time.
- **Identifier Tagging**: Support for custom instance identifier string prepended to OSLog output.
- **SwiftUI Debug Viewer (`LBLogsView`)**: Embedded `LBLogsView` SwiftUI component and `LogsViewModel` for displaying log history within app debug settings.
- **Multi-Platform Support**: Initial support for `iOS 15.0+` and `macOS 14.0+`.
- **Distribution via SPM & CocoaPods**: Initial Swift Package Manager (`Package.swift`) and CocoaPods (`LogBird.podspec`) package definitions.
