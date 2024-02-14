import Combine

extension StoreDependencies {

	var cancellableStorage: CancellableStorage {
		self[\.cancellableStorage] ?? .shared
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
