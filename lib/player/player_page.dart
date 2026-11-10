import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/database.dart';
import '../tracks/external_subs.dart';
import '../tracks/track_prefs.dart';
import '../ui/play.dart';
import '../ui/theme.dart';
import '../watch/autoplay.dart';
import '../watch/watch_logic.dart';
import 'control_bar.dart';
import 'mpv_properties.dart';
import 'next_episode_card.dart';
import 'player_config.dart';
import 'player_panel.dart';
import 'player_shortcuts.dart';
import 'progress_gate.dart';
import 'subtitle_overlay.dart';
import 'subtitle_placement.dart';
import 'subtitle_style.dart';
import 'track_catalog.dart';

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
    this.config = PlayerConfig.defaults,
  });

  /// File to start playing immediately (from the library).
  final String? initialPath;
  final String? title;

  /// When both are set, progress is saved and the next episode is offered.
  final AppDatabase? db;
  final int? episodeId;

  /// Resume point. Null or zero = start from the beginning.
  final Duration? startAt;

  /// Tunable numbers (steps, delays, subtitle spacing).
  final PlayerConfig config;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> implements PlayerCommands {
  PlayerConfig get _cfg => widget.config;

  // libass on: mpv can draw picture subtitles (PGS, VobSub) itself. For text
  // tracks we switch mpv's drawing off and draw them ourselves (movable).
  late final Player _player = Player(
    configuration: const PlayerConfiguration(libass: true),
  );
  late final VideoController _video = VideoController(_player);
  late final MpvProperties _mpv = MpvProperties(_player);
  late final TrackCatalog _tracksOf = TrackCatalog(_player);
  late final ProgressGate _gate = ProgressGate(
    startTolerance: _cfg.startTolerance,
    startGuard: _cfg.startGuard,
    armedBelowFraction: _cfg.armedBelowFraction,
  );
  late final SubtitlePlacement _placement = SubtitlePlacement(
    baseBottom: _cfg.subBaseBottom,
    barClearance: _cfg.barClearance,
  );
  static const _shortcuts = PlayerShortcuts();
  final FocusNode _focus = FocusNode();

  bool _fullscreen = false;
  bool _controlsVisible = true;
  bool _hasMedia = false;
  late double _preMuteVolume = _cfg.defaultVolume;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _countdownTimer;
  Timer? _volumeSaveTimer;

  // --- episode context (library playback only) ---
  int? _episodeId;
  String? _title;
  Show? _show;
  List<Episode> _siblings = const [];
  Episode? _next;
  final AutoplayState _autoplay = AutoplayState();
  bool _advancing = false;

  // --- audio / subtitle choice (remembered per show) ---
  int? _showId;
  TrackPref? _prefs;
  bool _prefsLoaded = false;
  bool _tracksApplied = false;
  Future<List<ExternalSub>> _externalSubs = Future.value(const []);
  List<ExternalSub> _externalList = const [];

  SubtitleStyle _subStyle = SubtitleStyle.defaults;
  Offset _lastMouse = Offset.zero;

  /// Picture-based subtitle (PGS/VobSub) selected: mpv draws it itself and
  /// our text overlay stays hidden.
  bool _bitmapSub = false;

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
    _placement.addListener(_onPlacementChanged);
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
        _cfg.progressSaveInterval,
        (_) => _saveProgress(),
      );
      _player.stream.playing.listen((playing) {
        if (!playing) _saveProgress();
      });
      _loadContext();
    }
  }

  void _onPlacementChanged() {
    if (mounted) setState(() {});
  }

  /// Restores the saved volume, subtitle look and subtitle position.
  Future<void> _loadSettings() async {
    final db = widget.db;
    if (db == null) return;
    final vol = double.tryParse(await db.getSetting(settingVolume) ?? '');
    final style = SubtitleStyle.decode(await db.getSetting(settingSubStyle));
    if (!mounted) return;
    _subStyle = style;
    if (vol != null) _player.setVolume(vol.clamp(0, 100));
    await _placement.load(db);
  }

  void _saveVolumeLater(double v) {
    final db = widget.db;
    if (db == null) return;
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(
      _cfg.volumeSaveDebounce,
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
      await _mpv.set('sub-visibility', bitmap ? 'yes' : 'no');
    }
    await _applyBitmapPos();
  }

  /// Keeps picture subtitles above the control bar while it is visible.
  Future<void> _applyBitmapPos() async {
    if (!_bitmapSub) return;
    final pos = _controlsVisible
        ? _cfg.bitmapSubPosVisible
        : _cfg.bitmapSubPosHidden;
    await _mpv.set('sub-pos', '$pos');
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
    _placement.reset();
    _placement.save(widget.db);
  }

  void _openMedia(String path, {Duration? start}) {
    _gate.begin(start);
    _tracksApplied = false;
    _externalList = const [];
    _externalSubs = findExternalSubtitles(path).then((list) {
      if (mounted) setState(() => _externalList = list);
      return list;
    });
    final resume = start != null && start > Duration.zero;
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

  /// Applies the show's remembered audio/subtitle choice once per opened
  /// file, after the new file's tracks are known.
  Future<void> _maybeApplyTracks() async {
    if (_tracksApplied || !_tracking || !_prefsLoaded || !_gate.armed) return;
    final audio = _tracksOf.audioInfos;
    final subs = _tracksOf.subtitleInfos;
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
        for (final e in external) TrackCatalog.externalInfo(e),
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
          : TrackChoice.fromTrack(TrackCatalog.audioInfo(t)),
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
      TrackChoice.fromTrack(TrackCatalog.subtitleInfo(t)),
    );
  }

  Future<void> _pickExternalSubtitle(ExternalSub e) async {
    _tracksApplied = true;
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(e.path, title: e.title, language: e.language),
    );
    setState(() {});
    await _rememberSubtitle(
      TrackChoice.fromTrack(TrackCatalog.externalInfo(e)),
    );
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
    final real = _tracksOf.audio;
    if (real.isEmpty) return const [];
    final curId = _player.state.track.audio.id;
    return [
      PanelOption(
        label: 'Auto',
        selected: curId == 'auto',
        onTap: () => _pickAudio(AudioTrack.auto()),
      ),
      for (var i = 0; i < real.length; i++)
        PanelOption(
          label: TrackCatalog.audioInfo(real[i]).label(i),
          selected: curId == real[i].id,
          onTap: () => _pickAudio(real[i]),
        ),
    ];
  }

  List<PanelOption> _subtitleOptions() {
    final cur = _player.state.track.subtitle;
    final embedded = _tracksOf.embeddedSubtitles;
    return [
      PanelOption(
        label: 'Off',
        selected: cur.id == 'no',
        onTap: _pickSubtitleOff,
      ),
      for (var i = 0; i < embedded.length; i++)
        PanelOption(
          label: TrackCatalog.subtitleInfo(embedded[i]).label(i),
          selected: !cur.uri && cur.id == embedded[i].id,
          onTap: () => _pickEmbeddedSubtitle(embedded[i]),
        ),
      for (var i = 0; i < _externalList.length; i++)
        PanelOption(
          label: TrackCatalog.externalInfo(_externalList[i]).label(i),
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

  // ---------------------------------------------------------------------
  // Next episode and progress

  /// Next regular episode: same season, else first of the next season.
  /// Specials and missing files are skipped; null at the end of the show.
  Episode? _computeNext(Episode current) {
    final n = nextInOrder(_siblings.map(episodeRef), episodeRef(current));
    if (n == null) return null;
    return _siblings.firstWhere((e) => e.id == n.id);
  }

  void _onPosition(Duration p) {
    final durMs = _player.state.duration.inMilliseconds;
    if (_gate.onPosition(p, _player.state.duration)) _maybeApplyTracks();
    if (!_tracking || !_gate.trusted || _advancing) return;
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
        _gate.armed) {
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
    if (!_tracking || !_gate.trusted) return;
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
    _gate.dispose();
    _countdownTimer?.cancel();
    _hideTimer?.cancel();
    if (_volumeSaveTimer?.isActive ?? false) {
      _volumeSaveTimer!.cancel();
      widget.db?.setSetting(settingVolume, _player.state.volume.toString());
    }
    _placement.removeListener(_onPlacementChanged);
    _placement.dispose();
    _focus.dispose();
    if (_fullscreen) defaultExitNativeFullscreen();
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // PlayerCommands (keyboard and buttons)

  @override
  void playPause() => _player.playOrPause();

  @override
  void seek(int direction) => _seekBy(_cfg.seekStep * direction);

  @override
  void changeVolume(int direction) =>
      _setVolume(_player.state.volume + _cfg.volumeStep * direction);

  @override
  void toggleFullscreen() => _setFullscreen(!_fullscreen);

  @override
  void toggleMute() {
    // Mute is temporary: it is not saved, so the next start uses the last
    // real volume.
    if (_player.state.volume > 0) {
      _preMuteVolume = _player.state.volume;
      _player.setVolume(0);
    } else {
      _setVolume(_preMuteVolume > 0 ? _preMuteVolume : _cfg.defaultVolume);
    }
  }

  @override
  Future<void> openFile() async {
    final file = await FilePicker.pickFile(type: FileType.video);
    final path = file?.path;
    if (path == null) return;
    _openMedia(path);
    setState(() => _hasMedia = true);
    _focus.requestFocus();
  }

  /// V: cycle subtitles (off, then each embedded track).
  @override
  void cycleSubtitles() {
    if (!_tracksOf.hasSubtitles) return;
    final next = _tracksOf.nextSubtitle();
    if (next == null) {
      _pickSubtitleOff();
    } else {
      _pickEmbeddedSubtitle(next);
    }
  }

  /// B: cycle audio tracks.
  @override
  void cycleAudio() {
    final next = _tracksOf.nextAudio();
    if (next != null) _pickAudio(next);
  }

  @override
  void nextEpisode() {
    if (_next != null) _advance();
  }

  @override
  void toggleShortcutHelp() {
    if (_panel == PanelPage.shortcuts) {
      _closePanel();
    } else {
      _openPanel(PanelPage.shortcuts);
    }
  }

  @override
  void escape() {
    if (_panel != null) {
      _closePanel();
    } else if (_fullscreen) {
      _setFullscreen(false);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
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

  Future<void> _setFullscreen(bool value) async {
    await (value
        ? defaultEnterNativeFullscreen()
        : defaultExitNativeFullscreen());
    setState(() => _fullscreen = value);
  }

  void _pokeControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _applyBitmapPos();
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_cfg.controlsHideDelay, () {
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
    if (!_shortcuts.dispatch(event.logicalKey, event.character, this)) {
      return KeyEventResult.ignored;
    }
    _pokeControls();
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------
  // Widgets

  /// Subtitle text drawn by us so it can sit above the control bar and be
  /// dragged. Drag it anywhere; double-click resets the position.
  Widget _buildSubtitles() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          final bottom = _placement.effectiveBottom(
            controlsVisible: _controlsVisible,
          );
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
                dx: _placement.dx,
                dragging: _placement.dragging,
                maxWidth: box.maxWidth * _cfg.subMaxWidthFraction,
                onDragStart: () => _placement.startDrag(shownBottom: bottom),
                onDragUpdate: (d) => _placement.dragBy(
                  d,
                  area: Size(box.maxWidth, box.maxHeight),
                ),
                onDragEnd: () {
                  _placement.endDrag();
                  _placement.save(widget.db);
                },
                onReset: _resetSubPosition,
              );
            },
          );
        },
      ),
    );
  }

  Widget _fading({required Widget child}) => AnimatedOpacity(
    opacity: _controlsVisible ? 1 : 0,
    duration: _cfg.controlsFade,
    child: IgnorePointer(ignoring: !_controlsVisible, child: child),
  );

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: _fading(
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Positioned(
      right: Ui.s4,
      bottom: _cfg.barClearance + Ui.s2,
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
          // The player is a video surface with its own keyboard shortcuts.
          // Its constantly changing overlays (control bar fade, subtitles,
          // position slider) made Flutter's Windows accessibility bridge log
          // hundreds of 'Failed to update ui::AXTree' errors, so they are
          // kept out of the semantics tree.
          body: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_hasMedia) _player.playOrPause();
                    _pokeControls();
                  },
                  onDoubleTap: toggleFullscreen,
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
                      onPressed: openFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Open video file'),
                    ),
                  ),
                if (_hasMedia && Navigator.canPop(context)) _buildTopBar(),
                if (_hasMedia)
                  _fading(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ControlBar(
                        player: _player,
                        fullscreen: _fullscreen,
                        config: _cfg,
                        onOpen: openFile,
                        onToggleMute: toggleMute,
                        onVolume: _setVolume,
                        onSeekBy: _seekBy,
                        onFullscreen: toggleFullscreen,
                        onNext: _next == null ? null : _advance,
                        onPanel: _openPanel,
                      ),
                    ),
                  ),
                if (_hasMedia && _panel != null)
                  // Click on the video (not the bar) closes the panel.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: _cfg.barClearance,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _closePanel,
                    ),
                  ),
                // Above the control bar and the click-away region so the text
                // can always be grabbed and dragged, bar visible or not.
                if (_hasMedia && !_bitmapSub) _buildSubtitles(),
                if (_hasMedia && _panel != null) _buildPanel(),
                if (_autoplay.showing && _next != null)
                  Positioned(
                    right: 24,
                    bottom: _controlsVisible
                        ? _cfg.nextCardBottomWithBar
                        : _cfg.nextCardBottomNoBar,
                    child: NextEpisodeCard(
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
      ),
    );
  }
}
