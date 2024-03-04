import Combine

struct StoreBox<Output>: Publisher {

	typealias Failure = Never

	var state: Output {
		get { getter() }
		nonmutating set { setter(newValue, true) }
	}

	var isUpdating: Bool { updatesCounter.wrappedValue > 0 }
	var willSet: AnyPublisher<Void, Never> { publisher(_willSet) }
	private let getter: () -> Output
	private let setter: (Output, _ sendWillSet: Bool) -> Void
	private let _willSet: PassthroughSubject<Void, Never>
	private let updatesCounter: Ref<UInt>
	private let valuePublisher: AnyPublisher<Output, Never>

	init(_ value: Output) {
		let willSet = PassthroughSubject<Void, Never>()
		_willSet = willSet

		let valuePublisher = CurrentValueSubject<Output, Never>(value)
		getter = { valuePublisher.value }
		setter = { value, sendWillSet in
			if sendWillSet {
				willSet.send()
			}
			valuePublisher.send(value)
		}
		self.valuePublisher = valuePublisher.eraseToAnyPublisher()

		var updatesCounter: UInt = 0
		self.updatesCounter = Ref {
			updatesCounter
		} set: {
			updatesCounter = $0
		}
	}

	init<T>(
		parent: StoreBox<T>,
		get: @escaping (T) -> Output,
		set: @escaping (inout T, Output) -> Void
	) {
		valuePublisher = parent.valuePublisher.map(get).eraseToAnyPublisher()
		_willSet = parent._willSet
		updatesCounter = parent.updatesCounter
		getter = { get(parent.getter()) }
		setter = {
			var state = parent.getter()
			set(&state, $0)
			parent.setter(state, $1)
		}
	}

	func beforeUpdate() {
		if updatesCounter.wrappedValue == 0 {
			_willSet.send()
		}
		updatesCounter.wrappedValue &+= 1
	}

	func afterUpdate() {
		updatesCounter.wrappedValue &-= 1
		if updatesCounter.wrappedValue == 0 {
			setter(getter(), false)
		}
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		publisher(valuePublisher).receive(subscriber: subscriber)
	}

	private func publisher<P: Publisher>(_ publisher: P) -> AnyPublisher<P.Output, P.Failure> {
		publisher.filter { [updatesCounter] _ in
			updatesCounter.wrappedValue == 0
		}
		.eraseToAnyPublisher()
	}
}
