import Foundation

/// Encodes events as single-line JSON, the bridge's output format.
public enum JSONLines {
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Stable key order makes output diffable and testable.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

/// Parses `--since` values: a full ISO 8601 date-time, or a date (midnight UTC).
public enum SinceDate {
    public static func parse(_ text: String) -> Date? {
        let dateTime = ISO8601DateFormatter()
        if let date = dateTime.date(from: text) {
            return date
        }
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        return dateOnly.date(from: text)
    }
}
