import Foundation

extension StoreDependencies {
    
    public var tasksStore: TaskStore {
        self[\.tasksStore] ?? .shared
    }
}

@MainActor
public final class TaskStore {
    
    public static let shared = TaskStore()
    
    private var tasks: [AnyHashable: Task<Void, Never>] = [:]
    
    public func cancel(id: AnyHashable) {
        tasks[id]?.cancel()
    }
    
    fileprivate func add<T, E: Error>(for id: AnyHashable, _ task: Task<T, E>) {
        cancel(id: id)
        tasks[id] = Task { [weak self] in
            do {
                _ = try await task.value
            } catch {
            }
            self?.remove(id: id)
        }
    }
    
    fileprivate func remove(id: AnyHashable) {
        tasks[id] = nil
    }
}

extension Task {
    
    @MainActor
    @discardableResult
    public func store(in store: TaskStore, id: AnyHashable) -> Task {
        store.add(for: id, self)
        return self
    }
}
