import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/database.dart';
import '../tracks/external_subs.dart';
import '../tracks/track_prefs.dart';
import '../ui/artwork.dart';
import '../ui/play.dart';
import '../ui/theme.dart';
import '../watch/autoplay.dart';
import '../watch/watch_logic.dart';
import 'cone_volume.dart';
import 'player_panel.dart';
import 'subtitle_overlay.dart';
import 'subtitle_style.dart';

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
  // libass on: mpv can draw picture subtitles (PGS, VobSub) itself. For text
  // tracks we switch mpv's drawing off and draw them ourselves (movable).
  late final Player _player = Player(
    configuration: const PlayerConfiguration(libass: true),
  );
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

  // --- audio / subtitle choice (remembered per show) ---
  int? _showId;
  TrackPref? _prefs;
  bool _prefsLoaded = false;
  bool _tracksApplied = false;
  Future<List<ExternalSub>> _externalSubs = Future.value(const []);
  List<ExternalSub> _externalList = const [];

  // --- subtitle placement (draggable, remembered) ---
  static const _subBaseBottom = 28.0;
  static const _barClearance = 84.0; // keeps subs above the control bar
  double _subBottom = _subBaseBottom;
  double _subDx = 0;
  Timer? _volumeSaveTimer;
  SubtitleStyle _subStyle = SubtitleStyle.defaults;
  Offset _lastMouse = Offset.zero;

  /// Picture-based subtitle (PGS/VobSub) selected: mpv draws it itself and
  /// our text overlay stays hidden.
  bool _bitmapSub = false;
  bool _subDragging = false;

  /// Open settings panel page, or null when closed.
  PanelPage? _panel;

  /// What mpv's own subtitle drawing is currently set to (starts on).
  bool _mpvDraws = true;

  bool get _tracking => widget.db != null && _episodeId != null;

  @override
  void initState() {
    super.initState();
    _episodeId = widget.episodeId;
    _title = widget.title;
    _player.stream.volume.listen((_) => setState(() {}));
    _loadSettings();
    _player.stream.playing.listen((playing) {
      if (playing) _pokeControls();
    });
    _player.stream.track.listen((_) => _syncSubtitleRender());
    _player.stream.tracks.listen((_) => _syncSubtitleRender());
    _pokeControls(); // start the idle-hide timer
    _player.stream.position.listen(_onPosition);
    _player.stream.completed.listen(_onCompleted);
    _player.stream.tracks.listen((_) => _maybeApplyTracks());
    final path = widget.initialPath;
    if (path != null) {
      _openMedia(path, start: widget.startAt);
      _hasMedia = true;
    }
    if (_tracking) {
      _saveTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _saveProgress(),
      );
      _player.stream.playing.listen((playing) {
        if (!playing) _saveProgress();
      });
      _loadContext();
    }
  }

  /// Restores the saved volume and subtitle position.
  Future<void> _loadSettings() async {
    final db = widget.db;
    if (db == null) return;
    final vol = double.tryParse(await db.getSetting(settingVolume) ?? '');
    final bottom = double.tryParse(await db.getSetting(settingSubBottom) ?? '');
    final dx = double.tryParse(await db.getSetting(settingSubDx) ?? '');
    final style = SubtitleStyle.decode(await db.getSetting(settingSubStyle));
    if (!mounted) return;
    _subStyle = style;
    if (vol != null) _player.setVolume(vol.clamp(0, 100));
    setState(() {
      if (bottom != null) _subBottom = bottom;
      if (dx != null) _subDx = dx;
    });
  }

  void _saveVolumeLater(double v) {
    final db = widget.db;
    if (db == null) return;
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => db.setSetting(settingVolume, v.toString()),
    );
  }

  /// Text subtitles are drawn by us (movable, styled). Picture subtitles
  /// can only be drawn by mpv, so switch its renderer on for those.
  Future<void> _syncSubtitleRender() async {
    final cur = _player.state.track.subtitle;
    var codec = cur.codec;
    for (final t in _player.state.tracks.subtitle) {
      if (t.id == cur.id && t.uri == cur.uri && t.codec != null) {
        codec = t.codec;
      }
    }
    final bitmap =
        cur.id != 'no' && cur.id != 'auto' && isBitmapSubtitleCodec(codec);
    if (bitmap != _bitmapSub && mounted) setState(() => _bitmapSub = bitmap);
    if (bitmap != _mpvDraws) {
      _mpvDraws = bitmap;
      await _setMpv('sub-visibility', bitmap ? 'yes' : 'no');
    }
    await _applyBitmapPos();
  }

  Future<void> _setMpv(String name, String value) async {
    final p = _player.platform;
    if (p is NativePlayer) {
      try {
        await p.setProperty(name, value);
      } catch (e) {
        debugPrint('mpv set $name failed: $e');
      }
    }
  }

  /// Keeps picture subtitles above the control bar while it is visible.
  Future<void> _applyBitmapPos() async {
    if (!_bitmapSub) return;
    await _setMpv('sub-pos', _controlsVisible ? '88' : '100');
  }

  void _saveSubStyle() =>
      widget.db?.setSetting(settingSubStyle, _subStyle.encode());

  void _openPanel(PanelPage page) {
    setState(() {
      _panel = page;
      _controlsVisible = true;
    });
    _hideTimer?.cancel();
    _applyBitmapPos();
  }

  void _closePanel() {
    if (_panel == null) return;
    setState(() => _panel = null);
    _saveSubStyle();
    _focus.requestFocus();
    _pokeControls();
  }

  void _resetSubPosition() {
    setState(() {
      _subBottom = _subBaseBottom;
      _subDx = 0;
    });
    _saveSubPosition();
  }

  void _saveSubPosition() {
    final db = widget.db;
    if (db == null) return;
    db.setSetting(settingSubBottom, _subBottom.toString());
    db.setSetting(settingSubDx, _subDx.toString());
  }

  void _openMedia(String path, {Duration? start}) {
    final resume = start != null && start > Duration.zero;
    _reachedStart = !resume;
    _pendingStart = resume ? start : null;
    _armed = false;
    _tracksApplied = false;
    _externalList = const [];
    _externalSubs = findExternalSubtitles(path).then((list) {
      if (mounted) setState(() => _externalList = list);
      return list;
    });
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
    final prefs = await db.getTrackPrefs(showId);
    if (!mounted || _episodeId != id) return;
    setState(() {
      _show = show;
      _showId = showId;
      _prefs = prefs;
      _prefsLoaded = true;
      _siblings = siblings;
      _next = _computeNext(ep);
    });
    _maybeApplyTracks();
  }

  // ---------------------------------------------------------------------
  // Audio and subtitle tracks

  List<TrackInfo> _embeddedAudio() => [
    for (final t in _player.state.tracks.audio)
      if (t.id != 'auto' && t.id != 'no')
        TrackInfo(
          id: t.id,
          title: t.title,
          language: t.language,
          isDefault: t.isDefault ?? false,
        ),
  ];

  List<TrackInfo> _embeddedSubs() => [
    for (final t in _player.state.tracks.subtitle)
      if (t.id != 'auto' && t.id != 'no' && !t.uri)
        TrackInfo(
          id: t.id,
          title: t.title,
          language: t.language,
          isDefault: t.isDefault ?? false,
        ),
  ];

  TrackInfo _externalInfo(ExternalSub e) => TrackInfo(
    id: e.path,
    title: e.title,
    language: e.language,
    isExternal: true,
  );

  /// Applies the show's remembered audio/subtitle choice once per opened
  /// file, after the new file's tracks are known.
  Future<void> _maybeApplyTracks() async {
    if (_tracksApplied || !_tracking || !_prefsLoaded || !_armed) return;
    final audio = _embeddedAudio();
    final subs = _embeddedSubs();
    if (audio.isEmpty && subs.isEmpty) return;
    _tracksApplied = true;
    final prefs = _prefs;
    if (prefs == null) return;

    final a = pickTrack(audio, prefs.audioChoice);
    if (a != null) {
      final t = _player.state.tracks.audio.firstWhere((x) => x.id == a.id);
      await _player.setAudioTrack(t);
    }

    final sc = prefs.subtitleChoice;
    if (sc.mode == ChoiceMode.off) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } else if (sc.mode == ChoiceMode.track) {
      final external = await _externalSubs;
      final picked = pickTrack([
        ...subs,
        for (final e in external) _externalInfo(e),
      ], sc);
      if (picked == null) return;
      if (picked.isExternal) {
        await _player.setSubtitleTrack(
          SubtitleTrack.uri(
            picked.id,
            title: picked.title,
            language: picked.language,
          ),
        );
      } else {
        final t = _player.state.tracks.subtitle.firstWhere(
          (x) => x.id == picked.id && !x.uri,
        );
        await _player.setSubtitleTrack(t);
      }
    }
  }

  Future<void> _rememberAudio(TrackChoice choice) async {
    final db = widget.db, showId = _showId;
    if (db == null || showId == null) return;
    await db.saveAudioChoice(showId, choice);
    _prefs = await db.getTrackPrefs(showId);
  }

  Future<void> _rememberSubtitle(TrackChoice choice) async {
    final db = widget.db, showId = _showId;
    if (db == null || showId == null) return;
    await db.saveSubtitleChoice(showId, choice);
    _prefs = await db.getTrackPrefs(showId);
  }

  Future<void> _pickAudio(AudioTrack t) async {
    _tracksApplied = true; // the user's pick beats the remembered one
    await _player.setAudioTrack(t);
    setState(() {});
    await _rememberAudio(
      t.id == 'auto'
          ? TrackChoice.auto
          : TrackChoice.fromTrack(
              TrackInfo(id: t.id, title: t.title, language: t.language),
            ),
    );
  }

  Future<void> _pickSubtitleOff() async {
    _tracksApplied = true;
    await _player.setSubtitleTrack(SubtitleTrack.no());
    setState(() {});
    await _rememberSubtitle(const TrackChoice(mode: ChoiceMode.off));
  }

  Future<void> _pickEmbeddedSubtitle(SubtitleTrack t) async {
    _tracksApplied = true;
    await _player.setSubtitleTrack(t);
    setState(() {});
    await _rememberSubtitle(
      TrackChoice.fromTrack(
        TrackInfo(id: t.id, title: t.title, language: t.language),
      ),
    );
  }

  Future<void> _pickExternalSubtitle(ExternalSub e) async {
    _tracksApplied = true;
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(e.path, title: e.title, language: e.language),
    );
    setState(() {});
    await _rememberSubtitle(TrackChoice.fromTrack(_externalInfo(e)));
  }

  /// One-off subtitle file chosen by hand. Not remembered for the show.
  Future<void> _loadSubtitleFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [for (final e in subtitleExtensions) e.substring(1)],
    );
    final path = file?.path;
    if (path == null) return;
    _tracksApplied = true;
    final guess = matchLooseSubtitleName(path);
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(path, title: guess?.title, language: guess?.language),
    );
    setState(() {});
    _focus.requestFocus();
  }

  List<PanelOption> _audioOptions() {
    final state = _player.state;
    final real = [
      for (final t in state.tracks.audio)
        if (t.id != 'auto' && t.id != 'no') t,
    ];
    if (real.isEmpty) return const [];
    return [
      PanelOption(
        label: 'Auto',
        selected: state.track.audio.id == 'auto',
        onTap: () => _pickAudio(AudioTrack.auto()),
      ),
      for (var i = 0; i < real.length; i++)
        PanelOption(
          label: TrackInfo(
            id: real[i].id,
            title: real[i].title,
            language: real[i].language,
          ).label(i),
          selected: state.track.audio.id == real[i].id,
          onTap: () => _pickAudio(real[i]),
        ),
    ];
  }

  List<PanelOption> _subtitleOptions() {
    final cur = _player.state.track.subtitle;
    final embedded = [
      for (final t in _player.state.tracks.subtitle)
        if (t.id != 'auto' && t.id != 'no' && !t.uri) t,
    ];
    return [
      PanelOption(
        label: 'Off',
        selected: cur.id == 'no',
        onTap: _pickSubtitleOff,
      ),
      for (var i = 0; i < embedded.length; i++)
        PanelOption(
          label: TrackInfo(
            id: embedded[i].id,
            title: embedded[i].title,
            language: embedded[i].language,
          ).label(i),
          selected: !cur.uri && cur.id == embedded[i].id,
          onTap: () => _pickEmbeddedSubtitle(embedded[i]),
        ),
      for (var i = 0; i < _externalList.length; i++)
        PanelOption(
          label: _externalInfo(_externalList[i]).label(i),
          selected: cur.uri && cur.id == _externalList[i].path,
          onTap: () => _pickExternalSubtitle(_externalList[i]),
        ),
    ];
  }

  String _selectedLabel(List<PanelOption> opts, String fallback) {
    for (final o in opts) {
      if (o.selected) return o.label;
    }
    return fallback;
  }

  /// V: cycle subtitles (off, then each embedded track).
  void _cycleSubtitles() {
    final tracks = [
      for (final t in _player.state.tracks.subtitle)
        if (t.id != 'auto' && t.id != 'no' && !t.uri) t,
    ];
    if (tracks.isEmpty) return;
    final cur = _player.state.track.subtitle;
    final i = cur.id == 'no' ? -1 : tracks.indexWhere((t) => t.id == cur.id);
    if (i + 1 >= tracks.length) {
      _pickSubtitleOff();
    } else {
      _pickEmbeddedSubtitle(tracks[i + 1]);
    }
  }

  /// B: cycle audio tracks.
  void _cycleAudio() {
    final tracks = [
      for (final t in _player.state.tracks.audio)
        if (t.id != 'auto' && t.id != 'no') t,
    ];
    if (tracks.length < 2) return;
    final cur = _player.state.track.audio;
    final i = tracks.indexWhere((t) => t.id == cur.id);
    _pickAudio(tracks[(i + 1) % tracks.length]);
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
      _maybeApplyTracks();
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
    _openMedia(
      next.filePath,
      start: resumeMs > 0 ? Duration(milliseconds: resumeMs) : null,
    );
    _advancing = false;
  }

  /// Captures position/duration synchronously, then writes in the background.
  void _saveProgress({bool atEnd = false}) {
    if (!_tracking || !_reachedStart || !_armed) return;
    final duration = _player.state.duration.inMilliseconds;
    final position = atEnd ? duration : _player.state.position.inMilliseconds;
    if (duration <= 0) return;
    widget.db!.saveProgress(
      _episodeId!,
      positionMs: position,
      durationMs: duration,
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _saveTimer?.cancel();
    _startGuardTimer?.cancel();
    _countdownTimer?.cancel();
    _hideTimer?.cancel();
    if (_volumeSaveTimer?.isActive ?? false) {
      _volumeSaveTimer!.cancel();
      widget.db?.setSetting(settingVolume, _player.state.volume.toString());
    }
    _focus.dispose();
    if (_fullscreen) defaultExitNativeFullscreen();
    _player.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    final file = await FilePicker.pickFile(type: FileType.video);
    final path = file?.path;
    if (path == null) return;
    _openMedia(path);
    setState(() => _hasMedia = true);
    _focus.requestFocus();
  }

  void _seekBy(Duration d) {
    final target = _player.state.position + d;
    final max = _player.state.duration;
    _player.seek(
      target < Duration.zero ? Duration.zero : (target > max ? max : target),
    );
  }

  void _setVolume(double v) {
    final c = v.clamp(0, 100).toDouble();
    _player.setVolume(c);
    _saveVolumeLater(c);
  }

  /// Mute is temporary: it is not saved, so the next start uses the last
  /// real volume.
  void _toggleMute() {
    if (_player.state.volume > 0) {
      _preMuteVolume = _player.state.volume;
      _player.setVolume(0);
    } else {
      _setVolume(_preMuteVolume > 0 ? _preMuteVolume : 100);
    }
  }

  Future<void> _setFullscreen(bool value) async {
    await (value ? _enterFullscreen() : _exitFullscreen());
    setState(() => _fullscreen = value);
  }

  Future<void> _enterFullscreen() => defaultEnterNativeFullscreen();
  Future<void> _exitFullscreen() => defaultExitNativeFullscreen();

  void _pokeControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _applyBitmapPos();
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _panel == null && _player.state.playing) {
        setState(() => _controlsVisible = false);
        _applyBitmapPos();
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (event.character == '?') {
      if (_panel == PanelPage.shortcuts) {
        _closePanel();
      } else {
        _openPanel(PanelPage.shortcuts);
      }
      return KeyEventResult.handled;
    }
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
      if (_panel != null) {
        _closePanel();
      } else if (_fullscreen) {
        _setFullscreen(false);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyO) {
      _openFile();
    } else if (key == LogicalKeyboardKey.keyV) {
      _cycleSubtitles();
    } else if (key == LogicalKeyboardKey.keyB) {
      _cycleAudio();
    } else if (key == LogicalKeyboardKey.keyN) {
      if (_next != null) _advance();
    } else {
      return KeyEventResult.ignored;
    }
    _pokeControls();
    return KeyEventResult.handled;
  }

  /// Subtitle text drawn by us so it can sit above the control bar and be
  /// dragged. Drag it anywhere; double-click resets the position.
  Widget _buildSubtitles() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          // While dragging, follow the pointer exactly (no lift, no easing).
          // The lift only applies to the default spot. Once the user has moved
          // the subtitles, their position is respected as-is (otherwise a drop
          // below the bar height snaps back up while the bar is visible).
          final moved = _subBottom != _subBaseBottom || _subDx != 0;
          final lift = _controlsVisible && !_subDragging && !moved
              ? _barClearance
              : 0.0;
          final bottom = _subBottom < lift ? lift : _subBottom;
          return StreamBuilder<List<String>>(
            stream: _player.stream.subtitle,
            initialData: _player.state.subtitle,
            builder: (context, snap) {
              final text = (snap.data ?? const <String>[])
                  .where((l) => l.trim().isNotEmpty)
                  .join('\n')
                  .trim();
              if (text.isEmpty) return const SizedBox.shrink();
              return SubtitleLayer(
                text: text,
                style: _subStyle,
                bottom: bottom,
                dx: _subDx,
                dragging: _subDragging,
                maxWidth: box.maxWidth * 0.8,
                onDragStart: () => setState(() {
                  // Start from where the text is shown right now.
                  _subBottom = bottom;
                  _subDragging = true;
                }),
                onDragUpdate: (d) => setState(() {
                  _subBottom = (_subBottom - d.dy).clamp(
                    0.0,
                    box.maxHeight - 60,
                  );
                  _subDx = (_subDx + d.dx).clamp(
                    -box.maxWidth / 2,
                    box.maxWidth / 2,
                  );
                }),
                onDragEnd: () {
                  setState(() => _subDragging = false);
                  _saveSubPosition();
                },
                onReset: () {
                  setState(() {
                    _subBottom = _subBaseBottom;
                    _subDx = 0;
                  });
                  _saveSubPosition();
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (e) {
          // Flutter re-sends hover when widgets move under a still cursor
          // (subtitles, progress); only real movement counts as activity.
          if ((e.position - _lastMouse).distance < 2) return;
          _lastMouse = e.position;
          _pokeControls();
        },
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
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    visible: false,
                  ),
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
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Ui.scrim, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Back (Esc)',
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                            if (_title != null)
                              Expanded(
                                child: Text(
                                  _title!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                        onPanel: _openPanel,
                      ),
                    ),
                  ),
                ),
              if (_hasMedia && _panel != null) ...[
                // Click on the video (not the bar) closes the panel.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: _barClearance,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closePanel,
                  ),
                ),
              ],
              // Above the control bar and the click-away region so the text
              // can always be grabbed and dragged, bar visible or not.
              if (_hasMedia && !_bitmapSub) _buildSubtitles(),
              if (_hasMedia && _panel != null) ...[
                Positioned(
                  right: Ui.s4,
                  bottom: _barClearance + Ui.s2,
                  child: PlayerPanel(
                    page: _panel!,
                    onPage: (p) => setState(() => _panel = p),
                    onClose: _closePanel,
                    subtitleOptions: _subtitleOptions(),
                    audioOptions: _audioOptions(),
                    currentSubtitle: _selectedLabel(_subtitleOptions(), 'Off'),
                    currentAudio: _selectedLabel(_audioOptions(), 'Auto'),
                    onLoadSubtitleFile: _loadSubtitleFile,
                    subtitleStyle: _subStyle,
                    onStyleChanged: (st) => setState(() => _subStyle = st),
                    onResetPosition: _resetSubPosition,
                  ),
                ),
              ],
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
        color: Ui.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Ui.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT EPISODE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 104,
                  height: 58,
                  child: ArtworkImage(
                    path: episode.stillFile,
                    cacheWidth: 208,
                    placeholderIcon: Icons.movie_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S${episode.season}E${episode.episode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      name ?? 'Episode ${episode.episode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          Text(
            'Starting in ${secondsLeft}s',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPlayNow,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play now'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
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
    required this.onPanel,
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

  /// Opens a page of the settings panel.
  final ValueChanged<PanelPage> onPanel;

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static const _iconSize = 24.0;

  static final _btnStyle = IconButton.styleFrom(
    padding: const EdgeInsets.all(4),
    minimumSize: const Size(36, 36),
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    final timeStyle = Theme.of(context).textTheme.bodySmall
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
              activeTrackColor: Ui.accent,
              inactiveTrackColor: const Color(0x33FFFFFF),
              thumbColor: Ui.accent,
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
                            value: position.inMilliseconds.toDouble().clamp(
                              0,
                              max > 0 ? max : 1,
                            ),
                            max: max > 0 ? max : 1,
                            onChanged: (v) =>
                                player.seek(Duration(milliseconds: v.round())),
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
                iconSize: _iconSize,
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: () => onSeekBy(const Duration(seconds: -10)),
              ),
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snap) => IconButton(
                  style: _btnStyle,
                  tooltip: 'Play / pause (Space)',
                  iconSize: 32,
                  icon: Icon(
                    (snap.data ?? false)
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: player.playOrPause,
                ),
              ),
              IconButton(
                style: _btnStyle,
                tooltip: 'Forward 10s (→)',
                iconSize: _iconSize,
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: () => onSeekBy(const Duration(seconds: 10)),
              ),
              if (onNext != null)
                IconButton(
                  style: _btnStyle,
                  tooltip: 'Next episode (N)',
                  iconSize: _iconSize,
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
                        icon: Icon(
                          v == 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                        onPressed: onToggleMute,
                      ),
                      const SizedBox(width: 4),
                      ConeVolumeSlider(
                        value: v,
                        onChanged: onVolume,
                        width: 100,
                        height: 22,
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              IconButton(
                style: _btnStyle,
                tooltip: 'Subtitles (V)',
                iconSize: _iconSize,
                icon: const Icon(Icons.closed_caption_outlined),
                onPressed: () => onPanel(PanelPage.subtitles),
              ),
              IconButton(
                style: _btnStyle,
                tooltip: 'Audio (B)',
                iconSize: _iconSize,
                icon: const Icon(Icons.audiotrack_outlined),
                onPressed: () => onPanel(PanelPage.audio),
              ),
              IconButton(
                style: _btnStyle,
                tooltip: 'Settings and shortcuts (?)',
                iconSize: _iconSize,
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => onPanel(PanelPage.root),
              ),
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
                iconSize: _iconSize,
                icon: Icon(
                  fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
                onPressed: onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
