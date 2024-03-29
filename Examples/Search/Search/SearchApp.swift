import SwiftUI
import VDStore

@main
struct SearchApp: App {

	var body: some Scene {
		WindowGroup {
			SearchView()
				.storeDIValues {
					$0.middleware(LoggerMiddleware())
				}
		}
	}
}

struct LoggerMiddleware: StoreMiddleware {

	func execute<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Context,
		dependencies: StoreDIValues,
		next: (Args) -> Res
	) -> Res {
		print("\(context.actionID) called from \(context.file):\(context.line)  \(context.function)")
		return next(args)
	}
}
