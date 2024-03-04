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
/// The most important operation defined on ``Store`` is the ``scope(get:set:)`` or ``scope(_ keyPayh:)`` method,
/// which allows you to transform a store into one that deals with child state. This is
/// necessary for passing stores to subviews that only care about a small portion of the entire
/// application's domain.
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
///         $state.scope(\.activity)
///       )
///       .tabItem { Text("Activity") }
///
///       SearchView(
///         $state.scope(\.search)
///       )
///       .tabItem { Text("Search") }
///
///       ProfileView(
///         $state.scope(\.profile)
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
@MainActor
@propertyWrapper
public struct Store<State> {

	/// The state of the store.
	public var state: State {
		get { box.state }
		nonmutating set {
			if suspendAllSyncStoreUpdates, !box.isUpdating {
				suspendSyncUpdates()
			}
			box.state = newValue
		}
	}

	/// Injected dependencies.
	public var di: StoreDIValues {
		diStorage.with(store: self)
	}

	/// A publisher that emits when state changes.
	///
	/// This publisher supports dynamic member lookup so that you can pluck out a specific field in
	/// the state:
	///
	/// ```swift
	/// store.publisher.alert
	///   .sink { ... }
	/// ```
	public nonisolated var publisher: StorePublisher<State> {
		StorePublisher(upstream: box.eraseToAnyPublisher())
	}

	/// The publisher that emits before the state is going to be changed. Required by `SwiftUI`.
    nonisolated var willSet: AnyPublisher<Void, Never> {
		box.willSet.eraseToAnyPublisher()
	}

	private let box: StoreBox<State>
	private var diStorage: StoreDIValues

	public var wrappedValue: State {
		get { state }
		nonmutating set { state = newValue }
	}

	public var projectedValue: Store<State> {
		get { self }
		set { self = newValue }
	}

	/// Creates a new `Store` with the initial state.
	public nonisolated init(wrappedValue state: State) {
		self.init(state)
	}

	/// Creates a new `Store` with the initial state.
	public nonisolated init(_ state: State) {
		self.init(
            box: StoreBox(state),
			di: StoreDIValues()
		)
	}

	nonisolated init(
		box: StoreBox<State>,
		di: StoreDIValues
	) {
        self.box = box
		diStorage = di
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
	///   store.scope(state: \.login)
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
	public func scope<ChildState>(
		get getter: @escaping (State) -> ChildState,
		set setter: @escaping (inout State, ChildState) -> Void
	) -> Store<ChildState> {
		Store<ChildState>(
            box: StoreBox<ChildState>(parent: box, get: getter, set: setter),
			di: di
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
	///   store.scope(state: \.login)
	/// )
	/// ```
	///
	/// Scoping in this fashion allows you to better modularize your application. In this case,
	/// `LoginView` could be extracted to a module that has no access to `AppFeature`.
	///
	/// - Parameters:
	///   - state: A writable key path from `State` to `ChildState`.
	/// - Returns: A new store with its state transformed.
	public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
		scope {
			$0[keyPath: keyPath]
		} set: {
			$0[keyPath: keyPath] = $1
		}
	}

	/// Injects the given value into the store's.
	/// - Parameters:
	///  - keyPath: A key path to the value in the store's dependencies.
	///  - value: The value to inject.
	/// - Returns: A new store with the injected value.
	public func di<DIValue>(
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
	public func transformDI(
		_ transform: (StoreDIValues) -> StoreDIValues
	) -> Store {
		Store(box: box, di: transform(diStorage))
	}

	/// Transforms the store's injected dependencies.
	/// - Parameters:
	///  - transform: A closure that transforms the store's dependencies.
	/// - Returns: A new store with the transformed dependencies.
	public func transformDI(
		_ transform: (inout StoreDIValues) -> Void
	) -> Store {
		var dependencies = diStorage
		transform(&dependencies)
		return Store(box: box, di: dependencies)
	}

	/// Suspends the store from updating the UI until the block returns.
	public func update<T>(_ update: () throws -> T) rethrows -> T {
		if !suspendAllSyncStoreUpdates, !box.isUpdating {
			defer { box.afterUpdate() }
			box.beforeUpdate()
		}
		let result = try update()
		return result
	}

	/// Suspends the store from updating the UI while all synchronous operations are being performed.
	public func suspendSyncUpdates() {
		box.beforeUpdate()
		DispatchQueue.main.async { [box] in
			box.afterUpdate()
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
