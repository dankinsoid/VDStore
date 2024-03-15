import Foundation
import Dependencies

/// The middleware for the store.
/// This middleware is responsible for handling the actions execution chain.
public protocol StoreMiddleware {

	/// Executes the action with given arguments and context.
	func execute<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Context,
		dependencies: DependencyValues,
		next: (Args) -> Res
	) -> Res
}

public extension Store {

	/// Adds a middleware to the store.
	func middleware(_ middleware: StoreMiddleware) -> Store {
		transformDependency {
            $0.set(middleware: middleware)
		}
	}
}

public extension DependencyValues {

	/// Adds a middleware.
	mutating func set(middleware: StoreMiddleware) {
		middlewares.middlewares.append(middleware)
	}
}

extension DependencyValues {

	var middlewares: Middlewares {
        get { self[Middlewares.self] }
        set { self[Middlewares.self] = newValue }
	}
}

extension Middlewares: DependencyKey {
    static let liveValue = Middlewares()
}

struct Middlewares: StoreMiddleware {

	var middlewares: [StoreMiddleware] = []

	func execute<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Context,
		dependencies: DependencyValues,
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
