# photos-bridge

A small command-line helper that ScreenGraph runs to read screenshots from the Apple Photos library through PhotoKit. Each command prints JSON lines to stdout; errors go to stderr as `{"type":"error",...}`.

| Command | What it does |
|---|---|
| `photos-bridge auth` | Shows the Photos permission prompt if needed, prints `{"type":"auth","status":...}` |
| `photos-bridge status` | Prints the current status without prompting |
| `photos-bridge list [--since 2026-10-01]` | One `{"type":"screenshot",...}` line per screenshot, newest first. Exits 3 if access isn't granted |

Screenshots come from Photos' built-in Screenshots album.

## Develop

```bash
swift build
swift run photos-bridge list --since 2026-10-01
scripts/test.sh   # works with or without full Xcode
```

macOS attributes the permission to the app that launches the helper: the terminal during development, ScreenGraph once bundled.
