import Foundation
final class Subject: NSObject {}
struct Changed: NotificationCenter.MainActorMessage {
    typealias Subject = Foundation.NSObject
    let value: Int
    static let name = Notification.Name(rawValue: "qvolution.round3.changed")
    @MainActor static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, userInfo: ["value": message.value])
    }
    @MainActor static func makeMessage(_ notification: Notification) -> Self? {
        guard let value = notification.userInfo?["value"] as? Int else { return nil }
        return Self(value: value)
    }
}
@MainActor func checkMessages() {
    let center = NotificationCenter()
    let a = NSObject(), b = NSObject()
    var received: [Int] = []
    let token = center.addObserver(of: a, for: Changed.self) { received.append($0.value) }
    let copy = token
    precondition(token == copy && Set([token, copy]).count == 1)
    center.post(Changed(value: 1), subject: b)
    center.post(Changed(value: 2), subject: a)
    center.post(Notification(name: Changed.name, object: a, userInfo: ["value": 3]))
    precondition(received == [2, 3])
    NotificationCenter().removeObserver(token) // Wrong center must not cancel.
    center.post(Changed(value: 4), subject: a)
    precondition(received == [2, 3, 4])
    center.removeObserver(token)
    center.removeObserver(copy) // Idempotent.
    center.post(Changed(value: 5), subject: a)
    precondition(received == [2, 3, 4])
    do {
        let scoped = center.addObserver(of: a, for: Changed.self) { received.append($0.value) }
        center.post(Changed(value: 6), subject: a)
        withExtendedLifetime(scoped) {}
    }
    center.post(Changed(value: 7), subject: a)
    precondition(received == [2, 3, 4, 6])
}
MainActor.assumeIsolated { checkMessages() }
print("round3-messages: passed")
