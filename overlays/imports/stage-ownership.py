#!/usr/bin/env python3
"""Verify source-built dependency producers without copying any stage files.

Only source-built payloads recorded by imp-foundation are hashed. This lane owns
the five import overlays; in particular, its CF/os images supersede that receipt.
"""
from pathlib import Path
import hashlib
import json
import sys

lane = Path(sys.argv[1]).resolve()
stage = lane / 'stage/usr/local/libexec/darling'
receipt = lane.parent / 'imp-foundation/prepared-private.json'
overridden = {'usr/lib/swift/libswiftCoreFoundation.dylib', 'usr/lib/swift/libswiftos.dylib'}
try:
    payload = json.loads(receipt.read_text())['payload_sha256']
    assert overridden <= payload.keys(), 'Foundation receipt must identify both CF/os producers'
    for rel, expected in payload.items():
        assert not Path(rel).is_absolute() and '..' not in Path(rel).parts, rel
        if rel in overridden:
            print('Owner imp-swift-overlays overrides imp-foundation:', rel)
            continue
        target = stage / rel
        assert target.is_file() and not target.is_symlink(), f'Missing private dependency: {rel}'
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        assert actual == expected, f'Wrong dependency producer or content: {rel}'
        print('Verified imp-foundation dependency:', rel)
except (OSError, ValueError, KeyError, AssertionError) as error:
    print('Stage ownership preflight failed:', error, file=sys.stderr)
    sys.exit(2)
