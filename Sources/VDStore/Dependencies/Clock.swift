#if canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst)
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public extension StoreDIValues {

	/// The current clock that features should use when a `ContinuousClock` would be appropriate.
	///
	/// By default, a live `ContinuousClock` is supplied.
	///
	/// See ``suspendingClock`` to override a feature's `SuspendingClock`, instead.
	var continuousClock: any Clock<Duration> {
		get { get(\.continuousClock, or: ContinuousClock()) }
		set { set(\.continuousClock, newValue) }
	}

	/// The current clock that features should use when a `SuspendingClock` would be appropriate.
	///
	/// By default, a live `SuspendingClock` is supplied.
	///
	/// See ``continuousClock`` to override a feature's `ContinuousClock`, instead.
	var suspendingClock: any Clock<Duration> {
		get { get(\.suspendingClock, or: SuspendingClock()) }
		set { set(\.suspendingClock, newValue) }
	}
}
#endif
