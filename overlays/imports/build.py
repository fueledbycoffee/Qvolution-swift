#!/usr/bin/env python3
"""Offline compiler driver for source-built x86_64 import overlays.

SWIFT_NETWORK_SOURCE must be an unmodified checkout at the commit in its recipe.
It is read-only: apply patches to a fresh private copy, never to that checkout.
No network fetch or binary input inspection is performed.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

only_dependencies = sys.argv[1] == '--dependencies'
recipe = Path(sys.argv[2] if only_dependencies else sys.argv[1]).resolve()
if not only_dependencies:
    output = Path(sys.argv[2]).resolve()
    if output.exists():
        shutil.rmtree(output)
spec = json.loads(recipe.read_text())
module = recipe.parent.name
w = Path('/home/sean/Documents/Codex/Projects/Qvolution-work')
root = Path(os.environ.get('DARLING_ROOT', str(w / 'stage41b/usr/local/libexec/darling')))
here = recipe.parent

def replace(value):
    return value.replace('@ROOT@', str(root)).replace('@HERE@', str(here)).replace('@WORK@', str(w))

sources = [here / name for name in spec['sources']]
upstream = spec.get('upstream')
if upstream:
    checkout = Path(os.environ.get(upstream['environment'], replace(upstream['default'])))
    pin = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
    if pin != upstream['commit']:
        raise SystemExit(f'{module}: upstream is {pin}; expected {upstream["commit"]}')
    origin = checkout / upstream['directory']
    originals = [origin / name for name in upstream['sources']]
    patches = [here / name for name in upstream['patches']]
    if subprocess.check_output(['git', '--no-optional-locks', '-C', str(checkout), 'status', '--porcelain', '--',
                                upstream['directory']], text=True).strip():
        raise SystemExit(f'{module}: upstream source directory must be clean')
else:
    originals, patches = [], []

if only_dependencies:
    print(';'.join(str(path) for path in sources + originals + patches))
    raise SystemExit(0)

output = Path(sys.argv[2]).resolve()
if upstream:
    adapted = output.with_name(output.name + '-upstream')
    if adapted.exists():
        shutil.rmtree(adapted)
    adapted.mkdir(parents=True)
    for source in originals:
        shutil.copyfile(source, adapted / source.name)
    for patch in patches:
        subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch)], cwd=adapted, check=True)
    sources += [adapted / source.name for source in originals]

args = [sys.executable, str(Path(__file__).with_name('swiftc-darwin.py')),
        '--module-name', module, '--install-name', f'/usr/lib/swift/libswift{module}.dylib',
        '--out', str(output), '--swift-flag=-module-link-name',
        '--swift-flag=swift' + module, '--swift-flag=-autolink-force-load']
args += [replace(value) for value in spec.get('args', [])]
args += [str(path) for path in sources]
subprocess.run(args, check=True)
(output / ('lib' + module + '.dylib')).rename(output / ('libswift' + module + '.dylib'))
