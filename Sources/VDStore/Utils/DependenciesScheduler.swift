import Foundation
import Combine
import Dependencies

struct DependenciesPublisher<Base: Publisher>: Publisher {

    typealias Output = Base.Output
    typealias Failure = Base.Failure
    
    let base: Base
    let continuation: DependencyValues.Continuation
    let modifier: (inout DependencyValues) -> Void
    
    init(base: Base, modifier: @escaping (inout DependencyValues) -> Void) {
        self.base = base
        self.continuation = withEscapedDependencies { $0 }
        self.modifier = modifier
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Base.Failure == S.Failure, Base.Output == S.Input {
        base.receive(subscriber: DependenciesSubscriber(base: subscriber, continuation: continuation, modifier: modifier))
    }
}

struct DependenciesSubscriber<Base: Subscriber>: Subscriber {

    typealias Input = Base.Input
    typealias Failure = Base.Failure
    
    let base: Base
    let continuation: DependencyValues.Continuation
    let modifier: (inout DependencyValues) -> Void
    
    var combineIdentifier: CombineIdentifier { base.combineIdentifier }
    
    func receive(subscription: Subscription) {
        execute {
            base.receive(subscription: subscription)
        }
    }
    
    func receive(_ input: Base.Input) -> Subscribers.Demand {
        execute {
            base.receive(input)
        }
    }

    func receive(completion: Subscribers.Completion<Base.Failure>) {
        execute {
            base.receive(completion: completion)
        }
    }
    
    func execute<T>(_ operation: () -> T) -> T {
        continuation.yield {
            withDependencies(modifier, operation: operation)
        }
    }
}
