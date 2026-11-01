import Foundation
import Combine
import Darwin

func progress(_ label: String) {
    print("CHECK " + label)
    fflush(stdout)
}

func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    precondition(condition(), label)
    print("PASS " + label)
    fflush(stdout)
}

progress("let url = URL(string: \"https://example.com/a?x=1#b\")!")
let url = URL(string: "https://example.com/a?x=1#b")!
progress("check(url.formatted(.url.scheme(.never)) == \"example.com/a?x=1#b\", \"URL scheme suppression\")")
check(url.formatted(.url.scheme(.never)) == "example.com/a?x=1#b", "URL scheme suppression")
progress("check(url.formatted(URL.FormatStyle()) == \"https://example.com/a?x=1#b\", \"URL components\")")
check(url.formatted(URL.FormatStyle()) == "https://example.com/a?x=1#b", "URL components")
progress("let decoder = JSONDecoder()")
let decoder = JSONDecoder()
progress("check(!decoder.allowsJSON5, \"JSON5 default off\")")
check(!decoder.allowsJSON5, "JSON5 default off")
progress("do {")
do {
    _ = try decoder.decode([String: Int].self, from: Data("{key: 1,}".utf8))
    preconditionFailure("strict decoder accepted JSON5")
} catch {}
progress("decoder.allowsJSON5 = true")
decoder.allowsJSON5 = true
progress("check(try! decoder.decode([String: Int].self, from: Data(\"{/*comment*/ key: +0x10,}\".utf8)) == [\"key\":16], \"JSON5 enabled\")")
check(try! decoder.decode([String: Int].self, from: Data("{/*comment*/ key: +0x10,}".utf8)) == ["key":16], "JSON5 enabled")
progress("check(try! decoder.decode(Float.self, from: Data(\"NaN\".utf8)).isNaN, \"JSON5 Float NaN\")")
check(try! decoder.decode(Float.self, from: Data("NaN".utf8)).isNaN, "JSON5 Float NaN")
func topDecoder<D: TopLevelDecoder>(_ d: D) where D.Input == Data {}
func topEncoder<E: TopLevelEncoder>(_ e: E) where E.Output == Data {}
progress("topDecoder(decoder); topEncoder(JSONEncoder())")
topDecoder(decoder); topEncoder(JSONEncoder())
progress("let center = NotificationCenter()")
let center = NotificationCenter()
progress("let name = Notification.Name(\"strong31\")")
let name = Notification.Name("strong31")
progress("var delivered = 0")
var delivered = 0
progress("let token = center.publisher(for: name).sink { _ in delivered += 1 }")
let token = center.publisher(for: name).sink { _ in delivered += 1 }
progress("center.post(name: name, object: nil)")
center.post(name: name, object: nil)
progress("check(delivered == 1, \"publisher delivery\")")
check(delivered == 1, "publisher delivery")
progress("token.cancel()")
token.cancel()
progress("center.post(name: name, object: nil)")
center.post(name: name, object: nil)
progress("check(delivered == 1, \"publisher cancellation\")")
check(delivered == 1, "publisher cancellation")
progress("let stride: RunLoop.SchedulerTimeType.Stride = 2")
let stride: RunLoop.SchedulerTimeType.Stride = 2
progress("check(stride == .seconds(2.0), \"run loop stride\")")
check(stride == .seconds(2.0), "run loop stride")
func scheduler<S: Scheduler>(_ value: S) {}
progress("scheduler(RunLoop.current)")
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
progress("let probe = DemandProbe()")
let probe = DemandProbe()
progress("center.publisher(for: name).receive(subscriber: probe)")
center.publisher(for: name).receive(subscriber: probe)
progress("center.post(name: name, object: nil)")
center.post(name: name, object: nil)
progress("check(probe.count == 0, \"publisher honors zero demand\")")
check(probe.count == 0, "publisher honors zero demand")
progress("probe.subscription!.request(.max(1))")
probe.subscription!.request(.max(1))
progress("center.post(name: name, object: nil)")
center.post(name: name, object: nil)
progress("center.post(name: name, object: nil)")
center.post(name: name, object: nil)
progress("check(probe.count == 1, \"publisher consumes finite demand\")")
check(probe.count == 1, "publisher consumes finite demand")
progress("probe.subscription!.cancel()")
probe.subscription!.cancel()
progress("var scheduled = false")
var scheduled = false
progress("RunLoop.current.schedule { scheduled = true }")
RunLoop.current.schedule { scheduled = true }
progress("let deadline = Date().addingTimeInterval(1)")
let deadline = Date().addingTimeInterval(1)
progress("while !scheduled && Date() < deadline { _ = RunLoop.current.run(mode: .default, before: deadline) }")
while !scheduled && Date() < deadline { _ = RunLoop.current.run(mode: .default, before: deadline) }
progress("check(scheduled, \"run loop executes scheduled work\")")
check(scheduled, "run loop executes scheduled work")
progress("let path = \"/Applications/r2-foundation-stub/foundation-strong31-io\"")
let path = "/Applications/r2-foundation-stub/foundation-strong31-io"
progress("let fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0600)")
let fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0600)
progress("precondition(fd >= 0)")
precondition(fd >= 0)
progress("let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)!")
let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)!
progress("try handle.write(contentsOf: Data([1,2,3]))")
try handle.write(contentsOf: Data([1,2,3]))
progress("handle.seek(toFileOffset: 0)")
handle.seek(toFileOffset: 0)
progress("check(try! handle.read(upToCount: 2) == Data([1,2]), \"checked read\")")
check(try! handle.read(upToCount: 2) == Data([1,2]), "checked read")
progress("check(try! handle.read(upToCount: 2) == Data([3]), \"short read\")")
check(try! handle.read(upToCount: 2) == Data([3]), "short read")
progress("check(try! handle.read(upToCount: 2) == nil, \"EOF nil\")")
check(try! handle.read(upToCount: 2) == nil, "EOF nil")
progress("handle.closeFile()")
handle.closeFile()
progress("print(\"PASS checked handle close\"); fflush(stdout)")
print("PASS checked handle close"); fflush(stdout)
progress("do { try handle.write(contentsOf: Data([4])); preconditionFailure(\"closed write succeeded\") } catch {}")
do { try handle.write(contentsOf: Data([4])); preconditionFailure("closed write succeeded") } catch {}
progress("print(\"PASS closed write throws\"); fflush(stdout)")
print("PASS closed write throws"); fflush(stdout)
progress("do { try handle.write(contentsOf: Data()); preconditionFailure(\"empty closed write succeeded\") } catch {}")
do { try handle.write(contentsOf: Data()); preconditionFailure("empty closed write succeeded") } catch {}
progress("do { _ = try handle.read(upToCount: 1); preconditionFailure(\"closed read succeeded\") } catch {}")
do { _ = try handle.read(upToCount: 1); preconditionFailure("closed read succeeded") } catch {}
progress("check(\"café\".applyingTransform(.stripDiacritics, reverse: false) == \"cafe\", \"string transform\")")
check("café".applyingTransform(.stripDiacritics, reverse: false) == "cafe", "string transform")
progress("do { _ = try url.bookmarkData(); preconditionFailure(\"unsupported bookmark succeeded\") } catch {}")
do { _ = try url.bookmarkData(); preconditionFailure("unsupported bookmark succeeded") } catch {}
progress("var stale = false")
var stale = false
progress("do { _ = try URL(resolvingBookmarkData: Data([0]), bookmarkDataIsStale: &stale); preconditionFailure(\"invalid bookmark succeeded\") } catch {}")
do { _ = try URL(resolvingBookmarkData: Data([0]), bookmarkDataIsStale: &stale); preconditionFailure("invalid bookmark succeeded") } catch {}
progress("do { _ = try URL(resolvingAliasFileAt: URL(fileURLWithPath: \"/tmp/no-alias\")); preconditionFailure(\"missing alias succeeded\") } catch {}")
do { _ = try URL(resolvingAliasFileAt: URL(fileURLWithPath: "/tmp/no-alias")); preconditionFailure("missing alias succeeded") } catch {}
progress("var cached = url")
var cached = url
progress("cached.removeCachedResourceValue(forKey: .nameKey)")
cached.removeCachedResourceValue(forKey: .nameKey)
progress("print(\"PASS strong31 Swift behavior\")")
print("PASS strong31 Swift behavior")
