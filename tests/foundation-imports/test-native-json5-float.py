#!/usr/bin/env python3
"""Run the production Float unboxing body with Linux NSNumber API spelling."""
from pathlib import Path
import subprocess,argparse
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--revision');p.add_argument('--build-only',action='store_true');a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=False);repo=Path(__file__).resolve().parents[2]
name='overlays/Foundation/JSONEncoder.swift'
s=subprocess.check_output(['git','-C',str(repo),'show',a.revision+':'+name],text=True) if a.revision else (repo/name).read_text()
s=s[s.index('    func unbox(_ value: Any, as type: Float.Type)'):s.index('    func unbox(_ value: Any, as type: Double.Type)')]
s=s.replace('number.doubleValue()', 'number.doubleValue')
preamble=r"""
import Foundation
import CoreFoundation
final class _JSONUnsignedNumber: NSObject { let value: UInt64 = 0 }
enum _JSONSerialization {
    static let trueNumber = unsafeBitCast(kCFBooleanTrue, to: NSNumber.self)
    static let falseNumber = unsafeBitCast(kCFBooleanFalse, to: NSNumber.self)
}
extension DecodingError {
    static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: Any) -> DecodingError {
        .typeMismatch(expectation, .init(codingPath: path, debugDescription: "type mismatch"))
    }
}
struct Harness {
    let options = JSONDecoder()
    let codingPath: [CodingKey] = []
"""
suffix=r"""
}
let h = Harness()
precondition(try h.unbox(NSNumber(value: Double.nan), as: Float.self)!.isNaN)
precondition(try h.unbox(NSNumber(value: Double.infinity), as: Float.self)! == .infinity)
precondition(try h.unbox(NSNumber(value: -Double.infinity), as: Float.self)! == -.infinity)
precondition(try h.unbox(NSNumber(value: 1.5), as: Float.self)! == 1.5)
do { _ = try h.unbox(NSNumber(value: Double.greatestFiniteMagnitude), as: Float.self); preconditionFailure("overflow accepted") } catch {}
print("PASS production Float unboxing: JSON5 NaN, infinities, finite values and overflow")
"""
# Throwing autoclosures are not accepted by precondition.
suffix=suffix.replace('precondition(try h.unbox', 'precondition(try! h.unbox')
(a.out/'main.swift').write_text(preamble+s+suffix)
compiler='/home/sean/Documents/Codex/Projects/Qvolution-work/toolchains/swift-6.3.3-linux-x64/compiler/usr/bin/swiftc'
subprocess.run([compiler,'-module-cache-path',str(a.out/'cache'),str(a.out/'main.swift'),'-o',str(a.out/'json5-float')],check=True)
if not a.build_only:subprocess.run([str(a.out/'json5-float')],check=True)
