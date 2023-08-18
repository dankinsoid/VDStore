import XCTest
import Combine
@testable import VDStore

@MainActor
class VDStoreTests: XCTestCase {
    
    // Test that initializing a Store with a given state sets the initial state correctly.
    func testInitialState() {
        let initialCounter = Counter(counter: 10)
        let store = Store(initialCounter)
        
        XCTAssertEqual(store.state.counter, 10)
    }
    
    // Test that a state mutation updates the state as expected.
    func testStateMutation() {
        let store = Store(Counter())
        store.add()
        
        XCTAssertEqual(store.state.counter, 1)
    }
    
    // Test dependency injection, ensuring that a service or dependency is correctly injected into a Store.
    func testDependencyInjection() {
        let service: SomeService = MockSomeService()
        let store = Store(Counter()).dependency(\.someService, service)
        
        XCTAssert(store.dependencies.someService === service)
    }
    
    // Test that scoped stores correctly inherit dependencies from their parent.
    func testScopedStoreInheritsDependencies() {
        let service: SomeService = MockSomeService()
        let parentStore = Store(Counter()).dependency(\.someService, service)
        let childStore = parentStore.scope(\.counter)
        XCTAssert(childStore.dependencies.someService === service)
    }
    
    // Test that the publisher property of a Store sends updates when the state changes.
    func testPublisherUpdates() {
        let initialCounter = Counter(counter: 0)
        let store = Store(initialCounter)
        let expectation = self.expectation(description: "State updated")
        var bag = Set<AnyCancellable>()
        
        store.publisher.sink { newState in
            if newState.counter == 1 {
                expectation.fulfill()
            }
        }
        .store(in: &bag)
        
        store.add()
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    // Test that computed properties in a Store extension return expected values based on the store’s state.
    func testComputedProperty() {
        let initialCounter = Counter(counter: 20)
        let store = Store(initialCounter).property(\.step, 2)
        
        XCTAssertEqual(store.step, 2)
    }
    
    // Test that a Store can use a mock dependency correctly.
    func testMockDependency() {
        let mockService = MockSomeService()
        let store = Store(Counter()).dependency(\.someService, mockService)
        
        XCTAssert(store.dependencies.someService is MockSomeService)
    }
    
    // Test that state mutations are thread-safe.
    func testThreadSafety() {
        let store = Store(Counter())
        let expectation = self.expectation(description: "Thread Safety")
        let group = DispatchGroup()
        
        for _ in 0..<1000 {
            group.enter()
            DispatchQueue.global().async {
                Task.detached {
                    await store.add()
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(store.state.counter, 1000)
    }
}

struct Counter: Equatable {
    
    var counter = 0
}

extension Store<Counter> {
    
    var step: Int {
        self[\.step] ?? 1
    }
    
    func add() {
        state.counter += 1
    }
}

protocol SomeService: AnyObject {
}

// Mock dependency for testing purposes
class MockSomeService: SomeService {
    // Override methods and properties as needed for testing
}

extension StoreDependencies {
    
    var someService: SomeService {
        self[\.someService] ?? MockSomeService()
    }
}
