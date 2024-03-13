import Foundation

public extension Store where State: MutableCollection {
    
    @MainActor
    func forEach(_ operation: (Store<State.Element>) throws -> Void) rethrows {
        for index in state.indices {
            try operation(self[index])
        }
    }
    
    @MainActor
    func forEach(_ operation: (Store<State.Element>) async throws -> Void) async rethrows {
        for index in state.indices {
            try await operation(self[index])
        }
    }
}
