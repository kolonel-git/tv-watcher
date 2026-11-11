# Decisions

Short record of product and engineering decisions, newest last. Each entry: what, why, consequence.
Rule: every decision made while building is added here in the same change that implements it.

## D1 Flutter + media_kit (Sprint 0)
Flutter Windows desktop with media_kit/libmpv for playback; SQLite via drift for the library. Local-only, no accounts or telemetry; the only network calls go to TMDB. Media files are never modified, renamed or moved.

## D2 Sprint 7 deferred to Sprint 10 (product owner)
Skip intro/credits moves to the end of the roadmap; subtitles and audio went first.

## D3 Subtitles drawn by the app, picture subtitles by mpv (Sprint 8)
Text subtitles are an app overlay (movable, styled, remembered). Picture subtitles (PGS, VobSub) can only be drawn by mpv, so libass stays on and the overlay hides for them. PGS still does not render: see ROADMAP KB-1.

## D4 `Positioned` must be a direct child of a `Stack`
Found after five failed subtitle-drag fixes: `Positioned` under `LayoutBuilder` or `StreamBuilder` is silently ignored. Components that position themselves own their Stack (`SubtitleLayer`), and callers wrap them in `Positioned.fill`.

## D5 Player split into single-purpose classes (refactor)
`PlayerConfig`, `PlayerShortcuts` + `PlayerCommands`, `SubtitlePlacement`, `ProgressGate`, `TrackCatalog`, `MpvProperties`, plus widget files. Why: `player_page.dart` was 1,319 lines and one subtitle bug cost five attempts. Every tunable number lives in `PlayerConfig`.

## D6 Player body excluded from semantics
Hundreds of `Failed to update ui::AXTree` errors came from the constantly changing player overlays. Excluding the body from semantics cut 446 errors to 4. Cost: screen readers do not see the player controls (personal desktop app, keyboard shortcuts unaffected). The 4 leftovers are KB-2 in ROADMAP.

## D7 Git: the user runs commit and push
No attribution of any kind in commit messages. Messages are given as files for `git commit -F`. One commit per logical change; never amend after pushing.

## D8 Seek icons show the real skip step (9b)
The built-in `replay_10`/`forward_10` icons are fixed at 10 s. `SeekIcon` draws a circular arrow with the configured number, so the skip-step setting cannot make the icon lie.

## D9 Settings model is `UserSettings`, not `AppSettings` (9b-1)
drift already generates `AppSettings` for the key/value table. `UserSettings` is a pure-Dart immutable class (no storage, no Flutter) so it can be unit-tested; `SettingsController` (ChangeNotifier) loads, saves and applies it.

## D10 Settings stored as `settings.<name>` rows in the existing key/value table (9b-1)
No schema change, no migration. Only changed values are written; "Reset all" deletes only the `settings.` rows, so player volume, subtitle look/position and per-show track choices are untouched. Why: other keys (`player.volume` etc.) already live in the same table.

## D11 Decoding is tolerant (9b-1)
A missing, unparsable or out-of-range stored value falls back to that field's default (skip step must be one of the offered steps, language one of the offered codes). A damaged settings table can never stop the app from starting.

## D12 Widgets read settings through `SettingsScope` (InheritedNotifier) (9b-1)
Constructors stay unchanged and widgets without a scope (most widget tests) get `UserSettings.defaults`. The player reads the settings once when it opens: the settings screen is not reachable from inside the player, so they cannot change mid-playback.

## D13 Watched threshold is a field on the database object (9b-1)
`AppDatabase.watchedFraction` (set by `SettingsController`) is used by progress saving and Continue Watching, which run deep inside database queries; passing it down five call sites was worse. The pure functions (`computeProgress`, `resumePositionMs`, `continueTarget`) still take an explicit `threshold` parameter (default 0.90) and stay pure.

## D14 Resume behaviour: autoplay never asks (9b-1)
Options: always resume (default), ask each time, always start over. "Ask" shows a dialog when the user opens an episode; dismissing the dialog plays nothing. Hands-free autoplay cannot wait for a click, so for the next episode "ask" acts like "always"; "start over" still applies.

## D15 Metadata language override applies to future fetches only (9b-1)
`TmdbClient.language` became mutable. Already-fetched titles keep their language until the user runs "Refresh metadata" on a show; the settings screen says so. Re-fetching everything on a language change would be many TMDB calls the user did not ask for. `null` means "use `TMDB_LANGUAGE` from `.env` (default en-US)".

## D16 Home sort is a saved setting; two new sorts (9b-1)
The sort menu on Home writes to settings (so it persists) and the settings screen shows the same value. New sorts: Recently added (earliest episode `addedAt`, no schema change) and Recently watched (latest `lastPlayedAt`); shows without a date go last, ties by name. `ShowSort` moved to `lib/settings/` and is re-exported from `home_page.dart`.

## D17 Show page: specials and missing files (9b-1)
"Show specials" off hides season 0 on the show page only (Continue Watching and autoplay already skip specials). "Show missing files" on lists episodes whose file is gone, greyed with a "File missing" badge; tapping one explains instead of failing to play, and Continue Watching ignores them. Both are read when the page opens.

## D18 Settings widgets: sliders save on release, dropdowns have a fixed width (9b-1)
A drag is one database write, not dozens. Dropdown controls are 260 px wide with ellipsis so long labels cannot overflow with the wider Poppins font.

## D19 Testing note: the Ahem test font
`flutter_test` draws text 14 px per character, so existing menu rows overflow when a test opens them. A test that must open such a menu shrinks the text scale instead of weakening the overflow check.

## D20 Playback tweaks are per viewing, not saved (9b-2)
Speed, subtitle delay, audio delay and aspect live in `PlaybackOptions` and are not stored. Speed carries across episodes of one viewing (binge at 1.25x); delays and aspect belong to one file's timing and shape, so they reset when a new file opens. Speed ladder 0.5-2x on `[` / `]`; delays step 0.1 s and are capped at +-30 s.

## D21 Aspect ratio: mpv override, plus Zoom (9b-2)
16:9, 4:3 and 21:9 use mpv's `video-aspect-override`; "Auto" removes it. "Zoom to fill" crops to fill the window by using `BoxFit.cover` on the video widget (mpv has no equivalent that works with the texture renderer). No stretch mode: distorted pictures are never wanted.

## D22 Subtitle delay on Z/X, audio delay in the panel only (9b-2)
Z (earlier) and X (later) follow mpv's convention. Audio delay is rarely needed, so it only has a stepper in the Playback page; no key was spent on it. A short on-screen message confirms speed and subtitle-delay changes.

## D23 Hardware decoding: a saved setting with a live switch (9b-2)
Default on (`auto-safe`). The switch is in Settings and in the player's Playback page and takes effect immediately: verified against libmpv that `hwdec-current` flips between `d3d11va-copy` and `no` mid-playback. The player applies the saved value before opening a file.

## D24 Backup format (9b-2)
JSON, `format: tv-watcher-backup`, `formatVersion: 1`. Contains watch progress per episode (identified by file path, so it survives a rebuilt library) and the whitelisted settings keys (`settings.*`, `player.*`). Never contains the TMDB token (it is in `.env`, not the database), media files, artwork, or per-show subtitle/audio choices (left out of v1 to keep the file simple; can be added under a new formatVersion). Restore rule: per episode the newer last-played time wins, so an old backup cannot erase newer progress; entries marked watched by hand (no play time) only fill episodes with no progress; settings in the backup replace the current ones.

## D25 Backup files are untrusted input (9b-2)
`BackupFile.parse` is pure and strict: wrong format or a newer formatVersion is rejected, malformed entries are skipped (not fatal), only whitelisted key prefixes with bounded length/size are kept, at most 200,000 episodes are read, files over 20 MB are refused before reading, and parsing never touches the database. A confirmation dialog shows what will be restored before anything is written.

## D26 OS actions behind a `DataActions` interface (9b-2)
File save/open dialogs and Explorer are in `PlatformDataActions`; the settings screen takes a `DataActions`, so tests use a fake and never open real dialogs. "Open data folder" opens the documents folder, where drift_flutter keeps `tv_watcher.sqlite`.

## D27 Version has one source in code, checked against pubspec (9b-2)
`lib/app_info.dart` holds name, version and build for About and for backups; a test fails if it differs from `version:` in pubspec.yaml. Chosen over adding the `package_info_plus` dependency for a single string.

## D28 libmpv property names verified live (9b-2)
A throwaway entry point set each property on a real player and read it back: `speed` 1.5, `sub-delay` -0.3, `audio-delay` 0.2, `video-aspect-override` 16:9 -> 1.777778 and back to -1, `hwdec` no <-> auto-safe. The entry point was deleted afterwards.

## D29 Unplayable files are explained before the player opens (9c)
`openEpisode` first checks the file (`checkPlayable`, read-only). File gone but its library folder present: dialog 'File not found' with the path and a Rescan button (runs `scanFolder` for that folder, so moved files are found again and deleted ones marked missing). Whole folder unreachable (unplugged drive, offline share): dialog 'Folder not reachable', no Rescan (nothing to scan), tells the user to reconnect. Previously the player opened and showed nothing useful. Scan-time offline folders, no TMDB token and offline metadata were already handled (notes on the home page).

## D30 Window size and position are remembered with window_manager 0.5.x (9c)
`WindowMemory` restores the last frame at startup and saves (debounced 500 ms) after move, resize and maximize. Stored under settings key `window.frame`, deliberately outside the backup whitelist: geometry belongs to one computer. A stored frame is untrusted: `WindowFrame.decode` is tolerant and `fitTo` raises tiny sizes to 640x400, shrinks to the screen, and centers frames that are (nearly) off every screen, for example after unplugging a monitor. While maximized the last normal size is kept so un-maximizing is sensible. The player sets `WindowMemory.suspended` during fullscreen so that frame is never saved. Any failure is swallowed: remembering the window must never block startup. window_manager 0.6.0 was rejected: it is a rewrite on a new native base (nativeapi) with a different API; 0.5.x is the long-used line. screen_retriever (its dependency) is used directly to read the screens.

## D31 Image cache has explicit limits (9c)
`ImageBudget` sets 200 MB and 400 images (Flutter default 100 MB and 1000). A 400 px poster decodes to about 1 MB, so the default held about 100 posters and a large grid re-decoded while scrolling; the byte cap keeps memory bounded regardless of library size.

## D32 Large-library performance was measured, not guessed (9c)
`test/large_library_test.dart` builds 400 shows and 10,000 episodes in memory: the home shows list loads in about 70 ms and Continue Watching in about 190 ms. That is far inside budget, so no query was changed. `watchContinueWatching` still reads all episodes and looks up shows one by one (it re-runs on every progress save); the test is the tripwire if that ever grows (bounds 1.5 s and 2.5 s, deliberately loose against machine noise).

## D33 Release is a portable zip built by a script (9c)
`tools/package_windows.ps1` runs `flutter build windows --release`, copies the Release folder to `dist/`, deletes any `.env`, `*.sqlite`, `*.db` as a safety net, adds `tools/INSTALL.txt` and zips it. The TMDB token is never packaged; the install note tells the user to put their own `.env` next to the exe. No installer: a personal local app, and the zip is also the upgrade path (data lives outside the folder). `dist/` is gitignored.

## D34 Loading placeholders (9c)
Home and show page showed a blank screen until their first database emission. They now show a small spinner. The DB is local so this is a flicker fix, not a progress bar.
