import Combine
import Foundation

@MainActor
@propertyWrapper
public struct Store<State> {

	@Ref public var state: State
	public let publisher: AnyPublisher<State, Never>
	public var dependencies: StoreDependencies {
		_dependencies.with(store: self)
	}

	private var _dependencies: StoreDependencies
	private var values: [PartialKeyPath<Store>: Any]

	public var wrappedValue: State {
		get { state }
		nonmutating set { state = newValue }
	}

	public var projectedValue: Store<State> {
		get { self }
		set { self = newValue }
	}

	public nonisolated init(wrappedValue state: State) {
		self.init(state)
	}

	public nonisolated init(_ state: State) {
		let subject = CurrentValueSubject<State, Never>(state)
		self.init(
			state: Ref {
				subject.value
			} set: { state in
				subject.send(state)
			},
			publisher: subject
		)
	}

	public nonisolated init<P: Publisher>(
		state: Ref<State>,
		publisher: P,
		dependencies: StoreDependencies = StoreDependencies()
	) where P.Output == State, P.Failure == Never {
		self.init(state: state, publisher: publisher, dependencies: dependencies, values: [:])
	}

	/// - Warning: This initializer creates a `Store` instance that can observe mutations called through this store or its scopes.
	public nonisolated init(
		state: Ref<State>,
		dependencies: StoreDependencies = StoreDependencies()
	) {
		self.init(
			state: state,
			publisher: RefPublisher(ref: state),
			dependencies: dependencies
		)
	}

	nonisolated init<P: Publisher>(
		state: Ref<State>,
		publisher: P,
		dependencies: StoreDependencies,
		values: [PartialKeyPath<Store>: Any]
	) where P.Output == State, P.Failure == Never {
		_state = state
		self.publisher = publisher.eraseToAnyPublisher()
		_dependencies = dependencies
		self.values = values
	}

	public func scope<ChildState>(
		get getter: @escaping (State) -> ChildState,
		set setter: @escaping (inout State, ChildState) -> Void
	) -> Store<ChildState> {
		Store<ChildState>(
			state: $state.scope(get: getter, set: setter),
			publisher: publisher.map(getter),
			dependencies: dependencies
		)
	}

	public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
		Store<ChildState>(
			state: $state.scope(keyPath),
			publisher: publisher.map(keyPath),
			dependencies: dependencies
		)
	}

	public func property<Dependency>(
		_ keyPath: KeyPath<Store, Dependency>,
		_ value: Dependency
	) -> Store {
		Store(
			state: $state,
			publisher: publisher,
			dependencies: dependencies,
			values: values.merging([keyPath: value]) { _, new in new }
		)
	}

	public func dependency<Dependency>(
		_ keyPath: KeyPath<StoreDependencies, Dependency>,
		_ value: Dependency
	) -> Store {
		transformDependency {
			$0.with(keyPath, value)
		}
	}

	public func transformDependency(
		_ transform: (StoreDependencies) -> StoreDependencies
	) -> Store {
		Store(
			state: $state,
			publisher: publisher,
			dependencies: transform(dependencies),
			values: values
		)
	}

	public func transformDependency(
		_ transform: (inout StoreDependencies) -> Void
	) -> Store {
		var dependencies = dependencies
		transform(&dependencies)
		return Store(
			state: $state,
			publisher: publisher,
			dependencies: dependencies,
			values: values
		)
	}

	public func modify(_ modifier: (inout State) -> Void) {
		modifier(&state)
	}

	public subscript<Value>(_ keyPath: KeyPath<Store<State>, Value>) -> Value? {
		values[keyPath] as? Value
	}
}

public extension StoreDependencies {

	private var stores: [ObjectIdentifier: Any] {
		get { self[\.stores] ?? [:] }
		set { self[\.stores] = newValue }
	}

	func store<T>(
		for type: T.Type,
		defaultForLive live: @autoclosure () -> Store<T>,
		test: @autoclosure () -> Store<T>? = nil,
		preview: @autoclosure () -> Store<T>? = nil
	) -> Store<T> {
		(stores[ObjectIdentifier(type)] as? Store<T>) ?? defaultFor(
			live: live(),
			test: test(),
			preview: preview()
		)
	}

	func with<T>(
		store: Store<T>
	) -> StoreDependencies {
		transform(\.stores) { stores in
			stores[ObjectIdentifier(T.self)] = store
		}
	}
}
