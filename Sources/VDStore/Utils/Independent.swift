import Foundation
import Combine

struct ObservableState {

	@ObservableProperty
	var string = ""
	@ObservableProperty
	var counter = 0
}

public protocol Scopeable {
}

@propertyWrapper
public struct ObservableProperty<Value> {

	private let id: UUID
	private var value: Value
	private let counter: _ManagedCriticalState<UInt64> = _ManagedCriticalState(0)

	public var wrappedValue: Value {
		@storageRestrictions(initializes: value)
		init(initialValue) {
			value = initialValue
		}
		_read {
			willAccess()
			yield value
		}
		_modify {
			counter.withCriticalRegion { $0 &+= 1 }
			yield &value
		}
	}

	public init(wrappedValue: Value) {
		self.id = UUID()
		self.value = wrappedValue
	}

	private func willAccess() {
		modifyThreadLocal(of: AccessList.self, AccessList()) {
			$0.updates[id] = counter
		}
	}
}

struct AccessList: ThreadLocalKey {

	typealias Value = Self
	var updates: [UUID: _ManagedCriticalState<UInt64>] = [:]
	
	struct Context {
		
	}
}

func accessList<T>(
	_ apply: () -> T
) -> (T, AccessList?) {
	collectThreadValues(of: AccessList.self, apply: apply) { (previous, scoped) in
		previous.updates.merge(scoped.updates) { _, new in new }
	}
}

private func modifyThreadLocal<L: ThreadLocalKey>(of: L.Type, _ create: @autoclosure () -> L.Value, _ operation: (inout L.Value) -> Void) {
	if let trackingPtr = _ThreadLocal<L>.pointer {
		 if trackingPtr.pointee == nil {
			 trackingPtr.pointee = create()
		 }
			operation(&trackingPtr.pointee!)
	 }
}

private func collectThreadValues<T, L: ThreadLocalKey>(of: L.Type = L.self, apply: () -> T, merge: (inout L.Value, L.Value) -> Void) -> (T, L.Value?) {
	var list: L.Value?
	let result = withUnsafeMutablePointer(to: &list) { ptr in
		let previous = _ThreadLocal<L>.pointer
		_ThreadLocal<L>.pointer = ptr
		defer {
			if let scoped = ptr.pointee, let previous {
				if var prevList = previous.pointee
				{
					merge(&prevList, scoped)
					previous.pointee = prevList
				} else {
					previous.pointee = scoped
				}
			}
			_ThreadLocal<L>.pointer = previous
		}
		return apply()
	}
	return (result, list)
}

extension ObservableProperty: Equatable where Value: Equatable {

	public static func == (lhs: ObservableProperty<Value>, rhs: ObservableProperty<Value>) -> Bool {
		lhs.wrappedValue == rhs.wrappedValue
	}
}

extension ObservableProperty: Hashable where Value: Hashable {

	public func hash(into hasher: inout Hasher) {
		hasher.combine(wrappedValue)
	}
}

extension ObservableProperty: Encodable where Value: Encodable {

	public func encode(to encoder: Encoder) throws {
		try wrappedValue.encode(to: encoder)
	}
}

extension ObservableProperty: Decodable where Value: Decodable {

	public init(from decoder: Decoder) throws {
		try self.init(wrappedValue: Value(from: decoder))
	}
}

extension ObservableProperty: @unchecked Sendable where Value: Sendable {}

extension ObservableProperty: CustomStringConvertible {

	public var description: String {
		"\(wrappedValue)"
	}
}

public extension ObservableProperty where Value: ExpressibleByNilLiteral {

	init() {
		self.init(wrappedValue: nil)
	}
}

public extension KeyedDecodingContainer {

	func decode<T>(_ type: ObservableProperty<T?>.Type, forKey key: Key) throws -> ObservableProperty<T?> where T: Decodable {
		try decodeIfPresent(ObservableProperty<T?>.self, forKey: key) ?? ObservableProperty()
	}
}

public extension KeyedEncodingContainer {

	mutating func encode<T>(_ value: ObservableProperty<T?>, forKey key: Key) throws where T: Encodable {
		try encodeIfPresent(value.wrappedValue, forKey: key)
	}
}
