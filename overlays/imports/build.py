#!/usr/bin/env python3
"""Offline compiler driver for source-built x86_64 import overlays."""
import json, os, subprocess, sys
from pathlib import Path
recipe, output = map(Path, sys.argv[1:])
module = recipe.parent.name
spec = json.loads(recipe.read_text())
w = Path('/home/sean/Documents/Codex/Projects/Qvolution-work')
root = Path(os.environ.get('DARLING_ROOT', str(w / 'stage41b/usr/local/libexec/darling')))
here = recipe.parent
replace = lambda s: s.replace('@ROOT@', str(root)).replace('@HERE@', str(here))
args = [sys.executable, str(Path(__file__).with_name('swiftc-darwin.py')),
        '--module-name', module, '--install-name', f'/usr/lib/swift/libswift{module}.dylib',
        '--out', str(output), '--swift-flag=-module-link-name',
        '--swift-flag=swift' + module, '--swift-flag=-autolink-force-load']
args += [replace(s) for s in spec.get('args', [])]
args += [str(here / s) for s in spec['sources']]
subprocess.run(args, check=True)
(output / ('lib' + module + '.dylib')).rename(output / ('libswift' + module + '.dylib'))
