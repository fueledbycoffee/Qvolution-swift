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

progress("01 list.and.init")
let style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .standard)
progress("02 list.and.english")
precondition(["one", "two", "three"].formatted(style.locale(Locale(identifier: "en_US"))) == "one, two, and three")
progress("03 list.empty")
precondition([String]().formatted(style) == "")
progress("04 list.singleton")
precondition(["only"].formatted(style) == "only")
progress("05 list.or.init")
let french: ListFormatStyle<StringStyle, [String]> = .list(type: .or, width: .short)
progress("06 list.or.french")
precondition(["un", "deux"].formatted(french.locale(Locale(identifier: "fr_FR"))).contains("ou"))
progress("07 url.base.init")
let base = URL(fileURLWithPath: "/Applications/", isDirectory: true)
progress("08 url.directory.init")
let directory = URL(filePath: "fixture dir/", directoryHint: .inferFromPath, relativeTo: base)
progress("09 url.directory.hint")
precondition(directory.hasDirectoryPath)
progress("10 url.directory.path")
precondition(directory.path == "/Applications/fixture dir")
progress("11 url.file.init")
let file = URL(filePath: "fixture #.txt", directoryHint: .notDirectory, relativeTo: base)
progress("12 url.file.path")
precondition(!file.hasDirectoryPath && file.path == "/Applications/fixture #.txt")
progress("13 url.applicationDirectory")
precondition(URL.applicationDirectory.hasDirectoryPath)
progress("14 url.applicationSupportDirectory")
precondition(URL.applicationSupportDirectory.hasDirectoryPath)
progress("15 locale.components.init")
let locale = Locale(languageCode: Locale.LanguageCode("zh"), script: Locale.Script("Hant"), languageRegion: Locale.Region("TW"))
progress("16 locale.components.result")
precondition(locale.languageCode == "zh" && locale.scriptCode == "Hant" && locale.regionCode == "TW")
progress("17 passed")
print("round3-formatting: passed")
