import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI
import VDFlow
import VDStore

public struct NewGameView: View {

	@ViewStore var state: NewGame

	public init(store: Store<NewGame>) {
		_state = ViewStore(store)
	}

	public var body: some View {
		Form {
			Section {
				TextField("Blob Sr.", text: _state.xPlayerName)
					.autocapitalization(.words)
					.disableAutocorrection(true)
					.textContentType(.name)
			} header: {
				Text("X Player Name")
			}

			Section {
				TextField("Blob Jr.", text: _state.oPlayerName)
					.autocapitalization(.words)
					.disableAutocorrection(true)
					.textContentType(.name)
			} header: {
				Text("O Player Name")
			}

			Button("Let's play!") {
				$state.letsPlayButtonTapped()
			}
			.disabled(state.isLetsPlayButtonDisabled)
		}
		.navigationTitle("New Game")
		.navigationBarItems(
			trailing: Button("Logout") {
				$state.di.logoutButtonDelegate?.logoutButtonTapped()
			}
		)
	}
}

private extension NewGame {
	var isLetsPlayButtonDisabled: Bool {
		oPlayerName.isEmpty || xPlayerName.isEmpty
	}
}

#Preview {
	NavigationStack {
		NewGameView(store: Store(NewGame()))
	}
}
