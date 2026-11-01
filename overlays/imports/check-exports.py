#!/usr/bin/env python3
"""Check only source-built images; require negative controls in the same run."""
import json, subprocess, sys
from pathlib import Path
build = Path(sys.argv[1])
recipes = sorted(Path(__file__).resolve().parent.parent.glob('*/imports.json'))
rows = []
def exports(path):
    return {line.split()[-1] for line in subprocess.check_output(
        ['llvm-nm', '--defined-only', '--extern-only', str(path)], text=True).splitlines() if line.split()}
for recipe in recipes:
    module = recipe.parent.name
    expected = set((recipe.parent / 'imports.exports').read_text().splitlines())
    if not expected:
        raise SystemExit('Empty demand set: ' + module)
    image = build / module / ('libswift' + module + '.dylib')
    actual = exports(image)
    missing = sorted(expected - actual)
    # Wrong-image and absent-symbol controls must fail the exact acceptance predicate.
    control = build / 'export-negative-control.so'
    wrong = exports(control)
    assert not (expected & wrong), 'Wrong-image control contains demanded exports'
    accepts = lambda demanded, offered: bool(demanded) and demanded <= offered
    assert not accepts(expected, wrong)
    assert not accepts(expected | {'_qv_intentionally_missing_export'}, actual)
    row = dict(module=module, required=len(expected), satisfied=len(expected & actual),
               missing=missing, negative_controls='pass', image=str(image))
    rows.append(row)
print(json.dumps(rows, indent=2))
raise SystemExit(1 if any(row['missing'] for row in rows) else 0)
