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
        self.remove(at: self.index(before: self.endIndex))
    }
}

extension FunctionDeclSyntax {
    
    mutating func remove(attribute: String) {
        if let i = attributes.firstIndex(where: { $0.as(AttributeSyntax.self)?.attributeName.description == attribute }) {
            attributes.remove(at: i)
        }
    }
}

extension MacroExpansionContext {
    
    func diagnose(_ type: DiagnosticSeverity = .error, node: SyntaxProtocol, _ message: String) {
        diagnose(Diagnostic(node: Syntax(node), message: Feedback(type, message)))
    }
}
#endif
