import Foundation

public protocol StoreMiddleware {

    func execute<State, Args, Res>(
        _ args: Args,
        context: Store<State>.Action<Args, Res>.Context,
        dependencies: StoreDIValues,
        next: (Args) -> Res
    ) -> Res
}

extension Store {
    
    public func middleware(_ middleware: StoreMiddleware) -> Store {
        transformDI {
            $0.middleware(middleware)
        }
    }
}

extension StoreDIValues {

    public func middleware(_ middleware: StoreMiddleware) -> StoreDIValues {
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
