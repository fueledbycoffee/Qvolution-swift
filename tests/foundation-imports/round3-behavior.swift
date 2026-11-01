import Foundation

struct Item { var number: Int; var optional: Int? }
let ascending = KeyPathComparator(\Item.number, order: .forward)
let descending = KeyPathComparator(\Item.number, order: .reverse)
let optional = KeyPathComparator(\Item.optional, order: .forward)
let a = Item(number: 2, optional: nil)
let b = Item(number: 10, optional: 1)
precondition(ascending.compare(a, b) == .orderedAscending)
precondition(descending.compare(a, b) == .orderedDescending)
precondition(optional.compare(a, b) == .orderedAscending)
precondition([b, a].sorted(using: ascending).map(\.number) == [2, 10])
precondition(ascending == KeyPathComparator(\Item.number, order: .forward))
precondition(Set([ascending, ascending]).count == 1)

let padded = "prefix\néclair\r\nlast"
let slice = padded[padded.index(padded.startIndex, offsetBy: 7)...]
precondition(slice.lengthOfBytes(using: .utf8) == 13)
precondition(!slice.canBeConverted(to: .ascii))
precondition(slice.precomposedStringWithCanonicalMapping == "éclair\r\nlast")
precondition(slice.decomposedStringWithCanonicalMapping.utf16.count == 13)
precondition("①".precomposedStringWithCompatibilityMapping == "1")
precondition("É".folding(options: .init(rawValue: 129), locale: Locale(identifier: "en_US")) == "e")
var lines: [String] = []
slice.enumerateLines { line, stop in lines.append(line); stop = true }
precondition(lines == ["éclair"])
let selection = slice.startIndex..<slice.index(after: slice.startIndex)
precondition(String(slice[slice.lineRange(for: selection)]) == "éclair\r\n")
var start = slice.endIndex, end = slice.startIndex, contents = slice.startIndex
slice.getLineStart(&start, end: &end, contentsEnd: &contents, for: selection)
precondition(start == slice.startIndex && String(slice[start..<contents]) == "éclair")
precondition(String(slice[start..<end]) == "éclair\r\n")
precondition(String(bytes: [0xc3, 0xa9], encoding: .utf8) == "é")
precondition(String(bytes: [0xff], encoding: .utf8) == nil)
let units: [UInt16] = [0x41, 0xd83d, 0xde00]
precondition(units.withUnsafeBufferPointer { String(utf16CodeUnits: $0.baseAddress!, count: $0.count) } == "A😀")
precondition(String.availableStringEncodings.contains(.utf8))
precondition(!String.localizedName(of: .utf8).isEmpty)
let substring = "[hello]".dropFirst().dropLast()
precondition(substring._bridgeToObjectiveC() as String == "hello")

let dictionary: NSDictionary = ["one": 1, "two": 2]
var pairs = dictionary.makeIterator()
var keys = Set<String>()
while let pair = pairs.next() { keys.insert(pair.key as! String) }
precondition(keys == ["one", "two"])
let range = NSRange(location: 4, length: 9)
var bridged: NSRange?
precondition(NSRange._conditionallyBridgeFromObjectiveC(range._bridgeToObjectiveC(), result: &bridged))
precondition(bridged == range)
print("round3-behavior: passed")
