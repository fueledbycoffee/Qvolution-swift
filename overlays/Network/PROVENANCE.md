# Network overlay provenance

The upstream inputs come from the read-only pinned Apple Swift 5.2.2 checkout,
stdlib/public/Darwin/Network (Apache 2.0 with Runtime Library Exception).
Two small patches carry the existing Catalyst adaptations; pristine files are
consumed without vendoring. DARLING-CHANGES.md lists
every difference and the per-file patch-size comparison. Clang shims and the
newer clean-room files reuse read-only Catalyst swift c58b53c (last Network
change dd45ed8). The shims explain their public-doc declarations and guesses.
NWBrowser/NWPath additions are Catalyst clean-room source, with conservative
unsupported DNS browsing. See catalyst/lanes/swift-network/STATUS.md.

NWListener.swift adapts the public declarations and Service formatting from the
same rung 1 source. The previous upstream wrapper threw EINVAL on construction:
Darling libnetwork src/nw/listener.m implements creation and lifecycle only as
stubs. Container-BkdTUk loaded all 77 exports, then observed that throw (rung 4).
The replacement owns only the Swift setup/cancellation lifecycle. It never
creates or fabricates a C listener, binds a port, advertises a service, receives
connections, or emits ready. Start emits failed(posix(ENOTSUP)) on the requested
queue; cancellation follows on that queue and is terminal. This explicit
unsupported-start policy is GUESS (rung 6), consistent with our NWBrowser's
unsupported-backend policy; it is not a claim about native macOS. Parameters
are retained, with validation deferred to the unsupported start. General C
parameter/connection functionality remains stubbed. The retired state-getter
patch is retained as history but is no longer an input to the recipe.

This lane also adds the demanded WebSocket subset. IINA's import names in imports-sweep-a/MISSING.md
supply signatures only (rung 5). The 5.2.2 source lacks WebSocket and there are no
cached member pages, so its declarations and behavior are GUESS (rung 6).
Opcode contains only binary/ping/pong; Version only version13. Neither enum
invents numeric raw values. Constructors and opcode access fail explicitly with
fatalError: no supported WebSocket backend, fabricated opaque handle, network
success, or completed transmission is claimed. This is a link-compatibility
subset, not usable WebSocket support.

Other existing Network APIs retain the limitations recorded by Catalyst: the
Darling C backend is mostly stubbed; constructors may fail or force-unwrap nil.
Those pre-existing functional gaps are not repaired by adding the imports.
