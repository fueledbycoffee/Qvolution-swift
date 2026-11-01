#!/usr/bin/env python3
"""Repin an existing private hardlink stage, retaining every replaced directory entry."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

OVERRIDDEN = {'usr/lib/swift/libswiftCoreFoundation.dylib', 'usr/lib/swift/libswiftos.dylib'}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    assert os.environ.get('QV_SLOT', '').startswith('build-'), 'Use qv-slot build'
    lane = Path(sys.argv[1]).resolve()
    stage = lane / 'stage/usr/local/libexec/darling'
    receipt_path = lane.parent / 'imp-foundation/prepared-private.json'
    receipt_bytes = receipt_path.read_bytes()
    receipt = json.loads(receipt_bytes)
    source = Path(receipt['root'])
    assert source == lane.parent / 'imp-foundation/private-install/usr/local/libexec/darling'
    payloads = receipt['payload_sha256']
    assert OVERRIDDEN <= payloads.keys()
    changed, verified = {}, {}
    for rel, expected in payloads.items():
        assert not Path(rel).is_absolute() and '..' not in Path(rel).parts, rel
        target, producer = stage / rel, source / rel
        assert target.is_file() and not target.is_symlink(), str(target)
        assert target.parent.resolve().is_relative_to(stage.resolve()), str(target)
        if rel in OVERRIDDEN:
            continue
        assert producer.is_file() and not producer.is_symlink(), str(producer)
        assert producer.parent.resolve().is_relative_to(source.resolve()), str(producer)
        assert digest(producer) == expected, 'Foundation producer does not match receipt: ' + rel
        actual = digest(target)
        verified[rel] = expected
        if actual != expected:
            changed[rel] = {'old_sha256': actual, 'new_sha256': expected}
    report = {'changed': changed, 'verified': verified, 'overridden': sorted(OVERRIDDEN),
              'foundation_commits': receipt['commits'], 'transaction': None}
    if changed:
        evidence = lane / 'evidence'
        evidence.mkdir(exist_ok=True)
        transaction = Path(tempfile.mkdtemp(prefix='foundation-repin-', dir=evidence))
        report['transaction'] = str(transaction)
        (transaction / 'prepared-private.json').write_bytes(receipt_bytes)
        # Prepare independent payloads first. Never link the producer: its runner
        # deliberately requires private single-link files.
        for rel, hashes in changed.items():
            new = transaction / 'new' / rel
            new.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / rel, new)
            assert digest(new) == hashes['new_sha256'], rel
        assert receipt_path.read_bytes() == receipt_bytes, 'Receipt changed during preparation'
        for rel, hashes in changed.items():
            assert digest(stage / rel) == hashes['old_sha256'], 'Stage changed during preparation: ' + rel
        # Persist intent before changing any entry; an interrupted transaction
        # retains both its old and new files for recovery without deletion.
        (transaction / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
        for rel in changed:
            target, saved = stage / rel, transaction / 'old' / rel
            saved.parent.mkdir(parents=True, exist_ok=True)
            target.rename(saved)
            os.link(transaction / 'new' / rel, target)
    for rel, expected in verified.items():
        assert digest(stage / rel) == expected, rel
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, AssertionError) as error:
        print('Foundation repin failed:', error, file=sys.stderr)
        sys.exit(2)
