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
bash "$lane/superproject/src/external/swift/overlays/imports/build-behavior.sh" "$build"
python3 "$lane/superproject/src/external/swift/overlays/imports/check-exports.py" "$build" > "$build/exports.json"
printf '%s\n' "$build" > "$lane/evidence/latest-build.path"
printf 'PASS build and exports: %s\n' "$build"
