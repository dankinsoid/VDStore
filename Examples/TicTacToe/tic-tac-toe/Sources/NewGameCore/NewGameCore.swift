import GameCore
import VDFlow
import VDStore

public struct NewGame: Equatable {

	public var flow: Flow = .none
	public var oPlayerName = ""
	public var xPlayerName = ""

	@Steps
	public struct Flow: Equatable {
		public var game: Game = Game(oPlayerName: "", xPlayerName: "")
		public var none
	}

	public init() {}
}

@MainActor
public protocol LogoutButtonDelegate {
	func logoutButtonTapped()
}

public extension StoreDIValues {
	@StoreDIValue
	var logoutButtonDelegate: LogoutButtonDelegate?
}

@Actions
public extension Store<NewGame> {

	func letsPlayButtonTapped() {
		state.flow.$game.select(
			with: Game(
				oPlayerName: state.oPlayerName,
				xPlayerName: state.xPlayerName
			)
		)
	}
}
