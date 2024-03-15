import SwiftUI

public extension Store {

	@MainActor
	/// Suspends the store from updating the UI until the block returns.
	func withAnimation<T>(_ animation: Animation? = .default, _ operation: @MainActor () throws -> T) rethrows -> T {
		try SwiftUI.withAnimation(animation) {
			let result = try update(operation)
			forceUpdateIfNeeded()
			return result
		}
	}
}
