import SwiftUI
import VDStore

@main
struct TodosApp: App {
	var body: some Scene {
		WindowGroup {
			AppView(todos: Todos())
		}
	}
}
