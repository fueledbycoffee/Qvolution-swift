#!/usr/bin/env python3
"""Execute the production parser natively; bridge only Linux collection API spelling."""
import argparse, subprocess
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--out',type=Path,required=True)
p.add_argument('--revision')
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
repo=Path(__file__).resolve().parents[2]
name='overlays/Foundation/JSONSerialization+Swift.swift'
s=(subprocess.check_output(['git','-C',str(repo),'show',a.revision+':'+name],text=True) if a.revision else (repo/name).read_text())
s=s[:s.index('    // MARK: - Writing')]+s[s.index('    // MARK: - Parsing'):]
s=s.replace('@_exported import Foundation','import Foundation\nimport CoreFoundation').replace('NSMutableArray()!', 'NSMutableArray()')
s+='\nlet root = CommandLine.arguments[1]\nlet items = FileManager.default.enumerator(atPath: root)!\nvar checked = 0\nfor case let item as String in items {\n    if !(item.hasSuffix(".json") || item.hasSuffix(".json5") || item.hasSuffix(".js") || item.hasSuffix(".txt")) { continue }\n    let valid = item.hasSuffix(".json") || item.hasSuffix(".json5")\n    let data = try Data(contentsOf: URL(fileURLWithPath: root + "/" + item))\n    do {\n        _ = try _JSONSerialization.object(with: data, allowsJSON5: true)\n        precondition(valid, "accepted invalid " + item)\n    } catch { precondition(!valid, "rejected valid " + item + ": " + String(describing: error)) }\n    checked += 1\n}\nlet enabled = try _JSONSerialization.object(with: Data("{/* hi */ answer: +0x10, list: [\'x\',],}".utf8), allowsJSON5: true) as! NSDictionary\nprecondition((enabled["answer"] as! NSNumber).intValue == 16)\nfor invalid in ["{key:1}", "[1,]", "\'text\'", "+1", "0x10", "/*c*/1"] {\n    do { _ = try _JSONSerialization.object(with: Data(invalid.utf8)); preconditionFailure("strict mode accepted " + invalid) } catch {}\n}\nprint("PASS production JSON5 parser corpus", checked, "plus strict-mode regressions")\n'
(a.out/'main.swift').write_text(s)
tool=Path('/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/bin/swiftc')
subprocess.run([str(tool),'-module-cache-path',str(a.out/'cache'),str(a.out/'main.swift'),'-o',str(a.out/'json5')],check=True)
corpus=Path('/home/sean/Documents/Codex/Projects/Qvolution-work/parallel/cryptokit-x64-bootstrap/foundation-source/Tests/FoundationEssentialsTests/Resources/JSON5/spec')
subprocess.run([str(a.out/'json5'),str(corpus)],check=True)
