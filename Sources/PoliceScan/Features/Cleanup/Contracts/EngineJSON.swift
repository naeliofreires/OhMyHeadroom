import Foundation

/// JSON codecs for the Python wire contract. Example: EngineJSON.decoder().decode(ScanReport.self, from: data).
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
