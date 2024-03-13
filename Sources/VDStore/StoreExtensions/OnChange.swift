import Foundation

public extension Store {

	func onChange<V>(
		of keyPath: WritableKeyPath<State, V>,
		removeDuplicates isDuplicate: @escaping (V, V) -> Bool,
		_ operation: @escaping (_ oldValue: V, _ newValue: V, inout State) -> Void
	) -> Store {
		scope {
			$0
		} set: {
			let oldValue = $0[keyPath: keyPath]
			$0 = $1
			operation(oldValue, $1[keyPath: keyPath], &$0)
		}
	}

	func onChange<V: Equatable>(
		of keyPath: WritableKeyPath<State, V>,
		_ operation: @escaping (_ oldValue: V, _ newValue: V, inout State) -> Void
	) -> Store {
		onChange(of: keyPath, removeDuplicates: ==, operation)
	}
}
