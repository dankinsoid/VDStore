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
}

public extension Store {

	/// Adds a middleware to the store.
	func middleware(_ middleware: StoreMiddleware) -> Store {
		transformDI {
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
		get { self[\.middlewares] ?? Middlewares() }
		set { self[\.middlewares] = newValue }
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
}