import Foundation
let text = AttributedString("A😀B")
let span = Range<AttributedString.Index>(NSRange(location: 1, length: 2), in: text)!
precondition(String(text[span].characters) == "😀")
precondition(Range<AttributedString.Index>(NSRange(location: NSNotFound, length: 1), in: text) == nil)
precondition(Range<AttributedString.Index>(NSRange(location: Int.max - 1, length: 3), in: text) == nil)
let localized: String.LocalizationValue = "Count: \(12, format: .number)"
precondition(String(localized: localized).contains("12"))
final class Target: NSObject { var value = 0 }
let target = Target()
let undo = UndoManager()
undo.beginUndoGrouping()
undo.registerUndo(withTarget: target) { $0.value = 1 }
undo.endUndoGrouping()
undo.undo()
precondition(target.value == 1)
// Typecheck the generic secure decoding entry point without inventing an archive.
func decodeStrings(_ coder: NSCoder) -> [NSString]? {
    coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: "strings")
}
print("round3-refinements: passed")
