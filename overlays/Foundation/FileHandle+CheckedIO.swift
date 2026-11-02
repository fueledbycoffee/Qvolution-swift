@_exported import Foundation
import Darwin

public typealias FileHandle = NSFileHandle

extension NSFileHandle {
    public func read(upToCount count: Int) throws -> Data? {
        precondition(count >= 0, "Negative read count")
        var error: NSError?
        guard let data = _readDataUpToLength(count, error: &error) else {
            throw (error ?? NSError(domain: NSPOSIXErrorDomain, code: Int(EIO), userInfo: nil)!) as Error
        }
        return data.isEmpty && count != 0 ? nil : data
    }

    public func write<D: DataProtocol>(contentsOf data: D) throws {
        // One call also validates a closed handle for empty input.
        var error: NSError?
        guard _writeData(Data(data), error: &error) else {
            throw (error ?? NSError(domain: NSPOSIXErrorDomain, code: Int(EIO), userInfo: nil)!) as Error
        }
    }
}
