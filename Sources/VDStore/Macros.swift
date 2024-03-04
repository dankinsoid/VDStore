#if swift(>=5.9)
import Foundation

/// Wrap all functions in the scope in `execute` method and generates `Action` static variables for each method.
/// This redirect all calls through middlewares and make async methods cancellable by generated `Action`.
/// This should only be applied on an ``Store`` extension.
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro Actions() = #externalMacro(module: "VDStoreMacros", type: "ActionsMacro")

/// Creates an store DI variable and adds getters and setters.
/// The initial value of the variable becomes the default value.
@attached(accessor, names: named(get), named(set))
public macro StoreDIValue() = #externalMacro(module: "VDStoreMacros", type: "StoreDIValueMacro")

/// Applies the @StoreDIValue macro to each child in the scope.
/// This should only be applied on an ``StoreDIValues`` extension.
@attached(memberAttribute)
public macro StoreDIValuesList() = #externalMacro(module: "VDStoreMacros", type: "StoreDIValuesMacro")
#endif
