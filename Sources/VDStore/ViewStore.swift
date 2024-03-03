#if canImport(SwiftUI)
import Combine
import SwiftUI

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
@MainActor
@propertyWrapper
public struct ViewStore<State>: DynamicProperty {

	private let property: Property
	@Environment(\.storeDependencies) private var dependencies

	public var wrappedValue: State {
		get { projectedValue.state }
		set { projectedValue.state = newValue }
	}

	public var projectedValue: Store<State> {
		let result: Store<State>
		switch property {
		case let .stateObject(observable):
			result = observable.wrappedValue.store
		case let .store(store):
			result = store
		}
		return result
			.transformDependency {
				$0.merging(with: dependencies)
			}
	}

	public var binding: Binding<State> {
		projectedValue.binding
	}

	public init(store: Store<State>) {
		if store.dependencies.isViewStore {
			property = .store(store)
		} else {
			property = .stateObject(
				StateObject(
					wrappedValue: Observable(store: store.dependency(\.isViewStore, true))
				)
			)
		}
	}

	public init(wrappedValue state: State) {
		self.init(store: Store(wrappedValue: state))
	}

    @MainActor
    private enum Property: DynamicProperty {

        case stateObject(StateObject<Observable>)
        case store(Store<State>)
    }

	private final class Observable: ObservableObject {

		typealias ObjectWillChangePublisher = AnyPublisher<Void, Never>

		let store: Store<State>
        var objectWillChange: AnyPublisher<Void, Never> {
            store.willSet
        }

        init(store: Store<State>) {
            self.store = store
        }
	}
}

extension StoreDependencies {

	var isViewStore: Bool {
		self[\.isViewStore] ?? false
	}
}

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
extension EnvironmentValues {

	private enum DependencyKey: EnvironmentKey {

		static let defaultValue = StoreDependencies()
	}

	var storeDependencies: StoreDependencies {
		get { self[DependencyKey.self] }
		set { self[DependencyKey.self] = newValue }
	}
}

public extension Store {

	@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
	var viewStore: ViewStore<State> {
		ViewStore(store: self)
	}

	var binding: Binding<State> {
        Binding {
            state
        } set: {
            state = $0
        }
	}
}

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
public extension View {

	func storeDependencies(_ dependencies: StoreDependencies) -> some View {
		environment(\.storeDependencies, dependencies)
	}

    func storeDependencies(_ dependencies: @escaping (StoreDependencies) -> StoreDependencies) -> some View {
        transformEnvironment(\.storeDependencies) { deps in
            deps = dependencies(deps)
        }
    }
    
	func storeDependency<D>(_ keyPath: WritableKeyPath<StoreDependencies, D>, _ value: D) -> some View {
		transformEnvironment(\.storeDependencies) { deps in
			deps[keyPath: keyPath] = value
		}
	}
}
#endif
