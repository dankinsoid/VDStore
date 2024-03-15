import SwiftUI
import VDFlow
import VDStore

struct SyncUpsList: Equatable {

	var destination = Destination()
	var syncUps: [SyncUp] = []

	init(
		destination: Destination.Steps? = nil,
		syncUps: () throws -> [SyncUp] = { [] }
	) {
		self.destination = Destination(destination)
		do {
			self.syncUps = try syncUps()
		} catch is DecodingError {
			self.destination.selected = .confirmLoadMockData
		} catch {
			self.syncUps = []
		}
	}

	@Steps
	struct Destination: Equatable {

		var add = SyncUpForm(syncUp: SyncUp(id: .init()))
		var confirmLoadMockData
	}
}

@Actions
extension Store<SyncUpsList> {

	func addSyncUpButtonTapped() {
		state.destination.add = SyncUpForm(syncUp: SyncUp(id: di.uuid()))
	}

	func confirmAddSyncUpButtonTapped() {
		var syncUp = state.destination.add.syncUp
		syncUp.attendees.removeAll { attendee in
			attendee.name.allSatisfy(\.isWhitespace)
		}
		if syncUp.attendees.isEmpty {
			syncUp.attendees.append(
				state.destination.add.syncUp.attendees.first ?? Attendee(id: di.uuid())
			)
		}
		state.syncUps.append(syncUp)
		state.destination.selected = nil
	}

	func destinationPresented() {
		state.destination.confirmLoadMockData.select()
		state.syncUps = [
			.mock,
			.designMock,
			.engineeringMock,
		]
	}

	func dismissAddSyncUpButtonTapped() {
		state.destination.selected = nil
	}

	func onDelete(indexSet: IndexSet) {
		state.syncUps.remove(atOffsets: indexSet)
	}
}

struct SyncUpsListView: View {

	@ViewStore var state: SyncUpsList
	@StateStep var feature = AppFeature.Path()

	init(state: SyncUpsList) {
		_state = ViewStore(wrappedValue: state)
	}

	init(store: Store<SyncUpsList>) {
		_state = ViewStore(store: store)
	}

	var body: some View {
		List {
			ForEach(state.syncUps) { syncUp in
				Button {
					feature.detail = SyncUpDetail(syncUp: syncUp)
				} label: {
					CardView(syncUp: syncUp)
				}
				.listRowBackground(syncUp.theme.mainColor)
			}
			.onDelete {
				$state.onDelete(indexSet: $0)
			}
		}
		.toolbar {
			Button {
				$state.addSyncUpButtonTapped()
			} label: {
				Image(systemName: "plus")
			}
		}
		.navigationTitle("Daily Sync-ups")
		.syncUpsListAlert($state)
		.sheet(
			isPresented: $state.binding.destination.isSelected(.add)
		) {
			NavigationStack {
				SyncUpFormView(store: $state.destination.add)
					.navigationTitle("New sync-up")
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Dismiss") {
								$state.dismissAddSyncUpButtonTapped()
							}
						}
						ToolbarItem(placement: .confirmationAction) {
							Button("Add") {
								$state.confirmAddSyncUpButtonTapped()
							}
						}
					}
			}
		}
	}
}

extension View {

	@MainActor
	func syncUpsListAlert(
		_ store: Store<SyncUpsList>
	) -> some View {
		alert(
			"Data failed to load",
			isPresented: Binding {
				store.state.destination.selected == .confirmLoadMockData
			} set: {
				if $0 {
					store.destinationPresented()
				}
			}
		) {
			Button("Yes") {
				store.withAnimation {
					store.destinationPresented()
				}
			}
			Button("No", role: .cancel) {}
		} message: {
			Text(
				"""
				Unfortunately your past data failed to load. Would you like to load some mock data to play \
				around with?
				"""
			)
		}
	}
}

struct CardView: View {
	let syncUp: SyncUp

	var body: some View {
		VStack(alignment: .leading) {
			Text(syncUp.title)
				.font(.headline)
			Spacer()
			HStack {
				Label("\(syncUp.attendees.count)", systemImage: "person.3")
				Spacer()
				Label(syncUp.duration.formatted(.units()), systemImage: "clock")
					.labelStyle(.trailingIcon)
			}
			.font(.caption)
		}
		.padding()
		.foregroundColor(syncUp.theme.accentColor)
	}
}

struct TrailingIconLabelStyle: LabelStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack {
			configuration.title
			configuration.icon
		}
	}
}

extension LabelStyle where Self == TrailingIconLabelStyle {
	static var trailingIcon: Self { Self() }
}

#Preview {
	SyncUpsListView(
		store: Store(
			SyncUpsList { [
				SyncUp.mock,
				.designMock,
				.engineeringMock,
			] }
		)
	)
}

#Preview("Load data failure") {
	SyncUpsListView(
		store: Store(
			SyncUpsList {
				try JSONDecoder().decode([SyncUp].self, from: Data("!@#$% bad data ^&*()".utf8))
			}
		)
	)
	.previewDisplayName("Load data failure")
}

#Preview("Card") {
	CardView(
		syncUp: SyncUp(
			id: SyncUp.ID(),
			attendees: [],
			duration: .seconds(60),
			meetings: [],
			theme: .bubblegum,
			title: "Point-Free Morning Sync"
		)
	)
}
