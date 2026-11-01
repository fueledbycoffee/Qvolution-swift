@_exported import Foundation
import CoreFoundation

extension StringProtocol {
    public func applyingTransform(_ transform: NSStringTransform, reverse: Bool) -> String? {
        if transform == .stripDiacritics && !reverse { return String(self).strippingDiacritics() }
        let source = unsafeBitCast(String(self) as NSString, to: CFString.self)
        guard let result = CFStringCreateMutableCopy(nil, 0, source) else { return nil }
        let identifier = unsafeBitCast(transform.rawValue as NSString, to: CFString.self)
        // Darling's CFStringTransform stores the transformed range through its range
        // argument unconditionally, so a nil pointer is dereferenced on success. Pass the
        // whole string as an in/out range, as the documented API allows.
        var range = CFRange(location: 0, length: CFStringGetLength(result))
        guard CFStringTransform(result, &range, identifier, reverse) else { return nil }
        return unsafeBitCast(result, to: NSString.self) as String
    }
}

private extension String {
    // Darling's CFStringTransform maps the strip-diacritics identifier to an ICU transliterator
    // that rewrites accents as ASCII notation instead of removing them. Apply the published rule
    // directly: NFD; remove [[[:Mn:]&[:Diacritic:]]-[:Grapheme_Link:]-[:ccc=0:]-[:ccc=8:]-[\u0338]]; NFC.
    // Grapheme_Link is not exposed by the Swift standard library; it consists of the virama
    // characters, canonical combining class 9.
    func strippingDiacritics() -> String? {
        guard let work = CFStringCreateMutableCopy(nil, 0, unsafeBitCast(self as NSString, to: CFString.self)) else { return nil }
        CFStringNormalize(work, .D)
        var kept = String.UnicodeScalarView()
        for scalar in (unsafeBitCast(work, to: NSString.self) as String).unicodeScalars where !scalar.isRemovedDiacritic {
            kept.append(scalar)
        }
        guard let composed = CFStringCreateMutableCopy(nil, 0, unsafeBitCast(String(kept) as NSString, to: CFString.self)) else { return nil }
        CFStringNormalize(composed, .C)
        return unsafeBitCast(composed, to: NSString.self) as String
    }
}

private extension Unicode.Scalar {
    var isRemovedDiacritic: Bool {
        let p = properties
        guard p.generalCategory == .nonspacingMark, p.isDiacritic, value != 0x338 else { return false }
        let combiningClass = p.canonicalCombiningClass.rawValue
        return combiningClass != 0 && combiningClass != 8 && combiningClass != 9
    }
}
