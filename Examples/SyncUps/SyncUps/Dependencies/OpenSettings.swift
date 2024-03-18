import UIKit
import VDStore

extension StoreDIValues {

	@StoreDIValue var openSettings: @Sendable () async -> Void = Self.openSettings

	private static let openSettings: @Sendable () async -> Void = {
		await MainActor.run {
			UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
		}
	}
}
