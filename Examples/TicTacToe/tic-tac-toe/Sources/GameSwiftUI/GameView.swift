import VDStore
import VDFlow
import GameCore
import SwiftUI

public struct GameView: View {

	@ViewStore private var state: Game

	public init(store: Store<Game>) {
		_state = ViewStore(store)
	}

	public var body: some View {
		GeometryReader { proxy in
			VStack(spacing: 0.0) {
				VStack {
					Text(state.title)
						.font(.title)

					if state.isPlayAgainButtonVisible {
						Button("Play again?") {
							$state.playAgainButtonTapped()
						}
						.padding(.top, 12)
						.font(.title)
					}
				}
				.padding(.bottom, 48)

				VStack {
					rowView(row: 0, proxy: proxy)
					rowView(row: 1, proxy: proxy)
					rowView(row: 2, proxy: proxy)
				}
				.disabled(state.isGameDisabled)
			}
			.navigationTitle("Tic-tac-toe")
			.navigationBarItems(leading: Button("Quit") { $state.quitButtonTapped() })
			.navigationBarBackButtonHidden(true)
		}
	}

	func rowView(
		row: Int,
		proxy: GeometryProxy
	) -> some View {
		HStack(spacing: 0.0) {
			cellView(row: row, column: 0, proxy: proxy)
			cellView(row: row, column: 1, proxy: proxy)
			cellView(row: row, column: 2, proxy: proxy)
		}
	}

	func cellView(
		row: Int,
		column: Int,
		proxy: GeometryProxy
	) -> some View {
		Button {
			$state.cellTapped(row: row, column: column)
		} label: {
			Text(state.rows[row][column])
				.frame(width: proxy.size.width / 3, height: proxy.size.width / 3)
				.background(
					(row + column).isMultiple(of: 2)
						? Color(red: 0.8, green: 0.8, blue: 0.8)
						: Color(red: 0.6, green: 0.6, blue: 0.6)
				)
		}
	}
}

private extension Game {
	var rows: [[String]] { board.map { $0.map { $0?.label ?? "" } } }
	var isGameDisabled: Bool { board.hasWinner || board.isFilled }
	var isPlayAgainButtonVisible: Bool { board.hasWinner || board.isFilled }
	var title: String {
		board.hasWinner
			? "Winner! Congrats \(currentPlayerName)!"
			: board.isFilled
			? "Tied game!"
			: "\(currentPlayerName), place your \(currentPlayer.label)"
	}
}

#Preview {
	NavigationStack {
		GameView(
			store: Store(Game(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr."))
		)
	}
}
