#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ActionsMacro: MemberAttributeMacro, MemberMacro {

	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
			throw CustomError("@Actions only works on Store<State> extension")
		}
		var result: [DeclSyntax] = []
		for member in extensionDecl.memberBlock.members {
			if let function = member.decl.as(FunctionDeclSyntax.self) {
				result += try VDStoreMacros.expansion(of: node, funcDecl: function, in: context)
			}
		}
		return result
	}

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingAttributesFor member: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [AttributeSyntax] {
		guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
			throw CustomError("@Actions only works on Store<State> extension")
		}
		let type = extensionDecl.extendedType.trimmed.description
		guard type.hasPrefix("Store<"), type.hasSuffix(">") else {
			throw CustomError("@Actions only works on Store<State> extension")
		}
		guard let funcDecl = member.as(FunctionDeclSyntax.self) else { return [] }
		guard !funcDecl.modifiers.contains(where: { $0.name.trimmed.description == "static" }) else { return [] }
		return ["@_disfavoredOverload"]
	}
}

public struct CancelInFlightMacro: PeerMacro {

	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
			throw CustomError("@CancelInFlight only works on functions")
		}
		guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
			throw CustomError("@CancelInFlight only works on async functions")
		}
		return []
	}
}

private func expansion(
	of node: AttributeSyntax,
	funcDecl: FunctionDeclSyntax,
	in context: some MacroExpansionContext
) throws -> [DeclSyntax] {
	let privateIndex = funcDecl.modifiers.firstIndex(where: { $0.trimmed.description == "private" })
	//    if privateIndex == nil {
	//        context.diagnose(Diagnostic(node: Syntax(funcDecl), message: Feedback(
	//            .warning,
	//            "It's recommended to make `\(funcDecl.name.trimmed.text)` private."
	//        )))
	//    }
	guard !funcDecl.modifiers.contains(where: { $0.name.trimmed.description == "static" }) else {
		return []
	}

	let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
	let isThrows = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil

	let callPrefix = switch (isAsync, isThrows) {
	case (true, true): "try await "
	case (true, false): "await "
	case (false, true): "try "
	default: ""
	}

	let callSuffix = switch (isAsync, isThrows) {
	case (true, true): " async throws"
	case (true, false): " async"
	case (false, true): " throws"
	default: ""
	}

	let argsCount = funcDecl.signature.parameterClause.parameters.count
	let args = funcDecl.signature.parameterClause.parameters.enumerated().map {
		"$0\(argsCount > 1 ? ".\($0.offset)" : "")"
	}
	.joined(separator: ", ")

	let resultType = funcDecl.signature.returnClause?.type.trimmed.description ?? "Void"
	var types = funcDecl.signature.parameterClause.parameters.map {
		$0.type.description
	}.joined(separator: ", ")

	let actionBody = """
	{ store in
	    return {\(types.isEmpty ? " _ in" : "")
	        let action: (\(types))\(callSuffix) -> \(resultType) = store.\(funcDecl.name.text)
	        return \(callPrefix)action(\(args))
	    }
	}
	"""
	if argsCount != 1 {
		types = "(\(types))"
	}

	var varType = "Action<\(types), \(resultType)>"
	switch (isAsync, isThrows) {
	case (true, true): varType += ".AsyncThrows"
	case (true, false): varType += ".Async"
	case (false, true): varType += ".Throws"
	default: break
	}

	let cancelInFlight = isAsync && funcDecl.containsAttribute("CancelInFlight")
	let lineNumber = context.location(of: funcDecl)?.line.description ?? "#line"
	let staticVarDecl = try VariableDeclSyntax(
		"""
		static var \(raw: funcDecl.name.text): \(raw: varType) {
		    Action(
		        id: StoreActionID(name: "\(raw: funcDecl.name.text)", fileID: #fileID, line: \(raw: lineNumber)),\(raw: cancelInFlight ? "\n        cancelInFlight: true," : "")
		        action: \(raw: actionBody)
		    )
		}
		""")

	var executeDecl = funcDecl
	if let privateIndex {
		executeDecl.modifiers.remove(at: privateIndex)
	}
	executeDecl.remove(attribute: "CancelInFlight")
	executeDecl.remove(attribute: "_disfavoredOverload")

	var parameterList = executeDecl.signature.parameterClause.parameters.map {
		FunctionParameterSyntax(
			leadingTrivia: .newline,
			attributes: $0.attributes,
			modifiers: $0.modifiers,
			firstName: $0.firstName,
			secondName: $0.secondName,
			colon: .colonToken(trailingTrivia: .space),
			type: $0.type,
			ellipsis: $0.ellipsis,
			defaultValue: $0.defaultValue,
			trailingComma: .commaToken(),
			trailingTrivia: nil
		)
	}
	executeDecl.signature.parameterClause.rightParen.leadingTrivia = .newline

	func parameter(
		name: inout String,
		type: TypeSyntax,
		value: ExprSyntax
	) throws -> FunctionParameterSyntax? {
		if let sameName = parameterList.first(where: { $0.defaultValue?.value.description == value.description }) {
			name = (sameName.secondName ?? sameName.firstName).text
			if sameName.type.trimmed.description != type.description {
				throw CustomError("Use \(type) for \(value)")
			}
			return nil
		}

		while parameterList.contains(where: { $0.firstName.text == name }) {
			name = "_\(name)"
		}
		return FunctionParameterSyntax(
			leadingTrivia: .newline,
			firstName: .identifier(name),
			colon: .colonToken(trailingTrivia: .space),
			type: type,
			defaultValue: InitializerClauseSyntax(
				equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
				value: value
			),
			trailingComma: .commaToken()
		)
	}

	var file = "fileID"
	var line = "line"
	var function = "function"
	let fileParam = try parameter(name: &file, type: "String", value: "#fileID")
	let lineParam = try parameter(name: &line, type: "UInt", value: "#line")
	let functionParam = try parameter(name: &function, type: "String", value: "#function")

	parameterList += [fileParam, lineParam, functionParam].compactMap { $0 }

	if var lastParam = parameterList.last {
		// We need to remove a trailing comma from the last argument.
		parameterList.removeLast()
		lastParam.trailingComma = nil
		parameterList.append(lastParam)
	}

	var callArguments = executeDecl.signature.parameterClause.parameters.map { param in
		(param.secondName ?? param.firstName).text
	}
	.joined(separator: ", ")
	if executeDecl.signature.parameterClause.parameters.count != 1 {
		callArguments = "(\(callArguments))"
	}

	executeDecl.signature.parameterClause.parameters = FunctionParameterListSyntax(parameterList)
	let body = CodeBlockItemSyntax("""
	\(raw: callPrefix)execute(
	    Self.\(raw: funcDecl.name.text),
	    with: \(raw: callArguments),
	    file: \(raw: file),
	    line: \(raw: line),
	    from: \(raw: function)
	)
	""")
	executeDecl.body = CodeBlockSyntax(statements: [body])
	return [DeclSyntax(staticVarDecl), DeclSyntax(executeDecl)]
}
#endif
