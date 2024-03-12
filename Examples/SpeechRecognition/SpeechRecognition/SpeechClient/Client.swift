import VDStore
import Speech

struct SpeechClient {

  var finishTask: @Sendable () async -> Void = { }
  var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus = { .notDetermined }
  var startTask:
    @Sendable (_ request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<
      SpeechRecognitionResult, Error
    > = { _ in
        AsyncThrowingStream { nil }
    }

  enum Failure: Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}

extension SpeechClient {

  static var previewValue: Self {
    let isRecording = ActorIsolated(false)

    return Self(
      finishTask: { await isRecording.set(false) },
      requestAuthorization: { .authorized },
      startTask: { _ in
        AsyncThrowingStream { continuation in
          Task {
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
              try await Task.sleep(for: .milliseconds(word.count * 50 + .random(in: 0...200)))
              finalText.removeFirst(word.count)
              if finalText.first == " " {
                finalText.removeFirst()
              }
              text += word + " "
              continuation.yield(
                SpeechRecognitionResult(
                  bestTranscription: Transcription(
                    formattedString: text,
                    segments: []
                  ),
                  isFinal: false,
                  transcriptions: []
                )
              )
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
    
    func `set`(_ value: T) {
        self.value = value
    }
}

extension StoreDIValues {

  var speechClient: SpeechClient {
      get {
          self[\.speechClient] ?? valueFor(
            live: .liveValue,
            test: SpeechClient(),
            preview: .previewValue
          )
      }
    set { self[\.speechClient] = newValue }
  }
}
