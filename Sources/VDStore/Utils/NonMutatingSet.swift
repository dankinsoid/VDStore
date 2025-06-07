import Foundation

@propertyWrapper
public struct NonMutatingSet<Value> {

	public var wrappedValue: Value {
		get { box.value }
		nonmutating set { box.value = newValue }
	}

	private let box: Box

	public init(wrappedValue: Value) {
		box = Box(value: wrappedValue)
	}

	public init(_ value: Value) {
		self.init(wrappedValue: value)
	}

	fileprivate final class Box {

		private let lock = NSLock()
		private var _value: Value
	
		var value: Value {
			get {
				lock.withLock { _value }
			}
			set {
				lock.withLock { _value = newValue }
			}
		}

		init(value: Value) {
			self._value = value
		}
	}
}

extension NonMutatingSet: Equatable where Value: Equatable {

	public static func == (lhs: NonMutatingSet<Value>, rhs: NonMutatingSet<Value>) -> Bool {
		lhs.wrappedValue == rhs.wrappedValue
	}
}

extension NonMutatingSet: Hashable where Value: Hashable {

	public func hash(into hasher: inout Hasher) {
		hasher.combine(wrappedValue)
	}
}

extension NonMutatingSet: Encodable where Value: Encodable {

	public func encode(to encoder: Encoder) throws {
		try wrappedValue.encode(to: encoder)
	}
}

extension NonMutatingSet: Decodable where Value: Decodable {

	public init(from decoder: Decoder) throws {
		try self.init(wrappedValue: Value(from: decoder))
	}
}

extension NonMutatingSet: CustomStringConvertible {

	public var description: String {
		"\(wrappedValue)"
	}
}

public extension NonMutatingSet where Value: ExpressibleByNilLiteral {

	init() {
		self.init(wrappedValue: nil)
	}
}

extension NonMutatingSet.Box: @unchecked Sendable where Value: Sendable {}
extension NonMutatingSet: Sendable where Value: Sendable {}

public extension KeyedDecodingContainer {

	func decode<T>(_ type: NonMutatingSet<T?>.Type, forKey key: Key) throws -> NonMutatingSet<T?> where T: Decodable {
		try decodeIfPresent(NonMutatingSet<T?>.self, forKey: key) ?? NonMutatingSet()
	}
}

public extension KeyedEncodingContainer {

	mutating func encode<T>(_ value: NonMutatingSet<T?>, forKey key: Key) throws where T: Encodable {
		try encodeIfPresent(value.wrappedValue, forKey: key)
	}
}
