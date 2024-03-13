import SwiftUI

extension Store {
    
    @MainActor
    /// Suspends the store from updating the UI until the block returns.
    public func withAnimation<T>(_ animation: Animation? = .default, _ update: @MainActor () throws -> T) rethrows -> T {
        try SwiftUI.withAnimation(animation) {
            try self.update(update)
        }
    }
}
