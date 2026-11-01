#!/usr/bin/env python3
"""Exercise stage repinning without mutating shared hardlinks or losing evidence."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

helper, evidence = (Path(p).resolve() for p in sys.argv[1:])
root = Path(tempfile.mkdtemp(prefix='repin-control-', dir=evidence))
lane = root / 'parallel/imp-swift-overlays'
foundation = root / 'parallel/imp-foundation'
source = foundation / 'private-install/usr/local/libexec/darling'
stage = lane / 'stage/usr/local/libexec/darling'
shared = root / 'shared'
payloads = {
    'System/Library/Frameworks/Foundation.framework/Versions/C/Foundation': b'new-foundation',
    'usr/lib/swift/libswiftFoundation.dylib': b'new-swift-foundation',
    'usr/lib/swift/libswiftCoreFoundation.dylib': b'foundation-cf',
    'usr/lib/swift/libswiftos.dylib': b'foundation-os',
    'usr/lib/swift/libswiftDarwin.dylib': b'unchanged-darwin',
}
for rel, data in payloads.items():
    target, original = stage / rel, shared / rel
    for parent in (target.parent, original.parent, (source / rel).parent):
        parent.mkdir(parents=True, exist_ok=True)
    (source / rel).write_bytes(data)
    original.write_bytes(data if 'Darwin' in rel else b'old-or-owned')
    os.link(original, target)
old_inodes = {rel: (stage / rel).stat().st_ino for rel in payloads}
receipt = {'root': str(source), 'commits': {'foundation': 'fixture'},
           'payload_sha256': {rel: hashlib.sha256(data).hexdigest() for rel, data in payloads.items()}}
receipt_path = foundation / 'prepared-private.json'
receipt_path.write_text(json.dumps(receipt))
env = dict(os.environ, QV_SLOT='build-native-control')

def run(label, expected):
    result = subprocess.run([sys.executable, str(helper), str(lane)], env=env,
                            capture_output=True, text=True)
    (root / (label + '.log')).write_text(result.stdout + result.stderr)
    assert result.returncode == expected, result.stdout + result.stderr
    return json.loads(result.stdout) if expected == 0 else None

# Validate every producer before any stage entry is changed.
(source / 'usr/lib/swift/libswiftFoundation.dylib').write_bytes(b'wrong-producer')
run('reject-before-mutation', 2)
assert all((stage / rel).stat().st_ino == inode for rel, inode in old_inodes.items())
(source / 'usr/lib/swift/libswiftFoundation.dylib').write_bytes(payloads['usr/lib/swift/libswiftFoundation.dylib'])
report = run('repin', 0)
assert len(report['changed']) == 2, report
transaction = Path(report['transaction'])
for rel, data in payloads.items():
    target, original = stage / rel, shared / rel
    assert original.stat().st_ino == old_inodes[rel]
    if rel in report['changed']:
        assert target.read_bytes() == data
        assert (transaction / 'old' / rel).stat().st_ino == old_inodes[rel]
        assert os.path.samefile(target, transaction / 'new' / rel)
        assert not os.path.samefile(target, source / rel)
        assert report['changed'][rel]['old_sha256'] == hashlib.sha256(b'old-or-owned').hexdigest()
        assert report['changed'][rel]['new_sha256'] == receipt['payload_sha256'][rel]
    else:
        assert target.stat().st_ino == old_inodes[rel]
assert not run('idempotent', 0)['changed']
assert (transaction / 'prepared-private.json').read_bytes() == receipt_path.read_bytes()
print('PASS corrupt producer rejected before mutation; shared inodes and CF/os preserved; old/new hashes; idempotence:', root)
