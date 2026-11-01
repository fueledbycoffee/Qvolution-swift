# Offline x86_64 import overlays

Configure this directory with CMake/Ninja, or enable DARLING_BUILD_IMPORT_OVERLAYS
in Darling. Each ../<Module>/imports.json registers one source-built library.
Build under qv-slot build with ninja -j6. No network access or installation occurs.

The driver adapts catalyst/tools/swiftc-darwin: private Swift 6.3.3 compiler,
source-built Darwin resource/module inputs, source SDK, Stage41b dependency libraries
and ld64. All inputs can be overridden with the environment variables documented
in swiftc-darwin.py. No Apple SDK binary is an input. Each compile uses a fresh attempt directory and module cache. Successful outputs
replace the published path only after completion; prior successes are renamed
and failed attempts are retained. Nothing is deleted.

Built libraries replace bundled copies only when the option is enabled. The
standalone build also has an install target with the normal Darling layout.
Modules are x86_64 only; do not enable for an arm64 installation.

Network consumes Apple Swift 5.2.2 from SWIFT_NETWORK_SOURCE (default: the
workspace's read-only catalyst/oss/swift-5.2.2), pinned to
`d66af16429153d81a8f5791a6da9d9b3d4b61bc7` (swift-5.2.2-RELEASE).
Its pristine source files are not vendored. Three small patches are applied
with zero fuzz to a fresh private copy. The upstream checkout must be clean
and at the pin; missing inputs fail explicitly without fetching the network.
CMake records original source paths and patch files as Ninja dependencies.

Export verification (only freshly built, own images): compile
`export-negative-control.c` into `<build>/export-negative-control.so` with
`qv-slot build cc -shared -fPIC`, then run
`python3 check-exports.py <build> [Module ...]`. Every checked demand set must
be nonempty, the wrong-image overlap must be zero, and adding a deliberately
absent symbol must fail acceptance. `load-exports.c` is the matching native
`dlopen`/`dlsym` probe, taking `IMAGE EXPORTS` pairs; each module's
`imports.exports` is its strong-demand list. Compile the probe for Darwin
and execute it only against the resulting own-source libraries. A Linux
build of the same probe supports testing its harness with the control ELF.
