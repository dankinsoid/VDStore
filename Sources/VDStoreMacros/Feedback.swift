#if canImport(SwiftCompilerPlugin)
import SwiftDiagnostics
import SwiftSyntax

struct Feedback: DiagnosticMessage {

	var message: String
	var severity: DiagnosticSeverity

	init(_ severity: DiagnosticSeverity, _ message: String) {
		self.severity = severity
		self.message = message
	}

	var diagnosticID: MessageID {
		MessageID(domain: "VDStore", id: message)
	}
}
#endif
