#if canImport(SwiftUI)
import Combine
import SwiftUI
import Dependencies

/// `Store` wrapper for using in SwiftUI views. Updates the view when the state changes.
/// It can be created with initial state value or with a given store.
///
/// You can use `storeDIValues` `View`` modifiers to inject dependencies into the view stores.
@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
@MainActor
@propertyWrapper
public struct ViewStore<State>: DynamicProperty {

	private let property: Property
	@Environment(\.storeDIValues) private var transformDI

	public var wrappedValue: State {
		get { projectedValue.state }
		nonmutating set { projectedValue.state = newValue }
	}

	public var projectedValue: Store<State> {
		let result: Store<State>
		switch property {
		case let .stateObject(observable):
			result = observable.wrappedValue.store
		case let .store(store):
			result = store
		}
		return result.transformDependency(transformDI)
	}

	public var binding: Binding<State> {
		projectedValue.binding
	}

	public init(store: Store<State>) {
		if store.di.isViewStore {
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

extension DependencyValues {

	var isViewStore: Bool {
        get { self[IsViewStoreKey.self] }
        set { self[IsViewStoreKey.self] = newValue }
	}

    private enum IsViewStoreKey: DependencyKey {

        static let liveValue = false
    }
}

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
extension EnvironmentValues {

	private enum DIValueKey: EnvironmentKey {

		static let defaultValue: (inout DependencyValues) -> Void = { _ in }
	}

	var storeDIValues: (inout DependencyValues) -> Void {
		get { self[DIValueKey.self] }
		set { self[DIValueKey.self] = newValue }
	}
}

public extension Store {

	/// SwiftUI binding to store's state.
	var binding: Binding<State> {
		Binding {
			state
		} set: {
			state = $0
		}
	}
    
    /// SwiftUI environment values. Available in SwiftUI view hierarchy.
    var env: EnvironmentValues {
        Environment(\.self).wrappedValue
    }
}

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
public extension View {

	/// Injects the dependencies into the view stores.
	func transformStoreDependency(_ transform: @escaping (inout DependencyValues) -> Void) -> some View {
		transformEnvironment(\.storeDIValues) { current in
			current = { [current] dependencies in
                current(&dependencies)
				transform(&dependencies)
			}
		}
	}

	/// Injects the dependencies into the view stores.
	func storeDependency<D>(_ keyPath: WritableKeyPath<DependencyValues, D>, _ value: D) -> some View {
        transformStoreDependency { deps in
            deps[keyPath: keyPath] = value
		}
	}
}
#endif
