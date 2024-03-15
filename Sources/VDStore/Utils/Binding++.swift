import SwiftUI

public extension Binding {

	func didSet(_ action: @escaping (Value, Value) -> Void) -> Binding {
		Binding(
			get: { wrappedValue },
			set: { newValue in
				let oldValue = wrappedValue
				wrappedValue = newValue
				action(oldValue, newValue)
			}
		)
	}

	func willSet(_ action: @escaping (Value, Value) -> Void) -> Binding {
		Binding(
			get: { wrappedValue },
			set: { newValue in
				let oldValue = wrappedValue
				action(oldValue, newValue)
				wrappedValue = newValue
			}
		)
	}
}
