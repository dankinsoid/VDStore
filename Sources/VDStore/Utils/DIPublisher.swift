import Combine
import Foundation

struct DIPublisher<Base: Publisher>: Publisher {

	typealias Output = Base.Output
	typealias Failure = Base.Failure

	let base: Base
	let values: (DIValues) -> DIValues

	init(base: Base, modifier: @escaping (DIValues) -> DIValues) {
		self.base = base
		values = modifier
	}

	func receive<S>(subscriber: S) where S: Subscriber, Base.Failure == S.Failure, Base.Output == S.Input {
		base.receive(subscriber: DISubscriber(base: subscriber, values: values))
	}
}

struct DISubscriber<Base: Subscriber>: Subscriber {

	typealias Input = Base.Input
	typealias Failure = Base.Failure

	let base: Base
	let values: (DIValues) -> DIValues

	var combineIdentifier: CombineIdentifier { base.combineIdentifier }

	func receive(subscription: Subscription) {
		execute {
			base.receive(subscription: subscription)
		}
	}

	func receive(_ input: Base.Input) -> Subscribers.Demand {
		execute {
			base.receive(input)
		}
	}

	func receive(completion: Subscribers.Completion<Base.Failure>) {
		execute {
			base.receive(completion: completion)
		}
	}

	func execute<T>(_ operation: () -> T) -> T {
		DIValues.$current.withValue(values) {
			operation()
		}
	}
}
