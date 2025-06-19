import Foundation

protocol ThreadLocalKey {
	
	associatedtype Value
}

enum _ThreadLocal<Key: ThreadLocalKey> {

	static var pointer: UnsafeMutablePointer<Key.Value?>? {
		get { rawPointer?.assumingMemoryBound(to: Key.Value?.self) }
		set { rawPointer = newValue.map { UnsafeMutableRawPointer($0) } }
	}

#if os(WASI)
	// NB: This can simply be 'nonisolated(unsafe)' when we drop support for Swift 5.9
	private static var rawPointer: UnsafeMutableRawPointer? {
		get { _value.value }
		set { _value.value = newValue }
	}
	private static let _value = UncheckedBox<UnsafeMutableRawPointer?>(nil)
#else
	private static var rawPointer: UnsafeMutableRawPointer? {
		get { Thread.current.threadDictionary[ObjectIdentifier(Key.self)] as! UnsafeMutableRawPointer? }
		set { Thread.current.threadDictionary[ObjectIdentifier(Key.self)] = newValue }
	}
#endif
}

#if os(WASI)
@usableFromInline final class UncheckedBox<Value>: @unchecked Sendable {
	@usableFromInline var value: Value
	@usableFromInline init(_ value: Value) {
		self.value = value
	}
}
#endif
