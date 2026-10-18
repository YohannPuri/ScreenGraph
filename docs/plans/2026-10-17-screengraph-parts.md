# ScreenGraph — Build Parts

Implementation order for the [v1 design](../specs/2026-10-15-screengraph-design.md). Each part is one pull request.

| # | Part | Scope | Done when |
|---|---|---|---|
| 1 | **photos-bridge: access + listing** | Swift package; `auth`, `status`, `list --since` print JSON lines; testable library target; unit tests | Tests pass; `auth` prompts for access; `list` prints the library's screenshots |
| 2 | **Model benchmark** | `llama-server` with a Gemma vision model and EmbeddingGemma 2 on a sample of ~20 screenshots; measure speed and quality; confirm image embeddings | Default models chosen; per-screenshot time measured |
| 3 | **Tauri shell + bundled bridge** | Tauri app (React + TS); `photos-bridge` bundled as a sidecar; app `Info.plist` carries the Photos usage text; UI runs `auth` and shows the result | The permission prompt names ScreenGraph; the screenshot count shows in the UI |
| 4 | **Store + folder source** | SQLite schema and migrations (`rusqlite`), `Source` trait, `FolderSource` (scan + `notify` watch), sha256/phash dedupe, `asset_locations`, thumbnails | Adding a folder fills `assets`; the same file in two folders becomes one asset with two locations |
| 5 | **Library UI** | Tauri commands and events; thumbnail grid; sources settings | Folder screenshots appear in the app and update live |
| 6 | **Photos source** | Bridge `export` (with iCloud download) and `watch`; `PhotosSource` in Rust | Photos screenshots appear alongside folder ones; new screenshots appear without a restart |
| 7 | **Model manager + job queue** | Hugging Face GGUF download (resumable, sha256), `llama-server` lifecycle with idle shutdown, `ModelClient` trait and fake, `jobs` table and worker | Queued jobs survive a restart; a model crash retries, then shows as failed |
| 8 | **Understanding pipeline** | Image embeddings, stage 1, stage 2, intent YAML files, JSON-schema output | Screenshots get an intent and fields; editing an intent file re-runs stage 2 only |
| 9 | **Grouping + search** | Sequence grouping (time window + embedding similarity), FTS5 + sqlite-vec hybrid search | A multi-screenshot capture becomes one item; search matches by keyword and by meaning |
| 10 | **Review + export** | Keyboard-driven review queue, `Destination` trait, Markdown export, sensitive-text masking, snapshot tests | Accepted items are written as `.md` files; `conversation` and `document` items are skipped by default |
| 11 | **Discovery** | Clustering job, discovery view with labels and sample thumbnails | The discovery view shows labeled clusters |
| 12 | **Evals** | `screengraph eval` against labeled sets; public sample set | Intent and field accuracy reported per model and prompt version |
| 13 | **Onboarding + polish** | First-run flow, model download UI, settings, delete all data, background processing rules, packaging | A fresh install reaches first results without a terminal |
