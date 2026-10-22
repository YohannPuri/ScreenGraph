import Foundation
import Photos
import Testing

@testable import PhotosBridgeCore

@Suite("JSON lines output")
struct JSONLinesTests {
    @Test func screenshotRecordUsesSortedKeysAndISODates() throws {
        let record = ScreenshotRecord(
            id: "ABC/L0/001",
            createdAt: Date(timeIntervalSince1970: 1_760_000_000),
            width: 1179,
            height: 2556,
            isFavorite: true
        )

        let line = try JSONLines.encode(record)

        #expect(line == #"{"createdAt":"2025-10-09T08:53:20Z","height":2556,"id":"ABC/L0/001","isFavorite":true,"type":"screenshot","width":1179}"#)
    }

    @Test func missingCreationDateIsOmitted() throws {
        let record = ScreenshotRecord(id: "X", createdAt: nil, width: 10, height: 20)

        let line = try JSONLines.encode(record)

        #expect(!line.contains("createdAt"))
    }

    @Test func outputIsASingleLine() throws {
        let line = try JSONLines.encode(ErrorEvent(code: "x", message: "line one\nline two"))

        #expect(!line.contains("\n"))
    }

    @Test func endEventCarriesCount() throws {
        #expect(try JSONLines.encode(EndEvent(count: 3)) == #"{"count":3,"type":"end"}"#)
    }

    @Test func eventsRoundTrip() throws {
        let event = AuthEvent(status: .limited)
        let data = Data(try JSONLines.encode(event).utf8)

        #expect(try JSONDecoder().decode(AuthEvent.self, from: data) == event)
    }
}

@Suite("--since parsing")
struct SinceDateTests {
    @Test func parsesDateTime() {
        #expect(SinceDate.parse("2026-10-01T12:30:00Z") == Date(timeIntervalSince1970: 1_790_857_800))
    }

    @Test func parsesFractionalSeconds() {
        #expect(SinceDate.parse("2026-10-01T12:30:00.123Z") == Date(timeIntervalSince1970: 1_790_857_800.123))
    }

    @Test func parsesTimezoneOffsets() {
        #expect(SinceDate.parse("2026-10-01T14:30:00+02:00") == Date(timeIntervalSince1970: 1_790_857_800))
    }

    @Test func parsesDateOnlyAsMidnightUTC() {
        #expect(SinceDate.parse("2026-10-01") == Date(timeIntervalSince1970: 1_790_812_800))
    }

    @Test(arguments: ["", "yesterday", "10/01/2026", "2026-13-01", "2026-10-01garbage", "2026-10-01T12:30"])
    func rejectsInvalid(_ text: String) {
        #expect(SinceDate.parse(text) == nil)
    }
}

@Suite("Authorization mapping")
struct AuthStatusTests {
    @Test func mapsPhotoKitStatuses() {
        #expect(AuthStatus(PHAuthorizationStatus.authorized) == .authorized)
        #expect(AuthStatus(PHAuthorizationStatus.limited) == .limited)
        #expect(AuthStatus(PHAuthorizationStatus.denied) == .denied)
        #expect(AuthStatus(PHAuthorizationStatus.notDetermined) == .notDetermined)
    }

    @Test func onlyAuthorizedAndLimitedCanRead() {
        #expect(AuthStatus.authorized.canRead)
        #expect(AuthStatus.limited.canRead)
        #expect(!AuthStatus.denied.canRead)
        #expect(!AuthStatus.notDetermined.canRead)
    }
}
