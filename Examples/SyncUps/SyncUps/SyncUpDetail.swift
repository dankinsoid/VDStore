import SwiftUI
import VDFlow
import VDStore

struct SyncUpDetail: Equatable {

	var destination = Destination()
	var syncUp: SyncUp

	@Steps
	struct Destination: Equatable {
		var alert = Alert()
		var edit = SyncUpForm(syncUp: SyncUp(id: .init()))

		@Steps
		struct Alert: Equatable {
			var confirmDeletion
			var speechRecognitionDenied
			var speechRecognitionRestricted
		}
	}
}

@MainActor
protocol SyncUpDetailDelegate {
	func deleteSyncUp(syncUp: SyncUp)
	func syncUpUpdated(syncUp: SyncUp)
	func startMeeting(syncUp: SyncUp)
}

@StoreDIValuesList
extension StoreDIValues {
	var syncUpDetailDelegate: SyncUpDetailDelegate?
}

@Actions
extension Store<SyncUpDetail> {

	func cancelEditButtonTapped() {
		state.destination.selected = nil
	}

	func deleteButtonTapped() {
		state.destination.alert.confirmDeletion.select()
	}

	func deleteMeetings(atOffsets indices: IndexSet) {
		state.syncUp.meetings.remove(atOffsets: indices)
	}

	func confirmDeletion() async {
		withAnimation {
			di.syncUpDetailDelegate?.deleteSyncUp(syncUp: state.syncUp)
		}
		di.dismiss()
	}

	func continueWithoutRecording() {
		di.syncUpDetailDelegate?.startMeeting(syncUp: state.syncUp)
	}

	func openSettings() async {
		await di.openSettings()
	}

	func doneEditingButtonTapped() {
		state.syncUp = state.destination.edit.syncUp
		di.syncUpDetailDelegate?.syncUpUpdated(syncUp: state.syncUp)
		state.destination.selected = nil
	}

	func editButtonTapped() {
		state.destination.edit = SyncUpForm(syncUp: state.syncUp)
	}

	func startMeetingButtonTapped() {
		switch di.speechClient.authorizationStatus() {
		case .notDetermined, .authorized:
			di.syncUpDetailDelegate?.startMeeting(syncUp: state.syncUp)

		case .denied:
			state.destination.alert.speechRecognitionDenied.select()

		case .restricted:
			state.destination.alert.speechRecognitionRestricted.select()

		@unknown default:
			break
		}
	}
}

struct SyncUpDetailView: View {

	@ViewStore var state: SyncUpDetail
	@StateStep var feature = AppFeature.Path()

	init(state: SyncUpDetail) {
		_state = ViewStore(wrappedValue: state)
	}

	init(store: Store<SyncUpDetail>) {
		_state = ViewStore(store: store)
	}

	var body: some View {
		Form {
			Section {
				Button {
					$state.startMeetingButtonTapped()
				} label: {
					Label("Start Meeting", systemImage: "timer")
						.font(.headline)
						.foregroundColor(.accentColor)
				}
				HStack {
					Label("Length", systemImage: "clock")
					Spacer()
					Text(state.syncUp.duration.formatted(.units()))
				}

				HStack {
					Label("Theme", systemImage: "paintpalette")
					Spacer()
					Text(state.syncUp.theme.name)
						.padding(4)
						.foregroundColor(state.syncUp.theme.accentColor)
						.background(state.syncUp.theme.mainColor)
						.cornerRadius(4)
				}
			} header: {
				Text("Sync-up Info")
			}

			if !state.syncUp.meetings.isEmpty {
				Section {
					ForEach(state.syncUp.meetings) { meeting in
						Button {
							feature.meeting = AppFeature.Path.MeetingSyncUp(meeting: meeting, syncUp: state.syncUp)
						} label: {
							HStack {
								Image(systemName: "calendar")
								Text(meeting.date, style: .date)
								Text(meeting.date, style: .time)
							}
						}
					}
					.onDelete { indices in
						$state.deleteMeetings(atOffsets: indices)
					}
				} header: {
					Text("Past meetings")
				}
			}

			Section {
				ForEach(state.syncUp.attendees) { attendee in
					Label(attendee.name, systemImage: "person")
				}
			} header: {
				Text("Attendees")
			}

			Section {
				Button("Delete") {
					$state.deleteButtonTapped()
				}
				.foregroundColor(.red)
				.frame(maxWidth: .infinity)
			}
		}
		.toolbar {
			Button("Edit") {
				$state.editButtonTapped()
			}
		}
		.navigationTitle(state.syncUp.title)
		.deleteSyncUpAlert(store: $state)
		.speechRecognitionDeniedAlert(store: $state)
		.speechRecognitionRestrictedAlert(store: $state)
		.sheet(
			isPresented: $state.binding.destination.isSelected(.edit)
		) {
			NavigationStack {
				SyncUpFormView(store: $state.destination.edit)
					.navigationTitle(state.syncUp.title)
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Cancel") {
								$state.cancelEditButtonTapped()
							}
						}
						ToolbarItem(placement: .confirmationAction) {
							Button("Done") {
								$state.doneEditingButtonTapped()
							}
						}
					}
			}
		}
	}
}

@MainActor
extension View {

	func deleteSyncUpAlert(store: Store<SyncUpDetail>) -> some View {
		alert(
			"Delete?",
			isPresented: store.binding.destination.alert.isSelected(.confirmDeletion)
		) {
			Button("Yes", role: .destructive) {
				Task {
					await store.confirmDeletion()
				}
			}
			Button("Nevermind", role: .cancel) {}
		} message: {
			Text("Are you sure you want to delete this meeting?")
		}
	}

	func speechRecognitionDeniedAlert(store: Store<SyncUpDetail>) -> some View {
		alert(
			"Speech recognition denied",
			isPresented: store.binding.destination.alert.isSelected(.speechRecognitionDenied)
		) {
			Button("Continue without recording") {
				store.continueWithoutRecording()
			}
			Button("Open settings") {
				Task {
					await store.openSettings()
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(
				"""
				You previously denied speech recognition and so your meeting will not be recorded. You can \
				enable speech recognition in settings, or you can continue without recording.
				"""
			)
		}
	}

	func speechRecognitionRestrictedAlert(store: Store<SyncUpDetail>) -> some View {
		alert(
			"Speech recognition restricted",
			isPresented: store.binding.destination.alert.isSelected(.speechRecognitionRestricted)
		) {
			Button("Continue without recording") {
				store.continueWithoutRecording()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(
				"""
				Your device does not support speech recognition and so your meeting will not be recorded.
				"""
			)
		}
	}
}

#Preview {
	NavigationStack {
		SyncUpDetailView(state: SyncUpDetail(syncUp: .mock))
	}
}
