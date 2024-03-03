#if swift(>=5.9)
import Foundation

@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro Actions() = #externalMacro(module: "VDStoreMacros", type: "ActionsMacro")

/// Creates an unique EnvironmentKey for the variable and adds getters and setters.
/// The initial value of the variable becomes the default value of the EnvironmentKey.
@attached(accessor, names: named(get), named(set))
public macro StoreDIValue() = #externalMacro(module: "VDStoreMacros", type: "StoreDIValueMacro")

/// Applies the @EnvironmentValue macro to each child in the scope.
/// This should only be applied on an EnvironmentValues extension.
@attached(memberAttribute)
public macro StoreDIValuesList() = #externalMacro(module: "VDStoreMacros", type: "StoreDIValuesMacro")
#endif
