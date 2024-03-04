#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

@main
struct VDStoreMacrosPlugin: CompilerPlugin {

	let providingMacros: [Macro.Type] = [
		ActionsMacro.self,
		StoreDIValueMacro.self,
		StoreDIValuesMacro.self,
	]
}
#endif
