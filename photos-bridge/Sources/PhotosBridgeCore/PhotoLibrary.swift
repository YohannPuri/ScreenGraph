import Foundation
import Photos

/// Thin wrapper over PhotoKit. Everything that touches the real library lives here.
public enum PhotoLibrary {
    /// macOS has no read-only level; `.readWrite` is what allows reading.
    static let accessLevel = PHAccessLevel.readWrite

    /// Current status, without prompting.
    public static func currentStatus() -> AuthStatus {
        AuthStatus(PHPhotoLibrary.authorizationStatus(for: accessLevel))
    }

    /// Shows the system prompt if the user hasn't decided yet.
    public static func requestAccess() async -> AuthStatus {
        AuthStatus(await PHPhotoLibrary.requestAuthorization(for: accessLevel))
    }

    /// Calls `body` for each screenshot in the Screenshots smart album, newest
    /// first, and returns how many there were.
    @discardableResult
    public static func forEachScreenshot(
        since: Date?,
        _ body: (ScreenshotRecord) throws -> Void
    ) throws -> Int {
        let albums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )
        guard let screenshots = albums.firstObject else {
            throw BridgeError.screenshotsAlbumUnavailable
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let since {
            options.predicate = NSPredicate(format: "creationDate > %@", since as NSDate)
        }

        let assets = PHAsset.fetchAssets(in: screenshots, options: options)
        for index in 0..<assets.count {
            try body(ScreenshotRecord(assets.object(at: index)))
        }
        return assets.count
    }
}

extension AuthStatus {
    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .limited: self = .limited
        @unknown default: self = .unknown
        }
    }
}

extension ScreenshotRecord {
    init(_ asset: PHAsset) {
        self.init(
            id: asset.localIdentifier,
            createdAt: asset.creationDate,
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            isFavorite: asset.isFavorite
        )
    }
}
