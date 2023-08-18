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
    
    public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Ref<ChildState> {
        Ref<ChildState>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
    
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> Ref<T> {
        scope(keyPath)
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension Ref {
    
    public init(_ binding: Binding<State>) {
        self.init(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0 }
        )
    }
    
    public var binding: Binding<State> {
        Binding(get: getter, set: setter)
    }
}
#endif
