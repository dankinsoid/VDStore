#if swift(>=5.9)
import Foundation

@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro Actions() = #externalMacro(
    module: "VDStoreMacros",
    type: "ActionsMacro"
)
#endif
