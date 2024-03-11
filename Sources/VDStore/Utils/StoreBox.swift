import Combine
import Foundation

struct StoreBox<Output>: Publisher {

	typealias Failure = Never

	var state: Output {
		get { getter() }
		nonmutating set { setter(newValue) }
	}

	let willSet: AnyPublisher<Void, Never>
	let beforeUpdate: () -> Void
	let afterUpdate: () -> Void
	private let getter: () -> Output
	private let setter: (Output) -> Void
	private let valuePublisher: AnyPublisher<Output, Never>

	init(_ value: Output) {
		let rootBox = StoreRootBox(value)
		willSet = rootBox.willSetPublisher
		valuePublisher = rootBox.eraseToAnyPublisher()
		getter = { rootBox.state }
		setter = { rootBox.state = $0 }
		beforeUpdate = rootBox.beforeUpdate
		afterUpdate = rootBox.afterUpdate
	}

	init<T>(
		parent: StoreBox<T>,
		get: @escaping (T) -> Output,
		set: @escaping (inout T, Output) -> Void
	) {
		valuePublisher = parent.valuePublisher.map(get).eraseToAnyPublisher()
		willSet = parent.willSet
		getter = { get(parent.getter()) }
		setter = {
			var state = parent.getter()
			set(&state, $0)
			parent.setter(state)
		}
		beforeUpdate = parent.beforeUpdate
		afterUpdate = parent.afterUpdate
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		valuePublisher.receive(subscriber: subscriber)
	}
}

private final class StoreRootBox<State>: Publisher {

	typealias Output = State
	typealias Failure = Never

	var state: State {
		get { subject.value }
		set {
			if suspendAllSyncStoreUpdates, updatesCounter == 0 {
				suspendSyncUpdates()
			} else if updatesCounter == 0 {
				willSet.send()
			}
			subject.value = newValue
		}
	}

	var willSetPublisher: AnyPublisher<Void, Never> { publisher(willSet) }

	private var updatesCounter = 0
	private let willSet = PassthroughSubject<Void, Never>()
	private let subject: CurrentValueSubject<State, Never>

	init(_ state: State) {
		subject = CurrentValueSubject(state)
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		publisher(subject).receive(subscriber: subscriber)
	}

	private func publisher<P: Publisher>(_ publisher: P) -> AnyPublisher<P.Output, P.Failure> {
		publisher.filter { [weak self] _ in
			self?.updatesCounter == 0
		}
		.eraseToAnyPublisher()
	}

	private func suspendSyncUpdates() {
		beforeUpdate()
		DispatchQueue.main.async { [self] in
			afterUpdate()
		}
	}

	func beforeUpdate() {
		if updatesCounter == 0 {
			willSet.send()
		}
		updatesCounter &+= 1
	}

	func afterUpdate() {
		updatesCounter &-= 1
		if updatesCounter == 0 {
			subject.value = state
		}
	}
}
