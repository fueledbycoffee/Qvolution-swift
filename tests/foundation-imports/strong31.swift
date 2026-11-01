import Foundation
import Combine
import Darwin

func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    precondition(condition(), label)
    print("PASS " + label)
    fflush(stdout)
}

let url = URL(string: "https://example.com/a?x=1#b")!
check(url.formatted(.url.scheme(.never)) == "example.com/a?x=1#b", "URL scheme suppression")
check(url.formatted(URL.FormatStyle()) == "https://example.com/a?x=1#b", "URL components")
let decoder = JSONDecoder()
check(!decoder.allowsJSON5, "JSON5 default off")
do {
    _ = try decoder.decode([String: Int].self, from: Data("{key: 1,}".utf8))
    preconditionFailure("strict decoder accepted JSON5")
} catch {}
decoder.allowsJSON5 = true
check(try! decoder.decode([String: Int].self, from: Data("{/*comment*/ key: +0x10,}".utf8)) == ["key":16], "JSON5 enabled")
check(try! decoder.decode(Float.self, from: Data("NaN".utf8)).isNaN, "JSON5 Float NaN")
func topDecoder<D: TopLevelDecoder>(_ d: D) where D.Input == Data {}
func topEncoder<E: TopLevelEncoder>(_ e: E) where E.Output == Data {}
topDecoder(decoder); topEncoder(JSONEncoder())
let center = NotificationCenter()
let name = Notification.Name("strong31")
var delivered = 0
let token = center.publisher(for: name).sink { _ in delivered += 1 }
center.post(name: name, object: nil)
check(delivered == 1, "publisher delivery")
token.cancel()
center.post(name: name, object: nil)
check(delivered == 1, "publisher cancellation")
let stride: RunLoop.SchedulerTimeType.Stride = 2
check(stride == .seconds(2.0), "run loop stride")
func scheduler<S: Scheduler>(_ value: S) {}
scheduler(RunLoop.current)
final class DemandProbe: Subscriber {
    typealias Input = Notification
    typealias Failure = Never
    var subscription: Subscription?
    var count = 0
    func receive(subscription: Subscription) { self.subscription = subscription }
    func receive(_ input: Notification) -> Subscribers.Demand { count += 1; return .none }
    func receive(completion: Subscribers.Completion<Never>) {}
}
let probe = DemandProbe()
center.publisher(for: name).receive(subscriber: probe)
center.post(name: name, object: nil)
check(probe.count == 0, "publisher honors zero demand")
probe.subscription!.request(.max(1))
center.post(name: name, object: nil)
center.post(name: name, object: nil)
check(probe.count == 1, "publisher consumes finite demand")
probe.subscription!.cancel()
var scheduled = false
RunLoop.current.schedule { scheduled = true }
let deadline = Date().addingTimeInterval(1)
while !scheduled && Date() < deadline { _ = RunLoop.current.run(mode: .default, before: deadline) }
check(scheduled, "run loop executes scheduled work")
let path = "/tmp/foundation-strong31-io"
let fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0600)
precondition(fd >= 0)
let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)!
try handle.write(contentsOf: Data([1,2,3]))
handle.seek(toFileOffset: 0)
check(try! handle.read(upToCount: 2) == Data([1,2]), "checked read")
check(try! handle.read(upToCount: 2) == Data([3]), "short read")
check(try! handle.read(upToCount: 2) == nil, "EOF nil")
handle.closeFile()
do { try handle.write(contentsOf: Data([4])); preconditionFailure("closed write succeeded") } catch {}
check("café".applyingTransform(.stripDiacritics, reverse: false) == "cafe", "string transform")
do { _ = try url.bookmarkData(); preconditionFailure("unsupported bookmark succeeded") } catch {}
var stale = false
do { _ = try URL(resolvingBookmarkData: Data([0]), bookmarkDataIsStale: &stale); preconditionFailure("invalid bookmark succeeded") } catch {}
do { _ = try URL(resolvingAliasFileAt: URL(fileURLWithPath: "/tmp/no-alias")); preconditionFailure("missing alias succeeded") } catch {}
var cached = url
cached.removeCachedResourceValue(forKey: .nameKey)
print("PASS strong31 Swift behavior")
