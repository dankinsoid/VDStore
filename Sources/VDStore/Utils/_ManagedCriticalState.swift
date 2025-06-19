import Foundation

internal struct _ManagedCriticalState<State> {
	private let lock: SynchronizationLock
	final private class LockedBuffer: ManagedBuffer<State, UnsafeRawPointer> {}

	private let buffer: ManagedBuffer<State, UnsafeRawPointer>

	internal init(_ buffer: ManagedBuffer<State, UnsafeRawPointer>) {
		self.buffer = buffer
#if canImport(os)
		if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
			self.lock = UnfairLockWrapper()
		} else {
			self.lock = NSLockWrapper()
		}
#else
		self.lock = NSLockWrapper()
#endif
	}

	internal init(_ initial: State) {
		let roundedSize =
			(MemoryLayout<UnsafeRawPointer>.size - 1) / MemoryLayout<UnsafeRawPointer>.size
		self.init(
			LockedBuffer.create(minimumCapacity: Swift.max(roundedSize, 1)) { buffer in
				return initial
			})
	}

	internal func withCriticalRegion<R>(
		_ critical: (inout State) throws -> R
	) rethrows -> R {
		try buffer.withUnsafeMutablePointers { header, lock in
			try self.lock.withLock {
				try critical(&header.pointee)
			}
		}
	}
}

extension _ManagedCriticalState: @unchecked Sendable where State: Sendable {}

extension _ManagedCriticalState: Identifiable {
	internal var id: ObjectIdentifier {
		ObjectIdentifier(buffer)
	}
}

// MARK: - Internal Synchronization Protocol

internal protocol SynchronizationLock: Sendable {
	func withLock<T>(_ body: () throws -> T) rethrows -> T
}

// MARK: - NSLock Wrapper

internal struct NSLockWrapper: SynchronizationLock {
	private let nsLock = NSLock()
	
	func withLock<T>(_ body: () throws -> T) rethrows -> T {
		try nsLock.withLock(body)
	}
}

// MARK: - OSAllocatedUnfairLock Wrapper

#if canImport(os)
import os

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
internal struct UnfairLockWrapper: SynchronizationLock {

	private let unfairLock = OSAllocatedUnfairLock()

	func withLock<T>(_ body: () throws -> T) rethrows -> T {
		try unfairLock.withLock {
			try body()
		}
	}
}
#endif
