import Combine
import Foundation

struct StoreBox<Output>: Publisher {

	typealias Failure = Never

	var state: Output {
		_read { yield ref.state }
		nonmutating _modify { yield &ref.state }
	}

	let root: StoreRootBoxType
	private let ref: any StateRef<Output>
	let valuePublisher: AnyPublisher<Output, Never>

	init(_ value: Output) {
		let rootBox = StoreRootBox(value)
		root = rootBox
		valuePublisher = rootBox
			.publisher
			.map { rootBox._state }
			.eraseToAnyPublisher()
		ref = rootBox
	}

	init<T>(
		parent: StoreBox<T>,
		keyPath: WritableKeyPath<T, Output>
	) {
		root = parent.root
		let ref = KeyPathRef(base: parent.ref, keyPath: keyPath)
		valuePublisher = parent.valuePublisher.map { _ in ref.state } .eraseToAnyPublisher()
		self.ref = ref
	}

//	init(
//		get: @escaping () -> Output,
//		set: @escaping (Output) -> Void
//	) {
//		let rootBox = StoreRootBoxRef(getter: get, setter: set)
//		root = rootBox
//		valuePublisher = rootBox.eraseToAnyPublisher()
//		ref = rootBox
//	}

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		valuePublisher.receive(subscriber: subscriber)
	}
}

protocol StoreRootBoxType {

	var publisher: StoreUpdatesPublisher { get }
}

protocol StateRef<State> {

	associatedtype State
	var state: State { get nonmutating set }
}

final class StateBox<State>: StateRef {

	var state: State

	init(_ state: State) {
		self.state = state
	}
}

final class KeyPathRef<Root, State>: StateRef {

	var state: State {
		_read { yield base.state[keyPath: keyPath] }
		_modify {
			yield &base.state[keyPath: keyPath]
		}
	}
	let base: any StateRef<Root>
	let keyPath: WritableKeyPath<Root, State>
	
	init(base: any StateRef<Root>, keyPath: WritableKeyPath<Root, State>) {
		self.base = base
		self.keyPath = keyPath
	}
}

extension StoreRootBoxType where Self: Publisher, Failure == Never {

	var valuePublisher: AnyPublisher<Void, Never> {
		map { _ in () }.eraseToAnyPublisher()
	}
}

private protocol ScopPublisherType: AnyObject {

	func willSet()
	func didSet(force: Bool)
}

private final class ScopePublisher<Output>: ScopPublisherType {

	typealias Failure = Never

	let getter: () -> Output
	private var updates: [UUID: AccessList.Context] = [:]
	let publisher = StoreUpdatesPublisher()

	init(
		getter: @escaping () -> Output
	) {
		self.getter = getter
	}

	func willSet() {
		
	}

	func didSet(force: Bool) {
		
	}
}

final class StoreUpdatesPublisher: Publisher {

	typealias Failure = Never
	typealias Output = Void
	private var children: [ObjectIdentifier: ScopPublisherType] = [:]

	@inline(__always)
	func willGet() {
		checkStateThread()
	}

	@inline(__always)
	func willSet() {
		if needSendUpdate, asyncUpdatesCounter == 0 {
			suspendSyncUpdates()
		}
	}

	@inline(__always)
	func didSet() {
		if needSendUpdate, asyncUpdatesCounter == 0 {
			sendDidSet()
		}
	}

	var force = false
	var needSendUpdate = true
	private var asyncUpdatesCounter = 0
	private let didSetSubject = PassthroughSubject<Void, Never>()

	func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		didSetSubject
			.prepend(())
			.receive(subscriber: subscriber)
	}

	func sendUpdate() {
		force = true
		guard asyncUpdatesCounter <= 0 else { return }
		sendWillSet()
		sendDidSet()
	}

	func sendUpdateIfInsideUpdateBatch() {
		guard asyncUpdatesCounter > 0 else { return }
		sendDidSet()
		sendWillSet()
	}

	fileprivate func add(child: ScopPublisherType) -> AnyCancellable {
		let id = ObjectIdentifier(child)
		children[id] = child
		return AnyCancellable { [weak self] in
			self?.children[id] = nil
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
		for (_, child) in children {
			child.willSet()
		}
	}

	private func sendDidSet() {
		didSetSubject.send()
		for (_, child) in children {
			child.didSet(force: force)
		}
		force = false
	}
}

private class StoreRootBox<State>: StoreRootBoxType, StateRef {

	var _state: State
	let publisher = StoreUpdatesPublisher()

	var state: State {
		get {
			publisher.willGet()
			return _state
		}
		set {
			publisher.willSet()
			defer { publisher.didSet() }
			_state = newValue
		}
	}

	init(_ state: State) {
		_state = state
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
