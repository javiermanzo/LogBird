# Changelog

All notable changes to LogBird will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-08-03

### Added
- **Centralized Configuration (`LBConfig`)**: Introduced `LBConfig` struct (`Hashable`, `Sendable`) consolidating `maxLogs`, `isEnabled`, `minLogLevel`, `redactSensitiveFields`, `sensitiveKeys`, and `identifier` into a single value. The whole `LogBird` logging entry (gate, redactor, identifier) is now derived from one config snapshot. Includes a new public `LogBird.config` property (static and instance) to read/replace the configuration atomically.
- **Configurable Recording Gate (`isEnabled` + `minLogLevel`)**: Added `isEnabled: Bool` master switch (defaults to `true` under `DEBUG`, `false` otherwise, resolved via `#if DEBUG` inside `LBConfig.init`) and `minLogLevel: LBLogLevel` severity floor. When recording is disabled or the entry is below the threshold, `log(...)` returns early after a single queue hop — no OSLog forwarding, storage, or publishing. `clearLogs()` and `export()` remain ungated. Available on both static and instance facades.
- **Layered Sensitive Keys API (`LBSensitiveKeysAction`)**: Introduced `LBSensitiveKeysAction` enum with `.add([String])`, `.set([String])`, `.reset`, and `.clear` cases, exposed via `LogBird.sensitiveKeys(_:)` (static and instance) and `LBConfig.sensitiveKeys(_:)`. New keys are normalized at insertion time (lowercased, stripping `-`, `_`, and whitespace).
- **Global Default Sensitive Keys**: Added thread-safe global application defaults through `LogBird.setDefaultSensitiveKeys(_:)` and read-only `LogBird.defaultSensitiveKeys` (`Set<String>`). Per-instance configs either inherit these globals (with optional `.add` extensions) or define an explicit override set via `.set`.
- **`LBLogLevel: Comparable`**: `LBLogLevel` now conforms to `Comparable`, ordered by declaration severity (`.debug < .info < .warning < .error < .critical`) via an internal `severityRank`, not the alphabetical raw value. Required by the `minLogLevel` floor.
- **Expanded Default Sensitive Key Set**: Extended the curated default needles from 6 to 10: `"password"`, `"token"`, `"authorization"`, `"auth"`, `"secret"`, `"apikey"`, `"cookie"`, `"bearer"`, `"credentials"`, `"privatekey"`. Defaults are now pre-normalized at declaration time.
- **Convenience Initializer**: Added `LogBird.init(subsystem:category:fileID:maxLogs:minLogLevel:)` convenience initializer exposing the most common tuning knobs without requiring a full `LBConfig`.

### Modified
- **`LogBird.init` Signature**: The designated initializer parameter `maxLogs: Int = 1000` was replaced by `config: LBConfig = LBConfig()`. **[Breaking]** Migrate with `LogBird(config: LBConfig(maxLogs: ...))` or the new convenience initializer.
- **`sensitiveKeys` Property**: Changed from a read-write `[String]` property to a read-only `Set<String>` view on both static and instance facades. **[Breaking]** Direct assignment (`LogBird.sensitiveKeys = [...]`) no longer compiles; reconfigure via `LogBird.sensitiveKeys(_:)` with an `LBSensitiveKeysAction` (`.add`, `.set`, `.reset`, `.clear`).
- **`defaultSensitiveKeys` Semantics**: Changed from a per-instance `[String]` constant (`static let`) to the global application defaults accessor (`static var`, `Set<String>`, thread-safe). **[Breaking]** It now reflects/overrides app-wide defaults instead of the shared instance baseline.
- **`LBManager` State Consolidation**: Replaced the scattered `storedMaxLogs`, `storedRedactSensitiveFields`, `storedSensitiveKeys`, and `storedIdentifier` fields with a single `storedConfig: LBConfig` value. All configuration reads/writes now go through one atomic `dispatchQueue.sync`.
- **Atomic Per-Field Config Setters**: Per-field setters (`maxLogs`, `identifier`, `redactSensitiveFields`, `isEnabled`, `minLogLevel`) now mutate `storedConfig` inside a single `dispatchQueue.sync`, eliminating the prior read-modify-write TOCTOU window across two queue hops.

### Fixed
- **Config TOCTOU Race**: Resolved a time-of-check/time-of-use race where a concurrent change to a different config field could be clobbered by a read-modify-write spanning two queue hops. All field setters are now atomic.
- **Snapshot Consistency**: The OSLog identifier is now read from the same config snapshot used by the gate and redactor, so a single log entry can no longer be split across two configurations by a concurrent change.
- **Dead State Removal**: Removed the unused `storedIdentifier` property and `LogSnapshot` struct left over after the `LBConfig` consolidation.
- **Dangling `defaultIsEnabled` Reference**: Removed stale documentation/SwiftDoc references to a `LogBird.defaultIsEnabled` symbol that was never defined; the `#if DEBUG` default now lives once inside `LBConfig.init`.

### Removed
- **`maxLogs:` Parameter on `LogBird.init`**: Replaced by `config: LBConfig`. **[Breaking]**
- **`LogBird.sensitiveKeys` Setter**: Direct assignment is no longer supported; use the `LBSensitiveKeysAction` API. **[Breaking]**
- **`LogBird.defaultSensitiveKeys` as a `[String]` `static let`**: Replaced by the global `Set<String>` accessor. **[Breaking]**
- **Public `LBSensitiveKeysState`**: Scoped to internal (backs a private property of `LBConfig` and was never part of the public surface).

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
