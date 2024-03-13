import VDStore
import SwiftUI
import VDFlow

struct AppFeature: Equatable {

    var path = Path(.detail)
    var syncUpsList = SyncUpsList()

    @Steps
    struct Path: Equatable {
        var detail: SyncUpDetail?
        var meeting = MeetingSyncUp()
        var record: RecordMeeting?
        
        struct MeetingSyncUp: Equatable {
            var meeting: Meeting?
            var syncUp: SyncUp?
        }
    }
}

@Actions
extension Store<AppFeature> {

    func setPathDetail(id: String, detail: SyncUpDetail) {
        switch detail {
        case let .delegate(delegateAction):
            guard case let .some(.detail(detailState)) = state.path[id: id] else { return .none }
            switch delegateAction {
            case .deleteSyncUp:
                state.syncUpsList.syncUps.remove(id: detailState.syncUp.id)
                return .none
                
            case let .syncUpUpdated(syncUp):
                state.syncUpsList.syncUps[id: syncUp.id] = syncUp
                return .none
                
            case .startMeeting:
                state.path.append(.record(RecordMeeting.State(syncUp: detailState.syncUp)))
                return .none
            }
        }
    }
    
    func setPathRecord(id: String, record: RecordMeeting) {
        switch delegateAction {
        case let .save(transcript: transcript):
            guard let id = state.path.ids.dropLast().last
            else {
                XCTFail(
              """
              Record meeting is the only element in the stack. A detail feature should precede it.
              """
                )
                return .none
            }
            
            state.path[id: id]?.detail?.syncUp.meetings.insert(
                Meeting(
                    id: Meeting.ID(self.uuid()),
                    date: self.now,
                    transcript: transcript
                ),
                at: 0
            )
            guard let syncUp = state.path[id: id]?.detail?.syncUp
            else { return .none }
            state.syncUpsList.syncUps[id: syncUp.id] = syncUp
            return .none
        }
    }

    var saveOnChange: Self {
        onChange(of: \.syncUpsList.syncUps) { _, syncUps, _ in
            Task {
                try await debounceSave(syncUps: syncUps)
            }
        }
    }

    func debounceSave(syncUps: [SyncUp]) async throws {
        cancel(Self.debounceSave)
        try await di.clock.sleep(for: .seconds(1))
        try await di.dataManager.save(JSONEncoder().encode(syncUps), .syncUps)
    }
}

struct AppView: View {
    
    @ViewStore var state: AppFeature
    
    var body: some View {
        NavigationStack(path: $state.binding.path.navigationPath) {
            SyncUpsListView(store: $state.syncUpsList)
                .navigationDestination($state.path.binding, for: \.$detail) {
                    SyncUpDetailView(store: $state.syncUpsList)
                }
                .navigationDestination($state.path.binding, \.$meeting) {
                    MeetingView(meeting: meeting, syncUp: syncUp)
                }
                .navigationDestination($state.path.binding, for: \.$record) {
                    RecordMeetingView(store: $state.syncUpsList)
                }
        }
        .stepEnvironment($state.binding.path)
    }
}

extension URL {
  static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
}
