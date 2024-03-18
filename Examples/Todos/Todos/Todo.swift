import SwiftUI
import VDStore

struct Todo: Equatable, Identifiable {

	var description = ""
	let id: UUID
	var isComplete = false

	static let mock = Todo(
		description: "Call Mom",
		id: UUID(),
		isComplete: true
	)
}

struct TodoView: View {
	@ViewStore var state: Todo

	init(store: Store<Todo>) {
		_state = ViewStore(store)
	}

	var body: some View {
		HStack {
			Button {
				state.isComplete.toggle()
			} label: {
				Image(systemName: state.isComplete ? "checkmark.square" : "square")
			}
			.buttonStyle(.plain)

			TextField("Untitled Todo", text: $state.binding.description)
		}
		.foregroundColor(state.isComplete ? .gray : nil)
	}
}
