#!/usr/bin/env bash
set -euo pipefail
W=/home/sean/Documents/Codex/Projects/Qvolution-work
lane=$W/parallel/imp-swift-overlays
if [[ ${QV_SLOT:-} != build-* ]]; then exec "$W/dashboard/qv-slot" build bash "$0" "$@"; fi
build=${1:?pass the existing five-image build directory}
root=$W/stage41b/usr/local/libexec/darling
attempt=$(mktemp -d "$build/behavior-attempt-XXXXXX")
imp=$lane/superproject/src/external/swift/overlays/imports
args=()
for module in UniformTypeIdentifiers AVFoundation Network; do
  args+=(-I "$build/$module" "--link=$build/$module/libswift$module.dylib")
done
python3 "$imp/swiftc-darwin.py" --module-name OverlayBehavior --install-name unused \
  --executable --out "$attempt/product" "${args[@]}" \
  --modulemap "$lane/superproject/src/external/swift/overlays/AVFoundation/shims/module.modulemap" \
  --modulemap "$lane/superproject/src/external/swift/overlays/AVFoundation/shims/coremedia.modulemap" \
  --modulemap "$lane/superproject/src/external/swift/overlays/UniformTypeIdentifiers/shims/module.modulemap" \
  --modulemap "$lane/superproject/src/external/swift/overlays/Network/shims/module.modulemap" \
  -I "$lane/superproject/src/external/swift/overlays/AVFoundation/shims/include" \
  -I "$lane/superproject/src/external/swift/overlays/Network/shims" \
  --link="$root/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation" \
  --link="$root/System/Library/Frameworks/AVFoundation.framework/Versions/A/AVFoundation" \
  --link=-lswiftFoundation --link=-lswiftDispatch --link=-lswiftDarwin --link=-lswift_Concurrency \
  "$imp/behavior.swift"
printf '%s\n' "$attempt/product/OverlayBehavior" > "$build/behavior.path"
