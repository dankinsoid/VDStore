import Combine
import TwoFactorCore
import UIKit
import VDStore

public final class TwoFactorViewController: UIViewController {

	public let store: Store<TwoFactor>
	private var cancellableSet: Set<AnyCancellable> = []

	public init(store: Store<TwoFactor>) {
		self.store = store
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()

		view.backgroundColor = .systemBackground

		let titleLabel = UILabel()
		titleLabel.text = "Enter the one time code to continue"
		titleLabel.textAlignment = .center

		let codeTextField = UITextField()
		codeTextField.placeholder = "1234"
		codeTextField.borderStyle = .roundedRect
		codeTextField.addTarget(
			self, action: #selector(codeTextFieldChanged(sender:)), for: .editingChanged
		)

		let loginButton = UIButton(type: .system)
		loginButton.setTitle("Login", for: .normal)
		loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)

		let activityIndicator = UIActivityIndicatorView(style: .large)
		activityIndicator.startAnimating()

		let rootStackView = UIStackView(arrangedSubviews: [
			titleLabel,
			codeTextField,
			loginButton,
			activityIndicator,
		])
		rootStackView.isLayoutMarginsRelativeArrangement = true
		rootStackView.layoutMargins = .init(top: 0, left: 32, bottom: 0, right: 32)
		rootStackView.translatesAutoresizingMaskIntoConstraints = false
		rootStackView.axis = .vertical
		rootStackView.spacing = 24

		view.addSubview(rootStackView)

		NSLayoutConstraint.activate([
			rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
		])

		var alertController: UIAlertController?

		store.publisher
			.removeDuplicates()
			.sink { [weak self] state in
				guard let self else { return }
				activityIndicator.isHidden = state.isActivityIndicatorHidden
				codeTextField.text = state.code
				loginButton.isEnabled = state.isLoginButtonEnabled

				if state.flow.selected == .alert,
				   alertController == nil
				{
					alertController = UIAlertController(title: state.flow.alert, message: nil, preferredStyle: .alert)
					alertController?.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
					present(alertController!, animated: true, completion: nil)
				} else if state.flow.selected != .alert, alertController != nil {
					alertController?.dismiss(animated: true)
					alertController = nil
				}
			}
			.store(in: &cancellableSet)
	}

	@objc private func codeTextFieldChanged(sender: UITextField) {
		store.state.code = sender.text ?? ""
	}

	@objc private func loginButtonTapped() {
		Task {
			await store.submitButtonTapped()
		}
	}
}

private extension TwoFactor {
	var isActivityIndicatorHidden: Bool { !isTwoFactorRequestInFlight }
	var isLoginButtonEnabled: Bool { isFormValid && !isTwoFactorRequestInFlight }
}
