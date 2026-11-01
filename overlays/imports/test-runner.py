#!/usr/bin/env python3
"""Run the production shell harness with a retrying fake container, never Darling."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

runner, dashboard, evidence = map(lambda p: Path(p).resolve(), sys.argv[1:])
root = Path(tempfile.mkdtemp(prefix='runner-', dir=evidence))


def script(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body)
    path.chmod(0o755)


for mode, expected in [('success', 0), ('behavior-fails', 41), ('home-changed', 3),
                       ('shutdown-fails', 1), ('init-retry', 0)]:
    workspace = root / mode
    lane = workspace / 'parallel/imp-swift-overlays'
    build = lane / 'build'
    (lane / 'evidence').mkdir(parents=True)
    # Keep the production prefix under the mandated 83-character socket limit.
    (workspace / 'p').symlink_to('/tmp', target_is_directory=True)
    modules = ['UniformTypeIdentifiers', 'AVFoundation', 'CoreFoundation', 'os', 'Network']
    for module in modules:
        name = 'libswift' + module + '.dylib'
        image = build / module / name
        image.parent.mkdir(parents=True)
        image.write_text('mock own image')
        target = lane / 'stage/usr/local/libexec/darling/usr/lib/swift' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(image, target)
        exports = lane / 'superproject/src/external/swift/overlays' / module / 'imports.exports'
        exports.parent.mkdir(parents=True)
        exports.write_text('mock_symbol\n')
    for name in ['load-exports', 'OverlayBehavior']:
        script(build / name, 'exit 0\n')
    (build / 'behavior.path').write_text(str(build / 'OverlayBehavior') + '\n')
    script(workspace / 'bin/git', 'exit 0\n')
    script(workspace / 'bin/sleep', 'exit 0\n')
    script(workspace / 'dashboard/qv-slot', 'export QV_SLOT=guest-mock\nshift\nexec "$@"\n')
    shutil.copyfile(dashboard / 'qv-shutdown', workspace / 'dashboard/qv-shutdown')
    (workspace / 'dashboard/qv-shutdown').chmod(0o755)
    script(workspace / 'dashboard/qv-host-guard', '''
echo "guard $1" >> "$QV_MOCK/events"
if [[ $1 == snapshot ]]; then touch "$2"; exit 0; fi
[[ -f $2 ]]
[[ $QV_MOCK_MODE != home-changed ]] || exit 3
''')
    script(workspace / 'parallel/stage41/build/src/startup/darling', '''
[[ $DARLING_NONROOT == 1 && -n $DARLING_INSTALL_PREFIX && ${#DPREFIX} -le 83 ]]
[[ -z ${DYLD_TEST_SENTINEL+x} ]]
echo "$*" >> "$QV_MOCK/events"
if [[ $1 == shutdown ]]; then
  [[ $QV_MOCK_MODE != shutdown-fails ]] || exit 1
  if [[ ! -e $QV_MOCK/retry ]]; then touch "$QV_MOCK/retry"; exit 1; fi
  exit 0
fi
[[ $1 == shell ]]
if [[ $2 == /usr/bin/true ]]; then
  if [[ $QV_MOCK_MODE == init-retry && ! -e $QV_MOCK/retried ]]; then
    touch "$QV_MOCK/retried"
    echo 'Timed out waiting for shellspawn in container'; exit 1
  fi
  [[ ! -e $DPREFIX ]]
  mkdir -p "$DPREFIX"
  exit 0
fi
[[ -x $DPREFIX/Applications/OverlayImports/load-exports ]]
if [[ $2 == */OverlayBehavior ]]; then
  if [[ $# == 2 ]]; then
    [[ $QV_MOCK_MODE != behavior-fails ]] || exit 41
    echo 'RESULT swift-overlay-behavior failures=0'
  else
    echo "BEGIN $3"; exit 132
  fi
fi
''')
    env = dict(os.environ, QV_WORKSPACE=str(workspace), QV_OVERLAY_BUILD=str(build),
               QV_MOCK=str(workspace), QV_MOCK_MODE=mode, DYLD_TEST_SENTINEL='clear-me',
               PATH=str(workspace / 'bin') + ':' + os.environ['PATH'])
    # A short alias keeps the mock workspace's generated DPREFIX within 83 chars.
    alias = Path(tempfile.mkdtemp(prefix='qvr-', dir='/tmp')) / 'w'
    alias.symlink_to(workspace, target_is_directory=True)
    env['QV_WORKSPACE'] = str(alias)
    result = subprocess.run(['bash', str(runner)], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (workspace / 'runner.log').write_text(result.stdout)
    events = (workspace / 'events').read_text().splitlines()
    assert events[0] == 'guard snapshot', events
    assert events[-1] == 'guard verify' and events[-2] == 'shutdown', events
    assert result.returncode == expected, (mode, result.returncode, expected, result.stdout)
    if expected == 0:
        assert 'PASS real five-image load' in result.stdout
        assert events.count('shutdown') >= 4, events
    else:
        assert 'PASS real five-image load' not in result.stdout
    print('PASS', mode, 'exit', expected)
print('Retained mock evidence:', root)
