import Combine
import LoginCore
import TwoFactorUIKit
import UIKit
import VDFlow
import VDStore

public class LoginViewController: UIViewController {
	public let store: Store<Login>
	private var cancellableSet: Set<AnyCancellable> = []

	public init(store: Store<Login>) {
		self.store = store
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = "Login"
		view.backgroundColor = .systemBackground

		let disclaimerLabel = UILabel()
		disclaimerLabel.text = """
		To login use any email and "password" for the password. If your email contains the \
		characters "2fa" you will be taken to a two-factor flow, and on that screen you can use \
		"1234" for the code.
		"""
		disclaimerLabel.textAlignment = .left
		disclaimerLabel.numberOfLines = 0

		let divider = UIView()
		divider.backgroundColor = .gray

		let titleLabel = UILabel()
		titleLabel.text = "Please log in to play TicTacToe!"
		titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
		titleLabel.numberOfLines = 0

		let emailTextField = UITextField()
		emailTextField.placeholder = "email@address.com"
		emailTextField.borderStyle = .roundedRect
		emailTextField.autocapitalizationType = .none
		emailTextField.addTarget(
			self, action: #selector(emailTextFieldChanged(sender:)), for: .editingChanged
		)

		let passwordTextField = UITextField()
		passwordTextField.placeholder = "**********"
		passwordTextField.borderStyle = .roundedRect
		passwordTextField.addTarget(
			self, action: #selector(passwordTextFieldChanged(sender:)), for: .editingChanged
		)
		passwordTextField.isSecureTextEntry = true

		let loginButton = UIButton(type: .system)
		loginButton.setTitle("Login", for: .normal)
		loginButton.addTarget(self, action: #selector(loginButtonTapped(sender:)), for: .touchUpInside)

		let activityIndicator = UIActivityIndicatorView(style: .large)
		activityIndicator.startAnimating()

		let rootStackView = UIStackView(arrangedSubviews: [
			disclaimerLabel,
			divider,
			titleLabel,
			emailTextField,
			passwordTextField,
			loginButton,
			activityIndicator,
		])
		rootStackView.isLayoutMarginsRelativeArrangement = true
		rootStackView.layoutMargins = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
		rootStackView.translatesAutoresizingMaskIntoConstraints = false
		rootStackView.axis = .vertical
		rootStackView.spacing = 24

		view.addSubview(rootStackView)

		NSLayoutConstraint.activate([
			rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			divider.heightAnchor.constraint(equalToConstant: 1),
		])

		var alertController: UIAlertController?
		var twoFactorController: TwoFactorViewController?

		store.publisher
			.removeDuplicates()
			.sink { [weak self] state in
				guard let self else { return }
				if state.email != emailTextField.text {
					emailTextField.text = state.email
				}
				emailTextField.isEnabled = state.isEmailTextFieldEnabled
				if passwordTextField.text != state.password {
					passwordTextField.text = state.password
				}
				passwordTextField.isEnabled = state.isPasswordTextFieldEnabled
				loginButton.isEnabled = state.isLoginButtonEnabled
				activityIndicator.isHidden = state.isActivityIndicatorHidden

				if store.state.flow.selected == .alert,
				   alertController == nil
				{
					alertController = UIAlertController(title: store.state.flow.alert, message: nil, preferredStyle: .alert)
					alertController?.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
					present(alertController!, animated: true, completion: nil)
				} else if store.state.flow.selected != .alert, alertController != nil {
					alertController?.dismiss(animated: true)
					alertController = nil
				}

				if store.state.flow.selected == .twoFactor,
				   twoFactorController == nil
				{
					twoFactorController = TwoFactorViewController(store: store.flow.twoFactor)
					navigationController?.pushViewController(
						twoFactorController!,
						animated: true
					)
				} else if store.state.flow.selected != .twoFactor, twoFactorController != nil {
					navigationController?.popToViewController(self, animated: true)
					twoFactorController = nil
				}
			}
			.store(in: &cancellableSet)
	}

	override public func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		if !isMovingToParent {
			store.twoFactorDismissed()
		}
	}

	@objc private func loginButtonTapped(sender: UIButton) {
		Task {
			await store.loginButtonTapped()
		}
	}

	@objc private func emailTextFieldChanged(sender: UITextField) {
		store.state.email = sender.text ?? ""
	}

	@objc private func passwordTextFieldChanged(sender: UITextField) {
		store.state.password = sender.text ?? ""
	}
}

private extension Login {
	var isActivityIndicatorHidden: Bool { !isLoginRequestInFlight }
	var isEmailTextFieldEnabled: Bool { !isLoginRequestInFlight }
	var isLoginButtonEnabled: Bool { isFormValid && !isLoginRequestInFlight }
	var isPasswordTextFieldEnabled: Bool { !isLoginRequestInFlight }
}

@Actions
private extension Store<Login> {

	func twoFactorDismissed() {}
}
