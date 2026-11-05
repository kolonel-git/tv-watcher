import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Sprint 1 player: open a file, standard controls, keyboard shortcuts.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.initialPath, this.title});

  /// File to start playing immediately (from the library).
  final String? initialPath;
  final String? title;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  final FocusNode _focus = FocusNode();

  bool _fullscreen = false;
  bool _controlsVisible = true;
  bool _hasMedia = false;
  double _preMuteVolume = 100;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _player.stream.volume.listen((_) => setState(() {}));
    final path = widget.initialPath;
    if (path != null) {
      _player.open(Media(path));
      _hasMedia = true;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focus.dispose();
    if (_fullscreen) defaultExitNativeFullscreen();
    _player.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    final file = await FilePicker.pickFile(type: FileType.video);
    final path = file?.path;
    if (path == null) return;
    await _player.open(Media(path));
    setState(() => _hasMedia = true);
    _focus.requestFocus();
  }

  void _seekBy(Duration d) {
    final target = _player.state.position + d;
    final max = _player.state.duration;
    _player.seek(target < Duration.zero
        ? Duration.zero
        : (target > max ? max : target));
  }

  void _setVolume(double v) => _player.setVolume(v.clamp(0, 100));

  void _toggleMute() {
    if (_player.state.volume > 0) {
      _preMuteVolume = _player.state.volume;
      _player.setVolume(0);
    } else {
      _player.setVolume(_preMuteVolume > 0 ? _preMuteVolume : 100);
    }
  }

  Future<void> _setFullscreen(bool value) async {
    await (value ? _enterFullscreen() : _exitFullscreen());
    setState(() => _fullscreen = value);
  }

  Future<void> _enterFullscreen() => defaultEnterNativeFullscreen();
  Future<void> _exitFullscreen() => defaultExitNativeFullscreen();

  void _pokeControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      _player.playOrPause();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(const Duration(seconds: -10));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(const Duration(seconds: 10));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume(_player.state.volume + 5);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume(_player.state.volume - 5);
    } else if (key == LogicalKeyboardKey.keyF) {
      _setFullscreen(!_fullscreen);
    } else if (key == LogicalKeyboardKey.escape) {
      if (_fullscreen) {
        _setFullscreen(false);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyO) {
      _openFile();
    } else {
      return KeyEventResult.ignored;
    }
    _pokeControls();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _pokeControls(),
        cursor: _controlsVisible || !_hasMedia
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_hasMedia) _player.playOrPause();
                  _pokeControls();
                },
                onDoubleTap: () => _setFullscreen(!_fullscreen),
                child: Video(
                  controller: _video,
                  controls: NoVideoControls,
                ),
              ),
              if (!_hasMedia)
                Center(
                  child: FilledButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open video file'),
                  ),
                ),
              if (_hasMedia && Navigator.canPop(context))
                Positioned(
                  top: 8,
                  left: 8,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Row(children: [
                        IconButton(
                          tooltip: 'Back (Esc)',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        if (widget.title != null)
                          Text(widget.title!,
                              style: Theme.of(context).textTheme.titleMedium),
                      ]),
                    ),
                  ),
                ),
              if (_hasMedia)
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _ControlBar(
                        player: _player,
                        fullscreen: _fullscreen,
                        onOpen: _openFile,
                        onToggleMute: _toggleMute,
                        onVolume: _setVolume,
                        onFullscreen: () => _setFullscreen(!_fullscreen),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.player,
    required this.fullscreen,
    required this.onOpen,
    required this.onToggleMute,
    required this.onVolume,
    required this.onFullscreen,
  });

  final Player player;
  final bool fullscreen;
  final VoidCallback onOpen;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, pos) => StreamBuilder<Duration>(
              stream: player.stream.duration,
              builder: (context, dur) {
                final position = pos.data ?? player.state.position;
                final duration = dur.data ?? player.state.duration;
                final max = duration.inMilliseconds.toDouble();
                return Row(
                  children: [
                    Text(_fmt(position)),
                    Expanded(
                      child: Slider(
                        value: position.inMilliseconds
                            .toDouble()
                            .clamp(0, max > 0 ? max : 1),
                        max: max > 0 ? max : 1,
                        onChanged: (v) =>
                            player.seek(Duration(milliseconds: v.round())),
                      ),
                    ),
                    Text(_fmt(duration)),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snap) => IconButton(
                  iconSize: 32,
                  icon: Icon((snap.data ?? false)
                      ? Icons.pause
                      : Icons.play_arrow),
                  onPressed: player.playOrPause,
                ),
              ),
              StreamBuilder<double>(
                stream: player.stream.volume,
                builder: (context, snap) {
                  final v = snap.data ?? player.state.volume;
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(v == 0 ? Icons.volume_off : Icons.volume_up),
                        onPressed: onToggleMute,
                      ),
                      SizedBox(
                        width: 120,
                        child: Slider(value: v, max: 100, onChanged: onVolume),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open file (O)',
                icon: const Icon(Icons.folder_open),
                onPressed: onOpen,
              ),
              IconButton(
                tooltip: 'Fullscreen (F)',
                icon: Icon(
                    fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                onPressed: onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
