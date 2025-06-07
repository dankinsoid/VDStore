import Foundation

/// A property wrapper that provides thread-safe, non-mutating write access to a value.
///
/// `NonMutatingSet` allows you to modify wrapped values without triggering change notifications
/// in reactive systems. This is particularly useful for implementing non-mutating settable 
/// properties in Swift structs or when you want to change certain properties without causing
/// UI rebuilds in reactive frameworks.
///
/// The wrapper ensures thread safety through internal synchronization mechanisms while
/// providing a non-mutating setter interface.
///
/// ## Usage
///
/// Use `@NonMutatingSet` to wrap properties that should be modifiable without triggering
/// change notifications:
///
/// ```swift
/// struct AppState {
///   var importantData: String = ""
///   
///   @NonMutatingSet var temporaryFlag: Bool = false
///   @NonMutatingSet var cacheData: [String] = []
/// }
/// ```
///
/// When `temporaryFlag` or `cacheData` are modified, change notifications won't be emitted,
/// making this ideal for temporary state, cache data, or debugging flags.
///
/// ## SwiftUI Example
///
/// In SwiftUI, this property wrapper is particularly useful for state that should not trigger
/// view rebuilds:
///
/// ```swift
/// struct ContentView: View {
///
///   @State var state = AppState()
///
///   var body: some View {
///     VStack {
///       Text("Important: \(state.importantData)")
///       Button("Update Cache") {
///         // This won't trigger view rebuild
///         state.cacheData.append("new item")
///       }
///       Button("Update Important Data") {
///         // This will trigger view rebuild
///         state.importantData = "Updated!"
///       }
///     }
///   }
/// }
/// ```
///
/// ## Thread Safety
///
/// The wrapper is thread-safe and can be safely accessed from multiple threads concurrently.
/// All access to the wrapped value is properly synchronized.
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
