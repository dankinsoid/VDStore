@preconcurrency import Speech
import VDStore

struct SpeechClient {

	var authorizationStatus: @Sendable () -> SFSpeechRecognizerAuthorizationStatus = { .denied }
	var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus = { .denied }
	var startTask:
		@Sendable (_ request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<
			SpeechRecognitionResult, Error
		> = { _ in AsyncThrowingStream { nil } }
}

extension SpeechClient {
	static let liveValue: SpeechClient = {
		let speech = Speech()
		return SpeechClient(
			authorizationStatus: { SFSpeechRecognizer.authorizationStatus() },
			requestAuthorization: {
				await withUnsafeContinuation { continuation in
					SFSpeechRecognizer.requestAuthorization { status in
						continuation.resume(returning: status)
					}
				}
			},
			startTask: { request in
				await speech.startTask(request: request)
			}
		)
	}()

	static let previewValue: SpeechClient = {
		let isRecording = ActorIsolated(false)
		return Self(
			authorizationStatus: { .authorized },
			requestAuthorization: { .authorized },
			startTask: { _ in
				AsyncThrowingStream { continuation in
					Task { @MainActor in
						await isRecording.set(true)
						var finalText = """
						Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
						incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
						exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute \
						irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla \
						pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui \
						officia deserunt mollit anim id est laborum.
						"""
						var text = ""
						while await isRecording.value {
							let word = finalText.prefix { $0 != " " }
							try await Task.sleep(for: .milliseconds(word.count * 50 + .random(in: 0 ... 200)))
							finalText.removeFirst(word.count)
							if finalText.first == " " {
								finalText.removeFirst()
							}
							text += word + " "
							continuation.yield(
								SpeechRecognitionResult(
									bestTranscription: Transcription(
										formattedString: text
									),
									isFinal: false
								)
							)
						}
					}
				}
			}
		)
	}()

	static let testValue = SpeechClient()

	static func fail(after duration: Duration) -> Self {
		Self(
			authorizationStatus: { .authorized },
			requestAuthorization: { .authorized },
			startTask: { request in
				AsyncThrowingStream { continuation in
					Task {
						let start = ContinuousClock.now
						do {
							for try await result in await Self.previewValue.startTask(request) {
								if ContinuousClock.now - start > duration {
									struct SpeechRecognitionFailed: Error {}
									continuation.finish(throwing: SpeechRecognitionFailed())
									break
								} else {
									continuation.yield(result)
								}
							}
							continuation.finish()
						} catch {
							continuation.finish(throwing: error)
						}
					}
				}
			}
		)
	}
}

final actor ActorIsolated<T> {

	var value: T

	init(_ value: T) {
		self.value = value
	}

	func set(_ value: T) {
		self.value = value
	}
}

extension StoreDIValues {

	@StoreDIValue
	var speechClient: SpeechClient = valueFor(live: .liveValue, test: .testValue, preview: .previewValue)
}

struct SpeechRecognitionResult: Equatable {
	var bestTranscription: Transcription
	var isFinal: Bool
}

struct Transcription: Equatable {
	var formattedString: String
}

extension SpeechRecognitionResult {
	init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
		bestTranscription = Transcription(speechRecognitionResult.bestTranscription)
		isFinal = speechRecognitionResult.isFinal
	}
}

extension Transcription {
	init(_ transcription: SFTranscription) {
		formattedString = transcription.formattedString
	}
}

private actor Speech {
	private var audioEngine: AVAudioEngine?
	private var recognitionTask: SFSpeechRecognitionTask?
	private var recognitionContinuation:
		AsyncThrowingStream<SpeechRecognitionResult, Error>.Continuation?

	func startTask(
		request: SFSpeechAudioBufferRecognitionRequest
	) -> AsyncThrowingStream<SpeechRecognitionResult, Error> {
		AsyncThrowingStream { continuation in
            return;
			self.recognitionContinuation = continuation
			let audioSession = AVAudioSession.sharedInstance()
			do {
				try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
				try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
			} catch {
				continuation.finish(throwing: error)
				return
			}

			self.audioEngine = AVAudioEngine()
			let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
			self.recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
				switch (result, error) {
				case let (.some(result), _):
					continuation.yield(SpeechRecognitionResult(result))
				case (_, .some):
					continuation.finish(throwing: error)
				case (.none, .none):
					fatalError("It should not be possible to have both a nil result and nil error.")
				}
			}

			continuation.onTermination = { [audioEngine, recognitionTask] _ in
				_ = speechRecognizer
				audioEngine?.stop()
				audioEngine?.inputNode.removeTap(onBus: 0)
				recognitionTask?.finish()
			}

			self.audioEngine?.inputNode.installTap(
				onBus: 0,
				bufferSize: 1024,
				format: self.audioEngine?.inputNode.outputFormat(forBus: 0)
			) { buffer, _ in
				request.append(buffer)
			}

			self.audioEngine?.prepare()
			do {
				try self.audioEngine?.start()
			} catch {
				continuation.finish(throwing: error)
				return
			}
		}
	}
}
