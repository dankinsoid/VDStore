import Combine
import SwiftUI

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
/// The `Store` class is isolated to main actor by @MainActor attribute, but the thread safety is not guaranteed. All the state changes should be done on the main thread.
@propertyWrapper
@dynamicMemberLookup
@MainActor
public struct Store<State> {

	/// The state of the store.
	public var state: State {
		_read { yield box.state }
		nonmutating _modify { yield &box.state }
	}

	/// Injected dependencies.
	public nonisolated var di: StoreDIValues {
		diModifier(StoreDIValues.current.with(store: self))
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
		StorePublisher(upstream: withDI(box))
	}

	/// An async sequence that emits when state changes.
	///
	/// This sequence supports dynamic member lookup so that you can pluck out a specific field in the state:
	///
	/// ```swift
	/// for await state in store.async.alert { ... }
	/// ```
	public nonisolated var async: StoreAsyncSequence<State> {
		StoreAsyncSequence(upstream: withDI(box))
	}

	private nonisolated let box: StoreBox<State>
	private nonisolated let _diModifier: (StoreDIValues) -> StoreDIValues
	private nonisolated var diModifier: (StoreDIValues) -> StoreDIValues {
		{ _diModifier($0.with(store: self)) }
	}

	public var wrappedValue: State {
		get { state }
		nonmutating set { state = newValue }
	}

	public nonisolated var projectedValue: Store<State> {
		get { self }
		set { self = newValue }
	}

	/// Creates a new `Store` with the initial state.
	public init(wrappedValue state: State) {
		self.init(state)
	}

	/// Creates a new `Store` with the initial state.
	public init(_ state: State) {
		self.init(box: StoreBox(state))
	}

	/// Creates a new `Store` with a closure to get and set the state.
//	public init(get: @escaping () -> State, set: @escaping (State) -> Void) {
//		self.init(box: StoreBox(get: get, set: set))
//	}

	init(
		box: StoreBox<State>,
		di: @escaping (StoreDIValues) -> StoreDIValues = { $0 }
	) {
		self.box = box
		_diModifier = di
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
//	public func scope<ChildState>(
//		get getter: @escaping (State) -> ChildState,
//		set setter: @escaping (inout State, ChildState) -> Void
//	) -> Store<ChildState> {
//		Store<ChildState>(
//			box: StoreBox<ChildState>(parent: box, get: getter, set: setter),
//			di: { [self] in diModifier($0) }
//		)
//	}

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
	public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
		Store<ChildState>(
			box: StoreBox<ChildState>(parent: box, keyPath: keyPath),
			di: { [self] in diModifier($0) }
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
	public subscript<ChildState>(
		dynamicMember keyPath: WritableKeyPath<State, ChildState>
	) -> Store<ChildState> {
		scope(keyPath)
	}

	/// Scopes the store to one that exposes child state.
	///
	/// This can be useful for deriving new stores to hand to child views in an application. For
	/// example:
	///
	/// ```swift
	/// class AppFeature {
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
	public subscript<ChildState>(
		dynamicMember keyPath: ReferenceWritableKeyPath<State, ChildState>
	) -> Store<ChildState> {
		scope(keyPath)
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
		di {
			$0.with(keyPath, value)
		}
	}

	/// Transforms the store's injected dependencies.
	/// - Parameters:
	///  - transform: A closure that transforms the store's dependencies.
	/// - Returns: A new store with the transformed dependencies.
	public func di(
		_ transform: @escaping (StoreDIValues) -> StoreDIValues
	) -> Store {
		Store(box: box) { [_diModifier] in
			transform(_diModifier($0))
		}
	}

	/// Transforms the store's injected dependencies.
	/// - Parameters:
	///  - transform: A closure that transforms the store's dependencies.
	/// - Returns: A new store with the transformed dependencies.
	public func transformDI(
		_ transform: @escaping (inout StoreDIValues) -> Void
	) -> Store {
		di {
			var result = $0
			transform(&result)
			return result
		}
	}

	/// Executes the given update operation without sending updates of the state changes.
	public func silently<T>(_ update: @MainActor () throws -> T) rethrows -> T {
		let currentNeedSendUpdate = box.root.publisher.needSendUpdate
		box.root.publisher.needSendUpdate = false
		defer {
			box.root.publisher.needSendUpdate = currentNeedSendUpdate
		}
		return try withDIValues(operation: update)
	}

	/// Sends an update.
	public func update() {
		box.root.publisher.sendUpdate()
	}

	public func withDIValues<T>(operation: () throws -> T) rethrows -> T {
		try StoreDIValues.$current.withValue(diModifier, operation: operation)
	}

	public func withDIValues<T>(operation: () async throws -> T) async rethrows -> T {
		try await StoreDIValues.$current.withValue(diModifier, operation: operation)
	}

	func sendUpdateIfInsideUpdateBatch() {
		box.root.publisher.sendUpdateIfInsideUpdateBatch()
	}

	private func changeState(_ operation: @MainActor (inout State) -> Void) {
		operation(&box.state)
	}
}

//public extension Store where State: MutableCollection, State.Element: Hashable, State.Index: Hashable {
//
//	subscript(index: State.Index, or defaultValue: State.Element) -> Store<State.Element> {
//		scope(\State[safe: index, or: defaultValue])
//	}
//}

public extension StoreDIValues {

	private var stores: [ObjectIdentifier: Any] {
		get { get(\.stores, or: [:]) }
		set { set(\.stores, newValue) }
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

private extension Store {

	nonisolated func withDI<P: Publisher>(_ publisher: P) -> AnyPublisher<P.Output, P.Failure> {
		DIPublisher(base: publisher, modifier: diModifier).eraseToAnyPublisher()
	}
}
