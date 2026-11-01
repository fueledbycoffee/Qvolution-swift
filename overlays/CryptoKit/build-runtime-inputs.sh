#!/bin/sh
# Compile the complete existing source overlays privately with the selected compiler.
# No publication, lipo merge, installation, runtime shim export or guest execution.
set -eu
# Preserve prior and partial products for integration evidence; never delete them.
preserve_paths() {
 for prior in "$@"; do
  if [ -e "$prior" ] || [ -L "$prior" ]; then
   archive=$(mktemp -d "${prior}.previous-XXXXXX")
   mv "$prior" "$archive/product"
  fi
 done
}
: "${SWIFT_TOOLCHAIN:?}" "${SWIFT_RESOURCE_DIR:?}" "${SWIFT_RUNTIME_DIR:?}"
: "${DARLING_SDK:?}" "${DARLING_SOURCE_ROOT:?}" "${DARLING_ROOT:?}"
: "${DARLING_LD:?}" "${DARLING_LIBSYSTEM:?}" "${CRYPTOKIT_MODULES_BUILD_DIR:?private output required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
overlays=$(CDPATH= cd -- "$here/.." && pwd)
arch=${CRYPTOKIT_ARCH:-arm64}
case "$arch" in arm64|x86_64) ;; *) printf 'Unsupported architecture: %s\n' "$arch" >&2; exit 1 ;; esac
target="$arch-apple-macosx26.0"
out=$CRYPTOKIT_MODULES_BUILD_DIR
mkdir -p "$out/obj" "$out/runtime" "$out/Combine.framework/Versions/A"
linked_modules='Darwin ObjectiveC CoreFoundation Dispatch os XPC Foundation'
all_modules='Darwin ObjectiveC CoreFoundation Dispatch os XPC Combine InternalCollectionsUtilities _RopeModule Foundation'
core_libraries='swiftCore swift_Concurrency swift_StringProcessing swift_RegexParser swiftSwiftOnoneSupport'
cleanup_outputs() {
 for module in $all_modules; do
  preserve_paths "$out/obj/$module.o"
  for suffix in swiftmodule swiftdoc swiftsourceinfo swiftinterface private.swiftinterface package.swiftinterface abi.json; do
   preserve_paths "$out/modules/$module.$suffix"
  done
 done
 preserve_paths "$out/obj/Dispatch.mm.o" "$out/obj/DarlingSerialExecutor.m.o" "$out/obj/CombineHelpers.o"
 for module in $linked_modules; do preserve_paths "$out/libswift$module.dylib" "$out/runtime/libswift$module.dylib"; done
 for library in $core_libraries; do preserve_paths "$out/runtime/lib$library.dylib"; done
 preserve_paths "$out/Combine.framework/Versions/A/Combine"
}
trap 'build_status=$?; if [ "$build_status" -ne 0 ]; then cleanup_outputs; fi' 0
cleanup_outputs
for library in $core_libraries; do
 test -s "$SWIFT_RUNTIME_DIR/lib$library.dylib" || { printf 'Missing selected runtime: %s\n' "$library" >&2; exit 1; }
done
# Reuse the complete, pin-checked source selection and all per-module flags.
CRYPTOKIT_EMIT_OVERLAY_OBJECTS=1 sh "$here/build-module-inputs.sh"
"$SWIFT_TOOLCHAIN/bin/clang++" -target "$target" -isysroot "$DARLING_SDK" \
 -I "$overlays/Dispatch/include" -std=c++17 -fobjc-arc -O2 \
 -c "$overlays/Dispatch/Dispatch.mm" -o "$out/obj/Dispatch.mm.o"
"$SWIFT_TOOLCHAIN/bin/clang" -target "$target" -isysroot "$DARLING_SDK" -fobjc-arc -O2 \
 -c "$overlays/Dispatch/DarlingSerialExecutor.m" -o "$out/obj/DarlingSerialExecutor.m.o"
"$SWIFT_TOOLCHAIN/bin/clang" -target "$target" -isysroot "$DARLING_SDK" \
 -I "$OPENCOMBINE_SRC/Sources/COpenCombineHelpers/include" -Wall -Wextra -O2 -fvisibility=hidden \
 -c "$overlays/Combine/helpers.c" -o "$out/obj/CombineHelpers.o"
mkdir -p "$out/obj/cmark"
: > "$out/cmark-objects.list"
find "$SWIFT_CMARK_SRC/src" "$SWIFT_CMARK_SRC/extensions" -maxdepth 1 -name '*.c' | LC_ALL=C sort | while IFS= read -r source; do
 object="$out/obj/cmark/$(basename "$(dirname "$source")")-$(basename "$source" .c).o"
 "$SWIFT_TOOLCHAIN/bin/clang" -target "$target" -isysroot "$DARLING_SDK" -O2 \
  -fvisibility=hidden -DCMARK_GFM_STATIC_DEFINE -DNDEBUG \
  -I "$SWIFT_CMARK_SRC/src/include" -I "$SWIFT_CMARK_SRC/extensions/include" -c "$source" -o "$object"
 printf '%s\n' "$object" >> "$out/cmark-objects.list"
done
corefoundation="$DARLING_ROOT/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
foundation="$DARLING_ROOT/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation"
link_overlay() {
 module=$1; shift
 # shellcheck disable=SC2086
 "$DARLING_LD" -dylib -arch "$arch" -platform_version macos 26.0 26.0 \
  -syslibroot "$DARLING_SDK" -syslibroot "$DARLING_ROOT" \
  -install_name "/usr/lib/swift/libswift$module.dylib" -compatibility_version 1.0.0 -current_version 1.0.0 \
  ${LD_EXTRA_FLAGS:-} -L "$out" -L "$SWIFT_RUNTIME_DIR" \
  "$out/obj/$module.o" "$DARLING_LIBSYSTEM" "$DARLING_ROOT/usr/lib/libobjc.A.dylib" \
  -lswiftCore "$@" -o "$out/libswift$module.dylib"
}
link_overlay Darwin
link_overlay ObjectiveC -lswiftDarwin
link_overlay CoreFoundation "$corefoundation" -lswiftDarwin
link_overlay Dispatch "$out/obj/Dispatch.mm.o" "$out/obj/DarlingSerialExecutor.m.o" -lswiftObjectiveC -lswiftDarwin
link_overlay os -lswiftDarwin -lswiftObjectiveC -lswiftDispatch
link_overlay XPC -lswiftDarwin -lswiftObjectiveC -lswiftDispatch
# shellcheck disable=SC2086
"$DARLING_LD" -dylib -arch "$arch" -platform_version macos 26.0 26.0 \
 -syslibroot "$DARLING_SDK" -syslibroot "$DARLING_ROOT" \
 -install_name /System/Library/Frameworks/Combine.framework/Versions/A/Combine \
 -compatibility_version 1.0.0 -current_version 1.0.0 ${LD_EXTRA_FLAGS:-} \
 -L "$SWIFT_RUNTIME_DIR" "$out/obj/Combine.o" "$out/obj/CombineHelpers.o" \
 "$DARLING_LIBSYSTEM" "$DARLING_ROOT/usr/lib/libobjc.A.dylib" -lswiftCore \
 -o "$out/Combine.framework/Versions/A/Combine"
printf '_$s11_RopeModule*\n_$s28InternalCollectionsUtilities*\n' > "$out/unexported.txt"
link_overlay Foundation -unexported_symbols_list "$out/unexported.txt" \
 "$out/obj/_RopeModule.o" "$out/obj/InternalCollectionsUtilities.o" -filelist "$out/cmark-objects.list" \
 "$foundation" "$corefoundation" "$DARLING_ROOT/usr/lib/libicucore.A.dylib" \
 "$out/Combine.framework/Versions/A/Combine" -lswiftDarwin -lswiftObjectiveC -lswiftCoreFoundation -lswiftDispatch
for library in $core_libraries; do ln -s "$SWIFT_RUNTIME_DIR/lib$library.dylib" "$out/runtime/lib$library.dylib"; done
for module in $linked_modules; do ln -s "../libswift$module.dylib" "$out/runtime/libswift$module.dylib"; done
printf 'Built private source overlays and Combine for %s in %s; no installation or runtime execution.\n' "$target" "$out"
