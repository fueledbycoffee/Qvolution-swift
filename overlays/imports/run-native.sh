#!/usr/bin/env bash
# A prepared, approved private stage is required; this runner never copies one.
set -euo pipefail
W=${QV_WORKSPACE:-/home/sean/Documents/Codex/Projects/Qvolution-work}
lane=$W/parallel/imp-swift-overlays
swift=$lane/superproject/src/external/swift
[[ -d $lane/stage ]] || { echo 'Orchestrator must prepare the approved private Swift stage first' >&2; exit 2; }
build=${QV_OVERLAY_BUILD:-$(cat "$lane/evidence/latest-build.path")}
[[ -z $(git -C "$swift" status --porcelain) && -z $(git -C "$lane/superproject" status --porcelain) ]] || { echo 'Commit all source and pins before running' >&2; exit 2; }
python3 "$(dirname "$0")/stage-ownership.py" "$lane"
for module in UniformTypeIdentifiers AVFoundation CoreFoundation os Network; do
  cmp "$build/$module/libswift$module.dylib" "$lane/stage/usr/local/libexec/darling/usr/lib/swift/libswift$module.dylib"
done
behavior=$(cat "$build/behavior.path")
[[ -x $build/load-exports && -x $behavior ]]
if [[ ${1-} != --guest-slot ]]; then exec "$W/dashboard/qv-slot" guest bash "$0" --guest-slot; fi
for name in ${!DYLD_@}; do unset "$name"; done
export DARLING_NONROOT=1 DARLING_INSTALL_PREFIX=$lane/stage/usr/local
export DPREFIX=$W/p/isw-$(date +%s)-$$
[[ ${#DPREFIX} -le 83 && ! -e $DPREFIX ]]
launcher=$W/parallel/stage41/build/src/startup/darling
[[ -x $launcher && ! -u $launcher ]]
run=$(mktemp -d "$lane/evidence/container-XXXXXX")
shutdown() { DPREFIX="$DPREFIX" "$W/dashboard/qv-shutdown" "$launcher" >> "$run/shutdown.log" 2>&1; }
finish() {
  local result=$? stopped guarded
  trap - EXIT
  set +e
  shutdown; stopped=$?
  "$W/dashboard/qv-host-guard" verify "$run/home-before.tsv" > "$run/home-verify.log" 2>&1; guarded=$?
  if (( guarded != 0 )); then result=$guarded
  elif (( result == 0 && stopped != 0 )); then result=$stopped; fi
  if (( result == 0 )); then printf 'PASS real five-image load, URL/listener/async behavior and WebSocket rejection: %s\n' "$run"; fi
  exit "$result"
}
"$W/dashboard/qv-host-guard" snapshot "$run/home-before.tsv"
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
guest() {
  local label=$1 result attempt; shift
  for attempt in 1 2; do
    if "$launcher" shell "$@" > "$run/$label-$attempt.log" 2>&1; then return 0; else result=$?; fi
    shutdown || true
    if [[ $attempt == 2 ]] || ! grep -q 'Timed out waiting for shellspawn in container' "$run/$label-$attempt.log"; then return "$result"; fi
  done
}
guest initialize /usr/bin/true
shutdown
mkdir -p "$DPREFIX/Applications/OverlayImports"
cp -a "$build/load-exports" "$behavior" "$DPREFIX/Applications/OverlayImports/"
args=()
for module in UniformTypeIdentifiers AVFoundation CoreFoundation os Network; do
  cp -a "$swift/overlays/$module/imports.exports" "$DPREFIX/Applications/OverlayImports/$module.exports"
  args+=("/usr/lib/swift/libswift$module.dylib" "/Applications/OverlayImports/$module.exports")
done
guest load /Applications/OverlayImports/load-exports "${args[@]}"
guest behavior /Applications/OverlayImports/OverlayBehavior
grep -q '^RESULT swift-overlay-behavior failures=0$' "$run/behavior-1.log" "$run/behavior-2.log" 2>/dev/null
for mode in websocket-options websocket-metadata; do
  result=0
  guest "$mode" /Applications/OverlayImports/OverlayBehavior "$mode" || result=$?
  [[ $result == 132 ]] || { echo "Expected Swift fatalError SIGILL for $mode, received $result" >&2; exit 1; }
  grep -q "^BEGIN $mode$" "$run/$mode-1.log" "$run/$mode-2.log" 2>/dev/null
done
