@_exported import Foundation
import CoreFoundation

extension StringProtocol {
    public func applyingTransform(_ transform: NSStringTransform, reverse: Bool) -> String? {
        let source = unsafeBitCast(String(self) as NSString, to: CFString.self)
        guard let result = CFStringCreateMutableCopy(nil, 0, source) else { return nil }
        let identifier = unsafeBitCast(transform.rawValue as NSString, to: CFString.self)
        guard CFStringTransform(result, nil, identifier, reverse) else { return nil }
        return unsafeBitCast(result, to: NSString.self) as String
    }
}
