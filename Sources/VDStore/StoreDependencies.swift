import Foundation

public struct StoreDependencies {
    
    private var dependencies: [PartialKeyPath<StoreDependencies>: Any] = [:]
    
    public init() {
    }
    
    public subscript<Dependency>(_ keyPath: KeyPath<StoreDependencies, Dependency>) -> Dependency? {
        get {
            dependencies[keyPath] as? Dependency
        }
        set {
            dependencies[keyPath] = newValue
        }
    }
    
    public func with<Dependency>(
        _ keyPath: KeyPath<StoreDependencies, Dependency>,
        _ value: Dependency
    ) -> StoreDependencies {
        var new = self
        new[keyPath] = value
        return new
    }
    
    public func merging(with dependencies: StoreDependencies) -> StoreDependencies {
        var new = self
        new.dependencies.merge(dependencies.dependencies) { _, new in new }
        return new
    }
    
    public func defaultFor<Value>(
        live: Value,
        test: Value? = nil,
        preview: Value? = nil
    ) -> Value {
        #if DEBUG
        if _isPreview {
            return preview ?? test ?? live
        } else if _XCTIsTesting {
            return test ?? preview ?? live
        } else {
            return live
        }
        #else
        return live
        #endif
    }
}

private let _XCTIsTesting: Bool = ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath")
private let _isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
