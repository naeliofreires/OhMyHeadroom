import Foundation

/// Text the engine sends in both languages. The app shows the one that matches its locale,
/// with the same rule as the engine: Portuguese if the language is Portuguese, English otherwise.
struct LocalizedText: Codable, Hashable {
    let pt: String
    let en: String

    var text: String {
        LocalizedText.isPortuguese ? pt : en
    }

    /// The code the engine's --lang flag expects: "pt" or "en".
    static var languageCode: String {
        isPortuguese ? "pt" : "en"
    }

    private static var isPortuguese: Bool {
        Locale.current.language.languageCode?.identifier == "pt"
    }
}

/// One safe-to-clean category from the scan. Mirrors scan.Category in the Python engine.
struct Category: Codable, Identifiable, Hashable {
    let key: String
    let label: LocalizedText
    let note: LocalizedText
    let sizeBytes: Int
    let paths: [SizedPath]
    let commands: [[String]]

    var id: String { key }

    /// Deps are big and need a reinstall afterwards, so they stay unchecked by default.
    var isOffByDefault: Bool { key.hasPrefix("deps-") }
}

/// A path the engine would remove, with the bytes it occupies.
struct SizedPath: Codable, Hashable {
    let path: String
    let sizeBytes: Int
}

/// A folder the user decides about. Never deleted by the app.
struct ReviewLine: Codable, Identifiable, Hashable {
    let label: LocalizedText
    let note: LocalizedText
    let sizeBytes: Int?
    let folder: String?

    var id: String { label.en }
}

/// The full answer of `limpar.py scan --json`.
struct ScanReport: Codable {
    let safe: [Category]
    let review: [ReviewLine]
    let freeBytes: Int
}

/// The folder the engine is measuring right now, e.g. "Docker images" at 4 of 17.
struct ScanStep: Equatable, Sendable {
    let position: Int
    let total: Int
    let label: LocalizedText
    let path: String
}

/// One line the engine writes to stderr during a scan. Only "step" lines reach the UI;
/// "start" carries the total and is not needed for the animation.
struct ProgressLine: Decodable {
    let event: String
    let position: Int?
    let total: Int?
    let label: LocalizedText?
    let path: String?

    var step: ScanStep? {
        guard event == "step", let position, let total, let label, let path else { return nil }
        return ScanStep(position: position, total: total, label: label, path: path)
    }
}

/// The engine speaks snake_case JSON; these coders translate to and from Swift names.
enum EngineJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
