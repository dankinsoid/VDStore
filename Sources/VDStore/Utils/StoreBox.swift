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
	let forceUpdate: () -> Void
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
		forceUpdate = rootBox.forceUpdateIfNeeded
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
		forceUpdate = parent.forceUpdate
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		valuePublisher.receive(subscriber: subscriber)
	}
}

private final class StoreRootBox<State>: Publisher {

	typealias Output = State
	typealias Failure = Never

	private var _state: State
	var state: State {
		get {
			_$observationRegistrar.access(box: self)
			return _state
		}
		set {
			if updatesCounter == 0 {
				if suspendAllSyncStoreUpdates {
					if asyncUpdatesCounter == 0 {
						suspendSyncUpdates()
					}
				} else {
					sendWillSet()
				}
			}

			_state = newValue

			if updatesCounter == 0, asyncUpdatesCounter == 0 {
				sendDidSet()
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
	private let _$observationRegistrar: ObservationRegistrarProtocol

	init(_ state: State) {
		_state = state
		if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
			_$observationRegistrar = ObservationRegistrar()
		} else {
			_$observationRegistrar = MockObservationRegistrar()
		}
	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		didSetSubject
			.compactMap { [weak self] in self?._state }
			.prepend(_state)
			.receive(subscriber: subscriber)
	}

	func startUpdate() {
		if updatesCounter == 0, asyncUpdatesCounter == 0 {
			sendWillSet()
		}
		updatesCounter &+= 1
	}

	func endUpdate() {
		updatesCounter &-= 1
		guard updatesCounter == 0 else { return }
		sendDidSet()

		if asyncUpdatesCounter > 0 {
			sendWillSet()
		}
	}

	func forceUpdateIfNeeded() {
		guard updatesCounter > 0 || asyncUpdatesCounter > 0 else { return }
		sendDidSet()
		sendWillSet()
	}

	private func suspendSyncUpdates() {
		startAsyncUpdate()
		DispatchQueue.main.async { [self] in
			endAsyncUpdate()
		}
	}

	private func startAsyncUpdate() {
		if asyncUpdatesCounter == 0 {
			sendWillSet()
		}
		asyncUpdatesCounter &+= 1
	}

	private func endAsyncUpdate() {
		asyncUpdatesCounter &-= 1
		if asyncUpdatesCounter == 0 {
			sendDidSet()
		}
	}

	private func sendWillSet() {
		willSetSubject.send()
		_$observationRegistrar.willSet(box: self)
	}

	private func sendDidSet() {
		didSetSubject.send()
		_$observationRegistrar.didSet(box: self)
	}
}

private protocol ObservationRegistrarProtocol {
	func access<State>(box: StoreRootBox<State>)
	func willSet<State>(box: StoreRootBox<State>)
	func didSet<State>(box: StoreRootBox<State>)
	func withMutation<State, T>(box: StoreRootBox<State>, _ mutation: () throws -> T) rethrows -> T
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension StoreRootBox: Observable {}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ObservationRegistrar: ObservationRegistrarProtocol {

	fileprivate func access<State>(box: StoreRootBox<State>) {
		access(box, keyPath: \.state)
	}

	fileprivate func willSet<Output>(box: StoreRootBox<Output>) {
		willSet(box, keyPath: \.state)
	}

	fileprivate func didSet<Output>(box: StoreRootBox<Output>) {
		didSet(box, keyPath: \.state)
	}

	fileprivate func withMutation<State, T>(box: StoreRootBox<State>, _ mutation: () throws -> T) rethrows -> T {
		try withMutation(of: box, keyPath: \.state, mutation)
	}
}

private struct MockObservationRegistrar: ObservationRegistrarProtocol {
	func access<State>(box: StoreRootBox<State>) {}
	func willSet<Output>(box: StoreRootBox<Output>) {}
	func didSet<Output>(box: StoreRootBox<Output>) {}
	func withMutation<State, T>(box: StoreRootBox<State>, _ mutation: () throws -> T) rethrows -> T {
		try mutation()
	}
}
