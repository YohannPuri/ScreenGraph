# photos-bridge

A command-line helper that ScreenGraph runs to read screenshots from the Apple Photos library through PhotoKit.

## Commands

| Command | Output (stdout) |
|---|---|
| `photos-bridge auth` | Shows the Photos permission prompt if needed, then prints `{"type":"auth","status":...}` |
| `photos-bridge status` | Prints the current status without prompting |
| `photos-bridge list [--since <date>]` | One `{"type":"screenshot",...}` line per screenshot, newest first, then `{"type":"end","count":N}` |

Screenshots come from Photos' built-in Screenshots album.

`--since` takes an ISO 8601 date (`2026-10-01`, midnight UTC) or date-time (`2026-10-01T12:30:00.123Z`) and filters by creation date. It is not a sync cursor: a screenshot can reach the library after newer ones (for example through iCloud), so incremental sync must not rely on it.

## Output contract

- Every stdout and stderr line is a single JSON object with a `type` field.
- A `list` without a final `end` line was cut short and is not the complete library.
- Failures print one `{"type":"error","code":...,"message":...}` line on stderr:

| Exit code | `code` | Meaning |
|---|---|---|
| 3 | `not_authorized` | Photos access isn't granted |
| 4 | `screenshots_album_unavailable` | The Screenshots album couldn't be fetched |
| 64 | `usage` | Invalid command or arguments |
| other | `internal` | Unexpected failure |

`--help` prints plain text on stdout and exits 0.

## Develop

```bash
swift build
swift run photos-bridge list --since 2026-10-01
scripts/test.sh   # works with or without full Xcode
```

macOS attributes the permission to the app that launches the helper: the terminal during development, ScreenGraph once bundled.
