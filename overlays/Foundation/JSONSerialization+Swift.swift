//===----------------------------------------------------------------------===//
//
// This source file is part of the darling-swift project.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//===----------------------------------------------------------------------===//

// A JSON writer and parser (RFC 8259) for the Foundation object trees JSONEncoder and JSONDecoder build and read:
// NSDictionary with string keys, NSArray, NSString, NSNumber (the kCFBooleanTrue/kCFBooleanFalse singletons for
// booleans) and NSNull.
// Written for Darling, whose NSJSONSerialization ignores NSJSONWritingSortedKeys, pretty-prints with tabs, reports
// no error for unsupported values and has a fragile number parser. The output follows macOS's JSONSerialization:
// two-space indentation, " : " between keys and values when pretty-printed, and "/" escaped unless asked not to.

@_exported import Foundation // Clang module

/// An integer above Int64.max in the boxed tree. Darling's NSNumber stores those as signed 64-bit values, so they
/// would read back negative; the writer and the decoder's numeric unboxing handle this box instead.
internal final class _JSONUnsignedNumber : NSObject {
    let value: UInt64

    init(_ value: UInt64) {
        self.value = value
        super.init()
    }
}

internal enum _JSONSerialization {
    struct WritingOptions {
        var prettyPrinted = false
        var sortedKeys = false
        var withoutEscapingSlashes = false
    }

    enum Error : Swift.Error, CustomStringConvertible {
        case invalidValue(String)
        case invalidJSON(String, offset: Int)

        var description: String {
            switch self {
            case .invalidValue(let reason): return reason
            case .invalidJSON(let reason, let offset): return "\(reason) around byte \(offset)."
            }
        }
    }

    static let trueNumber = unsafeBitCast(kCFBooleanTrue, to: NSNumber.self)
    static let falseNumber = unsafeBitCast(kCFBooleanFalse, to: NSNumber.self)

    // MARK: - Writing

    static func data(with object: Any, options: WritingOptions) throws -> Data {
        var writer = _Writer(options: options)
        try writer.write(object, depth: 0)
        return Data(writer.bytes)
    }

    private struct _Writer {
        let options: WritingOptions
        var bytes: [UInt8] = []

        init(options: WritingOptions) {
            self.options = options
        }

        mutating func append(_ string: String) {
            bytes.append(contentsOf: string.utf8)
        }

        mutating func indent(_ depth: Int) {
            bytes.append(contentsOf: repeatElement(UInt8(ascii: " "), count: 2 * depth))
        }

        mutating func write(_ object: Any, depth: Int) throws {
            switch object {
            case let number as NSNumber:
                try writeNumber(number)
            case let number as _JSONUnsignedNumber:
                append(String(number.value))
            case let string as String:
                writeString(string)
            case is NSNull:
                append("null")
            case let dictionary as NSDictionary:
                try writeDictionary(dictionary, depth: depth)
            case let array as NSArray:
                try writeArray(array, depth: depth)
            default:
                throw Error.invalidValue("Invalid type in JSON write (\(type(of: object))).")
            }
        }

        mutating func writeNumber(_ number: NSNumber) throws {
            if number === _JSONSerialization.trueNumber {
                append("true")
                return
            }
            if number === _JSONSerialization.falseNumber {
                append("false")
                return
            }
            switch number.objCType().map({ String(cString: $0) }) ?? "" {
            case "f":
                let float = number.floatValue()
                guard float.isFinite else {
                    throw Error.invalidValue("Invalid number value (\(float)) in JSON write.")
                }
                appendFloatingPoint(float.description)
            case "d":
                let double = number.doubleValue()
                guard double.isFinite else {
                    throw Error.invalidValue("Invalid number value (\(double)) in JSON write.")
                }
                appendFloatingPoint(double.description)
            default:
                append(String(number.longLongValue()))
            }
        }

        /// Writes a floating-point description without a trailing ".0", as macOS does ("1", "1e+16", "-0").
        mutating func appendFloatingPoint(_ description: String) {
            append(description.hasSuffix(".0") ? String(description.dropLast(2)) : description)
        }

        mutating func writeString(_ string: String) {
            bytes.append(UInt8(ascii: "\""))
            for scalar in string.unicodeScalars {
                switch scalar {
                case "\"": append("\\\"")
                case "\\": append("\\\\")
                case "/": append(options.withoutEscapingSlashes ? "/" : "\\/")
                case "\n": append("\\n")
                case "\r": append("\\r")
                case "\t": append("\\t")
                case "\u{8}": append("\\b")
                case "\u{C}": append("\\f")
                case _ where scalar.value < 0x20:
                    let hex = String(scalar.value, radix: 16)
                    append("\\u" + String(repeating: "0", count: 4 - hex.count) + hex)
                default:
                    bytes.append(contentsOf: String(scalar).utf8)
                }
            }
            bytes.append(UInt8(ascii: "\""))
        }

        mutating func writeDictionary(_ dictionary: NSDictionary, depth: Int) throws {
            var entries: [(key: String, value: Any)] = []
            for key in dictionary.allKeys() {
                let value: Any = dictionary.object(forKey: key)!
                guard let key = key as? String else {
                    throw Error.invalidValue("Invalid key in JSON write (\(type(of: key))).")
                }
                entries.append((key, value))
            }
            if options.sortedKeys {
                // The order JSONSerialization's sortedKeys uses for apps built against these SDKs.
                let order = NSStringCompareOptions([.numeric, .caseInsensitive, .forcedOrdering])
                entries.sort { $0.key.compare($1.key, options: order) == .orderedAscending }
            }
            guard !entries.isEmpty else {
                append(options.prettyPrinted ? "{\n\n" : "{")
                if options.prettyPrinted { indent(depth) }
                append("}")
                return
            }
            append("{")
            for (index, entry) in entries.enumerated() {
                if index > 0 { append(",") }
                if options.prettyPrinted {
                    append("\n")
                    indent(depth + 1)
                }
                writeString(entry.key)
                append(options.prettyPrinted ? " : " : ":")
                try write(entry.value, depth: depth + 1)
            }
            if options.prettyPrinted {
                append("\n")
                indent(depth)
            }
            append("}")
        }

        mutating func writeArray(_ array: NSArray, depth: Int) throws {
            guard array.count() > 0 else {
                append(options.prettyPrinted ? "[\n\n" : "[")
                if options.prettyPrinted { indent(depth) }
                append("]")
                return
            }
            append("[")
            for index in 0..<array.count() {
                if index > 0 { append(",") }
                if options.prettyPrinted {
                    append("\n")
                    indent(depth + 1)
                }
                try write(array.object(at: index) as Any, depth: depth + 1)
            }
            if options.prettyPrinted {
                append("\n")
                indent(depth)
            }
            append("]")
        }
    }

    // MARK: - Parsing

    static func object(with data: Data, allowsJSON5: Bool = false) throws -> Any {
        var parser = _Parser(bytes: [UInt8](data), json5: allowsJSON5)
        parser.skipByteOrderMark()
        try parser.skipWhitespace()
        let value = try parser.parseValue(depth: 0)
        try parser.skipWhitespace()
        guard parser.offset == parser.bytes.count else {
            throw Error.invalidJSON("Garbage at end", offset: parser.offset)
        }
        return value
    }

    private struct _Parser {
        let bytes: [UInt8]
        let json5: Bool
        var offset = 0

        init(bytes: [UInt8], json5: Bool) {
            self.bytes = bytes
            self.json5 = json5
        }

        var current: UInt8? {
            return offset < bytes.count ? bytes[offset] : nil
        }

        mutating func skipByteOrderMark() {
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
                offset = 3
            }
        }

        func scalarAtOffset() throws -> (Unicode.Scalar, Int) {
            guard let byte = current else { throw Error.invalidJSON("Unexpected end", offset: offset) }
            let count = byte < 0x80 ? 1 : byte < 0xE0 ? 2 : byte < 0xF0 ? 3 : 4
            guard offset + count <= bytes.count,
                  let text = String(validating: bytes[offset..<offset + count], as: UTF8.self),
                  text.unicodeScalars.count == 1, let scalar = text.unicodeScalars.first else {
                throw Error.invalidJSON("Invalid UTF-8", offset: offset)
            }
            return (scalar, count)
        }

        mutating func skipWhitespace() throws {
            while let byte = current {
                if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                    offset += 1
                } else if json5 && byte == 0x2F && offset + 1 < bytes.count {
                    if bytes[offset + 1] == 0x2F {
                        offset += 2
                        while current != nil {
                            let (scalar, count) = try scalarAtOffset()
                            offset += count
                            if scalar == "\n" || scalar == "\r" || scalar == "\u{2028}" || scalar == "\u{2029}" { break }
                        }
                    } else if bytes[offset + 1] == 0x2A {
                        offset += 2
                        while offset + 1 < bytes.count && !(bytes[offset] == 0x2A && bytes[offset + 1] == 0x2F) {
                            offset += 1
                        }
                        guard offset + 1 < bytes.count else { throw Error.invalidJSON("Unterminated comment", offset: offset) }
                        offset += 2
                    } else { break }
                } else if json5 {
                    let (scalar, count) = try scalarAtOffset()
                    guard scalar == "\u{B}" || scalar == "\u{C}" || scalar == "\u{FEFF}" ||
                          scalar == "\u{2028}" || scalar == "\u{2029}" || scalar.properties.generalCategory == .spaceSeparator else { break }
                    offset += count
                } else { break }
            }
        }

        mutating func parseIdentifier() throws -> String {
            var result = String.UnicodeScalarView()
            while current != nil {
                let scalar: Unicode.Scalar
                let escaped = current == 0x5C
                if escaped {
                    offset += 1
                    try expect("u")
                    guard let value = Unicode.Scalar(try parseHex4()) else {
                        throw Error.invalidJSON("Invalid identifier escape", offset: offset)
                    }
                    scalar = value
                } else {
                    let (value, count) = try scalarAtOffset()
                    let valid = value == "$" || value == "_" || (result.isEmpty ? value.properties.isIDStart : value.properties.isIDContinue) ||
                        (!result.isEmpty && (value == "\u{200C}" || value == "\u{200D}"))
                    if !valid { break }
                    scalar = value
                    offset += count
                }
                guard scalar == "$" || scalar == "_" || (result.isEmpty ? scalar.properties.isIDStart : scalar.properties.isIDContinue) ||
                    (!result.isEmpty && (scalar == "\u{200C}" || scalar == "\u{200D}")) else {
                    throw Error.invalidJSON("Invalid identifier", offset: offset)
                }
                result.append(scalar)
            }
            guard !result.isEmpty else { throw Error.invalidJSON("Missing identifier", offset: offset) }
            return String(result)
        }

        mutating func expect(_ literal: String) throws {
            let utf8 = Array(literal.utf8)
            guard offset + utf8.count <= bytes.count, Array(bytes[offset..<offset + utf8.count]) == utf8 else {
                throw Error.invalidJSON("Invalid value", offset: offset)
            }
            offset += utf8.count
        }

        mutating func parseValue(depth: Int) throws -> Any {
            guard depth < 512 else {
                throw Error.invalidJSON("Too many nested arrays or dictionaries", offset: offset)
            }
            guard let byte = current else {
                throw Error.invalidJSON("Unexpected end of file", offset: offset)
            }
            if json5 && (byte == 0x27) { return NSString(string: try parseString()) }
            if json5 && (byte == 0x2B || byte == 0x2E || byte == 0x49 || byte == 0x4E || byte == 0x2D || (0x30...0x39).contains(byte)) {
                return try parseJSON5Number()
            }
            switch byte {
            case UInt8(ascii: "{"): return try parseObject(depth: depth)
            case UInt8(ascii: "["): return try parseArray(depth: depth)
            case UInt8(ascii: "\""): return NSString(string: try parseString())
            case UInt8(ascii: "t"):
                try expect("true")
                return _JSONSerialization.trueNumber
            case UInt8(ascii: "f"):
                try expect("false")
                return _JSONSerialization.falseNumber
            case UInt8(ascii: "n"):
                try expect("null")
                return NSNull()
            case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                return try parseNumber()
            default:
                throw Error.invalidJSON("Invalid value", offset: offset)
            }
        }

        mutating func parseObject(depth: Int) throws -> NSDictionary {
            let result = NSMutableDictionary()
            offset += 1
            try skipWhitespace()
            if current == UInt8(ascii: "}") {
                offset += 1
                return result
            }
            while true {
                try skipWhitespace()
                let key: String
                if current == 0x22 || (json5 && current == 0x27) {
                    key = try parseString()
                } else if json5 {
                    key = try parseIdentifier()
                } else {
                    throw Error.invalidJSON("No string key for value in object", offset: offset)
                }
                try skipWhitespace()
                guard current == UInt8(ascii: ":") else {
                    throw Error.invalidJSON("No value for key in object", offset: offset)
                }
                offset += 1
                try skipWhitespace()
                let value = try parseValue(depth: depth + 1)
                result.setObject(value, forKey: NSString(string: key))
                try skipWhitespace()
                switch current {
                case UInt8(ascii: ","):
                    offset += 1
                    try skipWhitespace()
                    if json5 && current == 0x7D { offset += 1; return result }
                case UInt8(ascii: "}"):
                    offset += 1
                    return result
                default:
                    throw Error.invalidJSON("Badly formed object", offset: offset)
                }
            }
        }

        mutating func parseArray(depth: Int) throws -> NSArray {
            let result = NSMutableArray()!
            offset += 1
            try skipWhitespace()
            if current == UInt8(ascii: "]") {
                offset += 1
                return result
            }
            while true {
                try skipWhitespace()
                result.add(try parseValue(depth: depth + 1))
                try skipWhitespace()
                switch current {
                case UInt8(ascii: ","):
                    offset += 1
                    try skipWhitespace()
                    if json5 && current == 0x5D { offset += 1; return result }
                case UInt8(ascii: "]"):
                    offset += 1
                    return result
                default:
                    throw Error.invalidJSON("Badly formed array", offset: offset)
                }
            }
        }

        mutating func parseHex4(count: Int = 4) throws -> UInt32 {
            guard offset + count <= bytes.count else {
                throw Error.invalidJSON("Invalid unicode escape sequence", offset: offset)
            }
            var value: UInt32 = 0
            for byte in bytes[offset..<offset + count] {
                let digit: UInt8
                switch byte {
                case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = byte - UInt8(ascii: "0")
                case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = byte - UInt8(ascii: "a") + 10
                case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = byte - UInt8(ascii: "A") + 10
                default: throw Error.invalidJSON("Invalid unicode escape sequence", offset: offset)
                }
                value = value * 16 + UInt32(digit)
            }
            offset += count
            return value
        }

        mutating func parseString() throws -> String {
            let quote = current!
            offset += 1
            var utf8: [UInt8] = []
            while true {
                guard let byte = current else {
                    throw Error.invalidJSON("Unexpected end of file during string parse", offset: offset)
                }
                offset += 1
                if byte == quote {
                    guard let string = String(validating: utf8, as: UTF8.self) else {
                        throw Error.invalidJSON("Invalid UTF-8 string", offset: offset)
                    }
                    return string
                }
                switch byte {
                case UInt8(ascii: "\\"):
                    guard let escaped = current else {
                        throw Error.invalidJSON("Unexpected end of file during string parse", offset: offset)
                    }
                    offset += 1
                    if json5 {
                        switch escaped {
                        case 0x27: utf8.append(escaped); continue
                        case 0x76: utf8.append(0x0B); continue
                        case 0x30:
                            guard current.map({ !(0x30...0x39).contains($0) }) ?? true else { throw Error.invalidJSON("Octal escape", offset: offset) }
                            utf8.append(0); continue
                        case 0x78: utf8.append(UInt8(try parseHex4(count: 2))); continue
                        case 0x0A: continue
                        case 0x0D:
                            if current == 0x0A { offset += 1 }
                            continue
                        case 0xE2 where offset + 1 < bytes.count && bytes[offset] == 0x80 && (bytes[offset + 1] == 0xA8 || bytes[offset + 1] == 0xA9):
                            offset += 2; continue
                        case 0x31...0x39: throw Error.invalidJSON("Octal escape", offset: offset)
                        default: break
                        }
                    }
                    switch escaped {
                    case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): utf8.append(escaped)
                    case UInt8(ascii: "b"): utf8.append(0x08)
                    case UInt8(ascii: "f"): utf8.append(0x0C)
                    case UInt8(ascii: "n"): utf8.append(0x0A)
                    case UInt8(ascii: "r"): utf8.append(0x0D)
                    case UInt8(ascii: "t"): utf8.append(0x09)
                    case UInt8(ascii: "u"):
                        var value = try parseHex4()
                        if (0xD800..<0xDC00).contains(value) {
                            // A high surrogate must be followed by an escaped low surrogate.
                            guard current == UInt8(ascii: "\\"), offset + 1 < bytes.count, bytes[offset + 1] == UInt8(ascii: "u") else {
                                throw Error.invalidJSON("Unable to convert hex escape sequence (no low character) to UTF8-encoded character", offset: offset)
                            }
                            offset += 2
                            let low = try parseHex4()
                            guard (0xDC00..<0xE000).contains(low) else {
                                throw Error.invalidJSON("Unable to convert hex escape sequence (invalid low character) to UTF8-encoded character", offset: offset)
                            }
                            value = 0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00)
                        } else if (0xDC00..<0xE000).contains(value) {
                            throw Error.invalidJSON("Unable to convert hex escape sequence (no high character) to UTF8-encoded character", offset: offset)
                        }
                        guard let scalar = Unicode.Scalar(value) else {
                            throw Error.invalidJSON("Invalid unicode escape sequence", offset: offset)
                        }
                        utf8.append(contentsOf: String(scalar).utf8)
                    default:
                        guard json5 else { throw Error.invalidJSON("Invalid escape sequence", offset: offset) }
                        utf8.append(escaped)
                    }
                case 0x00..<0x20:
                    guard json5 && byte != 0x0A && byte != 0x0D else { throw Error.invalidJSON("Unescaped control character", offset: offset) }
                    utf8.append(byte)
                default:
                    utf8.append(byte)
                }
            }
        }

        mutating func parseJSON5Number() throws -> NSObject {
            let start = offset
            let negative = current == 0x2D
            if current == 0x2B || current == 0x2D { offset += 1 }
            if current == 0x49 { try expect("Infinity"); return NSNumber(value: negative ? -Double.infinity : Double.infinity) }
            if current == 0x4E { try expect("NaN"); return NSNumber(value: Double.nan) }
            if current == 0x30 && offset + 1 < bytes.count && (bytes[offset + 1] == 0x78 || bytes[offset + 1] == 0x58) {
                offset += 2
                let digits = offset
                var number: Double = 0
                while let byte = current {
                    let digit: UInt8
                    switch byte {
                    case 0x30...0x39: digit = byte - 0x30
                    case 0x41...0x46: digit = byte - 0x41 + 10
                    case 0x61...0x66: digit = byte - 0x61 + 10
                    default: digit = 255
                    }
                    if digit == 255 { break }
                    number = number * 16 + Double(digit)
                    offset += 1
                }
                guard offset > digits && number.isFinite else { throw Error.invalidJSON("Invalid hexadecimal number", offset: start) }
                let text = String(decoding: bytes[digits..<offset], as: UTF8.self)
                if !negative, let integer = UInt64(text, radix: 16) {
                    return integer <= UInt64(Int64.max) ? NSNumber(value: Int64(integer)) : _JSONUnsignedNumber(integer)
                }
                if negative, let integer = UInt64(text, radix: 16), integer > 0, integer <= UInt64(Int64.max) { return NSNumber(value: -Int64(integer)) }
                return NSNumber(value: negative ? -number : number)
            }
            let integerStart = offset
            while let byte = current, (0x30...0x39).contains(byte) { offset += 1 }
            let integerCount = offset - integerStart
            guard integerCount <= 1 || bytes[integerStart] != 0x30 else { throw Error.invalidJSON("Leading zero", offset: start) }
            var digits = integerCount
            if current == 0x2E {
                offset += 1
                while let byte = current, (0x30...0x39).contains(byte) { offset += 1; digits += 1 }
            }
            guard digits > 0 else { throw Error.invalidJSON("Invalid number", offset: start) }
            if current == 0x65 || current == 0x45 {
                offset += 1
                if current == 0x2B || current == 0x2D { offset += 1 }
                let exponentStart = offset
                while let byte = current, (0x30...0x39).contains(byte) { offset += 1 }
                guard offset > exponentStart else { throw Error.invalidJSON("Invalid exponent", offset: start) }
            }
            let text = String(decoding: bytes[start..<offset], as: UTF8.self)
            if text != "-0", let integer = Int64(text) { return NSNumber(value: integer) }
            if let integer = UInt64(text) { return _JSONUnsignedNumber(integer) }
            guard let number = Double(text), number.isFinite else { throw Error.invalidJSON("Invalid number", offset: start) }
            return NSNumber(value: number)
        }

        mutating func parseNumber() throws -> NSObject {
            let start = offset
            var isInteger = true
            if current == UInt8(ascii: "-") { offset += 1 }
            guard let first = current, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(first) else {
                throw Error.invalidJSON("Invalid number", offset: start)
            }
            if first == UInt8(ascii: "0") {
                offset += 1
            } else {
                while let byte = current, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) { offset += 1 }
            }
            if current == UInt8(ascii: ".") {
                isInteger = false
                offset += 1
                let digits = offset
                while let byte = current, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) { offset += 1 }
                guard offset > digits else { throw Error.invalidJSON("Invalid number", offset: start) }
            }
            if current == UInt8(ascii: "e") || current == UInt8(ascii: "E") {
                isInteger = false
                offset += 1
                if current == UInt8(ascii: "+") || current == UInt8(ascii: "-") { offset += 1 }
                let digits = offset
                while let byte = current, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) { offset += 1 }
                guard offset > digits else { throw Error.invalidJSON("Invalid number", offset: start) }
            }
            let text = String(decoding: bytes[start..<offset], as: UTF8.self)
            // "-0" stays a Double so its sign survives; integer decoding still gets 0.
            if isInteger && text != "-0" {
                if let value = Int64(text) { return NSNumber(value: value) }
                if let value = UInt64(text) { return _JSONUnsignedNumber(value) }
            }
            guard let value = Double(text), value.isFinite else {
                throw Error.invalidJSON("Number \(text) is not representable", offset: start)
            }
            return NSNumber(value: value)
        }
    }
}
