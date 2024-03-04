import Foundation
import Combine

/// A publisher of store state.
@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {
    
    public typealias Output = State
    public typealias Failure = Never
    
    let upstream: AnyPublisher<State, Never>
    
    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        upstream.receive(subscriber: subscriber)
    }
    
    /// Returns the resulting publisher of a given key path.
    public subscript<Value: Equatable>(
        dynamicMember keyPath: KeyPath<State, Value>
    ) -> StorePublisher<Value> {
        StorePublisher<Value>(upstream: upstream.map(keyPath).removeDuplicates().eraseToAnyPublisher())
    }

    /// Returns the resulting publisher of a given key path.
    @_disfavoredOverload
    public subscript<Value>(
        dynamicMember keyPath: KeyPath<State, Value>
    ) -> StorePublisher<Value> {
        StorePublisher<Value>(upstream: upstream.map(keyPath).eraseToAnyPublisher())
    }
}
