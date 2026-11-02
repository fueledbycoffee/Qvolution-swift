// Swift refinement of the vendored NSUndoManager.h block registration API.
@_exported import Foundation
extension NSUndoManager {
    @nonobjc public func registerUndo<T: AnyObject>(withTarget target: T, handler: @escaping (T) -> Void) {
        registerUndo(withTarget: target as Any, handler: { handler($0 as! T) })
    }
}
