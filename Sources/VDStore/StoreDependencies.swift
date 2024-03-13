import Foundation

/// The storage of injected dependencies.
public struct StoreDIValues {

	private var dependencies: [PartialKeyPath<StoreDIValues>: Any] = [:]

	/// Creates an empty storage.
	public init() {}

	/// Returns or modify the stored dependency by its key path.
	public subscript<DIValue>(_ keyPath: WritableKeyPath<StoreDIValues, DIValue>) -> DIValue? {
		get {
			dependencies[keyPath] as? DIValue
		}
		set {
			dependencies[keyPath] = newValue
		}
	}

	/// Injects the given value into the storage.
	/// - Parameters:
	///  - keyPath: A key path to the value in the storage.
	///  - value: The value to inject.
	/// - Returns: A new storage with the injected value.
	public func with<DIValue>(
		_ keyPath: WritableKeyPath<StoreDIValues, DIValue>,
		_ value: DIValue
	) -> StoreDIValues {
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
		_ keyPath: WritableKeyPath<StoreDIValues, DIValue>,
		_ transform: (inout DIValue) -> Void
	) -> StoreDIValues {
		var value = self[keyPath: keyPath]
		transform(&value)
		return with(keyPath, value)
	}

	/// Merges the storage's injected dependencies with the given ones.
	/// - Parameters:
	///  - dependencies: The dependencies to merge with.
	/// - Returns: A new storage with the merged dependencies.
	/// - Note: The given dependencies have higher priority than the stored ones.
	public func merging(with dependencies: StoreDIValues) -> StoreDIValues {
		var new = self
		new.dependencies.merge(dependencies.dependencies) { _, new in new }
		return new
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
public let _XCTIsTesting: Bool = {
    ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath")
    || ProcessInfo.processInfo.environment.keys.contains("XCTestConfigurationFilePath")
    || ProcessInfo.processInfo.environment.keys.contains("XCTestSessionIdentifier")
    || (ProcessInfo.processInfo.arguments.first
        .flatMap(URL.init(fileURLWithPath:))
        .map { $0.lastPathComponent == "xctest" || $0.pathExtension == "xctest" }
        ?? false)
    || XCTCurrentTestCase != nil
}()
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
