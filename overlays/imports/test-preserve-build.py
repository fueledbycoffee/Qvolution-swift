#!/usr/bin/env python3
"""Rebuild with a fake compiler and prove prior successes/failures survive."""
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
from unittest.mock import patch
import json

driver, evidence = map(Path, sys.argv[1:])
root = Path(tempfile.mkdtemp(prefix='preserve-', dir=evidence))
recipe = root / 'Example/imports.json'
recipe.parent.mkdir()
recipe.write_text(json.dumps({'sources': ['Example.swift']}))
(recipe.parent / 'Example.swift').touch()
output = root / 'product'
output.mkdir()
(output / 'old-result').write_text('retained')
def compile_ok(args, **kwargs):
    target = Path(args[args.index('--out') + 1])
    target.mkdir(parents=True)
    (target / 'libExample.dylib').write_text('new-result')
def invoke(compiler):
    with patch.object(sys, 'argv', [str(driver), str(recipe), str(output)]), patch('subprocess.run', compiler):
        runpy.run_path(str(driver), run_name='__main__')
invoke(compile_ok)
assert (output / 'libswiftExample.dylib').read_text() == 'new-result'
assert any(p.read_text() == 'retained' for p in root.rglob('old-result')), 'old successful build was deleted'
def compile_fail(args, **kwargs):
    target = Path(args[args.index('--out') + 1])
    target.mkdir(parents=True)
    (target / 'failed-result').write_text('failed evidence')
    raise subprocess.CalledProcessError(1, args)
try:
    invoke(compile_fail)
except subprocess.CalledProcessError:
    pass
else:
    raise AssertionError('failed compiler was accepted')
assert (output / 'libswiftExample.dylib').read_text() == 'new-result'
assert any(p.read_text() == 'failed evidence' for p in root.rglob('failed-result'))
print('PASS prior successful outputs and failed compiler evidence preserved:', root)
