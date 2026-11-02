// Written for Darling. GUESS: component defaults pending API-boundary validation.
@_exported import Foundation

extension URL {
    public struct FormatStyle: Foundation.FormatStyle, Sendable {
        public struct ComponentDisplayOption: Codable, Hashable, Sendable {
            fileprivate var display: Bool
            public static var never: Self { Self(display: false) }
            public static var always: Self { Self(display: true) }
        }

        private var schemeOption: ComponentDisplayOption = .always
        public init() {}

        public func scheme(_ option: ComponentDisplayOption) -> Self {
            var copy = self
            copy.schemeOption = option
            return copy
        }

        public func format(_ value: URL) -> String {
            guard var parts = URLComponents(url: value, resolvingAgainstBaseURL: true) else {
                return value.absoluteString
            }
            parts.user = nil
            parts.password = nil
            if !schemeOption.display { parts.scheme = nil }
            let result = parts.string ?? value.absoluteString
            if !schemeOption.display && result.hasPrefix("//") {
                return String(result.dropFirst(2))
            }
            return result
        }
    }

    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == URL {
        format.format(self)
    }
}

extension FormatStyle where Self == URL.FormatStyle {
    public static var url: URL.FormatStyle { .init() }
}
