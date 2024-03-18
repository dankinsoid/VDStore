import AuthenticationClient
import Combine
import Dispatch
import VDFlow
import VDStore

public struct TwoFactor: Sendable, Equatable {

	public var flow: Flow = .none
	public var code = ""
	public var isTwoFactorRequestInFlight = false
	public let token: String

	public init(token: String) {
		self.token = token
	}

	public var isFormValid: Bool {
		code.count >= 4
	}

	@Steps
	public struct Flow: Sendable, Equatable {
		public var alert = ""
		public var none
	}
}

@Actions
public extension Store<TwoFactor> {

	func submitButtonTapped() async {
		state.isTwoFactorRequestInFlight = true
		defer {
			state.isTwoFactorRequestInFlight = false
		}
		do {
			_ = try await di.authenticationClient.twoFactor(state.code, state.token)
			di.loginDelegate?.didSucceedLogin()
		} catch {
			state.flow.$alert.select(with: error.localizedDescription)
		}
	}
}

@MainActor
public protocol LoginDelegate {

	func didSucceedLogin()
}

public extension StoreDIValues {

	@StoreDIValue var loginDelegate: LoginDelegate?
}
