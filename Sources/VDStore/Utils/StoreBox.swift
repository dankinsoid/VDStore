import Combine
import Foundation

#if canImport(PerceptionCore)
import PerceptionCore
#endif
#if canImport(Observation)
import Observation
#endif

struct StoreBox<Output>: Publisher {

	typealias Failure = Never

	var state: Output {
		get { getter() }
		nonmutating set { setter(newValue) }
	}

	var willSet: AnyPublisher<Void, Never> { root.willSetPublisher }

	private let root: StoreRootBoxType
	private let getter: () -> Output
	private let setter: (Output) -> Void
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

	init<T>(
		parent: StoreBox<T>,
		get: @escaping (T) -> Output,
		set: @escaping (T, Output) -> Void
	) {
		let rootBox = StoreRootBoxRef {
			get(parent.state)
		} setter: { state in
			set(parent.state, state)
		}
		root = rootBox
		valuePublisher = rootBox
			.merge(with: parent.valuePublisher.dropFirst().map(get))
			.eraseToAnyPublisher()
		getter = { rootBox.state }
		setter = { rootBox.state = $0 }
	}

	init(
		get: @escaping () -> Output,
		set: @escaping (Output) -> Void
	) {
		let rootBox = StoreRootBoxRef(getter: get, setter: set)
		root = rootBox
		valuePublisher = rootBox.eraseToAnyPublisher()
		getter = { rootBox.state }
		setter = { rootBox.state = $0 }
	}

	func startUpdate() { root.startUpdate() }
	func endUpdate() { root.endUpdate() }
	func forceUpdate() { root.forceUpdate() }

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		valuePublisher.receive(subscriber: subscriber)
	}
}

private protocol StoreRootBoxType {

	var willSetPublisher: AnyPublisher<Void, Never> { get }
	func startUpdate()
	func endUpdate()
	func forceUpdate()
}

private class StoreRootBox<State>: StoreRootBoxType, Publisher {

	typealias Output = State
	typealias Failure = Never

	var _state: State
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
#if canImport(Observation)
		if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
			_$observationRegistrar = ObservationRegistrar()
		} else {
			#if canImport(PerceptionCore)
			_$observationRegistrar = PerceptionRegistrar()
			#else
		  _$observationRegistrar = MockObservationRegistrar()
			#endif
		}
#elseif canImport(PerceptionCore)
		_$observationRegistrar = PerceptionRegistrar()
#else
		_$observationRegistrar = MockObservationRegistrar()
#endif
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

private final class StoreRootBoxRef<State>: StoreRootBox<State> {

	private let getter: () -> Output
	private let setter: (Output) -> Void
	override var _state: State {
		get { getter() }
		set { setter(newValue) }
	}

	init(getter: @escaping () -> Output, setter: @escaping (Output) -> Void) {
		self.getter = getter
		self.setter = setter
		super.init(getter())
	}
}

private protocol ObservationRegistrarProtocol {
	func access<State>(box: StoreRootBox<State>)
	func willSet<State>(box: StoreRootBox<State>)
	func didSet<State>(box: StoreRootBox<State>)
	func withMutation<State, T>(box: StoreRootBox<State>, _ mutation: () throws -> T) rethrows -> T
}

#if canImport(Observation)
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
#endif

#if canImport(PerceptionCore)
extension StoreRootBox: Perceptible {}

extension PerceptionRegistrar: ObservationRegistrarProtocol {

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
#endif

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
