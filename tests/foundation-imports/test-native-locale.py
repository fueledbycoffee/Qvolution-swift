#!/usr/bin/env python3
"""Native projection: real Swift component types/initializer, owned CF normalizer.

Only CF string storage and NSLocale storage/dispatch are replaced. ICU parses the
canonical result as in CFLocaleCreateComponentsFromLocaleIdentifier. This does
not execute a Darwin runtime. Run builds inside qv-slot build.
"""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--out', type=Path, required=True)
p.add_argument('--corefoundation', type=Path, required=True)
p.add_argument('--foundation-source', type=Path, required=True)
p.add_argument('--toolchain', type=Path, required=True)
p.add_argument('--revision')
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=False)
repo = Path(__file__).resolve().parents[2]

def body(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

cf = (a.corefoundation/'CFLocaleIdentifier.c').read_text()
cf = cf[cf.index('// Max byte length'):cf.index('// CFLocaleCreateCanonicalLocaleIdentifierFromScriptManagerCodes')]
# The unused ScriptManager conversion table needs legacy platform typedefs.
start = cf.rindex('#if', 0, cf.index('struct LocaleToLegacyCodes'))
end = cf.index('#endif', start) + len('#endif')
cf = cf[:start] + cf[end:]
preamble = r'''
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <unicode/uloc.h>
#include <unicode/uenum.h>
#define DEPLOYMENT_TARGET_LINUX 1
typedef bool Boolean;
typedef void *CFAllocatorRef;
typedef const char *CFStringRef;
#define kCFStringEncodingASCII 0
static bool CFStringGetCString(const char *s, char *out, size_t cap, int encoding) {
    if (strlen(s) >= cap) return false;
    strcpy(out, s); return true;
}
static const char *CFStringCreateWithCString(void *allocator, const char *s, int encoding) { return strdup(s); }
'''
suffix = r'''
const char *native_canonical(const char *s) {
    return CFLocaleCreateCanonicalLocaleIdentifierFromString(NULL, s);
}
const char *native_component(const char *s, const char *key) {
    char buffer[ULOC_FULLNAME_CAPACITY];
    UErrorCode status = U_ZERO_ERROR;
    int32_t length = !strcmp(key, "language") ? uloc_getLanguage(s, buffer, sizeof(buffer), &status)
                   : !strcmp(key, "script") ? uloc_getScript(s, buffer, sizeof(buffer), &status)
                   : uloc_getCountry(s, buffer, sizeof(buffer), &status);
    return U_SUCCESS(status) && length > 0 ? strdup(buffer) : NULL;
}
'''
(a.out/'locale.c').write_text(preamble+cf+suffix)
subprocess.run(['/usr/bin/clang','-g','-O0','-c',str(a.out/'locale.c'),'-o',str(a.out/'locale.o')],check=True)
components = (repo/'overlays/Foundation/Locale+Components.swift').read_text()
language = (a.foundation_source/'Sources/FoundationEssentials/Locale/Locale+Language.swift').read_text()
darling = (subprocess.check_output(['git','-C',str(repo),'show',a.revision+':overlays/Foundation/Locale+Darling.swift'],text=True)
           if a.revision else (repo/'overlays/Foundation/Locale+Darling.swift').read_text())
locale = (repo/'overlays/Foundation/Locale.swift').read_text()
swift = r'''
import Foundation
import Glibc
@_silgen_name("native_canonical") func canonical(_ id: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>
@_silgen_name("native_component") func component(_ id: UnsafePointer<CChar>, _ key: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
let NSLocaleLanguageCode = "language", NSLocaleScriptCode = "script", NSLocaleCountryCode = "region"
public struct Locale {
    public let identifier: String
    public init(identifier: String) {
        let value = canonical(identifier)
        self.identifier = String(cString: value)
        free(value)
    }
    private func _string(forKey key: String) -> String? {
        guard let value = component(identifier, key) else { return nil }
        defer { free(value) }
        return String(cString: value)
    }
'''
for name in ('languageCode','scriptCode','regionCode'):
    swift += body(locale, 'public var '+name+':')+'\n'
swift += body(darling, 'public init(languageCode:')+'\n}\nextension Locale {\n'
for name in ('LanguageCode','Script','Region'):
    swift += body(components, 'public struct '+name+' :')+'\n'
swift += body(language, 'public struct Language :')+'\n}\n'
for name in ('ICULegacyKey','ICUCLDRKey'):
    swift += body(components, 'package struct '+name+' :')+'\n'
swift += (repo/'tests/foundation-imports/locale-components.swift').read_text()
(a.out/'main.swift').write_text(swift)
subprocess.run([str(a.toolchain/'bin/swiftc'),'-g','-Onone','-package-name','swift-foundation',
               '-module-cache-path',str(a.out/'module-cache'),
               str(a.out/'main.swift'),str(a.out/'locale.o'),'-licuuc','-o',str(a.out/'locale-components')],check=True)
