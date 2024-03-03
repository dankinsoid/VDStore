import Foundation

public extension StoreDIValues {

	var tasksStorage: TasksStorage {
        get { self[\.tasksStorage] ?? .shared }
        set { self[\.tasksStorage] = newValue }
	}
}

@MainActor
public final class TasksStorage {

	public static let shared = TasksStorage()

	private var tasks: [AnyHashable: CancellableTask] = [:]

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
		Task { [weak self] in
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

private protocol CancellableTask {
    
    func cancel()
}

extension Task: CancellableTask {}

public extension Store {

    @discardableResult
    func task<T>(
        id: AnyHashable,
        _ task: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        Task(operation: task).store(in: di.tasksStorage, id: id)
    }

    @discardableResult
    func task<T>(
        id: AnyHashable,
        _ task: @escaping @Sendable () async -> T
    ) -> Task<T, Never> {
        Task(operation: task).store(in: di.tasksStorage, id: id)
    }
    
    func cancel<Arg, Res>(_ action: Action<Arg, Res>.Async) {
        cancel(id: action.id)
    }
    
    func cancel<Arg, Res>(_ action: Action<Arg, Res>.AsyncThrows) {
        cancel(id: action.id)
    }
    
    func cancel(id: AnyHashable) {
        di.tasksStorage.cancel(id: id)
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
