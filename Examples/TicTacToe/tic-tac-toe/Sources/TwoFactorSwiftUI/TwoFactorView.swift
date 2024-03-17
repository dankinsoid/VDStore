import AuthenticationClient
import SwiftUI
import TwoFactorCore
import VDFlow
import VDStore

public struct TwoFactorView: View {

	@ViewStore public var state: TwoFactor

	public init(store: Store<TwoFactor>) {
		_state = ViewStore(store)
	}

	public var body: some View {
		Form {
			Text(#"To confirm the second factor enter "1234" into the form."#)

			Section {
				TextField("1234", text: $state.binding.code)
					.keyboardType(.numberPad)
			}

			HStack {
				Button("Submit") {
					// NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
					//     if you disable a text field while it is focused. This hack will force all
					//     fields to unfocus before we send the action to the store.
					// CF: https://stackoverflow.com/a/69653555
					UIApplication.shared.sendAction(
						#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
					)
					Task {
						await $state.submitButtonTapped()
					}
				}
				.disabled(state.isSubmitButtonDisabled)

				if state.isActivityIndicatorVisible {
					Spacer()
					ProgressView()
				}
			}
		}
		.alert(state.flow.alert, isPresented: $state.binding.flow.isSelected(.alert)) {
			Button("Ok") {}
		}
		.disabled(state.isFormDisabled)
		.navigationTitle("Confirmation Code")
	}
}

private extension TwoFactor {
	var isActivityIndicatorVisible: Bool { isTwoFactorRequestInFlight }
	var isFormDisabled: Bool { isTwoFactorRequestInFlight }
	var isSubmitButtonDisabled: Bool { !isFormValid }
}

#Preview {
	NavigationStack {
		TwoFactorView(
			store: Store(TwoFactor(token: "deadbeef"))
				.transformDI {
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
