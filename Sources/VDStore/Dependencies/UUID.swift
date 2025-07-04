import Foundation

public extension DIValues {

	/// A dependency that generates UUIDs.
	///
	/// Introduce controllable UUID generation to your features by using the ``di`` property
	///  with a key path to this property. The wrapped value is an instance of
	/// ``UUIDGenerator``, which can be called with a closure to create UUIDs. (It can be called
	/// directly because it defines ``UUIDGenerator/callAsFunction()``, which is called when you
	/// invoke the instance as you would invoke a function.)
	///
	/// For example, you could introduce controllable UUID generation to an observable object model
	/// that creates to-dos with unique identifiers:
	///
	/// ```swift
	/// extension Store<TodosModel> {
	///
	///   func addButtonTapped() {
	///     state.todos.append(Todo(id: di.uuid()))
	///   }
	/// }
	/// ```
	///
	/// By default, a "live" generator is supplied, which returns a random UUID when called by
	/// invoking `UUID.init` under the hood.  When used in tests, an "unimplemented" generator that
	/// additionally reports test failures if invoked, unless explicitly overridden.
	///
	/// To test a feature that depends on UUID generation, you can override its generator using
	/// ``di(_:_:)-4uz6m`` to override the underlying ``UUIDGenerator``:
	///
	///   * ``UUIDGenerator/incrementing`` for reproducible UUIDs that count up from
	///     `00000000-0000-0000-0000-000000000000`.
	///
	///   * ``UUIDGenerator/constant(_:)`` for a generator that always returns the given UUID.
	///
	/// For example, you could test the to-do-creating model by supplying an
	/// ``UUIDGenerator/incrementing`` generator as a dependency:
	///
	/// ```swift
	/// func testFeature() {
	///   let model = store.di(\.uuid, .incrementing)
	///
	///   model.addButtonTapped()
	///   XCTAssertEqual(
	///     model.state.todos,
	///     [Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)]
	///   )
	/// }
	/// ```
	var uuid: UUIDGenerator {
		get { get(\.uuid, or: UUIDGenerator { UUID() }) }
		set { set(\.uuid, newValue) }
	}
}

/// A dependency that generates a UUID.
///
/// See ``DIValues/uuid`` for more information.
public struct UUIDGenerator: Sendable {
	private let generate: @Sendable () -> UUID

	/// A generator that returns a constant UUID.
	///
	/// - Parameter uuid: A UUID to return.
	/// - Returns: A generator that always returns the given UUID.
	public static func constant(_ uuid: UUID) -> Self {
		Self { uuid }
	}

	/// A generator that generates UUIDs in incrementing order.
	///
	/// For example:
	///
	/// ```swift
	/// let generate = UUIDGenerator.incrementing
	/// generate()  // UUID(00000000-0000-0000-0000-000000000000)
	/// generate()  // UUID(00000000-0000-0000-0000-000000000001)
	/// generate()  // UUID(00000000-0000-0000-0000-000000000002)
	/// ```
	public static var incrementing: Self {
		let generator = IncrementingUUIDGenerator()
		return Self { generator() }
	}

	/// Initializes a UUID generator that generates a UUID from a closure.
	///
	/// - Parameter generate: A closure that returns the current date when called.
	public init(_ generate: @escaping @Sendable () -> UUID) {
		self.generate = generate
	}

	public func callAsFunction() -> UUID {
		generate()
	}
}

public extension UUID {
	init(_ intValue: Int) {
		self.init(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", intValue))")!
	}
}

private final class IncrementingUUIDGenerator: @unchecked Sendable {
	private let lock = NSLock()
	private var sequence = 0

	func callAsFunction() -> UUID {
		lock.lock()
		defer {
			self.sequence += 1
			self.lock.unlock()
		}
		return UUID(sequence)
	}
}
