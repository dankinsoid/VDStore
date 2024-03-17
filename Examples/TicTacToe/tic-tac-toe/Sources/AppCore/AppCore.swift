import LoginCore
import NewGameCore
import TwoFactorCore
import VDFlow
import VDStore

@Steps
public struct TicTacToe: Equatable {

	public var login: Login = Login()
	public var newGame: NewGame = NewGame()
}

extension Store<TicTacToe>: LogoutButtonDelegate {

	public func logoutButtonTapped() {
		state = .login()
	}
}

extension Store<TicTacToe>: LoginDelegate {

	public func didSucceedLogin() {
		state = .newGame()
	}
}
