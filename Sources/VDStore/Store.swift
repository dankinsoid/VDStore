import Combine
import Foundation

@MainActor
@propertyWrapper
public struct Store<State> {

    public var state: State {
        get { _publisher.state }
        nonmutating set {
            if suspendAllSyncStoreUpdates, !_publisher.isUpdating {
                suspendSyncUpdates()
            }
            _publisher.state = newValue
        }
    }

    public var di: StoreDIValues {
        _dependencies.with(store: self)
    }

    public nonisolated var publisher: AnyPublisher<State, Never> {
        _publisher.eraseToAnyPublisher()
    }
    public nonisolated var willSet: AnyPublisher<Void, Never> {
        _publisher.willSet.eraseToAnyPublisher()
    }

    private let _publisher: StorePublisher<State>
	private var _dependencies: StoreDIValues

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
            di: StoreDIValues()
		)
	}

    nonisolated init(
		publisher: StorePublisher<State>,
        di: StoreDIValues
    ) {
        _publisher = publisher
		_dependencies = di
	}

	public func scope<ChildState>(
		get getter: @escaping (State) -> ChildState,
		set setter: @escaping (inout State, ChildState) -> Void
	) -> Store<ChildState> {
		Store<ChildState>(
			publisher: StorePublisher<ChildState>(parent: _publisher, get: getter, set: setter),
            di: di
		)
	}

	public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
        scope {
            $0[keyPath: keyPath]
        } set: {
            $0[keyPath: keyPath] = $1
        }
	}

	public func di<DIValue>(
		_ keyPath: WritableKeyPath<StoreDIValues, DIValue>,
		_ value: DIValue
	) -> Store {
		transformDI {
			$0.with(keyPath, value)
		}
	}

	public func transformDI(
		_ transform: (StoreDIValues) -> StoreDIValues
	) -> Store {
		Store(
			publisher: _publisher,
            di: transform(_dependencies)
		)
	}

	public func transformDI(
		_ transform: (inout StoreDIValues) -> Void
	) -> Store {
		var dependencies = _dependencies
		transform(&dependencies)
		return Store(
			publisher: _publisher,
            di: dependencies
		)
	}

    /// Suspends the store from updating the UI until the block returns.
    public func update<T>(_ update: () throws -> T) rethrows -> T {
        if !suspendAllSyncStoreUpdates, !_publisher.isUpdating {
            defer { _publisher.afterUpdate() }
            _publisher.beforeUpdate()
        }
        let result = try update()
        return result
    }

    /// Suspends the store from updating the UI while all synchronous operations are being performed.
    public func suspendSyncUpdates() {
        _publisher.beforeUpdate()
        DispatchQueue.main.async { [_publisher] in
            _publisher.afterUpdate()
        }
    }
}

public var suspendAllSyncStoreUpdates = true

extension StoreDIValues {
    
    private var stores: [ObjectIdentifier: Any] {
        get { self[\.stores] ?? [:] }
        set { self[\.stores] = newValue }
    }
    
    public func store<T>(for type: T.Type) -> Store<T>? {
        stores[ObjectIdentifier(type)] as? Store<T>
    }

    public func store<T>(
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

    public func with<T>(
		store: Store<T>
	) -> StoreDIValues {
		transform(\.stores) { stores in
			stores[ObjectIdentifier(T.self)] = store
		}
	}
}
