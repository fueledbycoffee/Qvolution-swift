// Rung 5: imports-sweep-a's IINA imports provide the public symbol names.
// GUESS (rung 6): only the demanded cases and signatures are implemented.
// The local Swift 5.2.2 sources predate this overlay and no member docs are cached.
// Never construct fabricated libnetwork objects: unsupported constructors trap.

public class NWProtocolWebSocket: NWProtocol {
    public enum Opcode: Equatable {
        case binary
        case ping
        case pong
    }

    public enum Version {
        case version13
    }

    public class Options: NWProtocolOptions {
        public var autoReplyPing: Bool = false

        public init(_ version: Version = .version13) {
            fatalError("Darling does not support the WebSocket network protocol")
        }
    }

    public class Metadata: NWProtocolMetadata {
        public final var opcode: Opcode {
            fatalError("Darling does not support WebSocket metadata")
        }

        public init(opcode: Opcode) {
            fatalError("Darling does not support WebSocket metadata")
        }
    }
}
