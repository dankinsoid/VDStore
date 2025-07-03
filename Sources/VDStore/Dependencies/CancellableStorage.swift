import Combine

extension DIValues {

	var cancellableStorage: CancellableStorage {
		get { get(\.cancellableStorage, or: .shared) }
		set { set(\.cancellableStorage, newValue) }
	}

	/// Stores cancellables for Combine subscriptions.
	public var cancellableSet: Set<AnyCancellable> {
		get { cancellableStorage.set }
		nonmutating set { cancellableStorage.set = newValue }
	}
}

final class CancellableStorage {

	static nonisolated let shared = CancellableStorage()

	var set: Set<AnyCancellable> = []

	nonisolated init() {}
}
