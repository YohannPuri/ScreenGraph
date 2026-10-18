import ArgumentParser
import Foundation
import PhotosBridgeCore

@main
struct PhotosBridge: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "photos-bridge",
        abstract: "Reads screenshots from the Apple Photos library and prints JSON lines.",
        subcommands: [Auth.self, Status.self, List.self]
    )
}

struct Auth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Ask for Photos access if needed, then print the status."
    )

    func run() async throws {
        let status = await PhotoLibrary.requestAccess()
        print(try JSONLines.encode(AuthEvent(status: status)))
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the current Photos access status without prompting."
    )

    func run() throws {
        print(try JSONLines.encode(AuthEvent(status: PhotoLibrary.currentStatus())))
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print one JSON line per screenshot, newest first."
    )

    @Option(help: "Only screenshots created after this ISO 8601 date (2026-10-01) or date-time.")
    var since: String?

    func validate() throws {
        if let since, SinceDate.parse(since) == nil {
            throw ValidationError("--since must be an ISO 8601 date or date-time, got '\(since)'")
        }
    }

    func run() throws {
        let status = PhotoLibrary.currentStatus()
        guard status.canRead else {
            try printError(
                code: "not_authorized",
                message: "Photos access is '\(status.rawValue)'. Run 'photos-bridge auth' first."
            )
            throw ExitCode(3)
        }

        try PhotoLibrary.forEachScreenshot(since: since.flatMap(SinceDate.parse)) { record in
            print(try JSONLines.encode(record))
        }
    }
}

private func printError(code: String, message: String) throws {
    let line = try JSONLines.encode(ErrorEvent(code: code, message: message)) + "\n"
    FileHandle.standardError.write(Data(line.utf8))
}
