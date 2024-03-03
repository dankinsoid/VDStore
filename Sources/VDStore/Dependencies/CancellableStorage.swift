import Combine

extension StoreDIValues {

	var cancellableStorage: CancellableStorage {
        get { self[\.cancellableStorage] ?? .shared }
        set { self[\.cancellableStorage] = newValue }
	}

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

	var count: Int { self.set.count }

	nonisolated init() {}
}
