import Clocks
import IdentifiedCollections
import VDStore
import XCTest

@testable import Todos

final class TodosTests: XCTestCase {

	let clock = TestClock()

	@MainActor
	func testAddTodo() async {
		let store = Store(Todos()).di(\.uuid, .incrementing)

		store.addTodoButtonTapped()
		XCTAssertEqual(
			store.state.todos,
			[
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
			]
		)

		store.addTodoButtonTapped()

		XCTAssertEqual(
			store.state.todos,
			[
				Todo(
					description: "",
					id: UUID(1),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
			]
		)
	}

	@MainActor
	func testEditTodo() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
			]
		)

		let store = Store(state)
		store.state.todos[id: UUID(0)]?.description = "Learn VDStore"

		XCTAssertEqual(
			store.state.todos,
			[
				Todo(
					description: "Learn VDStore",
					id: UUID(0),
					isComplete: false
				),
			]
		)
	}

	@MainActor
	func testCompleteTodo() async throws {
		let todos: IdentifiedArrayOf<Todo> = [
			Todo(
				description: "",
				id: UUID(0),
				isComplete: false
			),
			Todo(
				description: "",
				id: UUID(1),
				isComplete: false
			),
		]
		let state = Todos(todos: todos)

		let middleware = TestMiddleware()
		let store = Store(state)
			.di(\.continuousClock, clock)
			.middleware(middleware)

		let itemStore = store.todos[id: UUID(0)].or(.mock).updateOnCompleted

		itemStore.state.isComplete = true
		await clock.advance(by: .seconds(1))

		try await middleware.waitExecution(of: Store<Todos>.sortCompletedTodos)
		XCTAssertEqual(
			store.state.todos,
			[todos[1], todos[0]]
		)
	}

	@MainActor
	func testCompleteTodoDebounces() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: false
				),
			]
		)

		let middleware = TestMiddleware()
		let store = Store(Todos())
			.di(\.continuousClock, clock)
			.middleware(middleware)

		let itemStore = store.todos[id: UUID(0)].or(.mock).updateOnCompleted

		itemStore.state.isComplete = true
		XCTAssertTrue(itemStore.state.isComplete)

		await clock.advance(by: .milliseconds(500))

		itemStore.state.isComplete = false
		XCTAssertFalse(itemStore.state.isComplete)

		await clock.advance(by: .seconds(1))
		middleware.didCall(Store<Todos>.sortCompletedTodos)
	}

	@MainActor
	func testClearCompleted() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: true
				),
			]
		)

		let store = Store(Todos())
		store.clearCompletedButtonTapped()
		XCTAssertEqual(
			store.state.todos,
			[state.todos[0]]
		)
	}

	@MainActor
	func testDelete() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(2),
					isComplete: false
				),
			]
		)

		let store = Store(Todos())
		store.delete(indexSet: [1])
		XCTAssertEqual(
			store.state.todos,
			[state.todos[0], state.todos[2]]
		)
	}

	@MainActor
	func testDeleteWhileFiltered() async {
		let state = Todos(
			filter: .completed,
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(2),
					isComplete: true
				),
			]
		)

		let store = Store(Todos())
		store.delete(indexSet: [0])
		XCTAssertEqual(
			store.state.todos,
			[state.todos[1], state.todos[2]]
		)
	}

	@MainActor
	func testEditModeMoving() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(2),
					isComplete: false
				),
			]
		)

		let middleware = TestMiddleware()
		let store = Store(Todos())
			.di(\.continuousClock, clock)
			.middleware(middleware)

		store.state.editMode = .active
		XCTAssertEqual(store.state.editMode, .active)
		store.move(source: [0], destination: 2)

		XCTAssertEqual(
			store.state.todos,
			[state.todos[1], state.todos[0], state.todos[2]]
		)
		await clock.advance(by: .milliseconds(100))
		middleware.didCall(Store<Todos>.sortCompletedTodos)
	}

	@MainActor
	func testEditModeMovingWithFilter() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(2),
					isComplete: true
				),
				Todo(
					description: "",
					id: UUID(3),
					isComplete: true
				),
			]
		)

		let middleware = TestMiddleware()
		let store = Store(Todos())
			.di(\.continuousClock, clock)
			.di(\.uuid, .incrementing)
			.middleware(middleware)

		store.state.editMode = .active
		XCTAssertEqual(store.state.editMode, .active)
		store.state.filter = .completed
		XCTAssertEqual(store.state.filter, .completed)

		store.move(source: [0], destination: 2)

		XCTAssertEqual(
			store.state.todos,
			[state.todos[0], state.todos[1], state.todos[3], state.todos[2]]
		)
		await clock.advance(by: .milliseconds(100))
		middleware.didCall(Store<Todos>.sortCompletedTodos)
	}

	@MainActor
	func testFilteredEdit() async {
		let state = Todos(
			todos: [
				Todo(
					description: "",
					id: UUID(0),
					isComplete: false
				),
				Todo(
					description: "",
					id: UUID(1),
					isComplete: true
				),
			]
		)

		let store = Store(Todos())
		store.state.filter = .completed
		store.state.todos[id: UUID(1)]?.description = "Did this already"
		XCTAssertEqual(
			store.state.todos[id: UUID(1)]?.description,
			"Did this already"
		)
	}
}
