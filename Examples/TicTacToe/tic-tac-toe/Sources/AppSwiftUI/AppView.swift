import AppCore
import GameSwiftUI
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import VDFlow
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
			NavigationSteps(selection: $state.binding.newGame.flow.selected) {
				NewGameView(store: $state.newGame)
				GameView(store: $state.newGame.flow.game)
					.step($state.binding.newGame.flow.$game)
			}
		}
	}
}
