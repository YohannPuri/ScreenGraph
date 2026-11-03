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

    /// Runs the command and reports every failure, including usage errors,
    /// as a single JSON error line on stderr.
    static func main() async {
        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch let error as BridgeError {
            printError(error.event)
            Foundation.exit(error.exitCode)
        } catch {
            let status = exitCode(for: error)
            if status == .success {
                // --help is reported through an error but isn't one.
                print(fullMessage(for: error))
                Foundation.exit(0)
            }
            let code = status == .validationFailure ? "usage" : "internal"
            printError(ErrorEvent(code: code, message: message(for: error)))
            Foundation.exit(status.rawValue)
        }
    }
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
        abstract: "Print one JSON line per screenshot, newest first, then an end line."
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
            throw BridgeError.notAuthorized(status)
        }

        let count = try PhotoLibrary.forEachScreenshot(since: since.flatMap(SinceDate.parse)) { record in
            print(try JSONLines.encode(record))
        }
        print(try JSONLines.encode(EndEvent(count: count)))
    }
}

private func printError(_ event: ErrorEvent) {
    let line = ((try? JSONLines.encode(event)) ?? #"{"type":"error","code":"internal","message":"unencodable error"}"#) + "\n"
    FileHandle.standardError.write(Data(line.utf8))
}
