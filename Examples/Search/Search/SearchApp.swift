import SwiftUI
import VDStore

@main
struct SearchApp: App {

	var body: some Scene {
		WindowGroup {
			SearchView()
                .storeDependencies {
                    $0.middleware(LoggerMiddleware())
                }
		}
	}
}
