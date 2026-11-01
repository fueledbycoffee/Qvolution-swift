#!/usr/bin/env -S python3 -I
"""Compile Swift sources into an x86_64 Darwin library-evolution module and Mach-O image.

  swiftc-darwin --module-name NAME --install-name PATH --out DIR [--framework]
                [--modulemap FILE]... [-I DIR]... [-F DIR]... [--link ARG]...
                [--swift-flag FLAG]... [--current-version V] [--compat-version V]
                SOURCE.swift...

Outputs, all under DIR:
  --framework  NAME.framework/Versions/A/NAME (+ Current, NAME, Modules symlinks),
               NAME.framework/Modules/NAME.swiftmodule/x86_64-apple-macos.{swiftmodule,swiftinterface}
  otherwise    libNAME.dylib and NAME.swiftmodule/x86_64-apple-macos.{swiftmodule,swiftinterface}
  obj/NAME.o   the whole-module object

Recipe (see src/catalyst/SwiftUI/README.md): the official Linux Swift 6.3.3 compiler, the
Darwin stdlib modules built from source for x86_64 (resource dir), the Darwin overlay modules
(Foundation, Combine, Dispatch, ObjectiveC, Darwin, CoreFoundation, os, XPC) built from source
for x86_64, Darling's source SDK for Clang modules, and Darling's ld64. Linked against the
runtime in DARLING_ROOT, whose overlay dylibs are the ones those modules were built with.

Every input can be overridden by environment variable; the defaults are this host's paths.
"""
import argparse, os, shlex, subprocess, sys
from pathlib import Path

W = Path('/home/sean/Documents/Codex/Projects/Qvolution-work')
C = W / 'catalyst'
BOOT = W / 'parallel/cryptokit-x64-bootstrap'


def env(name, default):
    return Path(os.environ.get(name, str(default)))


TOOLCHAIN = env('SWIFT_TOOLCHAIN', W / 'toolchains/swift-6.3.3-linux-x64/compiler/usr')
RESOURCE = env('SWIFT_RESOURCE_DIR', BOOT / 'cmake-normal-modules/lib/swift')
OVERLAYS = env('SWIFT_OVERLAY_MODULES', BOOT / 'overlay-runtime-attempt1/modules')
SOURCE_ROOT = env('DARLING_SOURCE_ROOT', W / 'parallel/stage41/superproject')
SDK = env('DARLING_SDK', SOURCE_ROOT / 'Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk')
ROOT = env('DARLING_ROOT', W / 'stage41b/usr/local/libexec/darling')
LD = env('DARLING_LD', W / 'parallel/stage41/build/src/external/cctools-port/cctools/ld64/src/x86_64-apple-darwin20-ld')

ARCH = 'x86_64'
TARGET = 'x86_64-apple-macosx26.0'
TRIPLE_FILE = 'x86_64-apple-macos'


def run(cmd, verbose):
    if verbose:
        print('+ ' + ' '.join(shlex.quote(str(c)) for c in cmd), file=sys.stderr)
    r = subprocess.run([str(c) for c in cmd])
    if r.returncode:
        sys.exit(f'swiftc-darwin: {Path(str(cmd[0])).name} exited {r.returncode}')


def symlink(target, link):
    link = Path(link)
    link.symlink_to(target)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--module-name', required=True)
    ap.add_argument('--install-name', required=True)
    ap.add_argument('--out', required=True, type=Path)
    ap.add_argument('--executable', action='store_true', help='link an authored @main behavior executable')
    ap.add_argument('--framework', action='store_true', help='emit NAME.framework instead of libNAME.dylib')
    ap.add_argument('--modulemap', action='append', default=[], help='extra Clang module map (repeatable)')
    ap.add_argument('-I', dest='incs', action='append', default=[], help='Swift module and Clang include dir')
    ap.add_argument('-F', dest='fws', action='append', default=[], help='framework search dir (compile and link)')
    ap.add_argument('--link', action='append', default=[], help='extra ld64 input or flag (repeatable)')
    ap.add_argument('--swift-flag', action='append', default=[], help='extra swift -frontend flag (repeatable)')
    ap.add_argument('--current-version', default='1.0.0')
    ap.add_argument('--compat-version', default='1.0.0')
    ap.add_argument('--onone', action='store_true', help='-Onone instead of -O')
    ap.add_argument('-v', '--verbose', action='store_true')
    ap.add_argument('sources', nargs='+', type=Path)
    a = ap.parse_args()

    for p in (TOOLCHAIN / 'bin/swiftc', RESOURCE / 'macosx/Swift.swiftmodule', OVERLAYS / 'Foundation.swiftmodule',
              SDK / 'usr/include', ROOT / 'usr/lib/swift/libswiftCore.dylib', LD):
        if not p.exists():
            sys.exit(f'swiftc-darwin: missing input {p}')

    name = a.module_name
    out = a.out.resolve()
    obj_dir = out / 'obj'
    # A fresh attempt keeps previous products and module caches as evidence.
    out.mkdir(parents=True, exist_ok=False)
    obj_dir.mkdir()
    if a.framework:
        fw = out / f'{name}.framework'
        ver = fw / 'Versions/A'
        mod_dir = ver / 'Modules' / f'{name}.swiftmodule'
        image = ver / name
    else:
        mod_dir = out / f'{name}.swiftmodule'
        image = out / (name if a.executable else f'lib{name}.dylib')
    mod_dir.mkdir(parents=True, exist_ok=True)
    obj = obj_dir / f'{name}.o'

    rsp = obj_dir / f'{name}.sources'
    rsp.write_text(''.join('"%s"\n' % str(s.resolve()).replace('\\', '\\\\').replace('"', '\\"') for s in a.sources))

    swift = [TOOLCHAIN / 'bin/swiftc', '-frontend', '-c', f'@{rsp}',
             '-target', TARGET, '-sdk', SDK, '-resource-dir', RESOURCE,
             '-module-cache-path', obj_dir / 'module-cache', '-swift-version', '5',
             '-module-name', name, '-module-link-name', name,
             '-enable-library-evolution', '-parse-as-library', '-Onone' if a.onone else '-O',
             '-I', OVERLAYS,
             '-Xcc', f'-fmodule-map-file={SOURCE_ROOT}/src/external/swift/overlays/shims/overlay-shims.modulemap',
             '-Xcc', f'-I{SOURCE_ROOT}/src/frameworks/CoreServices/include',
             '-emit-module-path', mod_dir / f'{TRIPLE_FILE}.swiftmodule',
             '-emit-module-interface-path', mod_dir / f'{TRIPLE_FILE}.swiftinterface',
             '-o', obj]
    for i in a.incs:
        swift += ['-I', Path(i).resolve(), '-Xcc', f'-I{Path(i).resolve()}']
    for f in a.fws:
        swift += ['-F', Path(f).resolve()]
    for m in a.modulemap:
        swift += ['-Xcc', f'-fmodule-map-file={Path(m).resolve()}']
    swift += a.swift_flag
    run(swift, a.verbose)

    ld = [LD, '-arch', ARCH, '-platform_version', 'macos', '26.0', '26.0',
          '-syslibroot', SDK, '-syslibroot', ROOT,
          '-L', ROOT / 'usr/lib/swift',
          '-F', ROOT / 'System/Library/Frameworks',
          '-F', ROOT / 'System/iOSSupport/System/Library/Frameworks']
    if a.executable:
        ld += [W / 'parallel/stage41/build/src/external/csu/CMakeFiles/crt1.10.6.dir/start.S.o']
    else:
        ld += ['-dylib', '-install_name', a.install_name, '-compatibility_version', a.compat_version, '-current_version', a.current_version]
    for f in a.fws:
        ld += ['-F', Path(f).resolve()]
    ld += [obj, ROOT / 'usr/lib/libSystem.B.dylib', ROOT / 'usr/lib/libobjc.A.dylib', '-lswiftCore']
    ld += a.link
    ld += ['-o', image]
    run(ld, a.verbose)

    if a.framework:
        symlink('A', fw / 'Versions/Current')
        symlink(f'Versions/Current/{name}', fw / name)
        symlink('Versions/Current/Modules', fw / 'Modules')
    print(image)


if __name__ == '__main__':
    main()
