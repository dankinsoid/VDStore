import Combine

extension StoreDIValues {

	var cancellableStorage: CancellableStorage {
		get { get(\.cancellableStorage, or: .shared) }
		set { set(\.cancellableStorage, newValue) }
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
