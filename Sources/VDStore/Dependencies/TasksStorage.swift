import Foundation

public extension StoreDIValues {

	/// Returns the storage of async tasks. Allows to store and cancel tasks.
	var tasksStorage: TasksStorage {
		get { get(\.tasksStorage, or: .shared) }
		set { set(\.tasksStorage, newValue) }
	}
}

/// The storage of async tasks. Allows to store and cancel tasks.
@MainActor
public final class TasksStorage {

	/// The shared instance of the storage.
	public static let shared = TasksStorage()

	private var tasks: [AnyHashable: CancellableTask] = [:]

	var count: Int { tasks.count }

	public init() {}

	/// Cancel a task by its cancellation id.
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

	/// Create a throwing task with cancellation id.
	@discardableResult
	func task<T>(
		id: AnyHashable,
		_ task: @escaping @Sendable () async throws -> T
	) -> Task<T, Error> {
		Task {
			try await withDIValues(operation: task)
		}
		.store(in: di.tasksStorage, id: id)
	}

	/// Create a task with cancellation id.
	@discardableResult
	func task<T>(
		id: AnyHashable,
		_ task: @escaping @Sendable () async -> T
	) -> Task<T, Never> {
		Task(operation: task).store(in: di.tasksStorage, id: id)
	}

	/// Cancel an async store action.
	/// Action is a static property generated by `@Actions` macro for each method.
	func cancel<Arg, Res>(_ action: Action<Arg, Res>.Async) {
		cancel(id: action.id)
	}

	/// Cancel an async throwing store action.
	/// Action is a static property generated by `@Actions` macro for each method.
	func cancel<Arg, Res>(_ action: Action<Arg, Res>.AsyncThrows) {
		cancel(id: action.id)
	}

	/// Cancel a task by its cancellation id.
	func cancel(id: AnyHashable) {
		di.tasksStorage.cancel(id: id)
	}
}

public extension Task {

	/// Store the task in the storage by it cancellation id.
	@MainActor
	@discardableResult
	func store(in storage: TasksStorage, id: AnyHashable) -> Task {
		storage.add(for: id, self)
		return self
	}
}
