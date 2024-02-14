import Foundation

public extension StoreDependencies {

	var tasksStorage: TasksStorage {
		self[\.tasksStorage] ?? .shared
	}
}

@MainActor
public final class TasksStorage {

	public static let shared = TasksStorage()

	private var tasks: [AnyHashable: Task<Void, Never>] = [:]

	var count: Int { tasks.count }

	public func cancel(id: AnyHashable) {
		tasks[id]?.cancel()
		remove(id: id)
	}

	fileprivate func add<T, E: Error>(for id: AnyHashable, _ task: Task<T, E>) {
		cancel(id: id)
		tasks[id] = Task { [weak self] in
			do {
				_ = try await task.value
			} catch {}
			self?.remove(id: id)
		}
	}

	private func remove(id: AnyHashable) {
		tasks[id] = nil
	}
}

public extension Task {

	@MainActor
	@discardableResult
	func store(in store: TasksStorage, id: AnyHashable) -> Task {
		store.add(for: id, self)
		return self
	}
}
