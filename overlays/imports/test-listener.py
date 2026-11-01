#!/usr/bin/env python3
"""Execute the production listener on Linux with the current nil C backend."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile

network, upstream, evidence = map(lambda p: Path(p).resolve(), sys.argv[1:4])
compiler = Path(sys.argv[4]).absolute()  # preserve swiftc's driver-selecting argv[0]
assert os.environ.get('QV_SLOT', '').startswith('build-')
output = Path(tempfile.mkdtemp(prefix='listener-', dir=evidence))
recipe = json.loads((network / 'imports.json').read_text())
source = output / 'NWListener.swift'
if 'NWListener.swift' in recipe['sources']:
    source.write_text((network / 'NWListener.swift').read_text())
else:
    source.write_text((upstream / recipe['upstream']['directory'] / 'NWListener.swift').read_text())
    subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i',
                    str(network / 'patches/NWListener.patch')], cwd=output, check=True)
# Linux has no ObjC interop or Darwin module. All listener bodies are unchanged.
text = source.read_text().replace('import Darwin', 'import Glibc')
text = '\n'.join(line for line in text.splitlines() if not line.startswith('@_objcRuntimeName'))
source.write_text(text)
harness = output / 'Test.swift'
harness.write_text('''import Foundation
import Dispatch
import Glibc
extension POSIXErrorCode { static var ENOTSUP: POSIXErrorCode { .EOPNOTSUPP } }
public enum NWError: Error, Equatable { case posix(POSIXErrorCode) }
final class Handle {}
typealias nw_listener_t = Handle
typealias nw_advertise_descriptor_t = Handle
typealias nw_listener_state_t = Int
typealias nw_error_t = Handle
let nw_listener_state_invalid = 0
let nw_listener_state_waiting = 1
let nw_listener_state_ready = 2
let nw_listener_state_failed = 3
let nw_listener_state_cancelled = 4
extension NWError { init?(_ error: Handle?) { return nil } }
public final class NWParameters {
  let nw = Handle()
  static var tcp: NWParameters { NWParameters() }
}
public struct NWEndpoint {
  init?(_ handle: Handle) { return nil }
  public struct Port: Equatable {
    let rawValue: UInt16
    init(_ value: UInt16) { rawValue = value }
    public static let any = Port(0)
  }
}
public final class NWConnection {
  let nw = Handle()
  init?(using: NWParameters, inbound: Handle) { return nil }
}
func nw_advertise_descriptor_create_bonjour_service(_ n: String?, _ t: String, _ d: String?) -> Handle? { nil }
func nw_advertise_descriptor_set_txt_record(_ h: Handle, _ p: UnsafePointer<UInt8>, _ n: Int) {}
func nw_listener_create(_ p: Handle) -> Handle? { nil }
func nw_listener_create_with_port(_ p: String, _ h: Handle) -> Handle? { nil }
func nw_listener_create_with_connection(_ c: Handle, _ p: Handle) -> Handle? { nil }
func nw_listener_set_state_changed_handler(_ h: Handle, _ f: ((Int, Handle?) -> Void)?) {}
func nw_listener_set_new_connection_handler(_ h: Handle, _ f: ((Handle) -> Void)?) {}
func nw_listener_set_advertise_descriptor(_ h: Handle, _ d: Handle?) {}
func nw_listener_set_advertised_endpoint_changed_handler(_ h: Handle, _ f: ((Handle, Bool) -> Void)?) {}
func nw_listener_get_port(_ h: Handle) -> UInt16 { 0 }
func nw_listener_set_queue(_ h: Handle, _ q: DispatchQueue) {}
func nw_listener_start(_ h: Handle) {}
func nw_listener_cancel(_ h: Handle) {}

@main struct Test {
  static func main() {
    do {
      // Match the real behavior client: the nil C constructor must not abort setup.
      let listener = try NWListener(using: .tcp)
      precondition(listener.state == .setup && listener.queue == nil && listener.port == nil)
      let done = DispatchSemaphore(value: 0)
      let queue = DispatchQueue(label: "listener-test")
      let key = DispatchSpecificKey<Int>()
      queue.setSpecific(key: key, value: 42)
      var states = [NWListener.State]()
      listener.stateUpdateHandler = { state in
        precondition(listener.state == state)
        precondition(DispatchQueue.getSpecific(key: key) == 42)
        states.append(state)
        if state == .failed(.posix(.ENOTSUP)) { listener.cancel(); listener.cancel() }
        if state == .cancelled { done.signal() }
      }
      listener.start(queue: queue)
      listener.start(queue: DispatchQueue(label: "must-not-replace-queue"))
      precondition(done.wait(timeout: .now() + 5) == .success)
      queue.sync {}
      precondition(states == [.failed(.posix(.ENOTSUP)), .cancelled])
      precondition(listener.state == .cancelled && listener.queue === queue)
      precondition(listener.port == nil)
      let silent = try NWListener(using: .tcp, on: NWEndpoint.Port(12345))
      silent.start(queue: queue)
      silent.cancel()
      for _ in 0..<500 {
        if silent.state == .cancelled { break }
        usleep(10000)
      }
      precondition(silent.state == .cancelled, "state must update without a handler")
      let cancelled = try NWListener(using: .tcp)
      cancelled.cancel()
      cancelled.start(queue: queue)
      precondition(cancelled.state == .cancelled && cancelled.queue == nil)
      print("PASS listener setup, unsupported start, callback queue, state, cancellation")
    } catch {
      print("FAIL listener construction with stub backend:", error)
      exit(1)
    }
  }
}
''')
subprocess.run([str(compiler), '-module-name', 'Network', '-module-cache-path',
                str(output / 'module-cache'), '-parse-as-library', str(source), str(harness),
                '-o', str(output / 'listener-test')], check=True)
subprocess.run([str(output / 'listener-test')], check=True)
print('Retained native evidence:', output)
