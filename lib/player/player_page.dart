import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/database.dart';
import '../ui/artwork.dart';
import '../ui/play.dart';
import '../watch/autoplay.dart';
import '../watch/watch_logic.dart';
import 'cone_volume.dart';

/// Player: controls, keyboard shortcuts, resume, progress saving and
/// autoplay of the next episode.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    this.initialPath,
    this.title,
    this.db,
    this.episodeId,
    this.startAt,
  });

  /// File to start playing immediately (from the library).
  final String? initialPath;
  final String? title;

  /// When both are set, progress is saved and the next episode is offered.
  final AppDatabase? db;
  final int? episodeId;

  /// Resume point. Null or zero = start from the beginning.
  final Duration? startAt;

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
  Timer? _saveTimer;
  Timer? _startGuardTimer;
  Timer? _countdownTimer;

  // --- episode context (library playback only) ---
  int? _episodeId;
  String? _title;
  Show? _show;
  List<Episode> _siblings = const [];
  Episode? _next;
  final AutoplayState _autoplay = AutoplayState();
  bool _advancing = false;

  /// Don't overwrite the saved resume point with the pre-seek position (0)
  /// before playback has actually reached the start offset.
  bool _reachedStart = true;
  Duration? _pendingStart;

  /// False until the freshly opened media reports a position in its first
  /// 90%. Stops stale position/duration from the previous episode being
  /// saved to, or autoplay-triggered for, the new one.
  bool _armed = false;

  bool get _tracking => widget.db != null && _episodeId != null;

  @override
  void initState() {
    super.initState();
    _episodeId = widget.episodeId;
    _title = widget.title;
    _player.stream.volume.listen((_) => setState(() {}));
    _player.stream.position.listen(_onPosition);
    _player.stream.completed.listen(_onCompleted);
    final path = widget.initialPath;
    if (path != null) {
      _openMedia(path, start: widget.startAt);
      _hasMedia = true;
    }
    if (_tracking) {
      _saveTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
      _player.stream.playing.listen((playing) {
        if (!playing) _saveProgress();
      });
      _loadContext();
    }
  }

  void _openMedia(String path, {Duration? start}) {
    final resume = start != null && start > Duration.zero;
    _reachedStart = !resume;
    _pendingStart = resume ? start : null;
    _armed = false;
    _startGuardTimer?.cancel();
    if (resume) {
      // Fallback if the seek never reports (e.g. unusual container).
      _startGuardTimer = Timer(const Duration(seconds: 10), () {
        _reachedStart = true;
      });
    }
    _player.open(Media(path, start: resume ? start : null));
  }

  /// Loads the show's episodes so the next one can be offered.
  Future<void> _loadContext() async {
    final db = widget.db!;
    final id = _episodeId!;
    final ep = await db.getEpisode(id);
    final showId = ep?.showId;
    if (ep == null || showId == null) return;
    final show = await db.getShow(showId);
    final siblings = await db.episodesOfShow(showId);
    if (!mounted || _episodeId != id) return;
    setState(() {
      _show = show;
      _siblings = siblings;
      _next = _computeNext(ep);
    });
  }

  /// Next regular episode: same season, else first of the next season.
  /// Specials and missing files are skipped; null at the end of the show.
  Episode? _computeNext(Episode current) {
    final n = nextInOrder(_siblings.map(episodeRef), episodeRef(current));
    if (n == null) return null;
    return _siblings.firstWhere((e) => e.id == n.id);
  }

  void _onPosition(Duration p) {
    final pending = _pendingStart;
    if (!_reachedStart &&
        pending != null &&
        p >= pending - const Duration(seconds: 3)) {
      _reachedStart = true;
    }
    final durMs = _player.state.duration.inMilliseconds;
    if (!_armed && durMs > 0 && p.inMilliseconds < durMs * 0.9) {
      _armed = true;
    }
    if (!_tracking || !_armed || !_reachedStart || _advancing) return;
    final changed = _autoplay.onPosition(
      positionMs: p.inMilliseconds,
      durationMs: durMs,
      hasNext: _next != null,
    );
    if (changed) {
      _syncCountdownTimer();
      if (mounted) setState(() {});
    }
  }

  void _syncCountdownTimer() {
    if (_autoplay.showing) {
      _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        // Hold the countdown while paused.
        if (!_player.state.playing) return;
        final done = _autoplay.tick();
        setState(() {});
        if (done) _advance();
      });
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  void _cancelAutoplay() {
    _autoplay.cancel();
    _syncCountdownTimer();
    setState(() {});
  }

  void _onCompleted(bool done) {
    if (!done) return;
    _saveProgress(atEnd: true);
    if (_tracking &&
        _next != null &&
        !_autoplay.cancelled &&
        !_advancing &&
        _armed) {
      _advance();
    }
  }

  /// Marks the current episode watched and plays the next one in place
  /// (keeps fullscreen, volume and window state).
  Future<void> _advance() async {
    final next = _next;
    final db = widget.db;
    final current = _episodeId;
    if (next == null || db == null || current == null || _advancing) return;
    _advancing = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    await db.setWatched([current], true);
    if (!mounted) return;

    final resumeMs = resumePositionMs(next.positionMs, next.durationMs);
    _episodeId = next.id;
    _autoplay.reset();
    setState(() {
      _title = _show == null ? null : episodeTitle(_show!, next);
      _next = _computeNext(next);
    });
    _openMedia(next.filePath,
        start: resumeMs > 0 ? Duration(milliseconds: resumeMs) : null);
    _advancing = false;
  }

  /// Captures position/duration synchronously, then writes in the background.
  void _saveProgress({bool atEnd = false}) {
    if (!_tracking || !_reachedStart || !_armed) return;
    final duration = _player.state.duration.inMilliseconds;
    final position =
        atEnd ? duration : _player.state.position.inMilliseconds;
    if (duration <= 0) return;
    widget.db!.saveProgress(_episodeId!,
        positionMs: position, durationMs: duration);
  }

  @override
  void dispose() {
    _saveProgress();
    _saveTimer?.cancel();
    _startGuardTimer?.cancel();
    _countdownTimer?.cancel();
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
    } else if (key == LogicalKeyboardKey.keyN) {
      if (_next != null) _advance();
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
                        if (_title != null)
                          Text(_title!,
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
                        onSeekBy: _seekBy,
                        onFullscreen: () => _setFullscreen(!_fullscreen),
                        onNext: _next == null ? null : _advance,
                      ),
                    ),
                  ),
                ),
              if (_autoplay.showing && _next != null)
                Positioned(
                  right: 24,
                  bottom: _controlsVisible ? 112 : 32,
                  child: _NextEpisodeCard(
                    episode: _next!,
                    show: _show,
                    secondsLeft: _autoplay.secondsLeft ?? 0,
                    totalSeconds: _autoplay.countdownSeconds,
                    onPlayNow: _advance,
                    onCancel: _cancelAutoplay,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextEpisodeCard extends StatelessWidget {
  const _NextEpisodeCard({
    required this.episode,
    required this.show,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onPlayNow,
    required this.onCancel,
  });

  final Episode episode;
  final Show? show;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = episode.tmdbTitle ?? episode.title;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF0101016),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT EPISODE',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 104,
                height: 58,
                child: ArtworkImage(
                    path: episode.stillFile,
                    cacheWidth: 208,
                    placeholderIcon: Icons.movie_outlined),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('S${episode.season}E${episode.episode}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white60)),
                  Text(name ?? 'Episode ${episode.episode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: totalSeconds == 0 ? 0 : secondsLeft / totalSeconds,
              minHeight: 3,
              backgroundColor: Colors.white12,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Starting in ${secondsLeft}s',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onPlayNow,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Play now'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
          ]),
        ],
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
    required this.onSeekBy,
    required this.onFullscreen,
    this.onNext,
  });

  final Player player;
  final bool fullscreen;
  final VoidCallback onOpen;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onFullscreen;

  /// Null when there is no next episode.
  final VoidCallback? onNext;

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static final _btnStyle = IconButton.styleFrom(
    padding: const EdgeInsets.all(4),
    minimumSize: const Size(36, 36),
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    final timeStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontWeight: FontWeight.w500, color: Colors.white70);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xDD000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: _red,
              inactiveTrackColor: Colors.white24,
              thumbColor: _red,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: StreamBuilder<Duration>(
              stream: player.stream.position,
              builder: (context, pos) => StreamBuilder<Duration>(
                stream: player.stream.duration,
                builder: (context, dur) {
                  final position = pos.data ?? player.state.position;
                  final duration = dur.data ?? player.state.duration;
                  final max = duration.inMilliseconds.toDouble();
                  return SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        Text(_fmt(position), style: timeStyle),
                        Expanded(
                          child: Slider(
                            value: position.inMilliseconds
                                .toDouble()
                                .clamp(0, max > 0 ? max : 1),
                            max: max > 0 ? max : 1,
                            onChanged: (v) => player
                                .seek(Duration(milliseconds: v.round())),
                          ),
                        ),
                        Text(_fmt(duration), style: timeStyle),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                style: _btnStyle,
                tooltip: 'Back 10s (←)',
                iconSize: 26,
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: () => onSeekBy(const Duration(seconds: -10)),
              ),
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snap) => IconButton(
                  style: _btnStyle,
                  tooltip: 'Play / pause (Space)',
                  iconSize: 34,
                  icon: Icon((snap.data ?? false)
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  onPressed: player.playOrPause,
                ),
              ),
              IconButton(
                style: _btnStyle,
                tooltip: 'Forward 10s (→)',
                iconSize: 26,
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: () => onSeekBy(const Duration(seconds: 10)),
              ),
              if (onNext != null)
                IconButton(
                  style: _btnStyle,
                  tooltip: 'Next episode (N)',
                  iconSize: 26,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: onNext,
                ),
              const SizedBox(width: 10),
              StreamBuilder<double>(
                stream: player.stream.volume,
                builder: (context, snap) {
                  final v = snap.data ?? player.state.volume;
                  return Row(
                    children: [
                      IconButton(
                        style: _btnStyle,
                        tooltip: 'Mute (M)',
                        iconSize: 24,
                        icon: Icon(v == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded),
                        onPressed: onToggleMute,
                      ),
                      const SizedBox(width: 4),
                      ConeVolumeSlider(
                          value: v, onChanged: onVolume, width: 100, height: 22),
                    ],
                  );
                },
              ),
              const Spacer(),
              IconButton(
                style: _btnStyle,
                tooltip: 'Open file (O)',
                iconSize: 24,
                icon: const Icon(Icons.folder_open_rounded),
                onPressed: onOpen,
              ),
              IconButton(
                style: _btnStyle,
                tooltip: 'Fullscreen (F)',
                iconSize: 26,
                icon: Icon(fullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded),
                onPressed: onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _red = Color(0xFFE50914);
