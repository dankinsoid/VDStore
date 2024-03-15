import Combine
import Dependencies

extension DependencyValues {

	var cancellableStorage: CancellableStorage {
        get { self[CancellableStorage.self] }
        set { self[CancellableStorage.self] = newValue }
	}

	/// Stores cancellables for Combine subscriptions.
	@MainActor
	public var cancellableSet: Set<AnyCancellable> {
		get { cancellableStorage.set }
		nonmutating set { cancellableStorage.set = newValue }
	}
}

@MainActor
final class CancellableStorage {

	static let shared = CancellableStorage()

	var set: Set<AnyCancellable> = []

	nonisolated init() {}
}

extension CancellableStorage: DependencyKey {
    
    static let liveValue = CancellableStorage.shared
}
