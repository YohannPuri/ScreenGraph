import Foundation

/// Photos authorization, as reported to the app.
public enum AuthStatus: String, Codable, Equatable, Sendable {
    case notDetermined, restricted, denied, authorized, limited, unknown

    /// Whether `list` and `export` can read the library.
    public var canRead: Bool { self == .authorized || self == .limited }
}

/// Printed by `auth` and `status`.
public struct AuthEvent: Codable, Equatable, Sendable {
    public let type: String
    public let status: AuthStatus

    public init(status: AuthStatus) {
        self.type = "auth"
        self.status = status
    }
}

/// One screenshot in the Photos library. Printed once per line by `list`.
public struct ScreenshotRecord: Codable, Equatable, Sendable {
    public let type: String
    /// PhotoKit `localIdentifier`, stable for this library on this Mac.
    public let id: String
    public let createdAt: Date?
    public let width: Int
    public let height: Int
    public let latitude: Double?
    public let longitude: Double?
    public let isFavorite: Bool

    public init(
        id: String,
        createdAt: Date?,
        width: Int,
        height: Int,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isFavorite: Bool = false
    ) {
        self.type = "screenshot"
        self.id = id
        self.createdAt = createdAt
        self.width = width
        self.height = height
        self.latitude = latitude
        self.longitude = longitude
        self.isFavorite = isFavorite
    }
}

/// Printed by `list` after the last screenshot. Its absence means the listing
/// was cut short and must not be treated as the complete library.
public struct EndEvent: Codable, Equatable, Sendable {
    public let type: String
    public let count: Int

    public init(count: Int) {
        self.type = "end"
        self.count = count
    }
}

/// Printed to stderr when a command can't do its job.
public struct ErrorEvent: Codable, Equatable, Sendable {
    public let type: String
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.type = "error"
        self.code = code
        self.message = message
    }
}

/// A failure the bridge reports as an `ErrorEvent` with a specific exit code.
public struct BridgeError: Error, Equatable, Sendable {
    public let code: String
    public let message: String
    public let exitCode: Int32

    public init(code: String, message: String, exitCode: Int32) {
        self.code = code
        self.message = message
        self.exitCode = exitCode
    }

    public static func notAuthorized(_ status: AuthStatus) -> BridgeError {
        BridgeError(
            code: "not_authorized",
            message: "Photos access is '\(status.rawValue)'. Run 'photos-bridge auth' first.",
            exitCode: 3
        )
    }

    public static let screenshotsAlbumUnavailable = BridgeError(
        code: "screenshots_album_unavailable",
        message: "The Photos Screenshots album could not be fetched.",
        exitCode: 4
    )

    public var event: ErrorEvent { ErrorEvent(code: code, message: message) }
}
