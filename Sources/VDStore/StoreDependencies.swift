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
}
