// The on-disk bookmark/alias formats are unavailable here. Never return a fake bookmark.
@_exported import Foundation
import Darwin

extension URL {
    public func bookmarkData(options: NSURLBookmarkCreationOptions = [],
                             includingResourceValuesForKeys keys: Set<URLResourceKey>? = nil,
                             relativeTo url: URL? = nil) throws -> Data {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTSUP), userInfo: nil)!
    }

    public init(resolvingBookmarkData data: __shared Data, options: NSURLBookmarkResolutionOptions = [],
                relativeTo url: __shared URL? = nil, bookmarkDataIsStale: inout Bool) throws {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTSUP), userInfo: nil)!
    }

    public init(resolvingAliasFileAt url: __shared URL, options: NSURLBookmarkResolutionOptions = []) throws {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTSUP), userInfo: nil)!
    }

    public mutating func removeCachedResourceValue(forKey key: URLResourceKey) {
        // NSURL currently fetches resource values on every call; it has no property cache.
    }
}
