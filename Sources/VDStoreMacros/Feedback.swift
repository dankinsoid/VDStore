#if canImport(SwiftCompilerPlugin)
import SwiftDiagnostics
import SwiftSyntax

struct Feedback: DiagnosticMessage {

	static let noDefaultArgument = Feedback(.error, "No default value provided.")
	static let missingAnnotation = Feedback(.error, "No annotation provided.")
	static let notAnIdentifier = Feedback(.error, "Identifier is not valid.")

	var message: String
	var severity: DiagnosticSeverity

	init(_ severity: DiagnosticSeverity, _ message: String) {
		self.severity = severity
		self.message = message
	}

	var diagnosticID: MessageID {
		MessageID(domain: "VDStoreMacros", id: message)
	}
}
#endif
