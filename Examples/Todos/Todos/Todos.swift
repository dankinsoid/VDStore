import IdentifiedCollections
import SwiftUI
import VDStore

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
	case all = "All"
	case active = "Active"
	case completed = "Completed"
}

struct Todos: Equatable {

	var editMode: EditMode = .inactive
	var filter: Filter = .all
	var todos: IdentifiedArrayOf<Todo> = []

	var filteredTodos: IdentifiedArrayOf<Todo> {
		switch filter {
		case .active: return todos.filter { !$0.isComplete }
		case .all: return todos
		case .completed: return todos.filter(\.isComplete)
		}
	}
}

@Actions
extension Store<Todos> {

	func addTodoButtonTapped() {
		state.todos.insert(Todo(id: di.uuid()), at: 0)
	}

	func clearCompletedButtonTapped() {
		state.todos.removeAll(where: \.isComplete)
	}

	func delete(indexSet: IndexSet) {
		let filteredTodos = state.filteredTodos
		for index in indexSet {
			state.todos.remove(id: filteredTodos[index].id)
		}
	}

	func move(source: IndexSet, destination: Int) {
		var source = source
		var destination = destination
		if state.filter == .completed {
			let filtered = state.filteredTodos
			source = IndexSet(
				source
					.map { filtered[$0] }
					.compactMap { state.todos.index(id: $0.id) }
			)
			destination =
				(destination < filtered.endIndex
					? state.todos.index(id: filtered[destination].id)
					: state.todos.endIndex)
				?? destination
		}

		state.todos.move(fromOffsets: source, toOffset: destination)
	}

	@CancelInFlight
	func todoIsCompletedChanged() async throws {
		try await di.continuousClock.sleep(for: .seconds(1))
		sortCompletedTodos()
	}

	func sortCompletedTodos() {
		state.todos.sort { $1.isComplete && !$0.isComplete }
	}
}

extension Store<Todo> {

	var updateOnCompleted: Store<Todo> {
		onChange(of: \.isComplete) { _, _, _ in
			Task {
				try await di.store(for: Todos.self)?.todoIsCompletedChanged()
			}
		}
	}
}

struct AppView: View {

	@ViewStore var todos: Todos

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading) {
				Picker("Filter", selection: $todos.binding.filter) {
					ForEach(Filter.allCases, id: \.self) { filter in
						Text(filter.rawValue).tag(filter)
					}
				}
				.pickerStyle(.segmented)
				.padding(.horizontal)

				List {
					ForEach(todos.filteredTodos) { todo in
						TodoView(
							store: $todos.todos[id: todo.id].or(todo).updateOnCompleted
						)
					}
					.onDelete { $todos.delete(indexSet: $0) }
					.onMove { $todos.move(source: $0, destination: $1) }
				}
			}
			.navigationTitle("Todos")
			.navigationBarItems(
				trailing: HStack(spacing: 20) {
					EditButton()
					Button("Clear Completed") {
						$todos.clearCompletedButtonTapped()
					}
					.disabled(!todos.todos.contains(where: \.isComplete))
					Button("Add Todo") { $todos.addTodoButtonTapped() }
				}
			)
			.environment(\.editMode, $todos.binding.editMode)
		}
		.animation(.default, value: todos)
	}
}

extension IdentifiedArrayOf<Todo> {
	static let mock: Self = [
		Todo(
			description: "Check Mail",
			id: UUID(),
			isComplete: false
		),
		Todo(
			description: "Buy Milk",
			id: UUID(),
			isComplete: false
		),
		Todo(
			description: "Call Mom",
			id: UUID(),
			isComplete: true
		),
	]
}

#Preview {
	AppView(todos: Todos(todos: .mock))
}
