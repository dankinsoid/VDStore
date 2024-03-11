import Foundation

public extension Store {

	func or<T>(_ defaultValue: @escaping @autoclosure () -> T) -> Store<T> where T? == State {
		scope {
			$0 ?? defaultValue()
		} set: {
			$0 = $1
		}
	}

	func onChange<V>(
		of keyPath: WritableKeyPath<State, V>,
		removeDuplicates isDuplicate: @escaping (V, V) -> Bool,
		_ operation: @MainActor @escaping (_ oldValue: V, _ newValue: V, inout State) -> Void
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
		_ operation: @MainActor @escaping (_ oldValue: V, _ newValue: V, inout State) -> Void
	) -> Store {
		onChange(of: keyPath, removeDuplicates: ==, operation)
	}
}

public extension Store where State: MutableCollection {

	func forEach(_ operation: @MainActor (Store<State.Element>) throws -> Void) rethrows {
		for index in state.indices {
			try operation(self[index])
		}
	}

	func forEach(_ operation: @MainActor (Store<State.Element>) async throws -> Void) async rethrows {
		for index in state.indices {
			try await operation(self[index])
		}
	}
}
