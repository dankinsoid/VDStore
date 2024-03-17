import VDStore
import VDFlow
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

public struct NewGameView: View {
    
    @ViewStore var state: NewGame

	public init(store: Store<NewGame>) {
		_state = ViewStore(store)
	}

	public var body: some View {
		Form {
			Section {
                TextField("Blob Sr.", text: $state.binding.xPlayerName)
					.autocapitalization(.words)
					.disableAutocorrection(true)
					.textContentType(.name)
			} header: {
				Text("X Player Name")
			}

			Section {
				TextField("Blob Jr.", text: $state.binding.oPlayerName)
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
        .navigationDestination(isPresented: $state.binding.flow.isSelected(.game)) {
            GameView(store: $state.flow.game)
		}
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
