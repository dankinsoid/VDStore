import SwiftUI
import VDFlow
import VDStore

struct AppFeature: Equatable {

	var path = Path(.list)
	var syncUpsList = SyncUpsList()

	@Steps
	struct Path: Equatable {
		var list
		var detail = SyncUpDetail(syncUp: .engineeringMock)
		var meeting = MeetingSyncUp()
		var record: RecordMeeting = .mock

		struct MeetingSyncUp: Equatable {
			var meeting: Meeting = .mock
			var syncUp: SyncUp = .engineeringMock
		}
	}
}

@Actions
extension Store<AppFeature>: SyncUpDetailDelegate {

	func deleteSyncUp(syncUp: SyncUp) {
		state.syncUpsList.syncUps.removeAll {
			$0.id == syncUp.id
		}
	}

	func syncUpUpdated(syncUp: SyncUp) {
		if let i = state.syncUpsList.syncUps.firstIndex(where: { $0.id == syncUp.id }) {
			state.syncUpsList.syncUps[i] = syncUp
		}
	}

	func startMeeting(syncUp: SyncUp) {
		state.path.record = RecordMeeting(syncUp: syncUp)
	}
}

@Actions
extension Store<AppFeature>: RecordMeetingDelegate {

	func savePath(transcript: String) {
		guard let i = state.syncUpsList.syncUps.firstIndex(where: { $0.id == state.path.detail.syncUp.id }) else { return }
		state.syncUpsList.syncUps[i] = state.path.detail.syncUp
	}

	func debounceSave(syncUps: [SyncUp]) async throws {
		cancel(Self.debounceSave)
		//        try await di.clock.sleep(for: .seconds(1))
		try await di.dataManager.save(JSONEncoder().encode(syncUps), .syncUps)
	}
}

extension Store<AppFeature> {

	var saveOnChange: Self {
		onChange(of: \.syncUpsList.syncUps) { _, syncUps, _ in
			Task {
				try await debounceSave(syncUps: syncUps)
			}
		}
	}
}

struct AppView: View {

	@ViewStore var state: AppFeature

	init(state: AppFeature) {
		self.state = state
	}

	init(store: Store<AppFeature>) {
		_state = ViewStore(store: store)
	}

	var body: some View {
		NavigationSteps(selection: $state.binding.path.selected) {
			listView
			detailView

			if state.path.selected == .record {
				recordView
			}
			if state.path.selected == .meeting {
				meetingView
			}
		}
		.stepEnvironment($state.binding.path)
	}

	private var listView: some View {
		SyncUpsListView(store: $state.syncUpsList)
			.step($state.binding.path, \.$list)
	}

	private var detailView: some View {
		SyncUpDetailView(
			store: $state.path.detail
				.di(\.syncUpDetailDelegate, $state)
		)
		.step($state.binding.path, \.$detail)
	}

	private var meetingView: some View {
		MeetingView(
			meeting: state.path.meeting.meeting,
			syncUp: state.path.meeting.syncUp
		)
		.step($state.binding.path, \.$meeting)
	}

	private var recordView: some View {
		RecordMeetingView(
			store: $state.path.record
				.di(\.recordMeetingDelegate, $state)
		)
		.step($state.binding.path, \.$record)
	}
}

extension URL {
	static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
}
