@_exported import Foundation
import CoreFoundation

extension StringProtocol {
    public func applyingTransform(_ transform: NSStringTransform, reverse: Bool) -> String? {
        let source = unsafeBitCast(String(self) as NSString, to: CFString.self)
        guard let result = CFStringCreateMutableCopy(nil, 0, source) else { return nil }
        let identifier = unsafeBitCast(transform.rawValue as NSString, to: CFString.self)
        // Darling's CFStringTransform writes the transformed range through its range
        // argument unconditionally, so a nil pointer is dereferenced on success. Pass the
        // whole string as an in/out range, as the documented API allows.
        var range = CFRange(location: 0, length: CFStringGetLength(result))
        guard CFStringTransform(result, &range, identifier, reverse) else { return nil }
        return unsafeBitCast(result, to: NSString.self) as String
    }
}
