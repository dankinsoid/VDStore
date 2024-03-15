import Speech

// The core data types in the Speech framework are reference types and are not constructible by us,
// and so they aren't testable out the box. We define struct versions of those types to make
// them easier to use and test.

struct SpeechRecognitionMetadata: Equatable {
	var averagePauseDuration: TimeInterval
	var speakingRate: Double
	var voiceAnalytics: VoiceAnalytics?
}

struct SpeechRecognitionResult: Equatable {
	var bestTranscription: Transcription
	var isFinal: Bool
	var speechRecognitionMetadata: SpeechRecognitionMetadata?
	var transcriptions: [Transcription]
}

struct Transcription: Equatable {
	var formattedString: String
	var segments: [TranscriptionSegment]
}

struct TranscriptionSegment: Equatable {
	var alternativeSubstrings: [String]
	var confidence: Float
	var duration: TimeInterval
	var substring: String
	var timestamp: TimeInterval
}

struct VoiceAnalytics: Equatable {
	var jitter: AcousticFeature
	var pitch: AcousticFeature
	var shimmer: AcousticFeature
	var voicing: AcousticFeature
}

struct AcousticFeature: Equatable {
	var acousticFeatureValuePerFrame: [Double]
	var frameDuration: TimeInterval
}

extension SpeechRecognitionMetadata {
	init(_ speechRecognitionMetadata: SFSpeechRecognitionMetadata) {
		averagePauseDuration = speechRecognitionMetadata.averagePauseDuration
		speakingRate = speechRecognitionMetadata.speakingRate
		voiceAnalytics = speechRecognitionMetadata.voiceAnalytics.map(VoiceAnalytics.init)
	}
}

extension SpeechRecognitionResult {
	init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
		bestTranscription = Transcription(speechRecognitionResult.bestTranscription)
		isFinal = speechRecognitionResult.isFinal
		speechRecognitionMetadata = speechRecognitionResult.speechRecognitionMetadata
			.map(SpeechRecognitionMetadata.init)
		transcriptions = speechRecognitionResult.transcriptions.map(Transcription.init)
	}
}

extension Transcription {
	init(_ transcription: SFTranscription) {
		formattedString = transcription.formattedString
		segments = transcription.segments.map(TranscriptionSegment.init)
	}
}

extension TranscriptionSegment {
	init(_ transcriptionSegment: SFTranscriptionSegment) {
		alternativeSubstrings = transcriptionSegment.alternativeSubstrings
		confidence = transcriptionSegment.confidence
		duration = transcriptionSegment.duration
		substring = transcriptionSegment.substring
		timestamp = transcriptionSegment.timestamp
	}
}

extension VoiceAnalytics {
	init(_ voiceAnalytics: SFVoiceAnalytics) {
		jitter = AcousticFeature(voiceAnalytics.jitter)
		pitch = AcousticFeature(voiceAnalytics.pitch)
		shimmer = AcousticFeature(voiceAnalytics.shimmer)
		voicing = AcousticFeature(voiceAnalytics.voicing)
	}
}

extension AcousticFeature {
	init(_ acousticFeature: SFAcousticFeature) {
		acousticFeatureValuePerFrame = acousticFeature.acousticFeatureValuePerFrame
		frameDuration = acousticFeature.frameDuration
	}
}
