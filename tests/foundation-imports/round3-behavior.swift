import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func progress(_ check: String) {
    print("CHECK round3-behavior: \(check)")
    fflush(nil)
}

struct Item { var number: Int; var optional: Int? }
progress("01 comparator.forward.init")
let ascending = KeyPathComparator(\Item.number, order: .forward)
progress("02 comparator.reverse.init")
let descending = KeyPathComparator(\Item.number, order: .reverse)
progress("03 comparator.optional.init")
let optional = KeyPathComparator(\Item.optional, order: .forward)
progress("04 item.nil.init")
let a = Item(number: 2, optional: nil)
progress("05 item.value.init")
let b = Item(number: 10, optional: 1)
progress("06 comparator.forward.compare")
precondition(ascending.compare(a, b) == .orderedAscending)
progress("07 comparator.reverse.compare")
precondition(descending.compare(a, b) == .orderedDescending)
progress("08 comparator.optional.compare")
precondition(optional.compare(a, b) == .orderedAscending)
progress("09 comparator.sorted")
precondition([b, a].sorted(using: ascending).map(\.number) == [2, 10])
progress("10 comparator.equality")
precondition(ascending == KeyPathComparator(\Item.number, order: .forward))
progress("11 comparator.hash")
precondition(Set([ascending, ascending]).count == 1)

progress("12 string.padded.init")
let padded = "prefix\néclair\r\nlast"
progress("13 string.slice.init")
let slice = padded[padded.index(padded.startIndex, offsetBy: 7)...]
progress("14 string.utf8.length")
precondition(slice.lengthOfBytes(using: .utf8) == 13)
progress("15 string.ascii.convertible")
precondition(!slice.canBeConverted(to: .ascii))
progress("16 string.normalize.canonical.composed")
precondition(slice.precomposedStringWithCanonicalMapping == "éclair\r\nlast")
progress("17 string.normalize.canonical.decomposed")
precondition(slice.decomposedStringWithCanonicalMapping.utf16.count == 13)
progress("18 string.normalize.compatibility.composed")
precondition("①".precomposedStringWithCompatibilityMapping == "1")
progress("19 string.fold.locale")
precondition("É".folding(options: .init(rawValue: 129), locale: Locale(identifier: "en_US")) == "e")
progress("20 lines.init")
var lines: [String] = []
progress("21 string.enumerateLines")
slice.enumerateLines { line, stop in lines.append(line); stop = true }
progress("22 string.enumerateLines.result")
precondition(lines == ["éclair"])
progress("23 string.selection.init")
let selection = slice.startIndex..<slice.index(after: slice.startIndex)
progress("24 string.lineRange")
precondition(String(slice[slice.lineRange(for: selection)]) == "éclair\r\n")
progress("25 line.indices.init")
var start = slice.endIndex, end = slice.startIndex, contents = slice.startIndex
progress("26 string.getLineStart")
slice.getLineStart(&start, end: &end, contentsEnd: &contents, for: selection)
progress("27 string.line.contents")
precondition(start == slice.startIndex && String(slice[start..<contents]) == "éclair")
progress("28 string.line.terminator")
precondition(String(slice[start..<end]) == "éclair\r\n")
progress("29 string.decode.utf8.valid")
precondition(String(bytes: [0xc3, 0xa9], encoding: .utf8) == "é")
progress("30 string.decode.utf8.invalid")
precondition(String(bytes: [0xff], encoding: .utf8) == nil)
progress("31 utf16.units.init")
let units: [UInt16] = [0x41, 0xd83d, 0xde00]
progress("32 string.decode.utf16")
precondition(units.withUnsafeBufferPointer { String(utf16CodeUnits: $0.baseAddress!, count: $0.count) } == "A😀")
progress("33 string.encodings.available")
precondition(String.availableStringEncodings.contains(.utf8))
progress("34 string.encoding.localizedName")
precondition(!String.localizedName(of: .utf8).isEmpty)
progress("35 substring.init")
let substring = "[hello]".dropFirst().dropLast()
progress("36 substring.bridge")
precondition(substring._bridgeToObjectiveC() as String == "hello")

progress("37 nsdictionary.init")
let dictionary: NSDictionary = ["one": 1, "two": 2]
progress("38 nsdictionary.iterator.init")
var pairs = dictionary.makeIterator()
progress("39 nsdictionary.keys.init")
var keys = Set<String>()
progress("40 nsdictionary.iterator.next")
while let pair = pairs.next() { keys.insert(pair.key as! String) }
progress("41 nsdictionary.iterator.result")
precondition(keys == ["one", "two"])
progress("42 nsrange.init")
let range = NSRange(location: 4, length: 9)
progress("43 nsrange.optional.init")
var bridged: NSRange?
progress("44 nsrange.bridge.conditional")
precondition(NSRange._conditionallyBridgeFromObjectiveC(range._bridgeToObjectiveC(), result: &bridged))
progress("45 nsrange.bridge.result")
precondition(bridged == range)
progress("46 passed")
print("round3-behavior: passed")
