import Foundation

public extension StoreDIValues {

	/// A dependency that returns the current date.
	///
	/// By default, a "live" generator is supplied, which returns the current system date when called
	/// by invoking `Date.init` under the hood. When used in tests, an "unimplemented" generator that
	/// additionally reports test failures is supplied, unless explicitly overridden.
	var date: DateGenerator {
		get { get(\.date, or: DateGenerator { Date() }) }
		set { set(\.date, newValue) }
	}
}

/// A dependency that generates a date.
///
/// See ``StoreDIValues/date`` for more information.
public struct DateGenerator: Sendable {

	private var generate: @Sendable () -> Date

	/// A generator that returns a constant date.
	///
	/// - Parameter now: A date to return.
	/// - Returns: A generator that always returns the given date.
	public static func constant(_ now: Date) -> Self {
		Self { now }
	}

	/// The current date.
	public var now: Date {
		get { generate() }
		set { generate = { newValue } }
	}

	/// Initializes a date generator that generates a date from a closure.
	///
	/// - Parameter generate: A closure that returns the current date when called.
	public init(_ generate: @escaping @Sendable () -> Date) {
		self.generate = generate
	}

	public func callAsFunction() -> Date {
		generate()
	}
}
