import UIKit
import VDStore

extension StoreDIValues {

	var openSettings: @Sendable () async -> Void {
		get { self[\.openSettings] ?? Self.openSettings }
		set { self[\.openSettings] = newValue }
	}

	private static let openSettings: @Sendable () async -> Void = {
		await MainActor.run {
			UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
		}
	}
}
