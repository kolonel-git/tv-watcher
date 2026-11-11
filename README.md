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

Or double-click `run_tv_watcher.cmd` (a Desktop shortcut to it works): it runs `flutter pub get` (fetches new packages) and then builds the latest source. In its window: `r` hot reload, `R` hot restart, `q` quit. Close a running copy first. Full rerun only for pubspec, native or DB schema changes.

## Test

```
flutter test
```

## Package

```
powershell -ExecutionPolicy Bypass -File tools\package_windows.ps1
```

Builds the release and writes `dist\tv-watcher-<version>-windows.zip`: portable, contains `INSTALL.txt`, never contains `.env` (the TMDB token) or the database. Unzip anywhere and run `tv_watcher.exe`; put your own `.env` next to it for posters. The bare build (`flutter build windows --release`) outputs `build\windows\x64\runner\Release\`.

The window remembers its position and size. If a file is moved or an external drive is unplugged, the app says so when you press play (and offers a rescan).

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
| [ / ] | Playback speed down / up |
| Z / X | Subtitle delay earlier / later (0.1 s) |
| ? | Shortcut list (settings panel) |

Playback options (speed, aspect ratio, subtitle and audio delay, hardware decoding): settings panel > Playback. Backup and restore, data folder and About: Settings > Data.

Settings (autoplay, skip step, watched threshold, resume behaviour, volume, language, sort, poster size, specials, missing files): Home > Library menu > Settings. Decisions are recorded in [DECISIONS.md](DECISIONS.md).

Subtitles: drag them to move, double-click to reset. They sit above the control bar while it is visible. Subtitle look: settings panel > Subtitles > Subtitle settings. Volume is remembered.

## Config

TMDB Read Access Token: copy `.env.example` to `.env` and set `TMDB_READ_TOKEN` (and optionally `TMDB_LANGUAGE`, default `en-US`). `.env` is gitignored.

## Code layout

`lib/settings/`: `user_settings.dart` (the model and its ranges), `settings_controller.dart` (storage and `SettingsScope`). `lib/ui/settings_page.dart` and `settings_widgets.dart` draw the screen.

`lib/data/backup_service.dart` (backup format, parsing, restore) and `data_actions.dart` (file dialogs, Explorer). `lib/app_info.dart` holds the version.

### Player

`lib/player/`: `player_page.dart` wires the parts together; `player_config.dart` (tunables), `player_shortcuts.dart` (keys), `subtitle_placement.dart` (subtitle drag/lift/save), `progress_gate.dart` (trust of reported position), `track_catalog.dart` (audio/subtitle tracks), `mpv_properties.dart` (libmpv), `control_bar.dart`, `next_episode_card.dart`, `player_panel.dart`, `subtitle_overlay.dart`.
