import Foundation

#if DEBUG
@inline(__always)
func threadCheck(message: @autoclosure () -> String) {
	guard !Thread.isMainThread else { return }
	runtimeWarn(message())
}
#else
@_transparent
func threadCheck(status: ThreadCheckStatus) {}
#endif
