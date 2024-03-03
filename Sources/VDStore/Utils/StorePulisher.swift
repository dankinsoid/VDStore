import Combine

final class StorePublisher<Output>: Publisher {

	typealias Failure = Never

    let stateRef: Ref<Output>
    let willSet: PassthroughSubject<Void, Never>
    let isUpdating: Ref<Bool>
    private let valuePublisher: AnyPublisher<Output, Never>

    init(_ value: Output) {
        let willSet = PassthroughSubject<Void, Never>()
        self.willSet = willSet

        let valuePublisher = CurrentValueSubject<Output, Never>(value)
        stateRef = Ref {
            valuePublisher.value
        } set: { value in
            willSet.send()
            valuePublisher.send(value)
        }
        self.valuePublisher = valuePublisher.eraseToAnyPublisher()

        var isUpdating = false
        self.isUpdating = Ref {
            isUpdating
        } set: {
            isUpdating = $0
        }
    }

    init<T>(
        parent: StorePublisher<T>,
        get getter: @escaping (T) -> Output,
        set setter: @escaping (inout T, Output) -> Void
    ) {
        valuePublisher = parent.valuePublisher.map(getter).eraseToAnyPublisher()
        willSet = parent.willSet
        isUpdating = parent.isUpdating
        stateRef = parent.stateRef.scope(get: getter, set: setter)
    }

    func send() {
        let value = stateRef.wrappedValue
        if !isUpdating.wrappedValue {
            stateRef.wrappedValue = value
        }
    }

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        valuePublisher.filter { [isUpdating] _ in
            !isUpdating.wrappedValue
        }
        .receive(subscriber: subscriber)
	}
}
