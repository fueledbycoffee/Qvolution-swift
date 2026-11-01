#!/usr/bin/env python3
"""Execute the production load bodies with a status-query tripwire on Linux."""
from pathlib import Path
import subprocess
import sys

source, output, compiler = map(Path, sys.argv[1:])
text = source.read_text()
body = text[text.rindex('extension AVAsynchronousKeyValueLoading {'):]
output.mkdir(parents=True, exist_ok=False)
harness = output / 'async-load.swift'
harness.write_text('''import Foundation
protocol AVAsynchronousKeyValueLoading {}
final class AVAsyncProperty<Root, Value> {}
enum Status<T> { case loaded(T), failed(Error), notYetLoaded, loading }
var queries = 0
extension AVAsynchronousKeyValueLoading {
  func status<T>(of property: AVAsyncProperty<Self, T>) -> Status<T> {
    queries += 1
    return .notYetLoaded
  }
}
final class Asset: AVAsynchronousKeyValueLoading {}
final class Track: AVAsynchronousKeyValueLoading {}
''' + body + '''
func check<R: AVAsynchronousKeyValueLoading>(_ root: R) async {
  let first = AVAsyncProperty<R, Int>()
  let second = AVAsyncProperty<R, Bool>()
  let third = AVAsyncProperty<R, String>()
  for count in 1...3 {
    do {
      if count == 1 { _ = try await root.load(first) }
      if count == 2 { _ = try await root.load(first, second) }
      if count == 3 { _ = try await root.load(first, second, third) }
      fatalError("unsupported load returned successfully")
    } catch {
      let error = error as NSError
      precondition(error.domain == NSCocoaErrorDomain)
      precondition(error.code == NSFeatureUnsupportedError)
    }
  }
}
@main struct Test {
  static func main() async {
    await check(Asset())
    await check(Track())
    precondition(queries == 0, "load reached the untyped backend status query")
    print("PASS single, pair and pack loads fail without status or KVC")
  }
}
''')
subprocess.run([str(compiler), '-module-cache-path', str(output / 'module-cache'), '-parse-as-library', str(harness), '-o', str(output / 'async-load')], check=True)
subprocess.run([str(output / 'async-load')], check=True)
