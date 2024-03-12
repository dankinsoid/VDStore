# VDStore

## Introduction

VDStore is a minimalistic iOS architecture library designed to manage application state in a clean and native manner.
It provides a `Store` struct that enables state mutation, state subscription, di injection, and fragmentation into scopes for scaling.
VDStore is compatible with both SwiftUI and UIKit.

## Features

- **State Management**: Easily handle and mutate the state of your app in a structured and type-safe way.
- **State Subscription**: Observe state changes and update your UI in a reactive manner.
- **Dependencies Injection**: Seamlessly manage dependencies and inject services as needed.
- **Fragmentation into Scopes**: Efficiently break down and manage complex states by creating focused sub-stores with scoped functionality.

## Usage

### Basic Example

Here's how you can define a simple counter state and its mutations:

```swift
struct Counter: Equatable {
  var counter: Int = 0
}

extension Store<Counter> {

  func add() {
    state.counter += 1
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
`ViewStore` is a property wrapper that automatically subscribes to state changes and updates the view.
`ViewStore` can be initialized with either `Store` or `State` instances.

### Using with UIKit

Example of integrating `VDStore` with a `UIViewController`:

```swift
final class CounterViewController: UIViewController {

  @Store var state = Counter()

  override func viewDidLoad() {
    super.viewDidLoad()
    $state.publisher.sink { [weak self] state in
      self?.render(with: state)
    }
    .store(in: &$state.di.cancellableSet)
  }

  func tapAddButton() {
    $state.add()
  }
}
```

### Defining actions
You can edit the state in any way you prefer, but the simplest one is extending Store.

There is a helper macro called `@Actions`.
`@Actions` redirect all your methods calls through your custom middlewares that allows you to intrecept all calls in runtime.
For example, you can use it to log all calls or state changes.
Also `@Actions` make all your `async` methods cancellable.
```swift
@Actions
extension Store<Converter> {

  func updateRates() async {
    cancel(Self.updateRates)
    state.isLoading = true
    defer { state.isLoading = false }
    do {
      try await di.api.updateRates()
      guard !Task.isCancelled else { return }
      ...
    } catch {
      ...
    }
  }
}

```

### Adding Dependencies

To define a dependency you should extend `StoreDIValues` with a computed property like this:
```swift
extension StoreDIValues {

   public var someService: SomeService {
      get { self[\.someService] ?? SomeService.shared }
      set { self[\.someService] = newValue }
   }
}
```
Or you can use on of two macros:
```swift
extension StoreDIValues {

   @StoreDIValue
   public var someService: SomeService = .shared
}
```
```swift
@StoreDIValuesList
extension StoreDIValues {

   public var someService1: SomeService1 = .shared
   public var someService2: SomeService2 = .shared
}
```
To inject a dependency you should use `di` method:
```swift
func getSomeChildStore(store: Store<Counter>) -> Store<Int> {
   store
     .scope(\.counter)
     .di(\.someService, SomeService())
}
```
To use a dependency you should use `di` property:
```swift
store.di.someService.someMethod()
```
There is `valueFor` global method that allows you to define default values depending on the environment: live, test or preview.

## Requirements

- Swift 5.7+
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
    .package(url: "https://github.com/dankinsoid/VDStore.git", from: "0.23.0")
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
