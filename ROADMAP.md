# TV Watcher — Roadmap

Windows desktop TV-show viewer. Flutter + media_kit (libmpv). Local-only, no accounts, no telemetry.
Only network calls: TMDB.

## Decisions

- Skeleton: Flutter + [media_kit](https://github.com/media-kit/media_kit) (MIT; bundled libmpv build: check LGPL/GPL, no obligation for personal use).
- Use: desk, mouse + keyboard. Not 10-foot UI.
- Collection: internal drive, < 50 shows. Simple incremental rescan, no heavy perf work.
- Metadata: TMDB, user-chosen language with English fallback.
- Anime with absolute numbering: some. Handled in Sprint 2b, not core.
- Storage: SQLite via `drift`. Media files are never modified, renamed or moved.
- TMDB key: `.env` (gitignored), `.env.example` committed. Asked at start of Sprint 3.
- Tests: `flutter test` for parser, next-episode resolver, resume logic.

## Prerequisites (one-time, Windows)

1. Flutter SDK (stable) on PATH — `winget install --id Google.Flutter` or zip from flutter.dev.
2. Visual Studio 2022 Build Tools, workload "Desktop development with C++".
3. Windows "Developer Mode" ON (Flutter plugins need symlinks).
4. `flutter doctor` shows Windows toolchain green.

Not installed on this machine yet (checked): flutter, dart, Visual Studio. Sprint 1 starts with this.

## Epics

| Epic | Contents |
|---|---|
| E1 Playback | media_kit player, controls, shortcuts, tracks, resume |
| E2 Library | folder scan, filename parsing, Unsorted, rescan |
| E3 Metadata | TMDB match, posters/backdrops/thumbs, offline cache |
| E4 Browsing | Home, Continue Watching, show page, episode cards |
| E5 Watch state | progress, watched flags, manual mark |
| E6 Autoplay | next-episode card, season rollover |
| E7 Skip | intro/credits via chapters + manual markers |
| E8 Tracks | subtitle/audio selection, remembered per show |
| E9 Polish | packaging, errors, settings, perf |

## Sprints

### Sprint 1 — Playable skeleton
**Goal:** app launches, plays a chosen video file with standard controls.
Stories:
- S1.1 As user, I open a file and it plays (mkv, mp4, avi). *AC:* file picker → video renders, audio audible.
- S1.2 Controls: play/pause, seek bar, volume, mute, fullscreen. *AC:* each works with mouse.
- S1.3 Keyboard: Space, ←/→ (±10s), ↑/↓ volume, F fullscreen, Esc exit fullscreen, M mute. *AC:* all work.
- S1.4 Project hygiene: repo, `.gitignore`, CHANGELOG, README with setup/run/package steps.
**Deliverable:** `flutter run -d windows` plays any local video. README setup verified.

### Sprint 2 — Library scan & filename parsing
**Goal:** pick folders; files become Show → Season → Episode rows in SQLite.
Stories:
- S2.1 Add/remove library folders (persisted). *AC:* survive restart.
- S2.2 Recursive scan for video extensions. *AC:* no media file touched (read-only).
- S2.3 Parser: `S01E01`, `s1e1`, `1x01`, `Season 1/Episode 3`, `S01E01E02` (multi), dotted/underscored names, show name from filename or folder. *AC:* table-driven unit tests, ≥ 40 real-world-style names.
- S2.4 Unmatched files → "Unsorted" list; user can assign show/season/episode manually. *AC:* assignment persists across rescans.
- S2.5 Rescan: adds new, flags missing, keeps watch data. *AC:* idempotent.
**Deliverable:** simple list UI of parsed library + Unsorted screen; tests green. Needs from you: sample filenames / test folder.

### Sprint 2b — Anime absolute numbering (small) — PARTLY DONE: bulk 'Assign group' in Unsorted; TMDB episode-group auto-mapping still open
- S2b.1 Parse `Show - 137`, `[Group] Show - 137 [1080p]`. *AC:* tests.
- S2b.2 Map absolute → season/episode using TMDB episode groups where available; else Unsorted.

### Sprint 3 — Metadata & artwork
**Goal:** shows/episodes enriched from TMDB, cached for offline.
Stories:
- S3.1 Settings: API key from `.env`, language with EN fallback.
- S3.2 Match show by parsed name (+year); ambiguous → user picks from candidates. *AC:* choice persists.
- S3.3 Fetch show synopsis, poster, backdrop; season/episode titles, descriptions, runtime, stills.
- S3.4 Artwork cached on disk, metadata in SQLite; rate-limited background queue. *AC:* works offline after first scan.
- S3.5 Manual re-match / refresh metadata per show.
**Deliverable:** library list shows real titles + posters, offline-capable. Needs from you: TMDB key in `.env`.

### Sprint 4 — Netflix-style browsing
**Goal:** the real UI.
Stories:
- S4.1 Home: poster grid of all shows. (Continue Watching row moved to Sprint 5: needs watch-progress data.) DONE
- S4.2 Show page: backdrop, synopsis, season selector, episode cards (thumb, title, description, runtime).
- S4.3 Click episode → player; back returns to same scroll position.
- S4.4 Dark theme, hover effects, keyboard-friendly focus.
**Deliverable:** browse → click → play flow end to end.

### Sprint 5 — Resume & watched tracking
Stories:
- S5.1 Save position every ~5s and on exit/pause; resume at exact timestamp. *AC:* kill app mid-play, reopen, resumes within 5s.
- S5.2 Watched = ≥ 90% (configurable) or manual. Progress bar on cards; watched check.
- S5.3 Mark episode/season/show watched/unwatched.
- S5.0 Home Continue Watching row UI (moved from Sprint 4), fed by watch progress.
- S5.4 Continue Watching: resumes the right episode (in-progress, else next unwatched). Unit tests for resume + next-episode logic.
**Deliverable:** close and reopen; Continue Watching correct.

### Sprint 6 — Autoplay & season rollover
Stories:
- S6.1 Near end (last ~30s / credits marker) show "Next episode" card with countdown + Cancel.
- S6.2 Auto-advance when countdown ends; last episode of season rolls to S+1E1; end of show stops.
- S6.3 Handle gaps (missing episodes) and specials (season 0 skipped by default).
**Deliverable:** binge a season boundary hands-free.

### Sprint 7 — Skip intro / credits
Stories:
- S7.1 Use chapter markers (names like Intro/Opening/Credits/Ending) → Skip button.
- S7.2 Manual markers per show or season ("set intro start/end from current time"). *AC:* applies to all episodes in scope.
- S7.3 Skip Credits jumps to next episode (or ends).
**Deliverable:** skip buttons appear on correct ranges.

### Sprint 8 — Subtitles & audio tracks
Stories:
- S8.1 List embedded + external (.srt/.ass alongside file) subtitle tracks; select/off.
- S8.2 Audio track selection.
- S8.3 Remember per show (language/title match across episodes). *AC:* next episode auto-picks same.
**Deliverable:** pick once, persists across episodes.

### Sprint 9 — Polish & packaging
- Settings screen, error states (missing file, no network), loading skeletons.
- Perf pass, window state memory.
- `flutter build windows` portable zip; optional installer.
- Docs final.

## Backlog / maybe
- Hardware-decoding toggle, playback speed, thumbnails on seek bar, file watcher for auto-rescan, installer.

## Process
- Each sprint ends with: Sprint Goal · Completed · How to Run & Test · Known Issues · Roadmap Changes · Proposed Next Sprint.
- Roadmap refined after each review. CHANGELOG.md updated per sprint.
