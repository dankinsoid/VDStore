#if canImport(SwiftUI)
import Combine
import SwiftUI

/// `Store` wrapper for using in SwiftUI views. Updates the view when the state changes.
/// It can be created with initial state value or with a given store.
///
/// You can use `storeDIValues` `View`` modifiers to inject dependencies into the view stores.
@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
@MainActor
@propertyWrapper
@dynamicMemberLookup
public struct ViewStore<State>: DynamicProperty {

	private let property: Property
	@Environment(\.storeDIValues) private var transformDI

	public var wrappedValue: State {
		get { store.state }
		nonmutating set { store.state = newValue }
	}

	public var projectedValue: Store<State> {
		store
	}

	public var store: Store<State> {
		let result: Store<State>
		switch property {
		case let .stateObject(observable):
			result = observable.wrappedValue.store
		case let .store(store):
			result = store
		case let .state(state):
			result = state.wrappedValue
		}
		return result.di(transformDI)
	}

	public var binding: Binding<State> {
		projectedValue.binding
	}

	public init(_ store: Store<State>) {
		if store.di.isViewStore {
			property = .store(store)
		} else if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
			property = .state(
				SwiftUI.State(wrappedValue: store.di(\.isViewStore, true))
			)
		} else {
			property = .stateObject(
				StateObject(
					wrappedValue: Observable(store: store.di(\.isViewStore, true))
				)
			)
		}
	}

	public init(wrappedValue state: State) {
		self.init(Store(wrappedValue: state))
	}

	public subscript<LocalValue>(
		dynamicMember keyPath: WritableKeyPath<State, LocalValue>
	) -> Binding<LocalValue> {
		store.binding[dynamicMember: keyPath]
	}

	@MainActor
	private enum Property: DynamicProperty {

		case stateObject(StateObject<Observable>)
		case state(SwiftUI.State<Store<State>>)
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

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
public struct WithViewStore<State, Content: View>: View {

	public let content: (Store<State>) -> Content
	public var store: Store<State> { $state }
	@ViewStore private var state: State
	@Environment(\.storeDIValues) private var transformDI

	public init(_ store: Store<State>, @ViewBuilder content: @escaping (Store<State>) -> Content) {
		self.content = content
		_state = ViewStore(store)
	}

	public var body: some View {
		content(store.di(transformDI))
	}
}

extension StoreDIValues {

	var isViewStore: Bool {
		get { get(\.isViewStore, or: false) }
		set { set(\.isViewStore, newValue) }
	}
}

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
extension EnvironmentValues {

	private enum DIValueKey: EnvironmentKey {

		static let defaultValue: (StoreDIValues) -> StoreDIValues = { $0 }
	}

	var storeDIValues: (StoreDIValues) -> StoreDIValues {
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
}

@available(iOS 14.0, macOS 11.00, tvOS 14.0, watchOS 7.0, *)
public extension View {

	/// Injects the dependencies into the view stores.
	func storeDIValues(_ transform: @escaping (StoreDIValues) -> StoreDIValues) -> some View {
		transformEnvironment(\.storeDIValues) { current in
			current = { [current] dependencies in
				transform(current(dependencies))
			}
		}
	}

	/// Injects the dependencies into the view stores.
	func storeDIValues(_ dependencies: StoreDIValues) -> some View {
		storeDIValues {
			$0.merging(with: dependencies)
		}
	}

	/// Injects the dependencies into the view stores.
	func storeDIValue<D>(_ keyPath: WritableKeyPath<StoreDIValues, D>, _ value: D) -> some View {
		storeDIValues { deps in
			deps.with(keyPath, value)
		}
	}
}
#endif
