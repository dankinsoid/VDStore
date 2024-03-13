#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

extension SyntaxCollection {

	mutating func removeLast() {
		remove(at: index(before: endIndex))
	}
}

extension FunctionDeclSyntax {

	mutating func remove(attribute: String) {
		if let i = attributes.firstIndex(where: { $0.as(AttributeSyntax.self)?.attributeName.description == attribute }) {
			attributes.remove(at: i)
		}
	}
    
    mutating func add(attribute: String) {
        if attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.description == attribute }) {
            return
        }
        attributes.insert(
            .attribute(AttributeSyntax("\(raw: attribute)")),
            at: attributes.startIndex
        )
    }
}

extension MacroExpansionContext {

	func diagnose(_ type: DiagnosticSeverity = .error, node: SyntaxProtocol, _ message: String) {
		diagnose(Diagnostic(node: Syntax(node), message: Feedback(type, message)))
	}
}
#endif
