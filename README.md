# VDStore

## Introduction

VDStore is a minimalistic iOS architecture library designed to manage application state in a clean and efficient manner. It provides a `Store` struct that enables state mutation, state subscription, dependency injection, and fragmentation into scopes for scaling. VDStore is compatible with both SwiftUI and UIKit.

## Features

- **State Management**: Easily handle and mutate the state of your app in a structured and type-safe way.
- **State Subscription**: Observe state changes and update your UI in a reactive manner.
- **Dependency Injection**: Seamlessly manage dependencies and inject services as needed.
- **Fragmentation into Scopes**: Efficiently break down and manage complex states by creating focused sub-stores with scoped functionality.

## Usage

### Basic Example

Here's how you can define a simple counter state and its mutations:

```swift
struct Counter: Equatable {
  var counter: Int = 0
}

extension Store<Counter> {

  var step: Int {
    self[\.step] ?? 1 
  }

  func add() {
    state.counter += step
  }
}
```

### Using with UIKit

Example of integrating `VDStore` with a `UIViewController`:

```swift
final class CounterViewController: UIViewController {

  @Store var state = Counter()
  private var bag: Set<AnyCancellable> = []

  override func viewDidLoad() {
    super.viewDidLoad()
    $state.publisher.sink { [weak self] state in
      self?.render(with: state)
    }
    .store(in: &bag)
  }

  func tapAddButton() {
    $state.add()
  }
}
```

### Using with SwiftUI

Example of integrating `VDStore` with a SwiftUI `View`:

```swift
struct CounterView: View {

  @ViewStore var counter = Counter() 

  var body: some View {
    HStack {
      Text("\(counter.counter)")
      Button("Add") {
         $counter.add()
      }
      SomeChildView($counter)
    }
  }
}
```

### Adding Dependencies

How to define and inject dependencies:

```swift
extension StoreDependencies {

   public var someService: SomeService {
      self[\.someService] ?? SomeService.shared
   }
}

func getSomeChildStore(store: Store<Counter>) -> Store<Int> {
   store
     .scope(\.counter)
     .dependency(\.someService, SomeService())
}
```

## Requirements

- Swift 5.0+
- iOS 13.0+

## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/VDStore.git", from: "0.3.0")
  ],
  targets: [
    .target(name: "SomeProject", dependencies: ["VDStore"])
  ]
)
```
```ruby
$ swift build
```

## Author

dankinsoid, voidilov@gmail.com

## License

VDStore is available under the MIT license. See the LICENSE file for more info.
