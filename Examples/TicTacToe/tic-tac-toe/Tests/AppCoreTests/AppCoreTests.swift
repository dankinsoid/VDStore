import AppCore
import AuthenticationClient
import LoginCore
import NewGameCore
import TwoFactorCore
import VDStore
import XCTest

final class AppCoreTests: XCTestCase {
	@MainActor
	func testIntegration() async {
        let middleware = TestMiddleware()
        let store = Store(TicTacToe.login()).transformDI {
			$0.authenticationClient.login = { @Sendable _, _ in
				AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
			}
		}
        .middleware(middleware)

        store.state.login.email = "daniil@voidilov.com"
        XCTAssertEqual(store.state.login.email, "daniil@voidilov.com")
        store.state.login.password = "bl0bbl0b"
        XCTAssertEqual(store.state.login.password, "bl0bbl0b")
        XCTAssertTrue(store.state.login.isFormValid)
    
        await store.login.loginButtonTapped()
//        XCTAssertTrue(store.login.isLoginRequestInFlight)
        XCTAssertEqual(store.state.selected, .newGame)
        store.state.newGame.oPlayerName = "Blob Sr."
		await store.send(\.newGame.binding.oPlayerName, "Blob Sr.") {
			$0.newGame?.oPlayerName = "Blob Sr."
		}
		await store.send(\.newGame.logoutButtonTapped) {
			$0 = .login(Login.State())
		}
	}

	@MainActor
	func testIntegration_TwoFactor() async {
		let store = TestStore(initialState: TicTacToe.State.login(Login.State())) {
			TicTacToe.body
		} withDependencies: {
			$0.authenticationClient.login = { @Sendable _, _ in
				AuthenticationResponse(token: "deadbeef", twoFactorRequired: true)
			}
			$0.authenticationClient.twoFactor = { @Sendable _, _ in
				AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
			}
		}

		await store.send(\.login.view.binding.email, "blob@pointfree.co") {
			$0.login?.email = "blob@pointfree.co"
		}

		await store.send(\.login.view.binding.password, "bl0bbl0b") {
			$0.login?.password = "bl0bbl0b"
			$0.login?.isFormValid = true
		}

		await store.send(\.login.view.loginButtonTapped) {
			$0.login?.isLoginRequestInFlight = true
		}
		await store.receive(\.login.loginResponse.success) {
			$0.login?.isLoginRequestInFlight = false
			$0.login?.twoFactor = TwoFactor.State(token: "deadbeef")
		}

		await store.send(\.login.twoFactor.view.binding.code, "1234") {
			$0.login?.twoFactor?.code = "1234"
			$0.login?.twoFactor?.isFormValid = true
		}

		await store.send(\.login.twoFactor.view.submitButtonTapped) {
			$0.login?.twoFactor?.isTwoFactorRequestInFlight = true
		}
		await store.receive(\.login.twoFactor.twoFactorResponse.success) {
			$0 = .newGame(NewGame.State())
		}
	}
}
