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
