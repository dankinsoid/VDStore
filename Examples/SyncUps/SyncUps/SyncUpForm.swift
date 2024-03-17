import SwiftUI
import VDStore

struct SyncUpForm: Equatable {

	var focus: Field? = .title
	var syncUp: SyncUp

	init(
		focus: Field? = .title,
		syncUp: SyncUp
	) {
		self.focus = focus
		self.syncUp = syncUp
		if self.syncUp.attendees.isEmpty {
			self.syncUp.attendees.append(Attendee(id: StoreDIValues.current.uuid()))
		}
	}

	enum Field: Hashable {
		case attendee(Attendee.ID)
		case title
	}
}

@Actions
extension Store<SyncUpForm> {

	func addAttendeeButtonTapped() {
		let attendee = Attendee(id: di.uuid())
		state.syncUp.attendees.append(attendee)
		state.focus = .attendee(attendee.id)
	}

	func deleteAttendees(atOffsets indices: IndexSet) {
		state.syncUp.attendees.remove(atOffsets: indices)
		if state.syncUp.attendees.isEmpty {
			state.syncUp.attendees.append(Attendee(id: di.uuid()))
		}
		guard let firstIndex = indices.first else { return }
		let index = min(firstIndex, state.syncUp.attendees.count - 1)
		state.focus = .attendee(state.syncUp.attendees[index].id)
	}
}

struct SyncUpFormView: View {

	@ViewStore var state: SyncUpForm
	@FocusState var focus: SyncUpForm.Field?

	init(state: SyncUpForm, focus: SyncUpForm.Field? = nil) {
		_state = ViewStore(wrappedValue: state)
		self.focus = focus
	}

	init(store: Store<SyncUpForm>, focus: SyncUpForm.Field? = nil) {
		_state = ViewStore(store: store)
		self.focus = focus
	}

	var body: some View {
		Form {
			Section {
				TextField("Title", text: $state.binding.syncUp.title)
					.focused($focus, equals: .title)
				HStack {
					Slider(value: $state.binding.syncUp.duration.minutes, in: 5 ... 30, step: 1) {
						Text("Length")
					}
					Spacer()
					Text(state.syncUp.duration.formatted(.units()))
				}
				ThemePicker(selection: $state.binding.syncUp.theme)
			} header: {
				Text("Sync-up Info")
			}
			Section {
				ForEach($state.binding.syncUp.attendees) { attendee in
					TextField("Name", text: attendee.name)
						.focused($focus, equals: .attendee(attendee.id))
				}
				.onDelete { indices in
					$state.deleteAttendees(atOffsets: indices)
				}

				Button("New attendee") {
					$state.addAttendeeButtonTapped()
				}
			} header: {
				Text("Attendees")
			}
		}
		//        .bind($state.binding.focus, to: $focus)
	}
}

struct ThemePicker: View {

	@Binding var selection: Theme

	var body: some View {
		Picker("Theme", selection: $selection) {
			ForEach(Theme.allCases) { theme in
				ZStack {
					RoundedRectangle(cornerRadius: 4)
						.fill(theme.mainColor)
					Label(theme.name, systemImage: "paintpalette")
						.padding(4)
				}
				.foregroundColor(theme.accentColor)
				.fixedSize(horizontal: false, vertical: true)
				.tag(theme)
			}
		}
	}
}

private extension Duration {
	var minutes: Double {
		get { Double(components.seconds / 60) }
		set { self = .seconds(newValue * 60) }
	}
}

#Preview {
	NavigationStack {
		SyncUpFormView(state: SyncUpForm(syncUp: .mock))
	}
}
