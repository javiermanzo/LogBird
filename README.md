
<p align="center" width="100%">
    <img width="30%" src="https://raw.githubusercontent.com/javiermanzo/LogBird/main/Resources/LogBird.png"> 
</p>

![Release](https://img.shields.io/github/v/release/javiermanzo/LogBird?style=flat-square)
[![CI](https://img.shields.io/github/actions/workflow/status/javiermanzo/LogBird/swift.yml?style=flat-square)](https://github.com/javiermanzo/LogBird/actions/workflows/swift.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9_6.0-orange?style=flat-square)](https://swift.org/)
[![Platforms](https://img.shields.io/badge/Platforms-macOS_iOS-yellowgreen?style=flat-square)](https://github.com/javiermanzo/LogBird#requirements) 
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://swiftpackageindex.com/javiermanzo/LogBird)

LogBird is a powerful yet simple logging library for Swift, designed to provide flexible and efficient console logging.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Swift Package Manager](#swift-package-manager)
- [Usage](#usage)
  - [Log Levels](#log-levels)
  - [Static Logging](#static-logging)
  - [Instance Logging](#instance-logging)
  - [Log Parameters](#log-parameters)
  - [Combine Support](#combine-support)
  - [SwiftUI View](#swiftui-view)
  - [Clearing Logs](#clearing-logs)
- [How It Works](#how-it-works)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

## Features

- [x] Static logging via `LogBird` methods
- [x] Custom logging instances
- [x] Multiple log levels
- [x] Customizable log identifier
- [x] Combine support via `logsPublisher`
- [x] SwiftUI `LBLogsView` for log visualization
- [x] Clearable in-memory log history

## Requirements

- Swift 5.9 or 6.0 toolchain (Swift 5 and 6 language modes are both supported)
- iOS 15.0+
- macOS 12.0+

## Installation
LogBird is distributed as a Swift Package. Add it to your project using [Swift Package Manager](https://swift.org/package-manager/).

### Swift Package Manager
Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/javiermanzo/LogBird.git")
]
```

## Usage

### Log Levels
LogBird supports the following log levels via the `LBLogLevel` enum:
- `.debug`: For debugging information.
- `.info`: For informational messages.
- `.warning`: For warnings.
- `.error`: For error messages.
- `.critical`: For critical issues.

### Static Logging
Use the static methods provided by `LogBird` for simple logging:

```swift
LogBird.log(message: "This is an info log")
```

### Instance Logging
Create a custom instance of `LogBird` for more flexibility:

```swift
let customLogger = LogBird(subsystem: "com.example.myapp", category: "Network")
customLogger.log(message: "This is a debug log from the Network category")
```

### Log Parameters
The `log` method supports additional parameters for more detailed logs.

#### Logging with extra messages:
```swift
let extraMessages: [LBExtraMessage] = [
    LBExtraMessage(key: "Extra key", value: "Extra value")
]
LogBird.log("My Log",
    extraMessages: extraMessages)
```

#### Logging with additional info:
```swift
LogBird.log("Purchase",
    additionalInfo: ["userId": 12, "planId": 2],
    level: .info)
```

#### Logging an error:
```swift
let someError = NSError(
    domain: "com.myapp.error",
    code: 500,
    userInfo: [NSLocalizedDescriptionKey: "Error description"]
)

LogBird.log("Log Error",
    error: someError,
    level: .error)
```

### Combine Support
React to log history events in real time with Combine. `logsPublisher` emits an `LBLogEvent` for each recorded entry and whenever the history is cleared:

```swift
import Combine

var logs: [LBLog] = []
var subscribers = Set<AnyCancellable>()
let logBird = LogBird(subsystem: "com.example.myapp", category: "UI")

LogBird.logsPublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] event in
        switch event {
        case .recorded(let newLog):
            self?.logs.insert(newLog, at: 0)
        case .cleared:
            self?.logs = []
        }
    }
    .store(in: &subscribers)
```

The recorded history is always available synchronously via `LogBird.logs` (newest first).

### SwiftUI View
Use `LBLogsView` to visualize logs in your app. You can optionally provide a custom `LogBird` instance; by default, it uses the static instance:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        LBLogsView(logBird: LogBird(subsystem: "com.example.myapp", category: "UI"))
    }
}
```

### Clearing Logs
Empty the in-memory log history at any time (e.g. after a logout or session reset). Subscribers of `logsPublisher` receive a `cleared` event:

```swift
LogBird.clearLogs()
// or on an instance
customLogger.clearLogs()
```

## How It Works

- **Storage**: every log is kept in an in-memory history (newest first) capped at `maxLogs` entries. The history is readable synchronously via `logs`; call `clearLogs()` to empty it.
- **Console output**: under the hood, each entry is also forwarded to `OSLog` (`os.Logger`), so logs are visible in Console.app and via `log stream` under your subsystem and category (pass `--debug` to `log stream` to include debug-level entries).
- **Combine**: `logsPublisher` emits an `LBLogEvent` for each new entry (`recorded`) and every `clearLogs()` call (`cleared`); earlier events are not replayed to new subscribers. Read `logs` for a synchronous snapshot of the recorded history.
- **SwiftUI**: `LBLogsView` observes `logsPublisher` through an internal `ObservableObject` view model and re-renders on each new entry.
- **Threading**: `LogBird` is safe to call from any thread. Internal state is protected by a serial dispatch queue, and publishing happens on a separate queue so subscriber callbacks never run while the internal lock is held.

## Contributing
If you encounter any issues, please submit an [issue](https://github.com/javiermanzo/LogBird/issues). [Pull requests](https://github.com/javiermanzo/LogBird/pulls) are also welcome!

## Author
LogBird was created by [Javier Manzo](https://www.linkedin.com/in/javiermanzo/).

## License
LogBird is available under the MIT license. See the [LICENSE](https://github.com/javiermanzo/LogBird/blob/main/LICENSE) file for more info.
