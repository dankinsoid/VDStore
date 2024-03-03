import Foundation

public struct StoreDIValues {

	private var dependencies: [PartialKeyPath<StoreDIValues>: Any] = [:]

	public init() {}

	public subscript<DIValue>(_ keyPath: WritableKeyPath<StoreDIValues, DIValue>) -> DIValue? {
		get {
			dependencies[keyPath] as? DIValue
		}
		set {
			dependencies[keyPath] = newValue
		}
	}

	public func with<DIValue>(
		_ keyPath: WritableKeyPath<StoreDIValues, DIValue>,
		_ value: DIValue
	) -> StoreDIValues {
		var new = self
        new[keyPath: keyPath] = value
		return new
	}

	public func transform<DIValue>(
		_ keyPath: WritableKeyPath<StoreDIValues, DIValue>,
		_ transform: (inout DIValue) -> Void
	) -> StoreDIValues {
		var value = self[keyPath: keyPath]
		transform(&value)
		return with(keyPath, value)
	}

	public func merging(with dependencies: StoreDIValues) -> StoreDIValues {
		var new = self
		new.dependencies.merge(dependencies.dependencies) { _, new in new }
		return new
	}
}

public func defaultFor<Value>(
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

private let _XCTIsTesting: Bool = ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath")
private let _isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
