#!/bin/sh
# Patch only a fresh private copy of the pinned public source; retain every attempt.
set -eu
src=${1:?pinned swift-foundation source}
out=${2:?private output directory}
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
[ "$(git -C "$src" rev-parse HEAD)" = dbacc67779dc0a41ddc9493acbaa332d76c9fb03 ]
[ -z "$(git -C "$src" status --porcelain --untracked-files=all)" ]
mkdir -p "$out"
copy=$(mktemp -d "$out/sort-sources.XXXXXXXX")
cp "$src/Sources/FoundationInternationalization/String/String+SortComparator.swift" "$copy/String+SortComparator.swift"
patch -s --batch -p1 -d "$copy" < "$here/patches/0001-select-framework-string-comparators.patch" >&2
printf '%s\n' "$copy/String+SortComparator.swift"
