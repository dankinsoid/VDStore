import Foundation

public extension Store {
    
    func or<T>(_ defaultValue: @escaping @autoclosure () -> T) -> Store<T> where T? == State {
        scope {
            $0 ?? defaultValue()
        } set: {
            $0 = $1
        }
    }
}
