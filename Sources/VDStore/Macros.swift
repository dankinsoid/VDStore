#if swift(>=5.9)
import Foundation

/// Wrap all functions in the scope in `execute` method and generates `Action` static variables for each method.
/// This redirect all calls through middlewares and make async methods cancellable by generated `Action`.
/// This should only be applied on an ``Store`` extension.
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro Actions() = #externalMacro(module: "VDStoreMacros", type: "ActionsMacro")

/// Determines if any in-flight executions of the function should be canceled before starting this new one.
/// Works within `@Actions` extension only.
@attached(peer, names: arbitrary)
public macro CancelInFlight() = #externalMacro(module: "VDStoreMacros", type: "CancelInFlightMacro")

/// Creates an store DI variable and adds getters and setters.
/// The initial value of the variable becomes the default value.
@attached(accessor, names: named(get), named(set))
public macro DI() = #externalMacro(module: "VDStoreMacros", type: "DIMacro")

/// Applies the @DI macro to each child in the scope.
/// This should only be applied on an ``DIValues`` extension.
@attached(memberAttribute)
public macro DIValues() = #externalMacro(module: "VDStoreMacros", type: "DIValues")
#endif
