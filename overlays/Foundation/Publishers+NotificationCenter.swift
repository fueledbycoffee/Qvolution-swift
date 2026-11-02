// Written for Darling. GUESS: Combine contract from public API names and demand semantics.
@_exported import Foundation
import Combine

extension JSONDecoder: TopLevelDecoder { public typealias Input = Data }
extension JSONEncoder: TopLevelEncoder { public typealias Output = Data }

extension NotificationCenter {
    public struct Publisher: Combine.Publisher, Equatable {
        public typealias Output = Notification
        public typealias Failure = Never
        public let center: NotificationCenter
        public let name: Notification.Name
        public let object: AnyObject?

        public init(center: NotificationCenter, name: Notification.Name, object: AnyObject? = nil) {
            self.center = center
            self.name = name
            self.object = object
        }

        public func receive<S: Subscriber>(subscriber: S) where S.Input == Notification, S.Failure == Never {
            subscriber.receive(subscription: NotificationSubscription(center: center, name: name, object: object, downstream: subscriber))
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.center === rhs.center && lhs.name == rhs.name && lhs.object === rhs.object
        }
    }

    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> Publisher {
        Publisher(center: self, name: name, object: object)
    }
}

private final class NotificationSubscription<S: Subscriber>: Subscription where S.Input == Notification, S.Failure == Never {
    private let lock = NSRecursiveLock()
    private var center: NotificationCenter?
    private var observer: Any?
    private var downstream: S?
    private var demand: Subscribers.Demand = .none

    init(center: NotificationCenter, name: Notification.Name, object: AnyObject?, downstream: S) {
        self.center = center
        self.downstream = downstream
        observer = center.addObserver(forName: name, object: object, queue: nil) { [weak self] note in
            self?.receive(note)
        }
    }

    private func receive(_ note: Notification) {
        lock.lock()
        defer { lock.unlock() }
        guard demand > .none, let downstream = downstream else { return }
        demand -= 1
        let additional = downstream.receive(note)
        if self.downstream != nil { demand += additional }
    }

    func request(_ demand: Subscribers.Demand) {
        precondition(demand > .none, "Demand must be positive")
        lock.lock()
        defer { lock.unlock() }
        if downstream != nil { self.demand += demand }
    }

    func cancel() {
        lock.lock()
        let oldCenter = center
        let oldObserver = observer
        center = nil
        observer = nil
        downstream = nil
        lock.unlock()
        if let oldObserver = oldObserver { oldCenter?.removeObserver(oldObserver) }
    }

    deinit { cancel() }
}
