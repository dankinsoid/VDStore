import Combine
@testable import VDStore
import XCTest

@MainActor
final class VDStoreTests: XCTestCase {

	/// Test that initializing a Store with a given state sets the initial state correctly.
	func testInitialState() {
		let initialCounter = Counter(counter: 10)
		let store = Store(initialCounter)
		XCTAssertEqual(store.state.counter, 10)
	}

	/// Test that a state mutation updates the state as expected.
	func testStateMutation() {
		let store = Store(Counter())
		store.add()

		XCTAssertEqual(store.state.counter, 1)
	}

	/// Test dependency injection, ensuring that a service or di is correctly injected into a Store.
	func testDependencyInjection() {
		let service: SomeService = MockSomeService()
		let store = Store(Counter()).di(\.someService, service)

		XCTAssert(store.di.someService === service)
	}

	/// Test that scoped stores correctly inherit dependencies from their parent.
	func testScopedStoreInheritsDependencies() {
		let service: SomeService = MockSomeService()
		let parentStore = Store(Counter()).di(\.someService, service)
		let childStore = parentStore.counter
		XCTAssert(parentStore.di.someService === service)
		XCTAssert(childStore.di.someService === service)
	}

	/// Test that a Store can use a mock di correctly.
	func testMockDIValue() {
		let mockService = MockSomeService()
		let store = Store(Counter()).di(\.someService, mockService)

		XCTAssert(store.di.someService is MockSomeService)
	}

	/// Test that state mutations are thread-safe.
	func testThreadSafety() async {
		let store = Store(Counter())
		let isMainThread = await Task.detached {
			await store.check {
				Thread.isMainThread
			}
		}.value
		XCTAssertEqual(isMainThread, true)
	}

	func testTasksCancel() async {
		let store = Store(Counter())
		let id = "id"
		let value = await store.task(id: id) {
			for i in 0 ..< 10 {
				guard !Task.isCancelled else { return i }
				if i == 5 {
					await store.cancel(id: id)
				}
			}
			return 10
		}
		.value
		XCTAssertEqual(value, 6)
	}

	func testUpdate() {
		let store = Store(Counter())
		let publisher = store.publisher
		var count = 0
		let cancellable = publisher
			.sink { _ in
				count += 1
			}
		cancellable.store(in: &store.di.cancellableSet)
		store.update {
			for _ in 0 ..< 10 {
				store.add()
			}
		}
		XCTAssertEqual(store.state.counter, 10)
		XCTAssertEqual(count, 2)
	}

	#if swift(>=5.9)
	/// Test that the publisher property of a Store sends updates when the state changes.
	func testPublisherUpdates() async {
		let initialCounter = Counter(counter: 0)
		let store = Store(initialCounter)
		let expectation = expectation(description: "State updated")

		store.publisher.sink { newState in
			if newState.counter == 1 {
				expectation.fulfill()
				store.di.cancellableSet = []
			}
		}
		.store(in: &store.di.cancellableSet)

		store.add()
		await fulfillment(of: [expectation], timeout: 0.1)
	}

	func testTasksMacroCancel() async {
		let store = Store(Counter())
		let value = await store.asyncTask()
		XCTAssertEqual(value, 6)
	}

	func testNumberOfUpdates() async {
		let store = Store(Counter())
		let publisher = store.publisher
		var updatesCount = 0
		var willSetCount = 0
		let expectation = expectation(description: "Counter")
		publisher
			.sink { i in
				updatesCount += 1
				if i.counter == 10 {
					expectation.fulfill()
					store.di.cancellableSet = []
				}
			}
			.store(in: &store.di.cancellableSet)
		store.willSet
			.sink { _ in
				willSetCount += 1
			}
			.store(in: &store.di.cancellableSet)
		for _ in 0 ..< 10 {
			store.add()
		}
		XCTAssertEqual(willSetCount, 1)
		XCTAssertEqual(updatesCount, 1)
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updatesCount, 2)
	}

	func testOnChange() async {
		let expectation = expectation(description: "Counter")
		let store = Store(Counter()).onChange(of: \.counter) { _, _, state in
			state.counter += 1
		}
		store.add()
		DispatchQueue.main.async {
			expectation.fulfill()
		}
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(store.state.counter, 2)
	}

	func testSyncUpdateInAsyncUpdate() async {
		let store = Store(Counter())
		let publisher = store.publisher
		var updatesCount = 0
		var willSetCount = 0
		let expectation = expectation(description: "Counter")
		publisher
			.sink { i in
				updatesCount += 1
				if i.counter == 10 {
					expectation.fulfill()
					store.di.cancellableSet = []
				}
			}
			.store(in: &store.di.cancellableSet)
		store.willSet
			.sink { _ in
				willSetCount += 1
			}
			.store(in: &store.di.cancellableSet)
		store.add()
		store.update {
			for _ in 0 ..< 8 {
				store.add()
			}
		}
		XCTAssertEqual(updatesCount, 2)
		store.add()
		XCTAssertEqual(willSetCount, 2)
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updatesCount, 3)
	}

	func testAsyncUpdateInSyncUpdate() async {
		let store = Store(Counter())
		let publisher = store.publisher
		var updatesCount = 0
		var willSetCount = 0
		let expectation = expectation(description: "Counter")
		publisher
			.sink { i in
				updatesCount += 1
				if i.counter == 10 {
					expectation.fulfill()
					store.di.cancellableSet = []
				}
			}
			.store(in: &store.di.cancellableSet)
		store.willSet
			.sink { _ in
				willSetCount += 1
			}
			.store(in: &store.di.cancellableSet)
		store.update {
			store.add()
			for _ in 0 ..< 8 {
				store.add()
			}
			store.add()
		}
		XCTAssertEqual(willSetCount, 1)
		XCTAssertEqual(updatesCount, 2)
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updatesCount, 2)
	}
	#endif
}

struct Counter: Equatable {

	var counter = 0
}

extension Store<Counter> {

	func add() {
		state.counter += 1
	}

	func check<T>(_ operation: () -> T) -> T {
		operation()
	}
}

#if swift(>=5.9)
@Actions
extension Store<Counter> {

	func asyncTask() async -> Int {
		for i in 0 ..< 10 {
			guard !Task.isCancelled else { return i }
			if i == 5 {
				cancel(Self.asyncTask)
			}
		}
		return 10
	}
}
#endif

protocol SomeService: AnyObject {}

/// Mock di for testing purposes
class MockSomeService: SomeService {}

extension StoreDIValues {

	var someService: SomeService {
		get { self[\.someService] ?? MockSomeService() }
		set { self[\.someService] = newValue }
	}
}
