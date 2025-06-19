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
					store.cancel(id: id)
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
	
	/// Test that the publisher property of a Store sends updates when the state changes.
	func testAsyncSequenceUpdates() async {
		let initialCounter = Counter(counter: 0)
		let store = Store(initialCounter)
		Task {
			store.add()
		}
		for await newState in store.async {
			if newState.counter == 1 {
				break
			}
		}
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
		let value = await store.cancellableTask()
		XCTAssertEqual(value, 6)
	}
	
	func testTaskMacroCancelInFlight() async {
		let store = Store(Counter())
		let value = await store.cancellableInFlightTask()
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
	
	//    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
	//    func testObservation() async {
	//        let store = Store(Counter()).counter
	//        let expectation = expectation(description: "Counter")
	////        store.state += 1
	//        withObservationTracking {
	//            store.state += 1
	//        } onChange: {
	//            expectation.fulfill()
	//        }
	////        withContinousObservation(of: store.state) { state in
	////            print("onChange")
	////            expectation.fulfill()
	////        }
	////        store.state += 1
	//        await fulfillment(of: [expectation], timeout: 0.1)
	//    }
#endif
	
	// MARK: - Non-mutating Substate Tests
	
	/// Test that @Independent properties don't trigger parent store updates
	func testIndependentDoesNotTriggerParentUpdates() async {
		let store = Store(AppStateWithIndependent())
		var updateCount = 0
		
		let expectation = expectation(description: "No parent updates from Independent")
		expectation.isInverted = true
		
		store.publisher.sink { _ in
			updateCount += 1
			if updateCount > 1 { // Initial state + any unexpected updates
				expectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// Modify @Independent properties directly - should not trigger parent updates
		store.state.homeScreen.posts.append("New Post")
		store.state.profileScreen.userName = "John Doe"
		store.state.settingsScreen.theme = "dark"
		
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updateCount, 1, "Parent store should only emit initial state")
	}
	
	/// Test that scoped stores from @Independent properties DO trigger updates
	func testScopedStoreFromIndependentTriggersUpdates() async {
		let store = Store(AppStateWithIndependent())
		let homeStore = store.scope(\.homeScreen)
		var updateCount = 0
		
		let expectation = expectation(description: "Scoped store updates")
		
		homeStore.publisher.sink { state in
			updateCount += 1
			if state.posts.count == 1 {
				expectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// This should trigger updates in the scoped store
		homeStore.addPost("New Post")
		
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updateCount, 2, "Scoped store should emit initial state + update")
		XCTAssertEqual(homeStore.state.posts, ["New Post"])
	}
	
	/// Test that global state changes trigger updates for all subscribers
	func testGlobalStateChangesDoesNotTriggersUpdates() async {
		let store = Store(AppStateWithIndependent())
		var parentUpdateCount = 0
		var homeUpdateCount = 0
		
		let parentExpectation = expectation(description: "Parent store updates")
		let homeExpectation = expectation(description: "Home store updates")
		
		let homeStore = store.scope(\.homeScreen)
		
		store.publisher.sink { state in
			parentUpdateCount += 1
			if state.globalCounter == 1 {
				parentExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		homeStore.publisher.sink { _ in
			homeUpdateCount += 1
			homeExpectation.fulfill()
		}
		.store(in: &store.di.cancellableSet)
		
		// This should trigger updates in both parent and child stores
		store.updateGlobalCounter()
		
		await fulfillment(of: [parentExpectation, homeExpectation], timeout: 0.1)
		XCTAssertEqual(parentUpdateCount, 2, "Parent should emit initial + update")
		XCTAssertEqual(homeUpdateCount, 1, "Child should not inherit parent updates")
	}
	
	/// Test independent updates between different scoped stores
	func testIndependentScopedStoreUpdates() async {
		let store = Store(AppStateWithIndependent())
		let homeStore = store.scope(\.homeScreen)
		let profileStore = store.scope(\.profileScreen)
		
		var homeUpdateCount = 0
		var profileUpdateCount = 0
		
		let homeExpectation = expectation(description: "Home store updates")
		let profileExpectation = expectation(description: "Profile store updates")
		profileExpectation.isInverted = true
		
		homeStore.publisher.sink { state in
			homeUpdateCount += 1
			if state.isLoading {
				homeExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		profileStore.publisher.sink { _ in
			profileUpdateCount += 1
			if profileUpdateCount > 1 { // Only initial should be emitted
				profileExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// Update only home store - profile should not be affected
		homeStore.setLoading(true)
		
		await fulfillment(of: [homeExpectation, profileExpectation], timeout: 0.1)
		XCTAssertEqual(homeUpdateCount, 2, "Home store should update")
		XCTAssertEqual(profileUpdateCount, 1, "Profile store should not update")
	}
	
	/// Test that @Independent preserves value equality
	func testIndependentPreservesEquality() {
		let store = Store(AppStateWithIndependent())
		let initialState = store.state
		
		// Modify @Independent property
		store.state.homeScreen.posts.append("New Post")
		
		// Parent state should still be considered equal for mutation detection
		// but the actual content has changed
		XCTAssertEqual(store.state.homeScreen.posts, ["New Post"])
		XCTAssertNotEqual(store.state.homeScreen, HomeScreenState()) // Content changed
		
		// Global properties should remain unchanged
		XCTAssertEqual(store.state.globalCounter, initialState.globalCounter)
		XCTAssertEqual(store.state.isOnline, initialState.isOnline)
	}
	
	/// Test shared dependency injection across scoped stores
	func testSharedDependencyInjectionAcrossScopes() {
		let mockService = MockSomeService()
		let store = Store(AppStateWithIndependent()).di(\.someService, mockService)
		
		let homeStore = store.homeScreen
		let profileStore = store.profileScreen
		let settingsStore = store.settingsScreen
		
		// All scoped stores should share the same dependency
		XCTAssert(store.di.someService === mockService)
		XCTAssert(homeStore.di.someService === mockService)
		XCTAssert(profileStore.di.someService === mockService)
		XCTAssert(settingsStore.di.someService === mockService)
		
		// Verify they're all the same instance
		XCTAssert(homeStore.di.someService === profileStore.di.someService)
		XCTAssert(profileStore.di.someService === settingsStore.di.someService)
	}
	
	// MARK: - Class-based Non-mutating State Tests
	
	/// Test that class-based states don't trigger parent store updates
	func testClassBasedStatesDoNotTriggerParentUpdates() async {
		let store = Store(AppClassState())
		var updateCount = 0
		
		let expectation = expectation(description: "No parent updates from class mutations")
		expectation.isInverted = true
		
		store.publisher.sink { _ in
			updateCount += 1
			if updateCount > 1 { // Initial state + any unexpected updates
				expectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// Modify class properties directly - should not trigger parent updates
		store.state.homeScreen.posts.append("New Post")
		store.state.profileScreen.userName = "John Doe"
		store.state.settingsScreen.theme = "dark"
		
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updateCount, 1, "Parent store should only emit initial state")
	}
	
	/// Test that scoped stores from class properties DO trigger updates
	func testScopedStoreFromClassTriggersUpdates() async {
		let store = Store(AppClassState())
		let homeStore = store.independentScope(get: { $0.homeScreen }, set: { parent, child in parent.homeScreen = child })
		var updateCount = 0
		
		let expectation = expectation(description: "Scoped store updates")
		
		homeStore.publisher.sink { state in
			updateCount += 1
			if state.posts.count == 1 {
				expectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// This should trigger updates in the scoped store
		homeStore.addPost("New Post")
		
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updateCount, 2, "Scoped store should emit initial state + update")
		XCTAssertEqual(homeStore.state.posts, ["New Post"])
	}
	
	/// Test independent updates between different class-based scoped stores
	func testIndependentClassBasedScopedStoreUpdates() async {
		let store = Store(AppClassState())
		let homeStore = store.scope(\.homeScreen)
		let profileStore = store.scope(\.profileScreen)
		
		var homeUpdateCount = 0
		var profileUpdateCount = 0
		
		let homeExpectation = expectation(description: "Home store updates")
		let profileExpectation = expectation(description: "Profile store updates")
		profileExpectation.isInverted = true
		
		homeStore.publisher.sink { state in
			homeUpdateCount += 1
			if state.isLoading {
				homeExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		profileStore.publisher.sink { _ in
			profileUpdateCount += 1
			if profileUpdateCount > 1 { // Only initial should be emitted
				profileExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// Update only home store - profile should not be affected
		homeStore.setLoading(true)
		
		await fulfillment(of: [homeExpectation, profileExpectation], timeout: 0.1)
		XCTAssertEqual(homeUpdateCount, 2, "Home store should update")
		XCTAssertEqual(profileUpdateCount, 1, "Profile store should not update")
	}

	/// Test direct class mutation vs scoped mutation behavior
	func testDirectClassMutationVsScopedMutation() async {
		let store = Store(AppClassState())
		let homeStore = store.homeScreen
		
		var parentUpdateCount = 0
		var homeUpdateCount = 0
		
		let parentExpectation = expectation(description: "Parent updates")
		parentExpectation.isInverted = true
		
		let homeExpectation = expectation(description: "Home updates")
		
		store.publisher.sink { _ in
			parentUpdateCount += 1
			if parentUpdateCount > 1 {
				parentExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		homeStore.publisher.sink { state in
			homeUpdateCount += 1
			if state.posts.count == 2 {
				homeExpectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)
		
		// Direct mutation on parent - should NOT trigger parent updates
		store.state.homeScreen.posts.append("Direct mutation")
		
		// Scoped mutation - should trigger scoped store updates
		homeStore.addPost("Scoped mutation")
		
		await fulfillment(of: [parentExpectation, homeExpectation], timeout: 0.1)
		XCTAssertEqual(parentUpdateCount, 1, "Parent should only emit initial")
		XCTAssertEqual(homeUpdateCount, 2, "Home should emit initial + update")
		XCTAssertEqual(homeStore.state.posts, ["Direct mutation", "Scoped mutation"])
	}
	
	func testEmptyUpdateFunctionTriggersUpdate() async {
		let store = Store(AppClassState())
		let publisher = store.publisher
		var updatesCount = 0
		let expectation = expectation(description: "Counter")
		publisher
			.sink { _ in
				updatesCount += 1
				if updatesCount > 1 {
					expectation.fulfill()
					store.di.cancellableSet = []
				}
			}
			.store(in: &store.di.cancellableSet)
		store.update()
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updatesCount, 2) // Initial state + empty update
	}

	func testSilentlyDoesNotTriggerUpdate() async {
		let store = Store(Counter())
		let publisher = store.publisher
		var updatesCount = 0
		let expectation = expectation(description: "Counter")
		publisher
			.sink { state in
				updatesCount += 1
				if state.counter > 1 {
					expectation.fulfill()
					store.di.cancellableSet = []
				}
			}
			.store(in: &store.di.cancellableSet)
		store.silently {
			store.state.counter += 1
			store.state.counter += 1
			store.state.counter += 1
		}
		store.silently {
			store.state.counter += 1
		}
		store.state.counter += 1
		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updatesCount, 2) // Initial state + last update
		XCTAssertEqual(store.state.counter, 5) // Final state after all silent updates
	}

	func testIndependentSendsUpdatesWhenChangedExternally() async {
		let store = Store(AppStateWithIndependent())
		let homeStore = store.homeScreen
		var updateCount = 0

		let expectation = expectation(description: "Home store updates")

		homeStore.publisher.sink { state in
			updateCount += 1
			if state.posts.count == 1 {
				expectation.fulfill()
			}
		}
		.store(in: &store.di.cancellableSet)

		// Directly modify the independent property
		store.state.homeScreen.posts.append("New Post")

		await fulfillment(of: [expectation], timeout: 0.1)
		XCTAssertEqual(updateCount, 2, "Home store should emit initial state + update")
		XCTAssertEqual(homeStore.state.posts, ["New Post"])
	}
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
func withContinousObservation<T>(of value: @escaping @autoclosure () -> T, execute: @escaping (T) -> Void) {
	withObservationTracking {
		execute(value())
	} onChange: {
		DispatchQueue.main.async {
			withContinousObservation(of: value(), execute: execute)
		}
	}
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
func observationTrackingStream<T>(
	of value: @escaping @autoclosure () -> T
) -> AsyncStream<T> {
	AsyncStream { continuation in
		@Sendable func observe() {
			let result = withObservationTracking {
				value()
			} onChange: {
				DispatchQueue.main.async {
					observe()
				}
			}
			continuation.yield(result)
		}
		observe()
	}
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

	func cancellableTask() async -> Int {
		for i in 0 ..< 10 {
			guard !Task.isCancelled else { return i }
			if i == 5 {
				cancel(Self.cancellableTask)
			}
		}
		return 10
	}

	@CancelInFlight
	func cancellableInFlightTask(ignore: Bool = false) async -> Int {
		guard !ignore else { return -1 }
		for i in 0 ..< 10 {
			guard !Task.isCancelled else { return i }
			if i == 5 {
				_ = await cancellableInFlightTask(ignore: true)
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
		get { get(\.someService, or: MockSomeService()) }
		set { set(\.someService, newValue) }
	}
}

// MARK: - Non-mutating Substate Test Models

struct AppStateWithIndependent: Equatable {
	var globalCounter: Int = 0
	var isOnline: Bool = true
	
	@Independent var homeScreen: HomeScreenState = HomeScreenState()
	@Independent var profileScreen: ProfileScreenState = ProfileScreenState()
	@Independent var settingsScreen: SettingsScreenState = SettingsScreenState()
}

struct HomeScreenState: Equatable {
	var posts: [String] = []
	var isLoading: Bool = false
	var searchQuery: String = ""
}

struct ProfileScreenState: Equatable {
	var userName: String = ""
	var isEditing: Bool = false
	var avatarUrl: String? = nil
}

struct SettingsScreenState: Equatable {
	var theme: String = "light"
	var notificationsEnabled: Bool = true
	var selectedLanguage: String = "en"
}

class AppClassState {
	var globalCounter: Int = 0
	var isOnline: Bool = true
	
	var homeScreen = HomeScreenState()
	var profileScreen = ProfileScreenState()
	var settingsScreen = SettingsScreenState()
}

// MARK: - Store Extensions for Testing

extension Store<AppStateWithIndependent> {
	func updateGlobalCounter() {
		state.globalCounter += 1
	}
	
	func updateOnlineStatus(_ isOnline: Bool) {
		state.isOnline = isOnline
	}
}

extension Store<HomeScreenState> {
	func addPost(_ post: String) {
		state.posts.append(post)
	}
	
	func setLoading(_ isLoading: Bool) {
		state.isLoading = isLoading
	}
	
	func updateSearchQuery(_ query: String) {
		state.searchQuery = query
	}
}

extension Store<ProfileScreenState> {
	func updateUserName(_ name: String) {
		state.userName = name
	}
	
	func toggleEditing() {
		state.isEditing.toggle()
	}
}

extension Store<SettingsScreenState> {
	func updateTheme(_ theme: String) {
		state.theme = theme
	}
	
	func toggleNotifications() {
		state.notificationsEnabled.toggle()
	}
}

extension Store<AppClassState> {
	func updateGlobalCounter() {
		state.globalCounter += 1
	}
	
	func updateOnlineStatus(_ isOnline: Bool) {
		state.isOnline = isOnline
	}
}
