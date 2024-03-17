import VDStore
import VDFlow
import SwiftUI

public struct Game: Sendable, Equatable {
    
    public var board: Three<Three<Player?>> = .empty
    public var currentPlayer: Player = .x
    public let oPlayerName: String
    public let xPlayerName: String
    
    public init(oPlayerName: String, xPlayerName: String) {
        self.oPlayerName = oPlayerName
        self.xPlayerName = xPlayerName
    }
    
    public var currentPlayerName: String {
        switch currentPlayer {
        case .o: return oPlayerName
        case .x: return xPlayerName
        }
    }
}

@Actions
extension Store<Game> {
    
    public func cellTapped(row: Int, column: Int) {
        guard
            state.board[row][column] == nil,
            !state.board.hasWinner
        else { return }
        
        state.board[row][column] = state.currentPlayer
        
        if !state.board.hasWinner {
            state.currentPlayer.toggle()
        }
    }
    
    public func playAgainButtonTapped() {
        state = Game(oPlayerName: state.oPlayerName, xPlayerName: state.xPlayerName)
    }
    
    public func quitButtonTapped() {
        di.dismiss()
    }
}

public enum Player: Equatable, Sendable {
	case o
	case x

	public mutating func toggle() {
		switch self {
		case .o: self = .x
		case .x: self = .o
		}
	}

	public var label: String {
		switch self {
		case .o: return "⭕️"
		case .x: return "❌"
		}
	}
}

public extension Three where Element == Three<Player?> {
	static let empty = Self(
		.init(nil, nil, nil),
		.init(nil, nil, nil),
		.init(nil, nil, nil)
	)

	var isFilled: Bool {
		allSatisfy { $0.allSatisfy { $0 != nil } }
	}

	func hasWin(_ player: Player) -> Bool {
		let winConditions = [
			[0, 1, 2], [3, 4, 5], [6, 7, 8],
			[0, 3, 6], [1, 4, 7], [2, 5, 8],
			[0, 4, 8], [6, 4, 2],
		]

		for condition in winConditions {
			let matches =
				condition
					.map { self[$0 % 3][$0 / 3] }
			let matchCount =
				matches
					.filter { $0 == player }
					.count

			if matchCount == 3 {
				return true
			}
		}
		return false
	}

	var hasWinner: Bool {
		hasWin(.x) || hasWin(.o)
	}
}
