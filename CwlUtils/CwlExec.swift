//
//  CwlExec.swift
//  CwlUtils
//
//  Created by Matt Gallagher on 2015/02/03.
//  Copyright © 2015 Matt Gallagher ( http://cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

import Foundation

/// A description about how functions will be invoked on an execution context.
public enum ExecutionType {
	/// Any function provided to `invoke` will be completed before the call to `invoke` returns. There is no inherent mutex (simultaneous invocations from multiple threads may run concurrently).
	case immediate
	
	/// Any function provided to `invoke` will be completed before the call to `invoke` returns. Mutual exclusion is applied preventing invocations from multiple threads running concurrently.
	case mutex
	
	/// Completion of the provided function is independent of the return from `invoke`. Subsequent functions provided to `invoke`, before completion if preceeding provided functions will be serialized and run after the preceeding calls have completed.
	case serialAsync
	
	/// If the current scope is already inside the context, the wrapped value will be `false` and the invocation will be `immediate`.
	/// If the current scope is not inside the context, the wrapped value will be `true` and the invocation will be like `serialAsync`.
	case conditionallyAsync(Bool)

	/// Completion of the provided function is independent of the return from `invoke`. Subsequent functions provided to `invoke` will be run concurrently.
	case concurrentAsync
	
	/// Returns true if an invoked function is guaranteed to complete before the `invoke` returns.
	public var isImmediate: Bool {
		switch self {
		case .immediate: return true
		case .mutex: return true
		case .conditionallyAsync(let now): return !now
		default: return false
		}
	}
	
	/// Returns true if simultaneous uses of the context from separate threads will run concurrently.
	public var isConcurrent: Bool {
		switch self {
		case .immediate: return true
		case .concurrentAsync: return true
		default: return false
		}
	}
}

/// An abstraction of common execution context concepts
public protocol ExecutionContext {
	/// A description about how functions will be invoked on an execution context.
	var type: ExecutionType { get }
	
	/// Run `execute` normally on the execution context
	func invoke(_ execute: @escaping () -> Void)
	
	/// Run `execute` asynchronously on the execution context
	func invokeAsync(_ execute: @escaping () -> Void)
	
	/// Run `execute` on the execution context but don't return from this function until the provided function is complete.
	func invokeAndWait(_ execute: @escaping () -> Void)

	/// Run `execute` on the execution context after `interval` (plus `leeway`) unless the returned `Cancellable` is cancelled or released before running occurs.
	func singleTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer

	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, unless the returned `Cancellable` is cancelled or released before running occurs.
	func singleTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	func periodicTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer

	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	func periodicTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`) unless the returned `Cancellable` is cancelled or released before running occurs.
	func singleTimer(interval: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer

	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, unless the returned `Cancellable` is cancelled or released before running occurs.
	func singleTimer<T>(parameter: T, interval: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	func periodicTimer(interval: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer

	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	func periodicTimer<T>(parameter: T, interval: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer
	
	/// Gets a timestamp representing the host uptime the in the current context
	func timestamp() -> DispatchTime
}

// Since it's not possible to have default parameters in protocols (yet) the "leeway" free functions are all default-implemented to call the "leeway" functions with a 0 second leeway.
extension ExecutionContext {
	public func singleTimer(interval: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer {
		return singleTimer(interval: interval, leeway: .seconds(0), handler: handler)
	}
	public func singleTimer<T>(parameter: T, interval: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer {
		return singleTimer(parameter: parameter, interval: interval, leeway: .seconds(0), handler: handler)
	}
	public func periodicTimer(interval: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer {
		return periodicTimer(interval: interval, leeway: .seconds(0), handler: handler)
	}
	public func periodicTimer<T>(parameter: T, interval: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer {
		return periodicTimer(parameter: parameter, interval: interval, leeway: .seconds(0), handler: handler)
	}
}

/// Timers need to be cancellable in two ways:
/// - Releasing the `Cancellable` should cancel the timer
/// - Invoking `cancel` should cancel the timer
/// The first point would usually imply the protocol be a `class` protocol but the default cause is `CancellableDispatchTimer` which is just a struct wrapper around a `DispatchSourceTimer` – the release behavior is handled by the underlying class, not the wrapper.
public protocol CancellableTimer {
	/// Immediately cancel the timer
	func cancel()
}

/// Slightly annoyingly, a `DispatchSourceTimer` is an existential, so we can't extend `DispatchSourceTimer` to conform to `CancellableTimer`. Instead, we use this littler wrapper around the `DispatchSourceTimer` to handle the conformance.
private struct CancellableDispatchTimer: CancellableTimer {
	let underlying: DispatchSourceTimer
	init(_ underlying: DispatchSourceTimer) {
		self.underlying = underlying
	}
	
	/// Immediately cancel the timer
	func cancel() {
		underlying.cancel()
	}
}

/// An `ExecutionContext` implementation around a DispatchQueue.
public struct CustomDispatchQueue: ExecutionContext {
	public let queue: DispatchQueue
	public init(sync: Bool = true, concurrent: Bool = false, qos: DispatchQoS = .default) {
		self.type = sync ? .mutex : (concurrent ? .concurrentAsync : .serialAsync)
		queue = DispatchQueue(label: "", qos: qos, attributes: concurrent ? DispatchQueue.Attributes.concurrent : DispatchQueue.Attributes(), autoreleaseFrequency: .inherit, target: nil)
	}

	/// A description about how functions will be invoked on an execution context.
	public let type: ExecutionType

	/// Run `execute` normally on the execution context
	public func invoke(_ execute: @escaping () -> Void) {
		if case .mutex = type {
			queue.sync(execute: execute)
		} else {
			queue.async(execute: execute)
		}
	}
	
	/// Run `execute` asynchronously on the execution context
	public func invokeAsync(_ execute: @escaping () -> Void) {
		queue.async(execute: execute)
	}
	
	/// Run `execute` on the execution context but don't return from this function until the provided function is complete.
	public func invokeAndWait(_ execute: @escaping () -> Void) {
		queue.sync(execute: execute)
	}

	/// Run `execute` on the execution context after `interval` (plus `leeway`) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func singleTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer {
		return CancellableDispatchTimer(DispatchSource.singleTimer(interval: interval, leeway: leeway, queue: queue, handler: handler))
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, unless the returned `Cancellable` is cancelled or released before running occurs.
	public func singleTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer {
		return CancellableDispatchTimer(DispatchSource.singleTimer(parameter: parameter, interval: interval, leeway: leeway, queue: queue, handler: handler))
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func periodicTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer {
		return CancellableDispatchTimer(DispatchSource.repeatingTimer(interval: interval, leeway: leeway, queue: queue, handler: handler))
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func periodicTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer {
		return CancellableDispatchTimer(DispatchSource.repeatingTimer(parameter: parameter, interval: interval, leeway: leeway, queue: queue, handler: handler))
	}

	/// Gets a timestamp representing the host uptime the in the current context
	public func timestamp() -> DispatchTime {
		return DispatchTime.now()
	}
}

/// A wrapper that applies an additional mutex
private class MutexWrappedCancellableTimer: CancellableTimer {
	var timer: CancellableTimer? = nil
	let mutex: PThreadMutex
	
	init(mutex: PThreadMutex) {
		self.mutex = mutex
	}
	
	func cancel() {
		mutex.sync {
			timer?.cancel()
			timer = nil
		}
	}
	
	deinit {
		cancel()
	}
}

/// An `ExecutionContext` wraps a mutex around calls invoked by an underlying execution context. The effect is to serialize concurrent contexts (immediate or concurrent).
public struct SerializingContext: ExecutionContext {
	public let underlying: ExecutionContext
	public let mutex = PThreadMutex(type: .recursive)
	
	public init(concurrentContext: ExecutionContext) {
		underlying = concurrentContext
	}

	public var type: ExecutionType {
		switch underlying.type {
		case .immediate: return .mutex
		case .concurrentAsync: return .serialAsync
		default: return underlying.type
		}
	}
	
	/// Run `execute` normally on the execution context
	public func invoke(_ execute: @escaping () -> Void) {
		underlying.invoke { [mutex] in mutex.sync(execute: execute) }
	}
	
	/// Run `execute` asynchronously on the execution context
	public func invokeAsync(_ execute: @escaping () -> Void) {
		underlying.invokeAsync { [mutex] in mutex.sync(execute: execute) }
	}
	
	/// Run `execute` on the execution context but don't return from this function until the provided function is complete.
	public func invokeAndWait(_ execute: @escaping () -> Void) {
		underlying.invokeAndWait { [mutex] in mutex.sync(execute: execute) }
	}

	/// Run `execute` on the execution context after `interval` (plus `leeway`) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func singleTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer {
		return mutex.sync { () -> CancellableTimer in
			let wrapper = MutexWrappedCancellableTimer(mutex: mutex)
			let cancellableTimer = underlying.singleTimer(interval: interval, leeway: leeway) { [weak wrapper] in
				if let w = wrapper {
					w.mutex.sync {
						if w.timer != nil {
							handler()
						}
					}
				}
			}
			wrapper.timer = cancellableTimer
			return wrapper
		}
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, unless the returned `Cancellable` is cancelled or released before running occurs.
	public func singleTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer {
		return mutex.sync { () -> CancellableTimer in
			let wrapper = MutexWrappedCancellableTimer(mutex: mutex)
			let cancellableTimer = underlying.singleTimer(parameter: parameter, interval: interval, leeway: leeway) { [weak wrapper] p in
				if let w = wrapper {
					w.mutex.sync {
						if w.timer != nil {
							handler(p)
						}
					}
				}
			}
			wrapper.timer = cancellableTimer
			return wrapper
		}
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func periodicTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping () -> Void) -> CancellableTimer {
		return mutex.sync { () -> CancellableTimer in
			let wrapper = MutexWrappedCancellableTimer(mutex: mutex)
			let cancellableTimer = underlying.periodicTimer(interval: interval, leeway: leeway) { [weak wrapper] in
				if let w = wrapper {
					w.mutex.sync {
						if w.timer != nil {
							handler()
						}
					}
				}
			}
			wrapper.timer = cancellableTimer
			return wrapper
		}
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func periodicTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, handler: @escaping (T) -> Void) -> CancellableTimer {
		return mutex.sync { () -> CancellableTimer in
			let wrapper = MutexWrappedCancellableTimer(mutex: mutex)
			let cancellableTimer = underlying.periodicTimer(parameter: parameter, interval: interval, leeway: leeway) { [weak wrapper] p in
				if let w = wrapper {
					w.mutex.sync {
						if w.timer != nil {
							handler(p)
						}
					}
				}
			}
			wrapper.timer = cancellableTimer
			return wrapper
		}
	}

	/// Gets a timestamp representing the host uptime the in the current context
	public func timestamp() -> DispatchTime {
		return underlying.timestamp()
	}
}

/// While `Exec` is an implementation of `ExecutionContext`, it is intended to be more transparent – allowing a context to be asked if it is a specific context like `sync` or `main`, so that the user of the `Exec` can perform appropriate optimizations.
public enum Exec: ExecutionContext {
	/// Invoked directly from the caller's context
	case direct
	
	/// Invoked on the main thread, directly if the current thread is the main thread, otherwise asynchronously
	case main
	
	/// Invoked on the main thread, always asynchronously
	case mainAsync
	
	/// Invoked asynchronously in the global queue with QOS_CLASS_USER_INTERACTIVE priority
	case interactive

	/// Invoked asynchronously in the global queue with QOS_CLASS_USER_INITIATED priority
	case user

	/// Invoked asynchronously in the global queue with QOS_CLASS_DEFAULT priority
	case `default`

	/// Invoked asynchronously in the global queue with QOS_CLASS_UTILITY priority
	case utility

	/// Invoked asynchronously in the global queue with QOS_CLASS_BACKGROUND priority
	case background

	/// Invoked using the wrapped existential.
	case custom(ExecutionContext)

	var dispatchQueue: DispatchQueue {
		switch self {
		case .direct: return DispatchQueue.global()
		case .main: return DispatchQueue.main
		case .mainAsync: return DispatchQueue.main
		case .custom: return DispatchQueue.global()
		case .interactive: return DispatchQueue.global(qos: .userInteractive)
		case .user: return DispatchQueue.global(qos: .userInitiated)
		case .default: return DispatchQueue.global()
		case .utility: return DispatchQueue.global(qos: .utility)
		case .background: return DispatchQueue.global(qos: .background)
		}
	}
	
	/// A description about how functions will be invoked on an execution context.
	public var type: ExecutionType {
		switch self {
		case .direct: return .immediate
		case .main where Thread.isMainThread: return .conditionallyAsync(false)
		case .main: return .conditionallyAsync(true)
		case .mainAsync: return .serialAsync
		case .custom(let c): return c.type
		case .interactive: return .concurrentAsync
		case .user: return .concurrentAsync
		case .default: return .concurrentAsync
		case .utility: return .concurrentAsync
		case .background: return .concurrentAsync
		}
	}
	
	/// Run `execute` normally on the execution context
	public func invoke(_ execute: @escaping () -> Void) {
		switch self {
		case .direct: execute()
		case .custom(let c): c.invoke(execute)
		case .main where Thread.isMainThread: execute()
		default: dispatchQueue.async(execute: execute)
		}
	}
	
	/// Run `execute` asynchronously on the execution context
	public func invokeAsync(_ execute: @escaping () -> Void) {
		switch self {
		case .custom(let c): c.invokeAsync(execute)
		default: dispatchQueue.async(execute: execute)
		}
	}

	/// Run `execute` on the execution context but don't return from this function until the provided function is complete.
	public func invokeAndWait(_ execute: @escaping () -> Void) {
		switch self {
		case .custom(let c):
			var complete = false
			c.invokeAndWait {
				execute()
				complete = true
			}
			precondition(complete, "Custom Exec failed to run execute before returning")
		case .main where Thread.isMainThread: execute()
		case .main: DispatchQueue.main.async(execute: execute)
		case .mainAsync where Thread.isMainThread: execute()
		case .mainAsync: DispatchQueue.main.async(execute: execute)
		case .direct: fallthrough
		case .interactive: fallthrough
		case .user: fallthrough
		case .default: fallthrough
		case .utility: fallthrough
		case .background:
			// For all other cases, assume the queue isn't actually required (and was only provided for asynchronous behavior). Just invoke the provided function directly.
			execute()
		}
	}
	
	/// If this context is concurrent, returns a serialization around this context, otherwise returns this context.
	public func serialized() -> Exec {
		if self.type.isConcurrent {
			return Exec.custom(SerializingContext(concurrentContext: self))
		}
		return self
	}
	
	/// Constructs an `Exec.custom` wrapping a synchronous `DispatchQueue`
	public static func syncQueue() -> Exec {
		return Exec.custom(CustomDispatchQueue())
	}
	
	/// Constructs an `Exec.custom` wrapping a synchronous `DispatchQueue` with a `DispatchSpecificKey` set for the queue (so that it can be identified when active).
	public static func syncQueueWithSpecificKey() -> (Exec, DispatchSpecificKey<()>) {
		let cdq = CustomDispatchQueue()
		let specificKey = DispatchSpecificKey<()>()
		cdq.queue.setSpecific(key: specificKey, value: ())
		return (Exec.custom(cdq), specificKey)
	}
	
	/// Constructs an `Exec.custom` wrapping an asynchronous `DispatchQueue`
	public static func asyncQueue(qos: DispatchQoS = .default) -> Exec {
		return Exec.custom(CustomDispatchQueue(sync: false, qos: qos))
	}
	
	/// Constructs an `Exec.custom` wrapping an asynchronous `DispatchQueue` with a `DispatchSpecificKey` set for the queue (so that it can be identified when active).
	public static func asyncQueueWithSpecificKey(qos: DispatchQoS = .default) -> (Exec, DispatchSpecificKey<()>) {
		let cdq = CustomDispatchQueue(sync: false, qos: qos)
		let specificKey = DispatchSpecificKey<()>()
		cdq.queue.setSpecific(key: specificKey, value: ())
		return (Exec.custom(cdq), specificKey)
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func singleTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval = .nanoseconds(0), handler: @escaping () -> Void) -> CancellableTimer {
		if case .custom(let c) = self {
			return c.singleTimer(interval: interval, leeway: leeway, handler: handler)
		}
		return CancellableDispatchTimer(DispatchSource.singleTimer(interval: interval, leeway: leeway, queue: dispatchQueue, handler: handler))
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, unless the returned `Cancellable` is cancelled or released before running occurs.
	public func singleTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval = .nanoseconds(0), handler: @escaping (T) -> Void) -> CancellableTimer {
		if case .custom(let c) = self {
			return c.singleTimer(parameter: parameter, interval: interval, leeway: leeway, handler: handler)
		}
		return CancellableDispatchTimer(DispatchSource.singleTimer(parameter: parameter, interval: interval, leeway: leeway, queue: dispatchQueue, handler: handler))
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func periodicTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval = .nanoseconds(0), handler: @escaping () -> Void) -> CancellableTimer {
		if case .custom(let c) = self {
			return c.periodicTimer(interval: interval, leeway: leeway, handler: handler)
		}
		return CancellableDispatchTimer(DispatchSource.repeatingTimer(interval: interval, leeway: leeway, queue: dispatchQueue, handler: handler))
	}
	
	/// Run `execute` on the execution context after `interval` (plus `leeway`), passing the `parameter` value as an argument, and again every `interval` (within a `leeway` margin of error) unless the returned `Cancellable` is cancelled or released before running occurs.
	public func periodicTimer<T>(parameter: T, interval: DispatchTimeInterval, leeway: DispatchTimeInterval = .nanoseconds(0), handler: @escaping (T) -> Void) -> CancellableTimer {
		if case .custom(let c) = self {
			return c.periodicTimer(parameter: parameter, interval: interval, leeway: leeway, handler: handler)
		}
		return CancellableDispatchTimer(DispatchSource.repeatingTimer(parameter: parameter, interval: interval, leeway: leeway, queue: dispatchQueue, handler: handler))
	}

	/// Gets a timestamp representing the host uptime the in the current context
	public func timestamp() -> DispatchTime {
		if case .custom(let c) = self {
			return c.timestamp()
		}
		return DispatchTime.now()
	}
}
