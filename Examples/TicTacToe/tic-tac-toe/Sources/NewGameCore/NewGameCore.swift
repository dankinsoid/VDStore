import VDStore
import VDFlow
import GameCore

public struct NewGame: Equatable {

    public var flow: Flow = .none
    public var oPlayerName = ""
    public var xPlayerName = ""

    @Steps
    public struct Flow: Equatable {
        public var game: Game = Game(oPlayerName: "", xPlayerName: "")
        public var none
    }
    
    public init() {
    }
}

@MainActor
public protocol LogoutButtonDelegate {
    func logoutButtonTapped()
}

extension StoreDIValues {
    @StoreDIValue
    public var logoutButtonDelegate: LogoutButtonDelegate?
}

@Actions
extension Store<NewGame> {
    
    public func letsPlayButtonTapped() {
        state.flow.$game.select(
            with: Game(
                oPlayerName: state.oPlayerName,
                xPlayerName: state.xPlayerName
            )
        )
    }
}
