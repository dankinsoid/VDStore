import Combine
import Foundation

@MainActor
@propertyWrapper
public struct Store<State> {

    public var state: State {
        get { _publisher.stateRef.wrappedValue }
        nonmutating set { _publisher.stateRef.wrappedValue = newValue }
    }
	public var dependencies: StoreDependencies {
		_dependencies.with(store: self)
	}
    public nonisolated var publisher: AnyPublisher<State, Never> {
        _publisher.eraseToAnyPublisher()
    }
    public nonisolated var willSet: AnyPublisher<Void, Never> {
        _publisher.willSet.eraseToAnyPublisher()
    }

    private let _publisher: StorePublisher<State>
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
		self.init(
            publisher: StorePublisher(state),
            dependencies: StoreDependencies(),
            values: [:]
		)
	}

    nonisolated init(
		publisher: StorePublisher<State>,
		dependencies: StoreDependencies,
		values: [PartialKeyPath<Store>: Any]
    ) {
        _publisher = publisher
		_dependencies = dependencies
		self.values = values
	}

	public func scope<ChildState>(
		get getter: @escaping (State) -> ChildState,
		set setter: @escaping (inout State, ChildState) -> Void
	) -> Store<ChildState> {
		Store<ChildState>(
			publisher: StorePublisher<ChildState>(parent: _publisher, get: getter, set: setter),
			dependencies: dependencies,
            values: [:]
		)
	}

	public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
        scope {
            $0[keyPath: keyPath]
        } set: {
            $0[keyPath: keyPath] = $1
        }
	}

	public func property<Dependency>(
		_ keyPath: KeyPath<Store, Dependency>,
		_ value: Dependency
	) -> Store {
		Store(
			publisher: _publisher,
			dependencies: dependencies,
			values: values.merging([keyPath: value]) { _, new in new }
		)
	}

	public func dependency<Dependency>(
		_ keyPath: WritableKeyPath<StoreDependencies, Dependency>,
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
			publisher: _publisher,
			dependencies: transform(_dependencies),
			values: values
		)
	}

	public func transformDependency(
		_ transform: (inout StoreDependencies) -> Void
	) -> Store {
		var dependencies = _dependencies
		transform(&dependencies)
		return Store(
			publisher: _publisher,
			dependencies: dependencies,
			values: values
		)
	}

    public func update<T>(_ update: () async throws -> T) async rethrows -> T {
        let wasUpdating = _publisher.isUpdating.wrappedValue
        _publisher.isUpdating.wrappedValue = true
        let result = try await update()
        if !wasUpdating {
            _publisher.isUpdating.wrappedValue = false
            _publisher.send()
        }
        return result
    }

    public func update<T>(_ update: () throws -> T) rethrows -> T {
        let wasUpdating = _publisher.isUpdating.wrappedValue
        _publisher.isUpdating.wrappedValue = true
        let result = try update()
        if !wasUpdating {
            _publisher.isUpdating.wrappedValue = false
            _publisher.send()
        }
        return result
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
    
    func store<T>(for type: T.Type) -> Store<T>? {
        stores[ObjectIdentifier(type)] as? Store<T>
    }

	func store<T>(
		for type: T.Type,
		defaultForLive live: @autoclosure () -> Store<T>,
		test: @autoclosure () -> Store<T>? = nil,
		preview: @autoclosure () -> Store<T>? = nil
	) -> Store<T> {
        store(for: type) ?? defaultFor(
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
