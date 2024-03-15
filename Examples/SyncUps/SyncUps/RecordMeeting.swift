@preconcurrency import Speech
import SwiftUI
import VDFlow
import VDStore

struct RecordMeeting: Equatable {

	var alert = Alert()
	var secondsElapsed = 0
	var speakerIndex = 0
	var syncUp: SyncUp
	var transcript = ""

	var durationRemaining: Duration {
		syncUp.duration - .seconds(secondsElapsed)
	}

	@Steps
	struct Alert: Equatable {
		var endMeeting = true
		var speechRecognizerFailed
	}

	static let mock = RecordMeeting(syncUp: .engineeringMock)
}

@MainActor
protocol RecordMeetingDelegate {
	func savePath(transcript: String)
}

@StoreDIValuesList
extension StoreDIValues {
	var recordMeetingDelegate: RecordMeetingDelegate?
}

extension Store<RecordMeeting> {

	func confirmDiscard() {
		di.dismiss()
	}

	func save() {
		state.syncUp.meetings.insert(
			Meeting(
				id: di.uuid(),
				date: Date(), // di.now,
				transcript: state.transcript
			),
			at: 0
		)
		di.recordMeetingDelegate?.savePath(transcript: state.transcript)
		di.dismiss()
	}

	func endMeetingButtonTapped() {
		state.alert.endMeeting = true
	}

	func nextButtonTapped() {
		guard state.speakerIndex < state.syncUp.attendees.count - 1
		else {
			state.alert.endMeeting = false
			return
		}
		state.speakerIndex += 1
		state.secondsElapsed =
			state.speakerIndex * Int(state.syncUp.durationPerAttendee.components.seconds)
	}

	func onTask() async {
		let authorization =
			await di.speechClient.authorizationStatus() == .notDetermined
				? di.speechClient.requestAuthorization()
				: di.speechClient.authorizationStatus()

		await withTaskGroup(of: Void.self) { group in
			if authorization == .authorized {
				group.addTask {
					await startSpeechRecognition()
				}
			}
			group.addTask {
				//                for await _ in di.clock.timer(interval: .seconds(1)) {
				//                    await send(.timerTick)
				//                }
			}
		}
	}

	func timerTick() {
		guard state.alert.selected == nil else { return }

		state.secondsElapsed += 1

		let secondsPerAttendee = Int(state.syncUp.durationPerAttendee.components.seconds)
		if state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
			if state.speakerIndex == state.syncUp.attendees.count - 1 {
				save()
				return
			}
			state.speakerIndex += 1
		}
	}

	func startSpeechRecognition() async {
		do {
			let speechTask = await di.speechClient.startTask(SFSpeechAudioBufferRecognitionRequest())
			for try await result in speechTask {
				state.transcript = result.bestTranscription.formattedString
			}
		} catch {
			speechFailure()
		}
	}

	func speechFailure() {
		if !state.transcript.isEmpty {
			state.transcript += " ❌"
		}
		state.alert.speechRecognizerFailed.select()
	}
}

struct RecordMeetingView: View {

	@ViewStore var state: RecordMeeting

	init(state: RecordMeeting) {
		self.state = state
	}

	init(store: Store<RecordMeeting>) {
		_state = ViewStore(store: store)
	}

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 16)
				.fill(state.syncUp.theme.mainColor)

			VStack {
				MeetingHeaderView(
					secondsElapsed: state.secondsElapsed,
					durationRemaining: state.durationRemaining,
					theme: state.syncUp.theme
				)
				MeetingTimerView(
					syncUp: state.syncUp,
					speakerIndex: state.speakerIndex
				)
				MeetingFooterView(
					syncUp: state.syncUp,
					nextButtonTapped: {
						$state.nextButtonTapped()
					},
					speakerIndex: state.speakerIndex
				)
			}
		}
		.padding()
		.foregroundColor(state.syncUp.theme.accentColor)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .cancellationAction) {
				Button("End meeting") {
					$state.endMeetingButtonTapped()
				}
			}
		}
		.navigationBarBackButtonHidden(true)
		.endMeetingAlert(store: $state)
		.speechRecognizerFailedAlert(store: $state)
		.task {
			await $state.onTask()
		}
	}
}

@MainActor
extension View {

	func endMeetingAlert(store: Store<RecordMeeting>) -> some View {
		alert(
			"End meeting?",
			isPresented: store.binding.alert.isSelected(.endMeeting)
		) {
			Button("Save and end") {
				store.save()
			}
			if store.state.alert.endMeeting {
				Button("Discard", role: .destructive) {
					store.confirmDiscard()
				}
			}
			Button("Resume", role: .cancel) {}
		} message: {
			Text("You are ending the meeting early. What would you like to do?")
		}
	}

	func speechRecognizerFailedAlert(store: Store<RecordMeeting>) -> some View {
		alert(
			"Speech recognition failure",
			isPresented: store.binding.alert.isSelected(.speechRecognizerFailed)
		) {
			Button("Continue meeting", role: .cancel) {}
			Button("Discard meeting", role: .destructive) {
				store.confirmDiscard()
			}
		} message: {
			Text(
				"""
				The speech recognizer has failed for some reason and so your meeting will no longer be \
				recorded. What do you want to do?
				"""
			)
		}
	}
}

struct MeetingHeaderView: View {
	let secondsElapsed: Int
	let durationRemaining: Duration
	let theme: Theme

	var body: some View {
		VStack {
			ProgressView(value: progress)
				.progressViewStyle(MeetingProgressViewStyle(theme: theme))
			HStack {
				VStack(alignment: .leading) {
					Text("Time Elapsed")
						.font(.caption)
					Label(
						Duration.seconds(secondsElapsed).formatted(.units()),
						systemImage: "hourglass.bottomhalf.fill"
					)
				}
				Spacer()
				VStack(alignment: .trailing) {
					Text("Time Remaining")
						.font(.caption)
					Label(durationRemaining.formatted(.units()), systemImage: "hourglass.tophalf.fill")
						.font(.body.monospacedDigit())
						.labelStyle(.trailingIcon)
				}
			}
		}
		.padding([.top, .horizontal])
	}

	private var totalDuration: Duration {
		.seconds(secondsElapsed) + durationRemaining
	}

	private var progress: Double {
		guard totalDuration > .seconds(0) else { return 0 }
		return Double(secondsElapsed) / Double(totalDuration.components.seconds)
	}
}

struct MeetingProgressViewStyle: ProgressViewStyle {
	var theme: Theme

	func makeBody(configuration: Configuration) -> some View {
		ZStack {
			RoundedRectangle(cornerRadius: 10)
				.fill(theme.accentColor)
				.frame(height: 20)

			ProgressView(configuration)
				.tint(theme.mainColor)
				.frame(height: 12)
				.padding(.horizontal)
		}
	}
}

struct MeetingTimerView: View {
	let syncUp: SyncUp
	let speakerIndex: Int

	var body: some View {
		Circle()
			.strokeBorder(lineWidth: 24)
			.overlay {
				VStack {
					Group {
						if speakerIndex < syncUp.attendees.count {
							Text(syncUp.attendees[speakerIndex].name)
						} else {
							Text("Someone")
						}
					}
					.font(.title)
					Text("is speaking")
					Image(systemName: "mic.fill")
						.font(.largeTitle)
						.padding(.top)
				}
				.foregroundStyle(syncUp.theme.accentColor)
			}
			.overlay {
				ForEach(Array(syncUp.attendees.enumerated()), id: \.element.id) { index, _ in
					if index < speakerIndex + 1 {
						SpeakerArc(totalSpeakers: syncUp.attendees.count, speakerIndex: index)
							.rotation(Angle(degrees: -90))
							.stroke(syncUp.theme.mainColor, lineWidth: 12)
					}
				}
			}
			.padding(.horizontal)
	}
}

struct SpeakerArc: Shape {
	let totalSpeakers: Int
	let speakerIndex: Int

	func path(in rect: CGRect) -> Path {
		let diameter = min(rect.size.width, rect.size.height) - 24
		let radius = diameter / 2
		let center = CGPoint(x: rect.midX, y: rect.midY)
		return Path { path in
			path.addArc(
				center: center,
				radius: radius,
				startAngle: startAngle,
				endAngle: endAngle,
				clockwise: false
			)
		}
	}

	private var degreesPerSpeaker: Double {
		360 / Double(totalSpeakers)
	}

	private var startAngle: Angle {
		Angle(degrees: degreesPerSpeaker * Double(speakerIndex) + 1)
	}

	private var endAngle: Angle {
		Angle(degrees: startAngle.degrees + degreesPerSpeaker - 1)
	}
}

struct MeetingFooterView: View {
	let syncUp: SyncUp
	var nextButtonTapped: () -> Void
	let speakerIndex: Int

	var body: some View {
		VStack {
			HStack {
				if speakerIndex < syncUp.attendees.count - 1 {
					Text("Speaker \(speakerIndex + 1) of \(syncUp.attendees.count)")
				} else {
					Text("No more speakers.")
				}
				Spacer()
				Button(action: nextButtonTapped) {
					Image(systemName: "forward.fill")
				}
			}
		}
		.padding([.bottom, .horizontal])
	}
}

#Preview {
	NavigationStack {
		RecordMeetingView(state: RecordMeeting(syncUp: .mock))
	}
}
