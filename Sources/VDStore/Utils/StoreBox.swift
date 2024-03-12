import Combine
import Foundation

struct StoreBox<Output>: Publisher {

	typealias Failure = Never

	var state: Output {
		get { getter() }
		nonmutating set { setter(newValue) }
	}

	let willSet: AnyPublisher<Void, Never>
	let startUpdate: () -> Void
	let endUpdate: () -> Void
	private let getter: () -> Output
	private let setter: (Output) -> Void
	private let valuePublisher: AnyPublisher<Output, Never>

	init(_ value: Output) {
		let rootBox = StoreRootBox(value)
		willSet = rootBox.willSetPublisher
		valuePublisher = rootBox.eraseToAnyPublisher()
		getter = { rootBox.state }
		setter = { rootBox.state = $0 }
		startUpdate = rootBox.startUpdate
		endUpdate = rootBox.endUpdate
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
		startUpdate = parent.startUpdate
		endUpdate = parent.endUpdate
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		valuePublisher.receive(subscriber: subscriber)
	}
}

private final class StoreRootBox<State>: Publisher {

	typealias Output = State
	typealias Failure = Never

	var state: State {
		willSet {
			if updatesCounter == 0 {
				if suspendAllSyncStoreUpdates {
					if asyncUpdatesCounter == 0 {
						suspendSyncUpdates()
					}
				} else {
					willSetSubject.send()
				}
			}
		}
		didSet {
			if updatesCounter == 0, asyncUpdatesCounter == 0 {
                didSetSubject.send()
			}
		}
	}

	var willSetPublisher: AnyPublisher<Void, Never> {
        willSetSubject.eraseToAnyPublisher()
	}

	private var updatesCounter = 0
	private var asyncUpdatesCounter = 0
	private let willSetSubject = PassthroughSubject<Void, Never>()
	private let didSetSubject = PassthroughSubject<Void, Never>()

	init(_ state: State) {
		self.state = state
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        didSetSubject
			.compactMap { [weak self] in self?.state }
			.prepend(state)
			.receive(subscriber: subscriber)
	}

	func startUpdate() {
		if updatesCounter == 0, asyncUpdatesCounter == 0 {
			willSetSubject.send()
		}
		updatesCounter &+= 1
	}

	func endUpdate() {
		updatesCounter &-= 1
		guard updatesCounter == 0 else { return }
        didSetSubject.send()

		if asyncUpdatesCounter > 0 {
            willSetSubject.send()
		}
	}

	private func suspendSyncUpdates() {
		startAsyncUpdate()
		DispatchQueue.main.async { [self] in
			endAsyncUpdate()
		}
	}

	private func startAsyncUpdate() {
		if asyncUpdatesCounter == 0 {
            willSetSubject.send()
		}
		asyncUpdatesCounter &+= 1
	}

	private func endAsyncUpdate() {
		asyncUpdatesCounter &-= 1
		if asyncUpdatesCounter == 0 {
            didSetSubject.send()
		}
	}
}
