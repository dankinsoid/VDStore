import AppCore
import Combine
import LoginUIKit
import NewGameUIKit
import SwiftUI
import UIKit
import VDStore

public struct UIKitAppView: UIViewControllerRepresentable {
	@Store private var state: TicTacToe

	public init(store: Store<TicTacToe>) {
		_state = store
	}

	public func makeUIViewController(context: Context) -> UIViewController {
		AppViewController(store: $state)
	}

	public func updateUIViewController(
		_ uiViewController: UIViewController,
		context: Context
	) {
		// Nothing to do
	}
}

class AppViewController: UINavigationController {
	@Store private var state: TicTacToe
	private var cancellableSet: Set<AnyCancellable> = []

	init(store: Store<TicTacToe>) {
		_state = store
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		$state.publisher
			.map(\.selected)
			.removeDuplicates()
			.sink { [weak self] selected in
				guard let self else { return }
				switch selected {
				case .login:
					setViewControllers([LoginViewController(store: $state.login)], animated: false)
				case .newGame:
					setViewControllers([NewGameViewController(store: $state.newGame)], animated: false)
				}
			}
			.store(in: &cancellableSet)
	}
}
