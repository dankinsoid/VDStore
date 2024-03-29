import SwiftUI
import VDFlow
import VDStore

struct AppFeature: Equatable {

	var path: Path = .list
	var syncUpsList = SyncUpsList()

	@Steps
	struct Path: Equatable {
		var list
		var detail: SyncUpDetail = .init(syncUp: .engineeringMock)
		var meeting: MeetingSyncUp = .init()
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
		state.path.$record.select(with: RecordMeeting(syncUp: syncUp))
	}
}

@Actions
extension Store<AppFeature>: RecordMeetingDelegate {

	func savePath(transcript: String) {
		guard let i = state.syncUpsList.syncUps.firstIndex(where: { $0.id == state.path.detail.syncUp.id }) else { return }
		state.syncUpsList.syncUps[i] = state.path.detail.syncUp
	}

	@CancelInFlight
	func debounceSave(syncUps: [SyncUp]) async throws {
		try await di.continuousClock.sleep(for: .seconds(1))
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
		_state = ViewStore(wrappedValue: state)
	}

	init(store: Store<AppFeature>) {
		_state = ViewStore(store)
	}

	var body: some View {
		NavigationSteps(
			selection: _state.path.selected
		) {
			listView
			detailView

			if state.path.selected == .record {
				recordView
			}
			if state.path.selected == .meeting {
				meetingView
			}
		}
		.stepEnvironment(_state.path)
	}

	private var listView: some View {
		SyncUpsListView(store: $state.syncUpsList)
			.step(_state.path.$list)
	}

	private var detailView: some View {
		SyncUpDetailView(
			store: $state.path.detail
				.di(\.syncUpDetailDelegate, $state)
		)
		.step(_state.path.$detail)
	}

	private var meetingView: some View {
		MeetingView(
			meeting: state.path.meeting.meeting,
			syncUp: state.path.meeting.syncUp
		)
		.step(_state.path.$meeting)
	}

	private var recordView: some View {
		RecordMeetingView(
			store: $state.path.record
				.di(\.recordMeetingDelegate, $state)
		)
		.step(_state.path.$record)
	}
}

extension URL {
	static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
}
