//===----------------------------------------------------------------------===//
// This source file is part of the Swift.org open source project
// Copyright (c) 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information.
//===----------------------------------------------------------------------===//
// Public API and Service formatting adapted from Apple Swift 5.2.2,
// stdlib/public/Darwin/Network/NWListener.swift (rung 1).
// Darling's listener backend is entirely stubbed. Keep the Swift lifecycle
// without fabricating a C object or reporting a successful bind. ENOTSUP on
// start is our conservative unsupported-backend policy (GUESS, rung 6).

import Darwin
import Dispatch
import Foundation

@_objcRuntimeName(_TtC7Network11_NWListener)
@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public final class NWListener: CustomDebugStringConvertible {
    public struct Service: Equatable, CustomDebugStringConvertible {
        public let name: String?
        public let type: String
        public let domain: String?
        public let txtRecord: Data?

        public init(name: String? = nil, type: String, domain: String? = nil, txtRecord: Data? = nil) {
            self.name = name
            self.type = type
            self.domain = domain
            self.txtRecord = txtRecord
        }

        public var debugDescription: String {
            var description = "\(name ?? "*").\(type).\(domain ?? "*")"
            if let txtRecord = txtRecord, !txtRecord.isEmpty {
                description += " <\(txtRecord.count) bytes of txt>"
            }
            return description
        }
    }

    public enum State: Equatable {
        case setup
        case waiting(NWError)
        case ready
        case failed(NWError)
        case cancelled
    }

    public enum ServiceRegistrationChange {
        case add(NWEndpoint)
        case remove(NWEndpoint)
    }

    public let parameters: NWParameters
    public var service: Service?
    public var newConnectionHandler: ((_ connection: NWConnection) -> Void)?
    public var stateUpdateHandler: ((_ state: State) -> Void)?
    public var serviceRegistrationUpdateHandler: ((_ change: ServiceRegistrationChange) -> Void)?

    private let lock = NSLock()
    private var currentState: State = .setup
    private var callbackQueue: DispatchQueue?
    private var events: DispatchQueue?

    public var state: State {
        lock.lock()
        defer { lock.unlock() }
        return currentState
    }

    public var queue: DispatchQueue? {
        lock.lock()
        defer { lock.unlock() }
        return callbackQueue
    }

    /// No port is bound: start reports that the backend is unsupported.
    public var port: NWEndpoint.Port? { nil }

    public var debugDescription: String { "NWListener (unsupported backend)" }

    /// Retain configuration in setup; unsupported listening is reported on start.
    public init(using: NWParameters, on: NWEndpoint.Port = .any) throws {
        self.parameters = using
    }

    /// Deliver failure on the requested queue. Repeated starts are ignored.
    public func start(queue: DispatchQueue) {
        lock.lock()
        guard callbackQueue == nil, currentState != .cancelled else {
            lock.unlock()
            return
        }
        let events = DispatchQueue(label: "org.darling.network.listener", target: queue)
        callbackQueue = queue
        self.events = events
        lock.unlock()
        events.async { self.update(.failed(.posix(.ENOTSUP))) }
    }

    /// After start, cancellation is serialized with the failure event.
    public func cancel() {
        lock.lock()
        let events = self.events
        lock.unlock()
        if let events = events {
            events.async { self.update(.cancelled) }
        } else {
            update(.cancelled)
        }
    }

    private func update(_ state: State) {
        lock.lock()
        guard currentState != .cancelled, currentState != state else {
            lock.unlock()
            return
        }
        currentState = state
        lock.unlock()
        stateUpdateHandler?(state)
    }
}
