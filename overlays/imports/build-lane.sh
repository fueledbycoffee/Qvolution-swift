#!/usr/bin/env bash
set -euo pipefail
W=/home/sean/Documents/Codex/Projects/Qvolution-work
lane=$W/parallel/imp-swift-overlays
if [[ ${QV_SLOT:-} != build-* ]]; then
  exec "$W/dashboard/qv-slot" build bash "$0" "$@"
fi
build=${1:-$(mktemp -d "$lane/build-attempt-XXXXXX")}
if [[ -n ${1:-} ]]; then
  [[ ! -e $build ]] || { echo 'Use a fresh output directory; preserve earlier attempts' >&2; exit 2; }
  mkdir -p "$build"
fi
cmake -S "$lane/superproject/src/external/swift/overlays/imports" -B "$build" -G Ninja
ninja -C "$build" -j6
ninja -C "$build" -n
cc -Wall -Wextra -Werror -shared -fPIC "$lane/superproject/src/external/swift/overlays/imports/export-negative-control.c" -o "$build/export-negative-control.so"
cc -Wall -Wextra -Werror "$lane/superproject/src/external/swift/overlays/imports/load-exports.c" -ldl -o "$build/load-exports-host"
sdk=$W/parallel/stage41/superproject/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
root=$W/stage41b/usr/local/libexec/darling
compiler=$W/toolchains/swift-6.3.3-linux-x64/compiler/usr/bin/clang
ld=$W/parallel/stage41/build/src/external/cctools-port/cctools/ld64/src/x86_64-apple-darwin20-ld
"$compiler" -target x86_64-apple-macosx26.0 -isysroot "$sdk" -O2 -Wall -Wextra -Werror -c \
  "$lane/superproject/src/external/swift/overlays/imports/load-exports.c" -o "$build/load-exports.o"
"$ld" -arch x86_64 -platform_version macos 26.0 26.0 -syslibroot "$sdk" -syslibroot "$root" \
  "$W/parallel/stage41/build/src/external/csu/CMakeFiles/crt1.10.6.dir/start.S.o" \
  "$build/load-exports.o" "$root/usr/lib/libSystem.B.dylib" -o "$build/load-exports"
imp=$lane/superproject/src/external/swift/overlays/imports
args=()
for module in UniformTypeIdentifiers AVFoundation Network; do
  args+=(-I "$build/$module" "--link=$build/$module/libswift$module.dylib")
done
python3 "$imp/swiftc-darwin.py" --module-name OverlayBehavior --install-name unused \
  --executable --out "$build/Behavior" "${args[@]}" \
  --modulemap "$lane/superproject/src/external/swift/overlays/AVFoundation/shims/module.modulemap" \
  --modulemap "$lane/superproject/src/external/swift/overlays/UniformTypeIdentifiers/shims/module.modulemap" \
  --modulemap "$lane/superproject/src/external/swift/overlays/Network/shims/module.modulemap" \
  -I "$lane/superproject/src/external/swift/overlays/AVFoundation/shims/include" \
  -I "$lane/superproject/src/external/swift/overlays/Network/shims" \
  --link="$root/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation" \
  --link="$root/System/Library/Frameworks/AVFoundation.framework/Versions/A/AVFoundation" \
  --link=-lswiftFoundation --link=-lswiftDispatch --link=-lswiftDarwin --link=-lswift_Concurrency \
  "$imp/behavior.swift"
python3 "$lane/superproject/src/external/swift/overlays/imports/check-exports.py" "$build" > "$build/exports.json"
printf '%s\n' "$build" > "$lane/evidence/latest-build.path"
printf 'PASS build and exports: %s\n' "$build"
