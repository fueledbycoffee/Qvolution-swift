# Offline x86_64 import overlays

Configure this directory with CMake/Ninja, or enable DARLING_BUILD_IMPORT_OVERLAYS
in Darling. Each ../<Module>/imports.json registers one source-built library.
Build under qv-slot build with ninja -j6. No network access or installation occurs.

The driver adapts catalyst/tools/swiftc-darwin: private Swift 6.3.3 compiler,
source-built Darwin resource/module inputs, source SDK, Stage41b dependency libraries
and ld64. All inputs can be overridden with the environment variables documented
in swiftc-darwin.py. No Apple SDK binary is an input. Delete output/module-cache
before compiling, so a failed rebuild cannot pass by leaving an older image.

Built libraries replace bundled copies only when the option is enabled. The
standalone build also has an install target with the normal Darling layout.
Modules are x86_64 only; do not enable for an arm64 installation.
