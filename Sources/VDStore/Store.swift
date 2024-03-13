import Combine
import Foundation

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application:
///
/// ```swift
/// @main
/// struct MyApp: App {
///
///   @ViewStore var store = AppFeature.State()
///
///   var body: some Scene {
///     WindowGroup {
///       RootView($store)
///     }
///   }
/// }
/// ```
///
/// …and then use the ``scope(_ keyPath:)`` method to derive more focused stores that can be
/// passed to subviews.
///
/// ### Scoping
///
/// The most important operation defined on ``Store`` is the ``scope(get:set:)`` or ``scope(_ keyPath:)`` methods,
/// which allows you to transform a store into one that deals with child state. This is
/// necessary for passing stores to subviews that only care about a small portion of the entire
/// application's domain.
/// The store supports dynamic member lookup so that you can scope with a specific field in the state.
///
/// For example, if an application has a tab view at its root with tabs for activity, search, and
/// profile, then we can model the domain like this:
///
/// ```swift
/// struct AppFeature {
///   var activity: Activity.State
///   var profile: Profile.State
///   var search: Search.State
/// }
/// ```
///
/// We can construct a view for each of these domains by applying ``scope(_ keyPath:)`` to
/// a store that holds onto the full app domain in order to transform it into a store for each
/// subdomain:
///
/// ```swift
/// struct AppView: View {
///
///   @ViewStore state: AppFeature
///
///   init(_ store: Store<AppFeature>) {
///    	_state = ViewStore(store)
///   }
///
///   init() {
///     _state = ViewStore(AppFeature())
///   }
///
///   var body: some View {
///     TabView {
///       ActivityView(
///         $state.activity // same as $state.scope(\.activity)
///       )
///       .tabItem { Text("Activity") }
///
///       SearchView(
///         $state.search // same as $state.scope(\.search)
///       )
///       .tabItem { Text("Search") }
///
///       ProfileView(
///         $state.profile // same as $state.scope(\.profile)
///       )
///       .tabItem { Text("Profile") }
///     }
///   }
/// }
/// ```
///
/// ### Thread safety
///
/// The `Store` class is isolated to main thread by @MainActor attribute.
@propertyWrapper
@dynamicMemberLookup
@MainActor
public struct Store<State>: Sendable {

	/// The state of the store.
	public var state: State {
		get { box.state }
		nonmutating set { box.state = newValue }
	}

	/// Injected dependencies.
	public nonisolated var di: StoreDIValues {
		diModifier(StoreDIValues().with(store: self))
	}

	/// A publisher that emits when state changes.
	///
	/// This publisher supports dynamic member lookup so that you can pluck out a specific field in the state:
	///
	/// ```swift
	/// store.publisher.alert
	///   .sink { ... }
	/// ```
	public nonisolated var publisher: StorePublisher<State> {
		StorePublisher(upstream: box.eraseToAnyPublisher())
	}

    /// An async sequence that emits when state changes.
    ///
    /// This sequence supports dynamic member lookup so that you can pluck out a specific field in the state:
    ///
    /// ```swift
    /// for await state in store.async.alert { ... }
    /// ```
    public nonisolated var async: StoreAsyncSequence<State> {
        StoreAsyncSequence(upstream: box.eraseToAnyPublisher())
    }

	/// The publisher that emits before the state is going to be changed. Required by `SwiftUI`.
    nonisolated var willSet: AnyPublisher<Void, Never> {
		box.willSet.eraseToAnyPublisher()
	}

	private let box: StoreBox<State>
	private let diModifier: @Sendable (StoreDIValues) -> StoreDIValues

	public var wrappedValue: State {
		get { state }
		nonmutating set { state = newValue }
	}

	public nonisolated var projectedValue: Store<State> {
		get { self }
		set { self = newValue }
	}

	/// Creates a new `Store` with the initial state.
	public nonisolated init(wrappedValue state: State) {
		self.init(state)
	}

	/// Creates a new `Store` with the initial state.
	public nonisolated init(_ state: State) {
		self.init(box: StoreBox(state))
	}

    nonisolated init(
		box: StoreBox<State>,
		di: @escaping @Sendable (StoreDIValues) -> StoreDIValues = { $0 }
	) {
		self.box = box
		diModifier = di
	}

	/// Scopes the store to one that exposes child state.
	///
	/// This can be useful for deriving new stores to hand to child views in an application. For
	/// example:
	///
	/// ```swift
	/// struct AppFeature {
	///   var login: Login.State
	///   // ...
	/// }
	///
	/// // A store that runs the entire application.
	/// let store = Store(AppFeature())
	///
	/// // Construct a login view by scoping the store
	/// // to one that works with only login domain.
	/// LoginView(
	///   store.scope {
	///     $0.login
	///   } set: {
	///     $0.login = $1
	///   }
	/// )
	/// ```
	///
	/// Scoping in this fashion allows you to better modularize your application. In this case,
	/// `LoginView` could be extracted to a module that has no access to `AppFeature`.
	///
	/// - Parameters:
	///   - get: A closure that gets the child state from the parent state.
	///   - set: A closure that modifies the parent state from the child state.
	/// - Returns: A new store with its state transformed.
	public nonisolated func scope<ChildState>(
		get getter: @escaping (State) -> ChildState,
		set setter: @escaping (inout State, ChildState) -> Void
	) -> Store<ChildState> {
		Store<ChildState>(
			box: StoreBox<ChildState>(parent: box, get: getter, set: setter),
			di: { [self] in diModifier($0).with(store: self) }
		)
	}

	/// Scopes the store to one that exposes child state.
	///
	/// This can be useful for deriving new stores to hand to child views in an application. For
	/// example:
	///
	/// ```swift
	/// struct AppFeature {
	///   var login: Login.State
	///   // ...
	/// }
	///
	/// // A store that runs the entire application.
	/// let store = Store(AppFeature())
	///
	/// // Construct a login view by scoping the store
	/// // to one that works with only login domain.
	/// LoginView(
	///   store.scope(\.login)
	/// )
	/// ```
	///
	/// Scoping in this fashion allows you to better modularize your application. In this case,
	/// `LoginView` could be extracted to a module that has no access to `AppFeature`.
	///
	/// - Parameters:
	///   - keyPath: A writable key path from `State` to `ChildState`.
	/// - Returns: A new store with its state transformed.
	public nonisolated func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
		scope {
			$0[keyPath: keyPath]
		} set: {
			$0[keyPath: keyPath] = $1
		}
	}

	/// Scopes the store to one that exposes child state.
	///
	/// This can be useful for deriving new stores to hand to child views in an application. For
	/// example:
	///
	/// ```swift
	/// struct AppFeature {
	///   var login: Login.State
	///   // ...
	/// }
	///
	/// // A store that runs the entire application.
	/// let store = Store(AppFeature())
	///
	/// // Construct a login view by scoping the store
	/// // to one that works with only login domain.
	/// LoginView(
	///   store.login
	/// )
	/// ```
	///
	/// Scoping in this fashion allows you to better modularize your application. In this case,
	/// `LoginView` could be extracted to a module that has no access to `AppFeature`.
	///
	/// - Parameters:
	///   - keyPath: A writable key path from `State` to `ChildState`.
	/// - Returns: A new store with its state transformed.
	public nonisolated subscript<ChildState>(
		dynamicMember keyPath: WritableKeyPath<State, ChildState>
	) -> Store<ChildState> {
		scope(keyPath)
	}

	/// Injects the given value into the store's.
	/// - Parameters:
	///  - keyPath: A key path to the value in the store's dependencies.
	///  - value: The value to inject.
	/// - Returns: A new store with the injected value.
	public nonisolated func di<DIValue>(
		_ keyPath: WritableKeyPath<StoreDIValues, DIValue>,
		_ value: DIValue
	) -> Store {
		transformDI {
			$0.with(keyPath, value)
		}
	}

	/// Transforms the store's injected dependencies.
	/// - Parameters:
	///  - transform: A closure that transforms the store's dependencies.
	/// - Returns: A new store with the transformed dependencies.
	public nonisolated func transformDI(
		_ transform: @escaping (StoreDIValues) -> StoreDIValues
	) -> Store {
		Store(box: box) { [diModifier] in
			transform(diModifier($0))
		}
	}

	/// Transforms the store's injected dependencies.
	/// - Parameters:
	///  - transform: A closure that transforms the store's dependencies.
	/// - Returns: A new store with the transformed dependencies.
	public nonisolated func transformDI(
		_ transform: @escaping (inout StoreDIValues) -> Void
	) -> Store {
		transformDI {
			var result = $0
			transform(&result)
			return result
		}
	}

	/// Suspends the store from updating the UI until the block returns.
	public func update<T>(_ update: @MainActor () throws -> T) rethrows -> T {
        box.startUpdate()
		defer { box.endUpdate() }
		let result = try update()
		return result
	}
}

public extension Store where State: MutableCollection {

    nonisolated subscript(_ index: State.Index) -> Store<State.Element> {
		scope(index)
	}

    nonisolated func scope(_ index: State.Index) -> Store<State.Element> {
		scope {
			$0[index]
		} set: {
			$0[index] = $1
		}
	}
}

public var suspendAllSyncStoreUpdates = true

public extension StoreDIValues {

	private var stores: [ObjectIdentifier: Any] {
		get { self[\.stores] ?? [:] }
		set { self[\.stores] = newValue }
	}

	/// Injected store with the given state type.
	func store<T>(for type: T.Type) -> Store<T>? {
		stores[ObjectIdentifier(type)] as? Store<T>
	}

	/// Inject the given store as a dependency.
	func with<T>(
		store: Store<T>
	) -> StoreDIValues {
		transform(\.stores) { stores in
			stores[ObjectIdentifier(T.self)] = store
		}
	}
}
