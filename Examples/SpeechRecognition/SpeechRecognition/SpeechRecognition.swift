import VDStore
import Speech
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a complex dependency in the Composable \
  Architecture. It uses the `SFSpeechRecognizer` API from the Speech framework to listen to audio \
  on the device and live-transcribe it to the UI.
  """

// MARK: - State

struct SpeechRecognition: Equatable {
    var alert: String?
    var isRecording = false
    var transcribedText = ""
}

// MARK: - Actions

extension Store<SpeechRecognition> {

    func recordButtonTapped() async {
        state.isRecording.toggle()
        if state.isRecording {
            do {
                try await startRecording()
            } catch {
                speechFailed(failure: error)
            }
        } else {
            await di.speechClient.finishTask()
        }
    }

    func startRecording() async throws {
        let status = await di.speechClient.requestAuthorization()
        speechRecognizerAuthorizationStatusResponse(status: status)
        
        guard status == .authorized
        else { return }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        for try await result in await di.speechClient.startTask(request) {
            state.transcribedText = result.bestTranscription.formattedString
        }
    }

    func speechFailed(failure: Error) {
        switch failure {
        case SpeechClient.Failure.couldntConfigureAudioSession,
            SpeechClient.Failure.couldntStartAudioEngine:
            state.alert = "Problem with audio device. Please try again."
        default:
            state.alert = "An error occurred while transcribing. Please try again."
        }
    }

    func speechRecognizerAuthorizationStatusResponse(status:  SFSpeechRecognizerAuthorizationStatus) {
        state.isRecording = status == .authorized
        
        switch status {
        case .denied:
            state.alert = """
              You denied access to speech recognition. This app needs access to transcribe your \
              speech.
              """
            
        case .restricted:
            state.alert = "Your device does not allow speech recognition."
        default:
            break
        }
    }
}

// MARK: - View

struct SpeechRecognitionView: View {

  @ViewStore var state = SpeechRecognition()

  var body: some View {
    VStack {
      VStack(alignment: .leading) {
        Text(readMe)
          .padding(.bottom, 32)
      }

      ScrollView {
        ScrollViewReader { proxy in
          Text(state.transcribedText)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      Spacer()

      Button {
          Task {
              await $state.recordButtonTapped()
          }
      } label: {
        HStack {
          Image(
            systemName: state.isRecording
              ? "stop.circle.fill" : "arrowtriangle.right.circle.fill"
          )
          .font(.title)
          Text(state.isRecording ? "Stop Recording" : "Start Recording")
        }
        .foregroundColor(.white)
        .padding()
        .background(state.isRecording ? Color.red : .green)
        .cornerRadius(16)
      }
    }
    .padding()
    .animation(.linear, value: state.transcribedText)
    .alert(
        state.alert ?? "",
        isPresented: Binding {
            state.alert != nil
        } set: { newValue in
            if !newValue {
                state.alert = nil
            }
        }
    ) {
        Button("OK") {
            state.alert = nil
        }
    }
  }
}

#Preview {
  SpeechRecognitionView(
    state: SpeechRecognition(transcribedText: "Test test 123")
  )
}
