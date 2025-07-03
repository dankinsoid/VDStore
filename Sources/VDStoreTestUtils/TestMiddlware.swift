#if canImport(XCTest)
import Foundation
import XCTest
@_exported import VDStore

public final class TestMiddleware: StoreMiddleware {

	private var calledActions: [StoreActionID] = []
	private var calledActionsContinuations: [StoreActionID: [UUID: CheckedContinuation<Void, Never>]] = [:]
	private var executedActions: [(StoreActionID, Error?)] = []
	private var executedActionsContinuations: [StoreActionID: [UUID: CheckedContinuation<Void, Error>]] = [:]

	public init() {}

	public func execute<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Context,
		dependencies: DIValues,
		next: (Args) -> Res
	) -> Res {
		didCallAction(context.actionID)
		let result = next(args)
		executedActions.append((context.actionID, nil))
		return result
	}

	public func executeThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Throws.Context,
		dependencies: DIValues,
		next: (Args) -> Result<Res, Error>
	) -> Result<Res, Error> {
		didCallAction(context.actionID)
		let result = next(args)
		switch result {
		case .success:
			didExecuteAction(context.actionID, error: nil)
		case let .failure(failure):
			didExecuteAction(context.actionID, error: failure)
		}
		return result
	}

	public func executeAsync<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.Async.Context,
		dependencies: DIValues,
		next: (Args) -> Task<Res, Never>
	) -> Task<Res, Never> where Res: Sendable {
		didCallAction(context.actionID)
		let nextTask = next(args)
		Task {
			_ = await nextTask.value
			self.didExecuteAction(context.actionID, error: nil)
		}
		return nextTask
	}

	public func executeAsyncThrows<State, Args, Res>(
		_ args: Args,
		context: Store<State>.Action<Args, Res>.AsyncThrows.Context,
		dependencies: DIValues,
		next: (Args) -> Task<Res, Error>
	) -> Task<Res, Error> where Res: Sendable {
		didCallAction(context.actionID)
		let nextTask = next(args)
		Task {
			do {
				_ = try await nextTask.value
				self.didExecuteAction(context.actionID, error: nil)
			} catch {
				self.didExecuteAction(context.actionID, error: error)
			}
		}
		return nextTask
	}

	public func didExecute<State, Args, Res>(
		_ action: Store<State>.Action<Args, Res>,
		file: StaticString = #file,
		line: UInt = #line
	) throws {
		if let i = executedActions.firstIndex(where: { $0.0 == action.id }) {
			defer { executedActions.remove(at: i) }
			if let error = executedActions[i].1 {
				throw error
			}
			return
		}
		XCTFail("Action \(action.id) was not executed", file: file, line: line)
	}

	public func waitExecution<State, Args, Res>(
		of action: Store<State>.Action<Args, Res>,
		timeout: TimeInterval = 1,
		file: StaticString = #file,
		line: UInt = #line
	) async throws {
		if let i = executedActions.firstIndex(where: { $0.0 == action.id }) {
			defer { executedActions.remove(at: i) }
			if let error = executedActions[i].1 {
				throw error
			}
			return
		}
		guard timeout > 0 else {
			XCTFail("Timeout waiting for action \(action.id) to be executed", file: file, line: line)
			return
		}
		try await withThrowingTaskGroup(of: Void.self) { group in
			let uuid = UUID()
			group.addTask {
				try await withCheckedThrowingContinuation { continuation in
					self.executedActionsContinuations[action.id, default: [:]][uuid] = continuation
				}
			}
			group.addTask {
				try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
				if let continuation = self.executedActionsContinuations[action.id]?[uuid] {
					self.executedActionsContinuations[action.id]?[uuid] = nil
					XCTFail("Timeout waiting for action \(action.id) to be executed", file: file, line: line)
					continuation.resume()
				}
			}
			try await group.waitForAll()
		}
	}

	public func didCall<State, Args, Res>(
		_ action: Store<State>.Action<Args, Res>,
		file: StaticString = #file,
		line: UInt = #line
	) {
		if let i = calledActions.firstIndex(of: action.id) {
			calledActions.remove(at: i)
			return
		}
		XCTFail("Action \(action.id) was not called", file: file, line: line)
	}

	public func waitCall<State, Args, Res>(
		of action: Store<State>.Action<Args, Res>,
		timeout: TimeInterval = 0.1,
		file: StaticString = #file,
		line: UInt = #line
	) async {
		if let i = calledActions.firstIndex(of: action.id) {
			calledActions.remove(at: i)
			return
		}
		guard timeout > 0 else {
			XCTFail("Timeout waiting for action \(action.id) to be called", file: file, line: line)
			return
		}
		await withTaskGroup(of: Void.self) { group in
			let uuid = UUID()
			group.addTask {
				await withCheckedContinuation { continuation in
					self.calledActionsContinuations[action.id, default: [:]][uuid] = continuation
				}
			}
			group.addTask {
				try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
				if let continuation = self.calledActionsContinuations[action.id]?[uuid] {
					self.calledActionsContinuations[action.id]?[uuid] = nil
					XCTFail("Timeout waiting for action \(action.id) to be called", file: file, line: line)
					continuation.resume()
				}
			}
			await group.waitForAll()
		}
	}

	private func didCallAction(_ actionID: StoreActionID) {
		calledActions.append(actionID)
		calledActionsContinuations[actionID]?.values.forEach { $0.resume() }
		calledActionsContinuations[actionID] = nil
	}

	private func didExecuteAction(_ actionID: StoreActionID, error: Error?) {
		executedActions.append((actionID, error))
		executedActionsContinuations[actionID]?.values.forEach {
			if let error {
				$0.resume(throwing: error)
			} else {
				$0.resume()
			}
		}
		executedActionsContinuations[actionID] = nil
	}
}

#endif
