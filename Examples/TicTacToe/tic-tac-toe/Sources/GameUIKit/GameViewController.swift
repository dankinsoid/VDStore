import Combine
import GameCore
import UIKit
import VDStore

public final class GameViewController: UIViewController {
	@Store private var state: Game
	private var cancellableSet: Set<AnyCancellable> = []

	public init(store: Store<Game>) {
		_state = store
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = "Tic-Tac-Toe"
		view.backgroundColor = .systemBackground

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: "Quit",
			style: .done,
			target: self,
			action: #selector(quitButtonTapped)
		)

		let titleLabel = UILabel()
		titleLabel.textAlignment = .center

		let playAgainButton = UIButton(type: .system)
		playAgainButton.setTitle("Play again?", for: .normal)
		playAgainButton.addTarget(self, action: #selector(playAgainButtonTapped), for: .touchUpInside)

		let titleStackView = UIStackView(arrangedSubviews: [titleLabel, playAgainButton])
		titleStackView.axis = .vertical
		titleStackView.spacing = 12

		let gridCell11 = UIButton()
		gridCell11.addTarget(self, action: #selector(gridCell11Tapped), for: .touchUpInside)
		let gridCell21 = UIButton()
		gridCell21.addTarget(self, action: #selector(gridCell21Tapped), for: .touchUpInside)
		let gridCell31 = UIButton()
		gridCell31.addTarget(self, action: #selector(gridCell31Tapped), for: .touchUpInside)
		let gridCell12 = UIButton()
		gridCell12.addTarget(self, action: #selector(gridCell12Tapped), for: .touchUpInside)
		let gridCell22 = UIButton()
		gridCell22.addTarget(self, action: #selector(gridCell22Tapped), for: .touchUpInside)
		let gridCell32 = UIButton()
		gridCell32.addTarget(self, action: #selector(gridCell32Tapped), for: .touchUpInside)
		let gridCell13 = UIButton()
		gridCell13.addTarget(self, action: #selector(gridCell13Tapped), for: .touchUpInside)
		let gridCell23 = UIButton()
		gridCell23.addTarget(self, action: #selector(gridCell23Tapped), for: .touchUpInside)
		let gridCell33 = UIButton()
		gridCell33.addTarget(self, action: #selector(gridCell33Tapped), for: .touchUpInside)

		let cells = [
			[gridCell11, gridCell12, gridCell13],
			[gridCell21, gridCell22, gridCell23],
			[gridCell31, gridCell32, gridCell33],
		]

		let gameRow1StackView = UIStackView(arrangedSubviews: cells[0])
		gameRow1StackView.spacing = 6
		let gameRow2StackView = UIStackView(arrangedSubviews: cells[1])
		gameRow2StackView.spacing = 6
		let gameRow3StackView = UIStackView(arrangedSubviews: cells[2])
		gameRow3StackView.spacing = 6

		let gameStackView = UIStackView(arrangedSubviews: [
			gameRow1StackView,
			gameRow2StackView,
			gameRow3StackView,
		])
		gameStackView.axis = .vertical
		gameStackView.spacing = 6

		let rootStackView = UIStackView(arrangedSubviews: [
			titleStackView,
			gameStackView,
		])
		rootStackView.isLayoutMarginsRelativeArrangement = true
		rootStackView.layoutMargins = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
		rootStackView.translatesAutoresizingMaskIntoConstraints = false
		rootStackView.axis = .vertical
		rootStackView.spacing = 100

		view.addSubview(rootStackView)

		NSLayoutConstraint.activate([
			rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
		])

		gameStackView.arrangedSubviews
			.flatMap { view in (view as? UIStackView)?.arrangedSubviews ?? [] }
			.enumerated()
			.forEach { idx, cellView in
				cellView.backgroundColor = idx % 2 == 0 ? .darkGray : .lightGray
				NSLayoutConstraint.activate([
					cellView.widthAnchor.constraint(equalTo: cellView.heightAnchor),
				])
			}

		$state.publisher
			.removeDuplicates()
			.sink { state in
				titleLabel.text = state.title
				playAgainButton.isHidden = state.isPlayAgainButtonHidden

				for (rowIdx, row) in state.rows.enumerated() {
					for (colIdx, label) in row.enumerated() {
						let button = cells[rowIdx][colIdx]
						button.setTitle(label, for: .normal)
						button.isEnabled = state.isGameEnabled
					}
				}
			}
			.store(in: &cancellableSet)
	}

	@objc private func gridCell11Tapped() { $state.cellTapped(row: 0, column: 0) }
	@objc private func gridCell12Tapped() { $state.cellTapped(row: 0, column: 1) }
	@objc private func gridCell13Tapped() { $state.cellTapped(row: 0, column: 2) }
	@objc private func gridCell21Tapped() { $state.cellTapped(row: 1, column: 0) }
	@objc private func gridCell22Tapped() { $state.cellTapped(row: 1, column: 1) }
	@objc private func gridCell23Tapped() { $state.cellTapped(row: 1, column: 2) }
	@objc private func gridCell31Tapped() { $state.cellTapped(row: 2, column: 0) }
	@objc private func gridCell32Tapped() { $state.cellTapped(row: 2, column: 1) }
	@objc private func gridCell33Tapped() { $state.cellTapped(row: 2, column: 2) }

	@objc private func quitButtonTapped() {
		$state.quitButtonTapped()
	}

	@objc private func playAgainButtonTapped() {
		$state.playAgainButtonTapped()
	}
}

private extension Game {
	var rows: Three<Three<String>> { board.map { $0.map { $0?.label ?? "" } } }
	var isGameEnabled: Bool { !board.hasWinner && !board.isFilled }
	var isPlayAgainButtonHidden: Bool { !board.hasWinner && !board.isFilled }
	var title: String {
		board.hasWinner
			? "Winner! Congrats \(currentPlayerName)!"
			: board.isFilled
			? "Tied game!"
			: "\(currentPlayerName), place your \(currentPlayer.label)"
	}
}
