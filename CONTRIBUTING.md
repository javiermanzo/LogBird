# Contributing to LogBird

Thank you for your interest in contributing to **LogBird**! We welcome bug reports, feature suggestions, documentation improvements, and pull requests from both human developers and AI coding agents.

This document outlines the guidelines and best practices for building, testing, and submitting contributions to LogBird.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Project Architecture & Modules](#project-architecture--modules)
- [Coding Guidelines](#coding-guidelines)
- [Testing Standards](#testing-standards)
- [Submitting Pull Requests](#submitting-pull-requests)
- [AI Agent Guidelines](#ai-agent-guidelines)

---

## Code of Conduct

Please maintain a respectful, inclusive, and collaborative environment. Be helpful, constructive, and open to feedback.

---

## Getting Started

### Prerequisites

- **macOS** with **Xcode 15.0+** or **Xcode 16.0+**
- **Swift 5.9** or **Swift 6.0** toolchain

### Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/javiermanzo/LogBird.git
   cd LogBird
   ```

2. **Open in Xcode or SwiftPM**:
   Double click `Package.swift` or open the directory in Xcode.

3. **Run Unit Tests**:
   Via command line:
   ```bash
   swift test
   ```
   Or inside Xcode using `Cmd + U`.

---

## Project Architecture & Modules

LogBird is organized into two Swift Package targets:

1. **`LogBird` Target (`Sources/LogBird/`)**:
   - The core logging runtime.
   - **Zero external dependencies** (uses only native Apple frameworks: `Foundation`, `Combine`, `OSLog`).
   - Contains:
     - `LogBird.swift`: Public API facade & instance interface (`@unchecked Sendable`).
     - `LBManager.swift`: Thread safety, dispatch queues, OSLog forwarding, and state management.
     - `LBRedactor.swift`: Key normalization and automatic privacy redaction.
     - `Models/`: Core data models (`LBLog`, `LBLogLevel`, `LBLogMessage`, `LBValue`, `LBError`, `LBExtraMessage`, `LBLocation`, `LBSource`, `LBLogEvent`).
     - `Export/`: Encoding engine for `.json`, `.jsonLines`, and `.plainText` formats (`LBLogExporter`, `LBExportContent`, `LBExportDestination`, `LBExportFormat`, `LBExportOutput`).

2. **`LogBirdUI` Target (`Sources/LogBirdUI/`)**:
   - Optional SwiftUI debug viewer.
   - Depends on `LogBird`.
   - Contains:
     - `LBLogsView.swift`: Main SwiftUI container view.
     - `LogsViewModel.swift`: `@MainActor` view model observing `LogBird.logsPublisher`.
     - `LBLogRowView.swift`: Modular row renderer Tinted by log level.
     - `LBLogExport.swift`: Platform export dialogs (macOS `NSSavePanel`, iOS `UIActivityViewController`).
     - `LBLogLevel+Color.swift`: SwiftUI Color extensions for log levels.

---

## Coding Guidelines

When writing code for LogBird, adhere to the following principles:

1. **Swift 6 & Concurrency Safety**:
   - Ensure all public types satisfy `Sendable` requirements.
   - Core state mutations in `LBManager` **must** execute synchronously on `dispatchQueue`.
   - Combine events **must** publish asynchronously on `publishQueue` to prevent re-entrancy deadlocks when subscriber callbacks trigger log statements.
2. **Zero Third-Party Dependencies**:
   - `LogBird` must remain dependency-free. Do not add SPM dependencies to third-party libraries.
3. **Privacy First**:
   - Always preserve and enforce sensitive field redaction via `LBRedactor` and `LBLogMessage`.
   - Never allow unredacted private values to bypass `LBRedactor` or `LBLogMessage.StringInterpolation`.
4. **Documentation**:
   - All `public` and `package` declarations must have complete SwiftDoc comments (`///`). Include description, parameter tags (`- Parameters:`), throw declarations (`- Throws:`), and return descriptions (`- Returns:`).
5. **Code Style**:
   - Prefer standard Swift style conventions.
   - Use clear, descriptive variable names.
   - Keep functions focused and concise.

---

## Testing Standards

LogBird maintains a comprehensive test suite under `Tests/`:

- **`Tests/LogBirdTests`**: Core logic tests covering history capping, thread safety, Combine events, privacy redaction, export encoding, and error extraction.
- **`Tests/LogBirdUITests`**: UI model tests validating search filtering, level filtering, deduplication, and export bindings.

### Requirements for New Features or Bug Fixes:

- Every new feature or bug fix **must include corresponding unit tests**.
- All tests must pass cleanly (`swift test` returns exit code 0 with no failures).
- Test names should clearly reflect what is being tested (e.g., `testClearLogsEmptiesHistory`).

---

## Submitting Pull Requests

1. **Fork the Repository**: Create your feature or bugfix branch off `main` (e.g., `feature/add-log-filter` or `fix/concurrency-race`).
2. **Commit Changes**: Use clean, descriptive commit messages.
3. **Verify Build & Tests**: Ensure `swift test` passes locally without any warnings or failures.
4. **Open a Pull Request**:
   - Describe what the PR does and why it is needed.
   - Reference any relevant issues (e.g., `Fixes #42`).
   - Check that CI builds pass.

---

## AI Agent Guidelines

If you are an AI Coding Agent (e.g., Antigravity, Claude, ChatGPT) working on LogBird:

- Consult **[AGENTS.md](AGENTS.md)** for a complete technical sitemap and invariant checklist before making changes.
- Consult the skill at **[.agents/skills/logbird/SKILL.md](.agents/skills/logbird/SKILL.md)** when integrating LogBird into client codebases.
- Do NOT remove existing SwiftDoc comments.
- Do NOT introduce third-party SPM packages.
- Always run `swift test` (using `BypassSandbox: true` if sandboxed) to verify correctness after code edits.
