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
progress("01 let ascending = KeyPathComparator(Item.number, order: .forward)")
let ascending = KeyPathComparator(\Item.number, order: .forward)
progress("02 let descending = KeyPathComparator(Item.number, order: .reverse)")
let descending = KeyPathComparator(\Item.number, order: .reverse)
progress("03 let optional = KeyPathComparator(Item.optional, order: .forward)")
let optional = KeyPathComparator(\Item.optional, order: .forward)
progress("04 let a = Item(number: 2, optional: nil)")
let a = Item(number: 2, optional: nil)
progress("05 let b = Item(number: 10, optional: 1)")
let b = Item(number: 10, optional: 1)
progress("06 precondition(ascending.compare(a, b) == .orderedAscending)")
precondition(ascending.compare(a, b) == .orderedAscending)
progress("07 precondition(descending.compare(a, b) == .orderedDescending)")
precondition(descending.compare(a, b) == .orderedDescending)
progress("08 precondition(optional.compare(a, b) == .orderedAscending)")
precondition(optional.compare(a, b) == .orderedAscending)
progress("09 precondition([b, a].sorted(using: ascending).map(.number) == [2, 10])")
precondition([b, a].sorted(using: ascending).map(\.number) == [2, 10])
progress("10 precondition(ascending == KeyPathComparator(Item.number, order: .forward))")
precondition(ascending == KeyPathComparator(\Item.number, order: .forward))
progress("11 precondition(Set([ascending, ascending]).count == 1)")
precondition(Set([ascending, ascending]).count == 1)

progress("12 let padded = prefixnéclairrnlast")
let padded = "prefix\néclair\r\nlast"
progress("13 let slice = padded[padded.index(padded.startIndex, offsetBy: 7)...]")
let slice = padded[padded.index(padded.startIndex, offsetBy: 7)...]
progress("14 precondition(slice.lengthOfBytes(using: .utf8) == 13)")
precondition(slice.lengthOfBytes(using: .utf8) == 13)
progress("15 precondition(!slice.canBeConverted(to: .ascii))")
precondition(!slice.canBeConverted(to: .ascii))
progress("16 precondition(slice.precomposedStringWithCanonicalMapping == éclairrnlast)")
precondition(slice.precomposedStringWithCanonicalMapping == "éclair\r\nlast")
progress("17 precondition(slice.decomposedStringWithCanonicalMapping.utf16.count == 13)")
precondition(slice.decomposedStringWithCanonicalMapping.utf16.count == 13)
progress("18 precondition(①.precomposedStringWithCompatibilityMapping == 1)")
precondition("①".precomposedStringWithCompatibilityMapping == "1")
progress("19 precondition(É.folding(options: .init(rawValue: 129), locale: Locale(identifier: en_US)) =")
precondition("É".folding(options: .init(rawValue: 129), locale: Locale(identifier: "en_US")) == "e")
progress("20 var lines: [String] = []")
var lines: [String] = []
progress("21 slice.enumerateLines { line, stop in lines.append(line); stop = true }")
slice.enumerateLines { line, stop in lines.append(line); stop = true }
progress("22 precondition(lines == [éclair])")
precondition(lines == ["éclair"])
progress("23 let selection = slice.startIndex..<slice.index(after: slice.startIndex)")
let selection = slice.startIndex..<slice.index(after: slice.startIndex)
progress("24 precondition(String(slice[slice.lineRange(for: selection)]) == éclairrn)")
precondition(String(slice[slice.lineRange(for: selection)]) == "éclair\r\n")
progress("25 var start = slice.endIndex, end = slice.startIndex, contents = slice.startIndex")
var start = slice.endIndex, end = slice.startIndex, contents = slice.startIndex
progress("26 slice.getLineStart(&start, end: &end, contentsEnd: &contents, for: selection)")
slice.getLineStart(&start, end: &end, contentsEnd: &contents, for: selection)
progress("27 precondition(start == slice.startIndex && String(slice[start..<contents]) == éclair)")
precondition(start == slice.startIndex && String(slice[start..<contents]) == "éclair")
progress("28 precondition(String(slice[start..<end]) == éclairrn)")
precondition(String(slice[start..<end]) == "éclair\r\n")
progress("29 precondition(String(bytes: [0xc3, 0xa9], encoding: .utf8) == é)")
precondition(String(bytes: [0xc3, 0xa9], encoding: .utf8) == "é")
progress("30 precondition(String(bytes: [0xff], encoding: .utf8) == nil)")
precondition(String(bytes: [0xff], encoding: .utf8) == nil)
progress("31 let units: [UInt16] = [0x41, 0xd83d, 0xde00]")
let units: [UInt16] = [0x41, 0xd83d, 0xde00]
progress("32 precondition(units.withUnsafeBufferPointer { String(utf16CodeUnits: $0.baseAddress!, count")
precondition(units.withUnsafeBufferPointer { String(utf16CodeUnits: $0.baseAddress!, count: $0.count) } == "A😀")
progress("33 precondition(String.availableStringEncodings.contains(.utf8))")
precondition(String.availableStringEncodings.contains(.utf8))
progress("34 precondition(!String.localizedName(of: .utf8).isEmpty)")
precondition(!String.localizedName(of: .utf8).isEmpty)
progress("35 let substring = [hello].dropFirst().dropLast()")
let substring = "[hello]".dropFirst().dropLast()
progress("36 precondition(substring._bridgeToObjectiveC() as String == hello)")
precondition(substring._bridgeToObjectiveC() as String == "hello")

progress("37 let dictionary: NSDictionary = [one: 1, two: 2]")
let dictionary: NSDictionary = ["one": 1, "two": 2]
progress("38 var pairs = dictionary.makeIterator()")
var pairs = dictionary.makeIterator()
progress("39 var keys = Set<String>()")
var keys = Set<String>()
progress("40 while let pair = pairs.next() { keys.insert(pair.key as! String) }")
while let pair = pairs.next() { keys.insert(pair.key as! String) }
progress("41 precondition(keys == [one, two])")
precondition(keys == ["one", "two"])
progress("42 let range = NSRange(location: 4, length: 9)")
let range = NSRange(location: 4, length: 9)
progress("43 var bridged: NSRange?")
var bridged: NSRange?
progress("44 precondition(NSRange._conditionallyBridgeFromObjectiveC(range._bridgeToObjectiveC(), resul")
precondition(NSRange._conditionallyBridgeFromObjectiveC(range._bridgeToObjectiveC(), result: &bridged))
progress("45 precondition(bridged == range)")
precondition(bridged == range)
progress("46 print(round3-behavior: passed)")
print("round3-behavior: passed")
