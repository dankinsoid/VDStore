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
- **Non-mutating Properties**: Support for class-based states and fine-grained control over which property changes trigger UI updates.

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

  @CancelInFlight
  func updateRates() async {
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
```swift
extension StoreDIValues {

  @StoreDIValue
  public var someService: SomeService = valueFor(
	live: SomeService.shared,
	test: SomeServiceMock()
)
```

### Non-mutating Properties

VDStore provides fine-grained control over which property changes trigger store updates using Swift's native value semantics. The mechanism is simple: **only state mutations trigger updates**. Make a substate non-mutating in any way, and updates will only be available when scoping to that specific substate.

#### The Simple Mechanism

There are two main ways to achieve non-mutating substates:

1. **Use a class** - Class properties don't trigger parent updates when modified
2. **Use `@NonMutatingSet`** - A property wrapper that makes specific struct properties non-mutating

#### Screen-based Architecture

Consider a typical app with multiple screens. You can structure your global state so that updates to one screen don't trigger rebuilds for other screens:

```swift
struct AppState {
  @NonMutatingSet var homeScreen: HomeScreenState = HomeScreenState()
  @NonMutatingSet var profileScreen: ProfileScreenState = ProfileScreenState()
  @NonMutatingSet var settingsScreen: SettingsScreenState = SettingsScreenState()
  
  // Global app data that affects all screens
  var user: User? = nil
  var isOnline: Bool = true
}

struct HomeScreenState {
  var posts: [Post] = []
  var isLoading: Bool = false
  var searchQuery: String = ""
}

struct ProfileScreenState {
  var userProfile: UserProfile? = nil
  var isEditing: Bool = false
  var avatarImage: UIImage? = nil
  @NonMutatingSet var recentActivities: [Activity] = []
}

struct SettingsScreenState {
  var theme: Theme = .light
  var notificationsEnabled: Bool = true
  var selectedLanguage: String = "en"
}
```

#### Independent Screen Updates

Each screen gets its own scoped store that only triggers updates for that specific screen:

```swift
struct HomeView: View {
  @ViewStore var homeState: HomeScreenState
  
  init(_ store: Store<AppState>) {
    _homeState = ViewStore(store.scope(\.homeScreen))
  }
  
  var body: some View {
    VStack {
      if homeState.isLoading {
        ProgressView()
      }
      
      List(homeState.posts) { post in
        PostRow(post: post)
      }
      
      Button("Load Posts") {
        $homeState.loadPosts()
      }
    }
  }
}

struct ProfileView: View {
  @ViewStore var profileState: ProfileScreenState
  
  init(_ store: Store<AppState>) {
    _profileState = ViewStore(store.scope(\.profileScreen))
  }
  
  var body: some View {
    VStack {
      if let profile = profileState.userProfile {
        ProfileCard(profile: profile)
      }
      
      Button("Edit Profile") {
        $profileState.startEditing()
      }
    }
  }
}
```

#### How It Works

The magic is in Swift's native value semantics:

```swift
extension Store<HomeScreenState> {
  func loadPosts() async {
    state.isLoading = true  // Only HomeView rebuilds
    // ... fetch posts
    state.posts = newPosts  // Only HomeView rebuilds
    state.isLoading = false // Only HomeView rebuilds
  }
}

extension Store<ProfileScreenState> {
  func startEditing() {
    state.isEditing = true  // Only ProfileView rebuilds
  }
}

extension Store<AppState> {
  func setUser(_ user: User) {
    state.user = user  // All views rebuild (global state change)
  }
  
  func updateHomeScreenDirectly() {
    // This WON'T trigger any updates because homeScreen is non-mutating
    state.homeScreen.posts.append(newPost)
    
    // To trigger updates, you need to scope to the substate:
    // homeStore.state.posts.append(newPost)  // This WILL trigger updates
  }
}
```

**Key insight**: When a property is non-mutating, changing it doesn't mutate the parent struct, so no updates are triggered at the parent level. Updates only happen when you scope directly to that substate.

#### Shared Dependencies

All screen stores share the same dependency injection context:

```swift
// All screens can access the same services
homeStore.di.apiService.fetchPosts()
profileStore.di.apiService.updateProfile(...)
settingsStore.di.userDefaults.save(...)
```

This approach provides optimal performance by ensuring that state changes in one screen don't cause unnecessary re-renders in other screens, while maintaining a unified global state and shared dependency context.

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
    .package(url: "https://github.com/dankinsoid/VDStore.git", from: "0.37.0")
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
