#!/bin/sh
# Emit complete existing source overlay modules privately; never link/publish binaries.
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
: "${SWIFT_TOOLCHAIN:?}" "${SWIFT_RESOURCE_DIR:?}" "${DARLING_SDK:?}" "${DARLING_SOURCE_ROOT:?}"
: "${OPENCOMBINE_SRC:?}" "${SWIFT_COLLECTIONS_SRC:?}" "${SWIFT_CMARK_SRC:?}" "${SWIFT_FOUNDATION_SRC:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
overlays=$(CDPATH= cd -- "$here/.." && pwd)
arch=${CRYPTOKIT_ARCH:-arm64}
case "$arch" in arm64|x86_64) ;; *) printf 'Unsupported architecture: %s\n' "$arch" >&2; exit 1 ;; esac
target="$arch-apple-macosx26.0"
out=${CRYPTOKIT_MODULES_BUILD_DIR:-$here/build-modules-$arch}
modules='Darwin ObjectiveC CoreFoundation Dispatch os XPC Combine InternalCollectionsUtilities _RopeModule Foundation'
emit_objects=${CRYPTOKIT_EMIT_OVERLAY_OBJECTS:-0}
case "$emit_objects" in 0|1) ;; *) printf 'Invalid object-emission mode: %s\n' "$emit_objects" >&2; exit 1 ;; esac
if [ "$emit_objects" = 1 ]; then mkdir -p "$out/obj"; fi
mkdir -p "$out/modules"
cleanup_modules() {
 for module in $modules; do
  if [ "$emit_objects" = 1 ]; then preserve_paths "$out/obj/$module.o"; fi
  for suffix in swiftmodule swiftdoc swiftsourceinfo swiftinterface private.swiftinterface package.swiftinterface abi.json; do
   preserve_paths "$out/modules/$module.$suffix"
  done
 done
}
trap 'build_status=$?; if [ "$build_status" -ne 0 ]; then cleanup_modules; fi' 0
cleanup_modules
preserve_paths "$out/module-cache"
for module in Swift _Concurrency _StringProcessing; do
 if [ ! -s "$SWIFT_RESOURCE_DIR/macosx/$module.swiftmodule/$arch-apple-macos.swiftmodule" ]; then
  printf 'Missing source-built Darwin module for %s: %s\n' "$arch" "$module" >&2
  exit 1
 fi
done
verify_source() {
 actual=$(git -C "$1" rev-parse HEAD)
 source_status=$(git -C "$1" status --porcelain --untracked-files=all)
 if [ "$actual" != "$2" ] || [ -n "$source_status" ]; then
  printf 'Expected a pristine source checkout at %s: %s\n' "$2" "$1" >&2
  exit 1
 fi
}
verify_source "$OPENCOMBINE_SRC" 10df981a64800643559490d72174f43438562e73
verify_source "$SWIFT_COLLECTIONS_SRC" c11818f3cae0780656baa430b49e7f163f08dffd
verify_source "$SWIFT_CMARK_SRC" 924936d0427cb25a61169739a7660230bffa6ea6
verify_source "$SWIFT_FOUNDATION_SRC" dbacc67779dc0a41ddc9493acbaa332d76c9fb03
write_source() {
 printf '"%s"\n' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')" >> "$2"
}
collect_top_sources() {
 : > "$2"
 find "$1" -maxdepth 1 -name '*.swift' | LC_ALL=C sort | while IFS= read -r source; do write_source "$source" "$2"; done
}
collect_sources() {
 : > "$2"
 find "$1" -name '*.swift' | LC_ALL=C sort | while IFS= read -r source; do write_source "$source" "$2"; done
}
emit_module() {
 module=$1
 response=$2
 shift 2
 if [ ! -s "$response" ]; then
  printf 'No source files selected for module %s\n' "$module" >&2
  exit 1
 fi
 # Match the main recipe: Combine is built before, and without, overlay imports.
 if [ "$module" != Combine ]; then
  set -- -I "$out/modules" -Xcc -fmodule-map-file="$overlays/shims/overlay-shims.modulemap" "$@"
 fi
 if [ "$emit_objects" = 1 ]; then
  set -- -o "$out/obj/$module.o" "$@"
  emission=-c
 else
  emission=-emit-module
 fi
 "$SWIFT_TOOLCHAIN/bin/swiftc" -frontend "$emission" @"$response" \
  -target "$target" -sdk "$DARLING_SDK" -resource-dir "$SWIFT_RESOURCE_DIR" \
  -module-cache-path "$out/module-cache" -swift-version 5 -module-name "$module" \
  -parse-as-library -O \
  -Xcc -I"$DARLING_SOURCE_ROOT/src/frameworks/CoreServices/include" \
  -emit-module-path "$out/modules/$module.swiftmodule" "$@"
 test -s "$out/modules/$module.swiftmodule"
 if [ "$emit_objects" = 1 ]; then test -s "$out/obj/$module.o"; fi
}
build_overlay() {
 name=$1
 shift
 collect_top_sources "$overlays/$name" "$out/$name.sources"
 emit_module "$name" "$out/$name.sources" -enable-library-evolution \
  -module-link-name "swift$name" -autolink-force-load "$@"
}
build_overlay Darwin
build_overlay ObjectiveC -disable-objc-attr-requires-foundation-module
build_overlay CoreFoundation
build_overlay Dispatch
build_overlay os -Xcc -fmodule-map-file="$overlays/os/shims/module.modulemap"
build_overlay XPC -Xcc -fmodule-map-file="$overlays/XPC/shims/module.modulemap"

# Apply the same adaptations as the published overlay build to a private copy.
preserve_paths "$out/combine-src"
cp -R "$OPENCOMBINE_SRC/Sources/OpenCombine" "$out/combine-src"
for source_patch in "$overlays"/Combine/patches/*.patch; do
 patch -p1 -s -d "$out/combine-src" < "$source_patch"
done
collect_sources "$out/combine-src" "$out/Combine.sources"
emit_module Combine "$out/Combine.sources" -enable-library-evolution \
 -Xcc -fmodule-map-file="$OPENCOMBINE_SRC/Sources/COpenCombineHelpers/include/module.modulemap"

for entry in InternalCollectionsUtilities _RopeModule; do
 case "$entry" in _RopeModule) source_dir=RopeModule ;; *) source_dir=$entry ;; esac
 collect_sources "$SWIFT_COLLECTIONS_SRC/Sources/$source_dir" "$out/$entry.sources"
 emit_module "$entry" "$out/$entry.sources"
done

collect_top_sources "$overlays/Foundation" "$out/Foundation.sources"
while IFS= read -r relative; do
 [ -n "$relative" ] || continue
 write_source "$SWIFT_FOUNDATION_SRC/Sources/$relative" "$out/Foundation.sources"
done < "$here/foundation-module-sources.list"
sh "$overlays/FoundationRuntime/prepare-sort-sources.sh" "$SWIFT_FOUNDATION_SRC" "$out" | while IFS= read -r source; do
 write_source "$source" "$out/Foundation.sources"
done
emit_module Foundation "$out/Foundation.sources" -enable-library-evolution \
 -module-link-name swiftFoundation -autolink-force-load -package-name swift-foundation \
 -Xcc -DCMARK_GFM_STATIC_DEFINE -Xcc -I"$SWIFT_CMARK_SRC/src/include" \
 -Xcc -fmodule-map-file="$SWIFT_CMARK_SRC/src/include/module.modulemap" \
 -Xcc -fmodule-map-file="$SWIFT_CMARK_SRC/extensions/include/module.modulemap"
printf 'Emitted source modules for %s in %s\n' "$target" "$out/modules"
