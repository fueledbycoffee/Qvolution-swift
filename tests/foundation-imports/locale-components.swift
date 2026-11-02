import Foundation

func check(_ language: String?, _ script: String?, _ region: String?) {
    let locale = Locale(languageCode: language.map { Locale.LanguageCode($0) },
                        script: script.map { Locale.Script($0) },
                        languageRegion: region.map { Locale.Region($0) })
    print("components \(language ?? "nil") \(script ?? "nil") \(region ?? "nil") -> \(locale.identifier): \(locale.languageCode ?? "nil") \(locale.scriptCode ?? "nil") \(locale.regionCode ?? "nil")")
    precondition(locale.languageCode == language?.lowercased())
    precondition(locale.scriptCode == script?.capitalized)
    precondition(locale.regionCode == region?.uppercased())
}

check("zh", "Hant", "TW")
check("ZH", "hANT", "hk")
check("zh", "Hant", "CN")
check("sr", "Latn", "RS")
check("en", nil, "US")
check("es", nil, "419")
check("zh", "Hant", nil)
check(nil, "Hant", "TW")
print("locale-components: passed")
