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

    public init() {
    }

	public func cancel(id: AnyHashable) {
		tasks[id]?.cancel()
		remove(id: id)
	}

	fileprivate func add<T, E: Error>(for id: AnyHashable, _ task: Task<T, E>) {
		cancel(id: id)
        var isFinished = false
		let task = Task { [weak self] in
            _ = try? await task.value
            self?.remove(id: id)
            isFinished = true
		}
        if !isFinished {
            tasks[id] = task
        }
	}

	private func remove(id: AnyHashable) {
		tasks[id] = nil
	}
}

public extension Store {

    @discardableResult
    func task<T>(
        id: AnyHashable,
        _ task: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        Task(operation: task).store(in: dependencies.tasksStorage, id: id)
    }

    @discardableResult
    func task<T>(
        id: AnyHashable,
        _ task: @escaping @Sendable () async -> T
    ) -> Task<T, Never> {
        Task(operation: task).store(in: dependencies.tasksStorage, id: id)
    }
    
    func cancel<Arg, Res>(_ action: Action<Arg, Res>.Async) {
        dependencies.tasksStorage.cancel(id: action.id)
    }
    
    func cancel<Arg, Res>(_ action: Action<Arg, Res>.AsyncThrows) {
        dependencies.tasksStorage.cancel(id: action.id)
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
