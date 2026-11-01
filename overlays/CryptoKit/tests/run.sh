#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/../../.." && pwd)
arch=${CRYPTOKIT_ARCH:-arm64}
case "$arch" in
 arm64) default_out="$here/../build" ;;
 x86_64) default_out="$here/../build-x86_64" ;;
 *) printf 'Unsupported CryptoKit architecture: %s\n' "$arch" >&2; exit 1 ;;
esac
target="$arch-apple-macosx26.0"
out=${CRYPTOKIT_BUILD_DIR:-$default_out}
: "${OVERLAY_BUILD_DIR:?}" "${DARLING_SOURCE_ROOT:?}"
rm -f "$out/obj/tests.o" "$out/cryptokit-tests"
rm -rf "$out/test-module-cache"
# An explicit runtime directory binds these links to the selected staged runtime.
# Preserve the original resource/repository search paths when no override is set.
if [ -n "${SWIFT_RUNTIME_DIR:-}" ]; then
    for library in swiftCore swiftFoundation swiftCoreFoundation swiftDarwin swiftObjectiveC; do
        if [ ! -s "$SWIFT_RUNTIME_DIR/lib$library.dylib" ]; then
            printf 'Missing selected Swift runtime library: %s\n' "$SWIFT_RUNTIME_DIR/lib$library.dylib" >&2
            exit 1
        fi
    done
    set -- -L "$SWIFT_RUNTIME_DIR"
else
    set -- -L "$SWIFT_RESOURCE_DIR/macosx" -L "$repo"
fi
framework_path=${CRYPTOKIT_FRAMEWORK_PATH:-$out}
if [ -z "${CRYPTOKIT_FRAMEWORK_PATH:-}" ]; then
 mkdir -p "$out/CryptoKit.framework/Versions/A"
 ln -sfn ../../../CryptoKit "$out/CryptoKit.framework/Versions/A/CryptoKit"
 ln -sfn A "$out/CryptoKit.framework/Versions/Current"
 ln -sfn Versions/Current/CryptoKit "$out/CryptoKit.framework/CryptoKit"
fi
if [ ! -f "$framework_path/CryptoKit.framework/Versions/A/CryptoKit" ]; then
 printf 'Missing selected CryptoKit framework executable: %s\n' "$framework_path" >&2
 exit 1
fi
"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c "$here/main.swift" \
 -target "$target" -sdk "$DARLING_SDK" -resource-dir "$SWIFT_RESOURCE_DIR" \
 -module-cache-path "$out/test-module-cache" -swift-version 5 -module-name CryptoKitAEADTests \
 -I "$out/modules" -I "$OVERLAY_BUILD_DIR/modules" -F "$framework_path" \
 -I "$repo/overlays/CryptoKit" -Xcc -I"$DARLING_SOURCE_ROOT/src/frameworks/CoreServices/include" \
 -Xcc -fmodule-map-file="$repo/overlays/shims/overlay-shims.modulemap" -o "$out/obj/tests.o"
"$DARLING_LD" -arch "$arch" -platform_version macos 26.0 26.0 -syslibroot "$DARLING_SDK" \
 ${LD_EXTRA_FLAGS:-} "$@" \
 "${DARLING_CRT1:?path to Darling crt1 start.S.o for CRYPTOKIT_ARCH}" \
 "$out/obj/tests.o" -F "$framework_path" -framework CryptoKit "$DARLING_LIBSYSTEM" \
 "$DARLING_ROOT/usr/lib/libobjc.A.dylib" \
 -lswiftCore -lswiftFoundation -lswiftCoreFoundation -lswiftDarwin -lswiftObjectiveC \
 -o "$out/cryptokit-tests"

printf '%s\n' "$out/cryptokit-tests"
