#!/usr/bin/env python3
"""Execute the production parser natively; bridge only Linux collection API spelling."""
import argparse, subprocess
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--out',type=Path,required=True)
p.add_argument('--revision')
p.add_argument('--build-only',action='store_true')
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
repo=Path(__file__).resolve().parents[2]
name='overlays/Foundation/JSONSerialization+Swift.swift'
s=(subprocess.check_output(['git','-C',str(repo),'show',a.revision+':'+name],text=True) if a.revision else (repo/name).read_text())
s=s[:s.index('    // MARK: - Writing')]+s[s.index('    // MARK: - Parsing'):]
s=s.replace('@_exported import Foundation','import Foundation\nimport CoreFoundation').replace('NSMutableArray()!', 'NSMutableArray()')
s += r'''

let root = CommandLine.arguments[1]
let items = FileManager.default.enumerator(atPath: root)!
var checked = 0
for case let item as String in items {
    if !(item.hasSuffix(".json") || item.hasSuffix(".json5") || item.hasSuffix(".js") || item.hasSuffix(".txt")) { continue }
    let valid = item.hasSuffix(".json") || item.hasSuffix(".json5")
    let data = try Data(contentsOf: URL(fileURLWithPath: root + "/" + item))
    do {
        _ = try _JSONSerialization.object(with: data, allowsJSON5: true)
        precondition(valid, "accepted invalid " + item)
    } catch { precondition(!valid, "rejected valid " + item + ": " + String(describing: error)) }
    checked += 1
}
let enabled = try _JSONSerialization.object(with: Data("{/* hi */ answer: +0x10, list: ['x',],}".utf8), allowsJSON5: true) as! NSDictionary
precondition((enabled["answer"] as! NSNumber).intValue == 16)
for invalid in ["{key:1}", "[1,]", "'text'", "+1", "0x10", "/*c*/1"] {
    do { _ = try _JSONSerialization.object(with: Data(invalid.utf8)); preconditionFailure("strict mode accepted " + invalid) } catch {}
}
print("PASS production JSON5 parser corpus", checked, "plus strict-mode regressions")

let zero = try _JSONSerialization.object(with: Data("-0".utf8), allowsJSON5: true) as! NSNumber
precondition(zero.doubleValue.sign == .minus, "JSON5 lost negative zero")
for (input, expected) in [("+.5", 0.5), ("1.", 1.0), ("-0x10", -16.0), ("1e2", 100.0)] {
    let value = try _JSONSerialization.object(with: Data(input.utf8), allowsJSON5: true) as! NSNumber
    precondition(value.doubleValue == expected, input)
}
print("PASS JSON5 numeric values and negative zero")
'''
(a.out/'main.swift').write_text(s)
tool=Path('/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/bin/swiftc')
subprocess.run([str(tool),'-module-cache-path',str(a.out/'cache'),str(a.out/'main.swift'),'-o',str(a.out/'json5')],check=True)
corpus=Path('/home/sean/Documents/Codex/Projects/Qvolution-work/parallel/cryptokit-x64-bootstrap/foundation-source/Tests/FoundationEssentialsTests/Resources/JSON5/spec')
if not a.build_only: subprocess.run([str(a.out/'json5'),str(corpus)],check=True)
