// Copyright (c) 2014-2025 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// Port of swift-foundation dbacc67779dc NotificationCenter/MainActorMessage.swift
// and NotificationCenterMessage.swift, using Darling's public block observer API.

extension NotificationCenter {
    public protocol MainActorMessage: SendableMetatype {
        associatedtype Subject
        static var name: Notification.Name { get }
        @MainActor static func makeMessage(_ notification: Notification) -> Self?
        @MainActor static func makeNotification(_ message: Self) -> Notification
    }

    public protocol MessageIdentifier {
        associatedtype MessageType
    }

    public struct BaseMessageIdentifier<MessageType>: MessageIdentifier, Sendable {
        public init() where MessageType: MainActorMessage {}
    }

    public struct ObservationToken: Hashable, Sendable {
        fileprivate let storage: Storage

        fileprivate final class Storage: @unchecked Sendable {
            weak var center: NotificationCenter?
            private var token: Any?
            private let lock = NSLock()

            init(center: NotificationCenter, token: Any) {
                self.center = center
                self.token = token
            }

            func remove() {
                lock.lock()
                let old = token
                token = nil
                lock.unlock()
                if let old { center?.removeObserver(old) }
            }

            deinit { remove() }
        }

        public static func ==(lhs: Self, rhs: Self) -> Bool { lhs.storage === rhs.storage }
        public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(storage)) }
    }

    public func removeObserver(_ token: ObservationToken) {
        guard token.storage.center == nil || token.storage.center === self else { return }
        token.storage.remove()
    }

    public func addObserver<Identifier: MessageIdentifier, Message: MainActorMessage>(
        of subject: Message.Subject, for identifier: Identifier,
        using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Identifier.MessageType == Message, Message.Subject: AnyObject {
        _addMainActorObserver(subject: subject, observer: observer)
    }

    public func addObserver<Identifier: MessageIdentifier, Message: MainActorMessage>(
        of subject: Message.Subject.Type, for identifier: Identifier,
        using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Identifier.MessageType == Message {
        _addMainActorObserver(subject: nil, observer: observer)
    }

    public func addObserver<Message: MainActorMessage>(
        of subject: Message.Subject? = nil, for messageType: Message.Type,
        using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Message.Subject: AnyObject {
        _addMainActorObserver(subject: subject, observer: observer)
    }

    fileprivate func _addMainActorObserver<Message: MainActorMessage>(
        subject: Message.Subject?, observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken {
        nonisolated(unsafe) let observer = observer
        let token = addObserver(forName: Message.name, object: subject, queue: nil) { notification in
            nonisolated(unsafe) let notification = notification
            MainActor.assumeIsolated {
                if let value = notification.userInfo?[_messageKey] as? Message {
                    observer(value)
                } else if let value = Message.makeMessage(notification) {
                    observer(value)
                }
            }
        }
        return ObservationToken(storage: .init(center: self, token: token))
    }

    @MainActor public func post<Message: MainActorMessage>(_ message: Message, subject: Message.Subject)
    where Message.Subject: AnyObject {
        _post(message: message, subject: subject)
    }

    @MainActor public func post<Message: MainActorMessage>(_ message: Message) {
        _post(message: message)
    }

    @MainActor private func _post<Message: MainActorMessage>(message: Message, subject: Message.Subject? = nil) {
        var notification = Message.makeNotification(message)
        notification.name = Message.name
        notification.object = subject
        var userInfo = notification.userInfo ?? [:]
        userInfo[_messageKey] = message
        notification.userInfo = userInfo
        post(notification)
    }
}

// An identity key cannot collide with an application-provided string key.
private final class _NotificationMessageKey: NSObject, NSCopying {
    func copy(with zone: NSZone? = nil) -> Any { self }
}
private let _messageKey = AnyHashable(_NotificationMessageKey())

extension NotificationCenter.MainActorMessage {
    public static var name: Notification.Name { Notification.Name(rawValue: _typeName(Self.self)) }
    @MainActor public static func makeMessage(_ notification: Notification) -> Self? { nil }
    @MainActor public static func makeNotification(_ message: Self) -> Notification { Notification(name: name) }
}
