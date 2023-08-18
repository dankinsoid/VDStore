import Foundation
import Combine

@MainActor
@propertyWrapper
public struct Store<State> {
    
    @Ref public var state: State
    public let publisher: AnyPublisher<State, Never>
    public var dependencies: StoreDependencies
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
        let subject = CurrentValueSubject<State, Never>(state)
        self.init(
            state: Ref {
                subject.value
            } set: { state in
                subject.send(state)
            },
            publisher: subject
        )
    }
    
    public nonisolated init<P: Publisher>(
        state: Ref<State>,
        publisher: P,
        dependencies: StoreDependencies = StoreDependencies()
    ) where P.Output == State, P.Failure == Never {
        self.init(state: state, publisher: publisher, dependencies: dependencies, values: [:])
    }
    
    public nonisolated init(
        state: Ref<State>,
        dependencies: StoreDependencies = StoreDependencies()
    ) {
        let subject = PassthroughSubject<State, Never>()
        self.init(
            state: state,
            publisher: subject,
            dependencies: dependencies
        )
    }
    
    nonisolated init<P: Publisher>(
        state: Ref<State>,
        publisher: P,
        dependencies: StoreDependencies,
        values: [PartialKeyPath<Store>: Any]
    ) where P.Output == State, P.Failure == Never {
        self._state = state
        self.publisher = publisher.eraseToAnyPublisher()
        self.dependencies = dependencies
        self.values = values
    }
    
    public func scope<ChildState>(_ keyPath: WritableKeyPath<State, ChildState>) -> Store<ChildState> {
        Store<ChildState>(
            state: $state.scope(keyPath),
            publisher: publisher.map(keyPath),
            dependencies: dependencies
        )
    }
    
    public func value<Dependency>(
        _ keyPath: KeyPath<Store, Dependency>,
        _ value: Dependency
    ) -> Store {
        Store(
            state: $state,
            publisher: publisher,
            dependencies: dependencies,
            values: values.merging([keyPath: value]) { _, new in new }
        )
    }
    
    public func dependency<Dependency>(
        _ keyPath: KeyPath<StoreDependencies, Dependency>,
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
            state: $state,
            publisher: publisher,
            dependencies: transform(dependencies),
            values: values
        )
    }
    
    public func modify(_ modifier: (inout State) -> Void) {
        modifier(&state)
    }
    
    public subscript<Value>(_ keyPath: KeyPath<Store<State>, Value>) -> Value? {
        values[keyPath] as? Value
    }
}
