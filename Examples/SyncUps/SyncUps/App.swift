import SwiftUI
import VDStore

@main
struct SyncUpsApp: App {

	let store = Store(AppFeature())

	var body: some Scene {
		WindowGroup {
			// NB: This conditional is here only to facilitate UI testing so that we can mock out certain
			//     dependencies for the duration of the test (e.g. the data manager). We do not really
			//     recommend performing UI tests in general, but we do want to demonstrate how it can be
			//     done.
			if _XCTIsTesting {
				// NB: Don't run application when testing so that it doesn't interfere with tests.
				EmptyView()
			} else {
				AppView(
					store: store
						.transformDI {
							if ProcessInfo.processInfo.environment["UITesting"] == "true" {
								$0.dataManager = .mock()
							}
						}
						.saveOnChange
				)
			}
		}
	}
}
