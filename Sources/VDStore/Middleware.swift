import Foundation

/// The middleware for the store.
/// This middleware is responsible for handling the actions execution chain.
public protocol StoreMiddleware {

	/// Executes the action with given arguments and context.
	func execute<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Res
	) -> Res

	/// Executes the throwing action with given arguments and context.
	func executeThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Throws.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Result<Res, Error>
	) -> Result<Res, Error>

	/// Executes the async action with given arguments and context.
	func executeAsync<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Async.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Task<Res, Never>
	) -> Task<Res, Never>

	/// Executes the throwing async action with given arguments and context.
	func executeAsyncThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.AsyncThrows.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Task<Res, Error>
	) -> Task<Res, Error>
}

public extension StoreMiddleware {

	/// Executes the throwing action with given arguments and context.
	func executeThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Throws.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Result<Res, Error>
	) -> Result<Res, Error> {
		execute(args, context: context, dependencies: dependencies, next: next)
	}

	/// Executes the async action with given arguments and context.
	func executeAsync<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Async.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Task<Res, Never>
	) -> Task<Res, Never> {
		execute(args, context: context, dependencies: dependencies, next: next)
	}

	/// Executes the throwing async action with given arguments and context.
	func executeAsyncThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.AsyncThrows.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Task<Res, Error>
	) -> Task<Res, Error> {
		execute(args, context: context, dependencies: dependencies, next: next)
	}
}

public extension Store {

	/// Adds a middleware to the store.
	func middleware(_ middleware: StoreMiddleware) -> Store {
		di {
			$0.middleware(middleware)
		}
	}
}

public extension StoreDIValues {

	/// Adds a middleware.
	func middleware(_ middleware: StoreMiddleware) -> StoreDIValues {
		transform(\.middlewares.middlewares) {
			$0.append(middleware)
		}
	}
}

extension StoreDIValues {

	var middlewares: Middlewares {
		get { get(\.middlewares, or: Middlewares()) }
		set { set(\.middlewares, newValue) }
	}
}

struct Middlewares: StoreMiddleware {

	var middlewares: [StoreMiddleware] = []

	func execute<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Res
	) -> Res {
		var call = next
		for middleware in middlewares {
			let currentCall = call
			call = {
				middleware.execute($0, context: context, dependencies: dependencies, next: currentCall)
			}
		}
		return call(args)
	}

	func executeThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Throws.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Result<Res, Error>
	) -> Result<Res, Error> {
		var call = next
		for middleware in middlewares {
			let currentCall = call
			call = {
				middleware.executeThrows($0, context: context, dependencies: dependencies, next: currentCall)
			}
		}
		return call(args)
	}

	func executeAsync<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Async.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Task<Res, Never>
	) -> Task<Res, Never> {
		var call = next
		for middleware in middlewares {
			let currentCall = call
			call = {
				middleware.executeAsync($0, context: context, dependencies: dependencies, next: currentCall)
			}
		}
		return call(args)
	}

	func executeAsyncThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.AsyncThrows.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Task<Res, Error>
	) -> Task<Res, Error> {
		var call = next
		for middleware in middlewares {
			let currentCall = call
			call = {
				middleware.executeAsyncThrows($0, context: context, dependencies: dependencies, next: currentCall)
			}
		}
		return call(args)
	}
}
