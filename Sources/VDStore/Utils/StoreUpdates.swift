import Combine
import Foundation

/// An async sequence and publisher of store state.
@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {

	public typealias Output = State
	public typealias Failure = Never

	let upstream: AnyPublisher<State, Never>

	public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
		upstream.receive(subscriber: subscriber)
	}

	/// Returns the resulting sequence of a given key path.
	public subscript<Value: Equatable>(
		dynamicMember keyPath: KeyPath<State, Value>
	) -> StorePublisher<Value> {
		StorePublisher<Value>(upstream: upstream.map(keyPath).removeDuplicates().eraseToAnyPublisher())
	}

	/// Returns the resulting sequence of a given key path.
	@_disfavoredOverload
	public subscript<Value>(
		dynamicMember keyPath: KeyPath<State, Value>
	) -> StorePublisher<Value> {
		StorePublisher<Value>(upstream: upstream.map(keyPath).eraseToAnyPublisher())
	}
}

/// An async sequence and publisher of store state.
@dynamicMemberLookup
public struct StoreAsyncSequence<State>: AsyncSequence {

	public typealias AsyncIterator = AsyncStream<State>.AsyncIterator
	public typealias Element = State

	let upstream: AnyPublisher<State, Never>

	/// Returns the resulting sequence of a given key path.
	public subscript<Value: Equatable>(
		dynamicMember keyPath: KeyPath<State, Value>
	) -> StoreAsyncSequence<Value> {
		StoreAsyncSequence<Value>(upstream: upstream.map(keyPath).removeDuplicates().eraseToAnyPublisher())
	}

	/// Returns the resulting sequence of a given key path.
	@_disfavoredOverload
	public subscript<Value>(
		dynamicMember keyPath: KeyPath<State, Value>
	) -> StoreAsyncSequence<Value> {
		StoreAsyncSequence<Value>(upstream: upstream.map(keyPath).eraseToAnyPublisher())
	}

	public func makeAsyncIterator() -> AsyncStream<State>.AsyncIterator {
		AsyncStream { continuation in
			let cancellable = upstream.sink { _ in
				continuation.finish()
			} receiveValue: {
				continuation.yield($0)
			}
			continuation.onTermination = { _ in
				cancellable.cancel()
			}
		}
		.makeAsyncIterator()
	}
}
