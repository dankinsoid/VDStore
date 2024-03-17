import Foundation
import VDStore

public struct AuthenticationResponse: Equatable, Sendable {
	public var token: String
	public var twoFactorRequired: Bool

	public init(
		token: String,
		twoFactorRequired: Bool
	) {
		self.token = token
		self.twoFactorRequired = twoFactorRequired
	}
}

public enum AuthenticationError: Equatable, LocalizedError, Sendable {
	case invalidUserPassword
	case invalidTwoFactor
	case invalidIntermediateToken
    case unimplemented

	public var errorDescription: String? {
		switch self {
		case .invalidUserPassword:
			return "Unknown user or invalid password."
		case .invalidTwoFactor:
			return "Invalid second factor (try 1234)"
		case .invalidIntermediateToken:
			return "404!! What happened to your token there bud?!?!"
        case .unimplemented:
            return "This feature is not yet implemented."
		}
	}
}

public struct AuthenticationClient: Sendable {

	public var login:
    @Sendable (_ email: String, _ password: String) async throws -> AuthenticationResponse = { _, _ in
        throw AuthenticationError.unimplemented
    }

	public var twoFactor:
    @Sendable (_ code: String, _ token: String) async throws -> AuthenticationResponse = { _, _ in
        throw AuthenticationError.unimplemented
    }
}
extension AuthenticationClient {

    public static let liveValue = Self(
        login: { email, password in
            guard email.contains("@"), password == "password"
            else { throw AuthenticationError.invalidUserPassword }
            
            try await Task.sleep(for: .seconds(1))
            return AuthenticationResponse(
                token: "deadbeef", twoFactorRequired: email.contains("2fa")
            )
        },
        twoFactor: { code, token in
            guard token == "deadbeef"
            else { throw AuthenticationError.invalidIntermediateToken }
            
            guard code == "1234"
            else { throw AuthenticationError.invalidTwoFactor }
            
            try await Task.sleep(for: .seconds(1))
            return AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
        }
    )
}

public extension StoreDIValues {
    
    @StoreDIValue
    var authenticationClient = valueFor(live: AuthenticationClient.liveValue, test: AuthenticationClient())
}
