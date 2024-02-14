import Foundation

@dynamicMemberLookup
@propertyWrapper
public struct Ref<State> {

	private let getter: () -> State
	private let setter: (State) -> Void

	public var wrappedValue: State {
		get { getter() }
		nonmutating set { setter(newValue) }
	}

	public var projectedValue: Ref<State> {
		get { self }
		set { self = newValue }
	}

	public init(get: @escaping () -> State, set: @escaping (State) -> Void) {
		getter = get
		setter = set
	}

	public func scope<ChildState>(
		get childGet: @escaping (State) -> ChildState,
		set childSet: @escaping (inout State, ChildState) -> Void
	) -> Ref<ChildState> {
		Ref<ChildState>(
			get: { childGet(getter()) },
			set: {
				var state = getter()
				childSet(&state, $0)
				setter(state)
			}
		)
	}

	public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Ref<ChildState> {
		scope(
			get: { $0[keyPath: keyPath] },
			set: { $0[keyPath: keyPath] = $1 }
		)
	}

	public subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> Ref<T> {
		scope(keyPath)
	}
}

#if canImport(SwiftUI)
import SwiftUI

public extension Ref {

	init(_ binding: Binding<State>) {
		self.init(
			get: { binding.wrappedValue },
			set: { binding.wrappedValue = $0 }
		)
	}

	var binding: Binding<State> {
		Binding(get: getter, set: setter)
	}
}
#endif
