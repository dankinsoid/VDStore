import Combine

struct RefPublisher<Output>: Publisher {
    
    typealias Failure = Never
    
    let ref: Ref<Output>
    let publisher = PassthroughSubject<Output, Never>()
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Output == S.Input {
        publisher
            .prepend(ref.wrappedValue)
            .receive(subscriber: subscriber)
    }
}
