#!/usr/bin/env python3
"""Reject a changed Foundation dependency while allowing our CF/os overrides."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

helper, evidence = map(lambda p: Path(p).resolve(), sys.argv[1:])
root = Path(tempfile.mkdtemp(prefix='ownership-', dir=evidence))
lane = root / 'parallel/imp-swift-overlays'
stage = lane / 'stage/usr/local/libexec/darling'
receipt = root / 'parallel/imp-foundation/prepared-private.json'
receipt.parent.mkdir(parents=True)
payload = {
    'System/Library/Frameworks/Foundation.framework/Versions/C/Foundation': b'foundation',
    'usr/lib/swift/libswiftCoreFoundation.dylib': b'foundation-cf',
    'usr/lib/swift/libswiftos.dylib': b'foundation-os',
    'usr/lib/swift/libswift_DarwinFoundation1.dylib': b'split-foundation',
}
receipt.write_text(json.dumps({'commits': {'swift': 'mock-foundation'},
    'payload_sha256': {p: hashlib.sha256(data).hexdigest() for p, data in payload.items()}}))
for rel, data in payload.items():
    target = stage / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
for name in ['libswiftCoreFoundation.dylib', 'libswiftos.dylib']:
    (stage / 'usr/lib/swift' / name).write_bytes(b'our-overlay')


def check(expected):
    result = subprocess.run([sys.executable, str(helper), str(lane)], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (root / ('pass.log' if expected else 'reject.log')).write_text(result.stdout)
    assert (result.returncode == 0) == expected, result.stdout
    return result.stdout


assert 'CoreFoundation' in check(True) and 'os' in check(True)
(stage / 'usr/lib/swift/libswift_DarwinFoundation1.dylib').write_bytes(b'wrong-producer')
assert 'libswift_DarwinFoundation1.dylib' in check(False)
print('PASS explicit CF/os ownership; mismatched Foundation dependency rejected:', root)
