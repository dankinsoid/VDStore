import Foundation

public protocol AsyncAction<State> {
    
    associatedtype State
    func mutate(state: borrowing StateWrapper<State>) async
}

public protocol Action<State>: AsyncAction {

    func mutate(state: inout State)
}

extension AsyncAction where Self: Action {
    
    public func mutate(state: borrowing StateWrapper<State>) async {
        mutate(state: &state.wrappedValue)
    }
}

@propertyWrapper
public struct StateWrapper<State>: ~Copyable {

    public var wrappedValue: State {
        get { get() }
        nonmutating set { set(newValue) }
    }
    private let get: () -> State
    private let set: (State) -> Void
}

public struct SomeAction: AsyncAction {
    
    public struct State {
        public var someString = ""
        public var someInt = 0
    }
    
    public func mutate(state: borrowing StateWrapper<State>) async {
        
    }
}

public struct BindableAction<State>: Action {
    
    public typealias State = State
    public let action: (inout State) -> Void

    public init(action: @escaping (inout State) -> Void) {
        self.action = action
    }

    public func mutate(state: inout State) {
        action(&state)
    }
}
