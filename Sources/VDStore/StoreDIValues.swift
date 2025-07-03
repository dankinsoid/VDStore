import Foundation

/// The storage of injected dependencies.
public struct DIValues: @unchecked Sendable {

	@TaskLocal public static var current = DIValues()

	typealias Key = PartialKeyPath<DIValues>

	private static let storage = Storage()
	private var overrides: [Key: Any] = [:]

	/// Creates an empty storage.
	public init() {}

	/// Returns the stored dependency by its key path.
	public func get<DIValue>(
		_ keyPath: WritableKeyPath<DIValues, DIValue>,
		or value: @autoclosure () -> DIValue
	) -> DIValue {
		(overrides[keyPath] as? DIValue) ?? Self.storage.value(for: keyPath, default: value())
	}

	/// Modify the stored dependency by its key path.
	public mutating func set<DIValue>(
		_ keyPath: WritableKeyPath<DIValues, DIValue>,
		_ value: DIValue
	) {
		overrides[keyPath] = value
	}

	/// Removes the stored dependency by its key path.
	public mutating func remove<DIValue>(
		_ keyPath: WritableKeyPath<DIValues, DIValue>
	) {
		overrides.removeValue(forKey: keyPath)
	}

	/// Returns a new storage with the stored dependency by its key path.
	public mutating func removing<DIValue>(
		_ keyPath: WritableKeyPath<DIValues, DIValue>
	) -> DIValues {
		var new = self
		new.remove(keyPath)
		return new
	}

	/// Injects the given value into the storage.
	/// - Parameters:
	///  - keyPath: A key path to the value in the storage.
	///  - value: The value to inject.
	/// - Returns: A new storage with the injected value.
	public func with<DIValue>(
		_ keyPath: WritableKeyPath<DIValues, DIValue>,
		_ value: DIValue
	) -> DIValues {
		var new = self
		new[keyPath: keyPath] = value
		return new
	}

	/// Transforms the storage's injected dependencies.
	/// - Parameters:
	///  - keyPath: A key path to the value in the storage.
	///  - transform: A closure that transforms the value.
	/// - Returns: A new storage with the transformed value.
	public func transform<DIValue>(
		_ keyPath: WritableKeyPath<DIValues, DIValue>,
		_ transform: (inout DIValue) -> Void
	) -> DIValues {
		var value = self[keyPath: keyPath]
		transform(&value)
		return with(keyPath, value)
	}

	/// Merges the storage's injected dependencies with the given ones.
	/// - Parameters:
	///  - dependencies: The dependencies to merge with.
	/// - Returns: A new storage with the merged dependencies.
	/// - Note: The given dependencies have higher priority than the stored ones.
	public func merging(with dependencies: DIValues) -> DIValues {
		var new = self
		new.overrides.merge(dependencies.overrides) { _, new in new }
		return new
	}

	public static func override<T>(
		default keyPath: KeyPath<DIValues, T>,
		_ value: @autoclosure () -> T
	) {
		Self.storage.modify {
			$0[keyPath] = value()
		}
	}

	public static func override(
		defaults: DIValues
	) {
		Self.storage.modify {
			$0.merge(defaults.overrides) { _, new in
				new
			}
		}
	}

	public static func remove<T>(default keyPath: KeyPath<DIValues, T>) {
		Self.storage.modify {
			$0.removeValue(forKey: keyPath)
		}
	}

	public static func removeDefaults() {
		Self.storage.modify { $0.removeAll(keepingCapacity: true) }
	}
}

extension DIValues {

	final class Storage {

		private var cache: [Key: Any] = [:]
		private let lock = NSRecursiveLock()
	
		func modify(_ modify: (inout [Key: Any]) -> Void) {
			lock.lock()
			defer { lock.unlock() }
			modify(&cache)
		}

		func value<DIValue>(for key: Key, default: @autoclosure () -> DIValue) -> DIValue {
			lock.lock()
			defer { lock.unlock() }
			if let value = cache[key] as? DIValue {
				return value
			}
			let value = `default`()
			cache[key] = value
			return value
		}
	}
}

public extension TaskLocal<DIValues> {

	func withValue<Result>(_ value: (DIValues) -> DIValues, operation: () throws -> Result) rethrows -> Result {
		try withValue(value(wrappedValue), operation: operation)
	}

	func withValue<Result>(_ value: (DIValues) -> DIValues, operation: () async throws -> Result) async rethrows -> Result {
		try await withValue(value(wrappedValue), operation: operation)
	}
}

/// Returns the value for the current environment.
/// - Parameters:
/// 	- live: The value is return when a `preview` or `test` environment is not detected.
/// 	- test: The value is return when running code from an XCTestCase. If missed `live` value is used.
/// 	- preview: The value is return when running code from an Xcode preview. If missed `test` value is used.
public func valueFor<Value>(
	live: @autoclosure () -> Value,
	test: @autoclosure () -> Value? = nil,
	preview: @autoclosure () -> Value? = nil
) -> Value {
	#if DEBUG
	if _isPreview {
		return preview() ?? test() ?? live()
	} else if _XCTIsTesting {
		return test() ?? preview() ?? live()
	} else {
		return live()
	}
	#else
	return live()
	#endif
}

public let _isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

#if !os(WASI)
public let _XCTIsTesting: Bool = ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath")
	|| ProcessInfo.processInfo.environment.keys.contains("XCTestConfigurationFilePath")
	|| ProcessInfo.processInfo.environment.keys.contains("XCTestSessionIdentifier")
	|| (ProcessInfo.processInfo.arguments.first
		.flatMap(URL.init(fileURLWithPath:))
		.map { $0.lastPathComponent == "xctest" || $0.pathExtension == "xctest" }
		?? false)
	|| XCTCurrentTestCase != nil
#else
public let _XCTIsTesting = false
#endif

#if canImport(ObjectiveC)
private var XCTCurrentTestCase: AnyObject? {
	guard
		let XCTestObservationCenter = NSClassFromString("XCTestObservationCenter"),
		let XCTestObservationCenter = XCTestObservationCenter as Any as? NSObjectProtocol,
		let shared = XCTestObservationCenter.perform(Selector(("sharedTestObservationCenter")))?
		.takeUnretainedValue(),
		let observers = shared.perform(Selector(("observers")))?
		.takeUnretainedValue() as? [AnyObject],
		let observer =
		observers
			.first(where: { NSStringFromClass(type(of: $0)) == "XCTestMisuseObserver" }),
			let currentTestCase = observer.perform(Selector(("currentTestCase")))?
			.takeUnretainedValue()
	else { return nil }
	return currentTestCase
}
#else
private var XCTCurrentTestCase: AnyObject? {
	nil
}
#endif
