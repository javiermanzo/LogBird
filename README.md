
<p align="center" width="100%">
    <img width="30%" src="https://raw.githubusercontent.com/javiermanzo/LogBird/main/Resources/LogBird.png"> 
</p>

![Release](https://img.shields.io/github/v/release/javiermanzo/LogBird?style=flat-square)
![CI](https://img.shields.io/github/actions/workflow/status/javiermanzo/LogBird/swift.yml?style=flat-square)
[![Swift](https://img.shields.io/badge/Swift-5.9_6.0-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.9_5.10_6.0-Orange?style=flat-square)
[![Platforms](https://img.shields.io/badge/Platforms-macOS_iOS-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_vision_OS_Linux_Windows_Android-Green?style=flat-square) 
![Swift Package Manager(https://swiftpackageindex.com/javiermanzo/LogBird)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

LogBird is a powerful yet simple logging library for Swift, designed to provide flexible and efficient console logging.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [CocoaPods](#cocoapods)
  - [Swift Package Manager](#swift-package-manager)
- [Usage](#usage)
  - [Log Levels](#log-levels)
  - [Static Logging](#static-logging)
  - [Instance Logging](#instance-logging)
  - [Log Parameters](#log-parameters)
  - [Combine Support](#combine-support)
  - [SwiftUI View](#swiftui-view)
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

## Requirements

- Swift 5.9+
- iOS 15.0+

## Installation
You can add LogBird to your project using [CocoaPods](https://cocoapods.org/) or [Swift Package Manager](https://swift.org/package-manager/).

### CocoaPods
Add the following line to your Podfile:

```ruby
pod 'LogBird'
```

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
    LBExtraMessage(title: "Title extra", message: "Message extra")
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
Access logs using Combine to react to new logs in real time:

```swift
import Combine

var logs: [LBLog] = []
var subscribers = Set<AnyCancellable>()
let logBird = LogBird(subsystem: "com.example.myapp", category: "UI")

LogBird.logsPublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] newLogs in
        self?.logs = newLogs
    }
    .store(in: &subscribers)
```

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

## Contributing
If you encounter any issues, please submit an [issue](https://github.com/javiermanzo/LogBird/issues). [Pull requests](https://github.com/javiermanzo/LogBird/pulls) are also welcome!

## Author
LogBird was created by [Javier Manzo](https://www.linkedin.com/in/javiermanzo/).

## License
LogBird is available under the MIT license. See the [LICENSE](https://github.com/javiermanzo/LogBird/blob/main/LICENSE.md) file for more info.
