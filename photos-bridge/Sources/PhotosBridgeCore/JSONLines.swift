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

/// Parses `--since` values: an ISO 8601 date-time (with or without fractional
/// seconds), or a bare date, which means midnight UTC.
public enum SinceDate {
    public static func parse(_ text: String) -> Date? {
        if text.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil {
            return formatter([.withFullDate]).date(from: text)
        }
        return formatter([.withInternetDateTime, .withFractionalSeconds]).date(from: text)
            ?? formatter([.withInternetDateTime]).date(from: text)
    }

    private static func formatter(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter
    }
}
