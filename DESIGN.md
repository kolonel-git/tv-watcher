# Design

Neutral and quiet. Artwork carries the screen; the interface stays out of its way.
Tokens live in [lib/ui/theme.dart](lib/ui/theme.dart) (`Ui`, `buildTheme()`); use them, never raw colours.

## Colour
- Surfaces, darkest to lightest: `bg` 0C0C0E, `surface` 151518, `surfaceHigh` 1E1E22 (menus, dialogs, panels), `selected` 232328.
- Text: `text` EDEBE6, `muted` A3A19B (secondary), `dim` 86847E (tertiary). All >= 4.5:1 on `bg` (checked in `player_panel_test.dart`).
- One accent: warm off-white (`accent`), used for primary buttons, progress and focus. `attention` amber only for "needs attention" labels.
- The red-to-yellow cone volume slider is the one deliberate exception (explicit product-owner request).

## Shape and space
- Radii: 6 / 10 / 14. Spacing scale 4, 8, 12, 16, 24, 32.
- Depth: soft shadows with real offset on floating surfaces (menus, panel); hairline `outline` borders, no coloured halos.

## Components
- Menus, dialogs, snackbars and tooltips are themed globally; menus open **under** their button.
- Player: one settings panel docked above the control bar (root: Subtitles, Audio, Shortcuts; 'Subtitle settings' lives only inside the Subtitles page) instead of popup menus and dialogs. Opens with the CC, audio or tune button, `?` for shortcuts, Esc closes.
- Subtitles: a text overlay (`SubtitleLayer`) above the control bar; drag anywhere (x and y), double-click resets, position saved. Flutter rule: `Positioned` must be a direct Stack child, never under a builder.
- Controls: icon size 24 (play 32), always with a tooltip; the control bar auto-hides after 3 s.
- Show page: season chips (up to 6 seasons, dropdown beyond), visible Select button, inline watched toggle on each episode, grouped overflow menu.
- Home: wordmark, search, sort, unsorted shortcut (when files wait), Library menu.

## Type
Poppins (bundled, OFL). Sizes: display 36 / title 20 / 16 / 14 / body 15, 14, 12 / label 14, 11.
