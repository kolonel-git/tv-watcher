import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../ui/theme.dart';
import 'cone_volume.dart';
import 'player_config.dart';
import 'player_panel.dart';

/// Bottom control bar: seek slider, transport, volume, panel shortcuts.
class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.player,
    required this.fullscreen,
    required this.onOpen,
    required this.onToggleMute,
    required this.onVolume,
    required this.onSeekBy,
    required this.onFullscreen,
    this.onNext,
    required this.onPanel,
    this.config = PlayerConfig.defaults,
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
  final PlayerConfig config;

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
                tooltip: 'Back ${config.seekStep.inSeconds}s (←)',
                iconSize: _iconSize,
                icon: SeekIcon(
                  seconds: config.seekStep.inSeconds,
                  forward: false,
                ),
                onPressed: () => onSeekBy(-config.seekStep),
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
                tooltip: 'Forward ${config.seekStep.inSeconds}s (→)',
                iconSize: _iconSize,
                icon: SeekIcon(
                  seconds: config.seekStep.inSeconds,
                  forward: true,
                ),
                onPressed: () => onSeekBy(config.seekStep),
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

/// Circular-arrow seek icon showing the actual step, so it stays correct when
/// the skip step is changed in settings (the built-in replay_10 icons are
/// fixed at 10).
class SeekIcon extends StatelessWidget {
  const SeekIcon({super.key, required this.seconds, required this.forward});
  final int seconds;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    final arrow = Icon(Icons.replay_rounded, size: size);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          forward ? Transform.flip(flipX: true, child: arrow) : arrow,
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$seconds',
              key: const Key('seek-seconds'),
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
