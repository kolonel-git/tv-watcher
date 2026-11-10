# TV Watcher

Windows desktop TV-show viewer: Netflix-style library over your local files, playback via libmpv (media_kit).
Local-only. No accounts, no telemetry. Media files are never modified.

See [ROADMAP.md](ROADMAP.md) and [CHANGELOG.md](CHANGELOG.md).

## Setup (Windows)

1. Flutter SDK (stable), on PATH: `git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter`
2. Visual Studio 2022+ Build Tools, workload "Desktop development with C++".
3. Windows Developer Mode ON (`start ms-settings:developers`), required for plugin symlinks.
4. `flutter doctor` must show Windows + Visual Studio green (Android/Chrome can be ignored).

libmpv is downloaded automatically at build time by `media_kit_libs_windows_video`.

## Run (dev)

```
flutter pub get
flutter run -d windows
```

Or double-click `run_tv_watcher.cmd` (a Desktop shortcut to it works): it always builds the latest source first. In its window: `r` hot reload, `R` hot restart, `q` quit. Close a running copy first. Full rerun only for pubspec, native or DB schema changes.

## Test

```
flutter test
```

## Package

```
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\` (copy the whole folder; it is portable).

## Player shortcuts

| Key | Action |
|---|---|
| Space / click | Play / pause |
| ← / → | Seek -10s / +10s |
| ↑ / ↓ | Volume +5 / -5 |
| M | Mute |
| F / double-click | Fullscreen |
| Esc | Close panel, exit fullscreen, go back |
| O | Open file |
| N | Next episode (library playback) |
| V | Cycle subtitles (off, then each track) |
| B | Cycle audio tracks |
| ? | Shortcut list (settings panel) |

Subtitles: drag them to move, double-click to reset. They sit above the control bar while it is visible. Subtitle look: settings panel > Subtitles > Subtitle settings. Volume is remembered.

## Config

TMDB Read Access Token: copy `.env.example` to `.env` and set `TMDB_READ_TOKEN` (and optionally `TMDB_LANGUAGE`, default `en-US`). `.env` is gitignored.

## Code layout (player)

`lib/player/`: `player_page.dart` wires the parts together; `player_config.dart` (tunables), `player_shortcuts.dart` (keys), `subtitle_placement.dart` (subtitle drag/lift/save), `progress_gate.dart` (trust of reported position), `track_catalog.dart` (audio/subtitle tracks), `mpv_properties.dart` (libmpv), `control_bar.dart`, `next_episode_card.dart`, `player_panel.dart`, `subtitle_overlay.dart`.
