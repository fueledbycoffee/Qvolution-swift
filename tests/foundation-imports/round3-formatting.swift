import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func progress(_ check: String) {
    print("CHECK round3-formatting: \(check)")
    fflush(nil)
}

progress("01 let style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .standard)")
let style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .standard)
progress("02 precondition([one, two, three].formatted(style.locale(Locale(identifier: en_US))) == one, ")
precondition(["one", "two", "three"].formatted(style.locale(Locale(identifier: "en_US"))) == "one, two, and three")
progress("03 precondition([String]().formatted(style) == )")
precondition([String]().formatted(style) == "")
progress("04 precondition([only].formatted(style) == only)")
precondition(["only"].formatted(style) == "only")
progress("05 let french: ListFormatStyle<StringStyle, [String]> = .list(type: .or, width: .short)")
let french: ListFormatStyle<StringStyle, [String]> = .list(type: .or, width: .short)
progress("06 precondition([un, deux].formatted(french.locale(Locale(identifier: fr_FR))).contains(ou))")
precondition(["un", "deux"].formatted(french.locale(Locale(identifier: "fr_FR"))).contains("ou"))
progress("07 let base = URL(fileURLWithPath: /Applications/, isDirectory: true)")
let base = URL(fileURLWithPath: "/Applications/", isDirectory: true)
progress("08 let directory = URL(filePath: fixture dir/, directoryHint: .inferFromPath, relativeTo: bas")
let directory = URL(filePath: "fixture dir/", directoryHint: .inferFromPath, relativeTo: base)
progress("09 precondition(directory.hasDirectoryPath)")
precondition(directory.hasDirectoryPath)
progress("10 precondition(directory.path == /Applications/fixture dir)")
precondition(directory.path == "/Applications/fixture dir")
progress("11 let file = URL(filePath: fixture #.txt, directoryHint: .notDirectory, relativeTo: base)")
let file = URL(filePath: "fixture #.txt", directoryHint: .notDirectory, relativeTo: base)
progress("12 precondition(!file.hasDirectoryPath && file.path == /Applications/fixture #.txt)")
precondition(!file.hasDirectoryPath && file.path == "/Applications/fixture #.txt")
progress("13 precondition(URL.applicationDirectory.hasDirectoryPath)")
precondition(URL.applicationDirectory.hasDirectoryPath)
progress("14 precondition(URL.applicationSupportDirectory.hasDirectoryPath)")
precondition(URL.applicationSupportDirectory.hasDirectoryPath)
progress("15 let locale = Locale(languageCode: Locale.LanguageCode(zh), script: Locale.Script(Hant), la")
let locale = Locale(languageCode: Locale.LanguageCode("zh"), script: Locale.Script("Hant"), languageRegion: Locale.Region("TW"))
progress("16 precondition(locale.languageCode == zh && locale.scriptCode == Hant && locale.regionCode =")
precondition(locale.languageCode == "zh" && locale.scriptCode == "Hant" && locale.regionCode == "TW")
progress("17 print(round3-formatting: passed)")
print("round3-formatting: passed")
