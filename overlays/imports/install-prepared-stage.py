#!/usr/bin/env python3
"""Install the five own images into an already-approved stage; preserve old files."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

lane = Path(__file__).resolve().parents[6]
build = Path(sys.argv[1]).resolve()
assert os.environ.get('QV_SLOT', '').startswith('build-')
assert not subprocess.check_output(['git', '-C', str(lane / 'superproject'), 'status', '--porcelain'], text=True).strip()
stage = lane / 'stage/usr/local/libexec/darling'
assert stage.is_dir(), 'Orchestrator must prepare the approved stage and matching Swift runtime first'
backup = Path(tempfile.mkdtemp(prefix='stage-before-overlays-', dir=lane / 'evidence'))
baseline = lane.parents[1] / 'stage41b/usr/local/libexec/darling'
for module in ['UniformTypeIdentifiers', 'AVFoundation', 'CoreFoundation', 'os', 'Network']:
    name = 'libswift' + module + '.dylib'
    target = stage / 'usr/lib/swift' / name
    assert target.is_file() and not target.is_symlink(), target
    original = baseline / 'usr/lib/swift' / name
    assert not original.exists() or not os.path.samefile(target, original), 'Refuse baseline-shared inode'
    shutil.copy2(target, backup / name)
    shutil.copy2(build / module / name, target)
    print('Installed own image:', target)
