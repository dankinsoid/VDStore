import SwiftUI

extension Binding {

    public func `didSet`(_ action: @escaping (Value, Value) -> Void) -> Binding {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                let oldValue = wrappedValue
                wrappedValue = newValue
                action(oldValue, newValue)
            }
        )
    }

    public func `willSet`(_ action: @escaping (Value, Value) -> Void) -> Binding {
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
