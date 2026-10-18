# ScreenGraph — Design (v1)

## 1. Overview

ScreenGraph is a local-first Mac app that reads a user's screenshots, infers why each one was taken, and turns it into something useful: a recipe, an article or post to read, a product, an event, a recommendation, a code snippet.

**Goals for v1:**
- New screenshots appear in the library, sorted by intent, within minutes of being added.
- Intent classification is at least **85%** accurate on the labeled eval set.
- Accepted items export as Markdown files compatible with Obsidian, Logseq and other folder-based tools.
- No data leaves the machine except model downloads and update checks.

## 2. Technology

| Area | Choice |
|---|---|
| Platform | macOS 14+, Apple Silicon |
| App shell | Tauri 2 (Rust core) |
| UI | React, TypeScript, Tailwind, shadcn/ui |
| Photos access | `photos-bridge`, a Swift helper using PhotoKit |
| Inference | `llama-server` (llama.cpp) run as a sidecar process |
| Models | GGUF models from Hugging Face: a Gemma vision model and EmbeddingGemma 2 (multimodal) |
| Storage | SQLite with sqlite-vec and FTS5, in one file |
| Grouping | Embeddings: time window plus image-embedding similarity, and clustering |
| Intents | A built-in set, defined as data files |
| Outputs | In-app library and Markdown folder export |

## 3. Architecture

```
ScreenGraph.app (Tauri 2)
├── UI: React + TS
│     onboarding · library · review queue · discovery · search · settings
│        ▲ Tauri commands (TS → Rust)     │ events (Rust → TS: progress, new items)
├── Core: Rust (src-tauri)
│     sources/    Source trait; PhotosSource, FolderSource (notify crate)
│     ingest/     exact + perceptual hash dedupe; asset locations
│     grouping/   Grouper trait; SequenceGrouper (time + image embedding), ClusterGrouper
│     pipeline/   resumable job queue; stage 1 (understand), stage 2 (classify/extract)
│     intents/    loads intent definition files
│     models/     ModelClient trait; model manager (download, verify, start/stop llama-server)
│     store/      SQLite + sqlite-vec + FTS5; VectorIndex trait
│     export/     Destination trait; MarkdownDestination
├── Sidecar: photos-bridge (Swift CLI, PhotoKit)
└── Sidecar: llama-server ×2 (vision model, embedding model)
```

Each boundary is a trait, so new sources (Windows folders), groupers, inference backends, vector indexes and export destinations can be added without restructuring.

### 3.1 photos-bridge

A command-line helper bundled inside the app. The app's `Info.plist` carries `NSPhotoLibraryUsageDescription`, so macOS shows the standard permission prompt. Output is JSON lines on stdout; errors are JSON lines on stderr.

| Command | Output |
|---|---|
| `auth` | Requests access if needed, prints the authorization status |
| `status` | Prints the authorization status without prompting |
| `list --since <iso8601>` | One line per screenshot: `{id, createdAt, width, height, isFavorite}` |
| `export <id> --to <path> [--max-dim N]` | Writes the image, downloading from iCloud if needed |
| `watch` | Long-running; prints added, changed and removed screenshot IDs |

The Rust core runs the helper through Tauri's sidecar support and parses each line as a typed event.

### 3.2 Models

- The model manager downloads GGUF files from Hugging Face into the app data folder, resumes partial downloads, verifies sha256 checksums and checks free disk space first.
- Two `llama-server` instances run, one per model. Each starts on demand and stops after an idle timeout.
- The default vision model is chosen by benchmark (Part 2), with a larger model available as an option.
- Stage-2 requests use JSON-schema constrained output.

## 4. Data model

| Table | Purpose |
|---|---|
| `sources` | id, kind (`photos` / `folder`), config JSON (path, screenshots-only filter, excluded albums), enabled |
| `assets` | A unique screenshot: sha256, phash, width, height, captured_at, thumbnail_path |
| `asset_locations` | asset_id, source_id, locator (Photos ID or file path), first_seen, missing |
| `asset_embeddings` | sqlite-vec: an image embedding per asset |
| `items` | What the library shows: intent, title, fields JSON, confidence, status (`pending_review` / `accepted` / `discarded`), intent_def_version |
| `item_assets` | item_id, asset_id, ordinal (an item can span several screenshots) |
| `understandings` | Stage-1 output per item: transcription, description, hints JSON (handles, visible URLs, platform), model_id, prompt_version |
| `item_embeddings` | sqlite-vec: a text embedding of the understanding |
| `item_fts` | FTS5 over transcription, title and fields |
| `clusters`, `cluster_members` | Clustering runs for discovery |
| `jobs` | kind, target_id, state (`queued` / `running` / `done` / `failed`), attempts, last_error, priority |
| `exports` | item_id, destination, output_path, content_hash |

## 5. Pipeline

```
source scan / watch
  → upsert asset + location            (sha256 exact dedupe; phash near-duplicate → same asset)
  → [job] embed image                  (EmbeddingGemma 2)
  → sequence grouping                  (captured within a time window AND cosine ≥ threshold → same item)
  → [job] stage 1: understand          (vision model reads all of the item's images, in order)
  → [job] embed understanding text + FTS index
  → [job] stage 2: classify + extract  (text-only, intent definitions, JSON schema)
  → review queue → accepted → [job] export
background: [job] clustering over embeddings → discovery suggestions
```

**Rules:**
- Sequence grouping defaults to a 5-minute window and a tuned cosine threshold. Both are settings.
- Every expensive step is a `jobs` row, so processing resumes after the app quits.
- Newest screenshots are processed first.
- Editing an intent definition re-queues stage 2 only for items classified with an older `intent_def_version`.
- Changing the vision model re-runs stage 1 only when the user requests it.
- When an item's grouping changes, its stage 1 and stage 2 results are invalidated.
- An asset missing from every source is marked `missing`, not deleted. Accepted items are kept.

## 6. Intents

Each intent is a YAML file in `intents/` with a name, description, JSON schema of fields, extraction prompt and version. Built-in intents ship as files.

| Intent | Fields |
|---|---|
| `recipe` | title, ingredients[], steps[], source |
| `article_link` | title, site, url_hints[], summary |
| `social_post` | platform, handle, text, url_hints[] |
| `product` | name, brand, price, store, url_hints[] |
| `place_event` | name, address, datetime, venue |
| `recommendation` | kind (book/show/movie/music/app/other), title, creator |
| `code_tech` | tool_or_language, snippet_or_error, summary |
| `document` | kind (receipt/ticket/confirmation/other), key_fields |
| `conversation` | participants, gist |
| `junk` | reason (meme/accidental/duplicate) |
| `other` | summary |

**Discovery:** a clustering job groups item embeddings. The discovery view shows each cluster's size, sample thumbnails and a generated label. In v1 this view is read-only.

## 7. UI

- **Onboarding:** privacy summary, Photos access, folder sources, model download with progress, optional Markdown export folder.
- **Library:** grid grouped by intent, filterable by intent, source, date and status.
- **Review queue:** one item at a time; accept, change intent, edit fields or discard; keyboard-driven.
- **Discovery:** clusters with sample thumbnails.
- **Search:** combined keyword (FTS5) and semantic (vector) results.
- **Settings:** sources, models, export folder and exclusions, background processing, delete all data.
- **Status:** queue progress and failed jobs with their errors.

## 8. Failure handling

- **Photos access denied:** onboarding explains the requirement and links to System Settings. Folder sources keep working.
- **iCloud-only originals and cloud placeholder files:** downloads are requested; timeouts retry with backoff and show "waiting for download."
- **llama-server crash or out of memory:** the server restarts and the job retries; after 3 attempts the job is `failed` and shown in the UI.
- **Invalid model output:** schema-constrained generation and validation; one retry, then fallback to `other` with low confidence, which places it in the review queue.
- **Model download:** resumable, sha256-verified, with a disk space check.
- **Corrupt or unsupported images:** skipped and logged without blocking the queue.

## 9. Privacy

- Network access is limited to model downloads and update checks. No telemetry, no accounts.
- `conversation` and `document` items are excluded from export by default.
- Export masks sensitive-looking text (card numbers, one-time codes, text near "password") and flags those items in review.
- Sources and Photos albums can be excluded.
- "Delete all data" removes the database and thumbnails. Original screenshots are never modified.

## 10. Performance

- Backlog processing runs at background priority with 1–2 concurrent vision jobs and pauses on battery or during user activity (configurable).
- Thumbnails are generated once and reused.
- Per-screenshot throughput is measured in Part 2.

## 11. Testing

- **Rust unit tests:** hashing, grouping, intent loading, schema validation, job state transitions.
- **Snapshot tests** (`insta`) for Markdown export.
- **Fake `ModelClient`** so pipeline tests and CI run without a model.
- **Bridge contract tests:** Rust parses recorded `photos-bridge` output. Photos access itself is covered by a manual checklist.
- **Evals:** `screengraph eval` reports intent and field accuracy per model and prompt version, against a public sample set in the repo and optional private labeled sets kept outside it.
- **CI** (GitHub Actions, macOS): `cargo test`, `cargo clippy`, `cargo fmt --check`, `tsc`, UI tests.

## 12. Development notes

macOS ties the Photos permission to the app's code signature. If dev builds re-prompt after every rebuild, sign them with a stable self-signed certificate.

The build is split into parts in [`docs/plans/2026-10-17-screengraph-parts.md`](../plans/2026-10-17-screengraph-parts.md).

## 13. Out of scope for v1

- Link recovery (opt-in online search for a screenshot's original URL)
- Non-embedding grouping strategies, such as SSIM
- Task-app destinations (TickTick, Apple Reminders, Todoist)
- User-defined intents, and turning discovery clusters into intents
- Windows support
- iPhone app
- MLX or mistral.rs inference backends
- Code signing and notarization for distribution
