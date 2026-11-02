#!/usr/bin/env python3
"""Require observable checkpoints and prove their helper flushes before a trap."""
import argparse
from pathlib import Path
import resource
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--swiftc', required=True)
parser.add_argument('--scratch', type=Path, required=True)
args = parser.parse_args()
here = Path(__file__).resolve().parent
for name in ('round3-behavior', 'round3-formatting'):
    source = (here / (name + '.swift')).read_text()
    lines = source.splitlines()
    checks = [i for i, line in enumerate(lines) if line.startswith('precondition(')]
    assert checks, name
    for i in checks:
        assert lines[i - 1].startswith('progress("'), f'{name}:{i + 1}: missing pre-check checkpoint'
    start = source.index('func progress(')
    end = source.index('\n}', start) + 2
    helper = source[start:end]
    assert 'fflush(nil)' in helper, name
    args.scratch.mkdir(parents=True, exist_ok=True)
    probe = args.scratch / (name + '-flush.swift')
    probe.write_text('import Glibc\n' + helper + '\nprogress("forced-trap")\nprecondition(false)\n')
    binary = probe.with_suffix('')
    subprocess.run([args.swiftc, '-O', '-module-cache-path', str(args.scratch / 'module-cache'), str(probe), '-o', str(binary)], check=True)
    result = subprocess.run([str(binary)], capture_output=True,
                            preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
    assert result.returncode < 0, result.returncode
    assert result.stdout.decode().splitlines() == [f'CHECK {name}: forced-trap'], result.stdout
    print(f'PASS {name}: {len(checks)} checkpoints, stdout survives forced trap')
