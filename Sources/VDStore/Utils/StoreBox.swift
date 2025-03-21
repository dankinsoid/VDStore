@preconcurrency import Combine
import Foundation

struct StoreBox<Output>: Publisher, Sendable {

	typealias Failure = Never

	var state: Output {
		get { getter() }
		nonmutating set { setter(newValue) }
	}

	var willSet: AnyPublisher<Void, Never> { root.willSetPublisher }

	private let root: StoreRootBoxType
	private let getter: @Sendable () -> Output
	private let setter: @Sendable (Output) -> Void
	private let valuePublisher: AnyPublisher<Output, Never>

	init(_ value: Output) {
		let rootBox = StoreRootBox(value)
		root = rootBox
		valuePublisher = rootBox.eraseToAnyPublisher()
		getter = { rootBox.state }
		setter = { rootBox.state = $0 }
	}

	init<T>(
		parent: StoreBox<T>,
		get: @escaping (T) -> Output,
		set: @escaping (inout T, Output) -> Void
	) {
		root = parent.root
		valuePublisher = parent.valuePublisher.map(get).eraseToAnyPublisher()
		getter = { get(parent.getter()) }
		setter = {
			var state = parent.getter()
			set(&state, $0)
			parent.setter(state)
		}
	}

	func startUpdate() { root.startUpdate() }
	func endUpdate() { root.endUpdate() }
	func forceUpdate() { root.forceUpdate() }

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		valuePublisher.receive(subscriber: subscriber)
	}
}

private protocol StoreRootBoxType: Sendable {

	var willSetPublisher: AnyPublisher<Void, Never> { get }
	func startUpdate()
	func endUpdate()
	func forceUpdate()
}

private final class StoreRootBox<State>: StoreRootBoxType, Publisher, @unchecked Sendable {

	typealias Output = State
	typealias Failure = Never

	private var _state: State
	var state: State {
		get {
			checkStateThread()
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

	func forceUpdate() {
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

private func checkStateThread() {
	threadCheck(message:
		"""
		Store state was accessed on a non-main thread. …

		The "Store" struct is not thread-safe, and so all interactions with an instance of \
		"Store" (including all of its scopes and derived view stores) must be done on the main \
		thread.
		"""
	)
}
