import Foundation
import Testing

/// Runs the built `photos-bridge` binary. Only commands that don't need Photos
/// access are exercised here.
@Suite("CLI process")
struct CLITests {
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    static let binary = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: ".build/debug/photos-bridge")

    func run(_ arguments: [String]) throws -> Result {
        let process = Process()
        process.executableURL = Self.binary
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        return Result(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    func errorEvent(_ stderr: String) throws -> [String: String] {
        let lines = stderr.split(separator: "\n")
        try #require(lines.count == 1)
        return try JSONDecoder().decode([String: String].self, from: Data(lines[0].utf8))
    }

    @Test func invalidSinceIsAJSONUsageError() throws {
        let result = try run(["list", "--since", "yesterday"])

        #expect(result.exitCode == 64)
        #expect(result.stdout.isEmpty)
        let event = try errorEvent(result.stderr)
        #expect(event["type"] == "error")
        #expect(event["code"] == "usage")
        #expect(event["message"]?.contains("--since") == true)
    }

    @Test func unknownCommandIsAJSONUsageError() throws {
        let result = try run(["nope"])

        #expect(result.exitCode == 64)
        #expect(try errorEvent(result.stderr)["code"] == "usage")
    }

    @Test func helpGoesToStdoutAndSucceeds() throws {
        let result = try run(["--help"])

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("OVERVIEW"))
        #expect(result.stderr.isEmpty)
    }
}
