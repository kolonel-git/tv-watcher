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
| Esc | Exit fullscreen |
| O | Open file |

## Config

TMDB API key (Sprint 3): copy `.env.example` to `.env` and fill in. `.env` is gitignored.
