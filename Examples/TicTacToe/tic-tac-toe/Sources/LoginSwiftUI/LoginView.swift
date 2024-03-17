import AuthenticationClient
import VDStore
import VDFlow
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {

	@ViewStore public var state: Login

	public init(store: Store<Login>) {
		_state = ViewStore(store)
	}

	public var body: some View {
		Form {
			Text(
				"""
				To login use any email and "password" for the password. If your email contains the \
				characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
				use "1234" for the code.
				"""
			)

			Section {
				TextField("blob@pointfree.co", text: $state.binding.email)
					.autocapitalization(.none)
					.keyboardType(.emailAddress)
					.textContentType(.emailAddress)

                SecureField("••••••••", text: $state.binding.password)
			}

			Button {
				// NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected" if
				//     you disable a text field while it is focused. This hack will force all fields to
				//     unfocus before we send the action to the store.
				// CF: https://stackoverflow.com/a/69653555
				_ = UIApplication.shared.sendAction(
					#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
				)
                Task {
                    await $state.loginButtonTapped()
                }
			} label: {
				HStack {
					Text("Log in")
					if state.isActivityIndicatorVisible {
						Spacer()
						ProgressView()
					}
				}
			}
			.disabled(state.isLoginButtonDisabled)
		}
		.disabled(state.isFormDisabled)
        .alert(state.flow.alert, isPresented: $state.binding.flow.isSelected(.alert)) {
            Button("Ok") {}
        }
        .navigationDestination(isPresented: $state.binding.flow.isSelected(.twoFactor)) {
            TwoFactorView(store: $state.flow.twoFactor)
		}
		.navigationTitle("Login")
	}
}

private extension Login {
	var isActivityIndicatorVisible: Bool { isLoginRequestInFlight }
	var isFormDisabled: Bool { isLoginRequestInFlight }
	var isLoginButtonDisabled: Bool { !isFormValid }
}

#Preview {
	NavigationStack {
		LoginView(
            store: Store(Login()).transformDI {
				$0.authenticationClient.login = { @Sendable _, _ in
					AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
				}
				$0.authenticationClient.twoFactor = { @Sendable _, _ in
					AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
				}
			}
		)
	}
}
