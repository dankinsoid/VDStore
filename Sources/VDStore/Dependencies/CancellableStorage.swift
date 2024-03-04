import Combine

extension StoreDIValues {

	var cancellableStorage: CancellableStorage {
		get { self[\.cancellableStorage] ?? .shared }
		set { self[\.cancellableStorage] = newValue }
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
