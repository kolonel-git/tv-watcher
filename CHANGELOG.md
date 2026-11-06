# Changelog

## Unreleased
- Sprint 3: TMDB metadata via Read Access Token (.env, gitignored; `.env.example` added). Auto-match by name (+year), manual Re-match dialog (locked against auto-rematch), show synopsis/poster/backdrop, episode titles/overviews/runtime/stills. Artwork cached under app support dir; works offline after first fetch. Language from `TMDB_LANGUAGE` (default en-US) with English fallback. Episode titles from filenames parsed. 80 tests.
- Sprint 2: SQLite (drift) library DB; add/remove library folders; recursive read-only scan; filename parser (SxxExx, 1x01, Season N/Episode N, multi-episode, year, release tags); Unsorted tab with manual assign; rescan (new/missing, manual assignments preserved, unreachable folders skipped); simple Shows/Unsorted/Folders UI; 60 unit tests.
- Sprint 1: Flutter Windows scaffold, media_kit player (open file, play/pause, seek, volume, mute, fullscreen, keyboard shortcuts), README.
- Sprint 0: skeleton chosen (Flutter + media_kit). ROADMAP.md written.
