import AppCore
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import VDStore

public struct AppView: View {
	@ViewStore private var state: TicTacToe

	public init(store: Store<TicTacToe>) {
		_state = ViewStore(store)
	}

	public var body: some View {
		switch state.selected {
		case .login:
			NavigationStack {
				LoginView(store: $state.login)
			}
		case .newGame:
			NavigationStack {
				NewGameView(store: $state.newGame)
			}
		}
	}
}
