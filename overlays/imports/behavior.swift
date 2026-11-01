import Foundation
import UniformTypeIdentifiers
import AVFoundation
import Network
import Dispatch
import Darwin

func unsupported(_ operation: () async throws -> Void) async {
    do {
        try await operation()
        fatalError("unsupported load succeeded")
    } catch {
        let error = error as NSError
        precondition(error.domain == NSCocoaErrorDomain && error.code == NSFeatureUnsupportedError)
    }
}

@main struct Behavior {
    static func main() async throws {
        switch CommandLine.arguments.dropFirst().first {
        case "websocket-options":
            print("BEGIN websocket-options"); fflush(nil)
            _ = NWProtocolWebSocket.Options()
            exit(90)
        case "websocket-metadata":
            print("BEGIN websocket-metadata"); fflush(nil)
            _ = NWProtocolWebSocket.Metadata(opcode: .binary)
            exit(90)
        default: break
        }
        let base = URL(fileURLWithPath: "/tmp/overlay-policy", isDirectory: true)
        precondition(base.appendingPathComponent("notes", conformingTo: .plainText).lastPathComponent == "notes.txt")
        precondition(base.appendingPathComponent("notes.txt", conformingTo: .plainText).lastPathComponent == "notes.txt")
        precondition(base.appendingPathComponent("notes.bin", conformingTo: .plainText).lastPathComponent == "notes.bin.txt")
        precondition(base.appendingPathComponent("folder", conformingTo: .directory).hasDirectoryPath)

        let asset = AVAsset()
        await unsupported { _ = try await asset.load(.duration) }
        await unsupported { _ = try await asset.load(.duration, .isPlayable) }
        await unsupported { _ = try await asset.load(.duration, .isPlayable, .metadata) }
        let track = AVAssetTrack()
        await unsupported { _ = try await track.load(.naturalSize) }
        await unsupported { _ = try await track.load(.naturalSize, .nominalFrameRate) }
        await unsupported { _ = try await track.load(.naturalSize, .nominalFrameRate, .segments) }

        let listener = try NWListener(using: .tcp)
        precondition(listener.state == .setup)
        let completed = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            precondition(listener.state == state)
            if state == .cancelled { completed.signal() }
        }
        listener.start(queue: DispatchQueue(label: "overlay-listener-test"))
        listener.cancel()
        precondition(completed.wait(timeout: .now() + 5) == .success)
        precondition(listener.state == .cancelled)
        print("RESULT swift-overlay-behavior failures=0")
    }
}
