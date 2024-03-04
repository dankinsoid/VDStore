import Foundation

extension Store {

    public struct Action<Args, Res>: Identifiable {

        public let id: StoreActionID
        public var name: String { id.name }
        let action: @MainActor (Store<State>, Args) -> Res

        public init(
            id: StoreActionID,
            action: @escaping @MainActor (Store<State>, Args) -> Res
        ) {
            self.id = id
            self.action = action
        }
    }
}

public extension Store.Action {

    typealias Throws = Store.Action<Args, Result<Res, Error>>
    typealias Async = Store.Action<Args, Task<Res, Never>>
    typealias AsyncThrows = Store.Action<Args, Task<Res, Error>>
}

extension Store.Action: CustomStringConvertible {

    public var description: String {
        "Store<\(State.self)>.\(id.name)"
    }
}

extension Store.Action: CustomDebugStringConvertible {

    public var debugDescription: String {
        "Store<\(State.self)>.Action<\(Args.self), \(Res.self)>.\(id)"
    }
}

public extension Store.Action where Res == Void {

    typealias Return<T> = Store.Action<Args, T>
}

public extension Store.Action {

    init(
        id: StoreActionID,
        action: @escaping (Store<State>) -> @MainActor (Args) -> Res
    ) {
        self.init(id: id) { store, args in
            store.update {
                action(store)(args)
            }
        }
    }

    init<T>(
        id: StoreActionID,
        action: @escaping @Sendable (Store<State>) -> @MainActor (Args) async -> T
    ) where Res == Task<T, Never> {
        self.init(id: id) { store, args in
            store.task(id: id) {
                await action(store)(args)
            }
        }
    }

    init<T>(
        id: StoreActionID,
        action: @escaping @Sendable (Store<State>) -> @MainActor (Args) async throws -> T
    ) where Res == Task<T, Error> {
        self.init(id: id) { store, args in
            store.task(id: id) {
                try await action(store)(args)
            }
        }
    }

    init<T>(
        id: StoreActionID,
        action: @escaping (Store<State>) -> @MainActor (Args) throws -> T
    ) where Res == Result<T, Error> {
        self.init(id: id) { store, args in
            store.update {
                Result {
                    try action(store)(args)
                }
            }
        }
    }
}

extension Store.Action {

    public struct Context: Hashable {

        public let actionID: StoreActionID
        public let file: String
        public let line: UInt
        public let function: String

        public init(
            actionID: StoreActionID,
            file: String,
            line: UInt,
            function: String
        ) {
            self.actionID = actionID
            self.file = file
            self.line = line
            self.function = function
        }
    }
}

extension Store {

    public func execute<Args, Res>(
        _ action: Action<Args, Res>,
        with args: Args,
        file: String,
        line: UInt,
        from function: String
    ) -> Res {
        let closure = {
            action.action(self, $0)
        }
        return di.middlewares.execute(
            args,
            context: Store<State>.Action<Args, Res>.Context(
                actionID: action.id,
                file: file,
                line: line,
                function: function
            ),
            dependencies: di
        ) { args in
            closure(args)
        }
    }

    public func execute<Args, Res>(
        _ action: Action<Args, Result<Res, Error>>,
        with args: Args,
        file: String,
        line: UInt,
        from function: String
    ) throws -> Res {
        try execute(
            action,
            with: args,
            file: file,
            line: line,
            from: function
        )
        .get()
    }

    public func execute<Args, Res>(
        _ action: Action<Args, Task<Res, Never>>,
        with args: Args,
        file: String,
        line: UInt,
        from function: String
    ) async -> Res {
        await execute(
            action,
            with: args,
            file: file,
            line: line,
            from: function
        )
        .value
    }

    public func execute<Args, Res>(
        _ action: Action<Args, Task<Res, Error>>,
        with args: Args,
        file: String,
        line: UInt,
        from function: String
    ) async throws -> Res {
        try await execute(
            action,
            with: args,
            file: file,
            line: line,
            from: function
        )
        .value
    }

    public func execute<Res>(
        file: String = #fileID,
        line: UInt = #line,
        from function: String = #function,
        action: @MainActor @escaping () -> Res
    ) -> Res {
        execute(
            Action<Void, Res>(
                id: StoreActionID(name: "anonymous", fileID: file, line: line),
                action: { _, _ in
                    action()
                }
            ),
            with: (),
            file: file,
            line: line,
            from: function
        )
    }

    public func execute<Res>(
        file: String = #fileID,
        line: UInt = #line,
        from function: String = #function,
        action: @MainActor @escaping () throws -> Res
    ) throws -> Res {
        try execute(
            Action<Void, Result<Res, Error>>(
                id: StoreActionID(name: "anonymous", fileID: file, line: line),
                action: { _ in
                    { _ in try action() }
                }
            ),
            with: (),
            file: file,
            line: line,
            from: function
        )
    }

    public func execute<Res>(
        file: String = #fileID,
        line: UInt = #line,
        from function: String = #function,
        action: @MainActor @escaping () async throws -> Res
    ) async throws -> Res {
        try await execute(
            Action<Void, Task<Res, Error>>(
                id: StoreActionID(name: "anonymous", fileID: file, line: line),
                action: { _ in
                    { _ in try await action() }
                }
            ),
            with: (),
            file: file,
            line: line,
            from: function
        )
    }

    public func execute<Res>(
        file: String = #fileID,
        line: UInt = #line,
        from function: String = #function,
        action: @MainActor @escaping () async -> Res
    ) async -> Res {
        await execute(
            Action<Void, Task<Res, Never>>(
                id: StoreActionID(name: "anonymous", fileID: file, line: line),
                action: { _ in
                    { _ in await action() }
                }
            ),
            with: (),
            file: file,
            line: line,
            from: function
        )
    }
}

public struct StoreActionID: Hashable, CustomStringConvertible {

    public let name: String
    public let fileID: String
    public let line: UInt

    public init(name: String, fileID: String, line: UInt) {
        self.name = name
        self.fileID = fileID
        self.line = line
    }

    public var description: String {
        "\(fileID):\(line) \(name)"
    }
}
