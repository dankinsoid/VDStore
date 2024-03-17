import AuthenticationClient
import VDStore
import VDFlow
import Dispatch
import TwoFactorCore

public struct Login: Sendable, Equatable {

    public var flow: Flow = .none
    public var email = ""
    public var isLoginRequestInFlight = false
    public var password = ""

    public init() {}

    public var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    @Steps
    public struct Flow: Equatable, Sendable {
        public var twoFactor: TwoFactor = TwoFactor(token: "")
        public var alert = ""
        public var none
    }
}

@Actions
public extension Store<Login> {

    func loginButtonTapped() async {
        state.isLoginRequestInFlight = true
        defer {
            state.isLoginRequestInFlight = false
        }
        do {
            let response = try await di.authenticationClient.login(state.email, state.password)
            if response.twoFactorRequired {
                state.flow.$twoFactor.select(with:  TwoFactor(token: response.token))
            } else {
                di.loginDelegate?.didSucceedLogin()
            }
        } catch {
            state.flow.$alert.select(with: error.localizedDescription)
        }
    }
}
