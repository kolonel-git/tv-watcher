import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'playback_options.dart';

/// Panel page for per-viewing tweaks: speed, aspect, subtitle and audio
/// delay, and the hardware decoding switch.
class PlaybackPanelPage extends StatelessWidget {
  const PlaybackPanelPage({
    super.key,
    required this.options,
    required this.onOptions,
    required this.hardwareDecoding,
    required this.onHardwareDecoding,
  });

  final PlaybackOptions options;
  final ValueChanged<PlaybackOptions> onOptions;
  final bool hardwareDecoding;
  final ValueChanged<bool> onHardwareDecoding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Ui.s4, Ui.s3, Ui.s4, Ui.s2),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: Ui.muted,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget chips<T>(
      List<T> values,
      T selected,
      String Function(T) text,
      ValueChanged<T> onPick,
    ) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Ui.s4),
      child: Wrap(
        spacing: Ui.s2,
        runSpacing: Ui.s2,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(text(v)),
              selected: v == selected,
              onSelected: (_) => onPick(v),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('Speed  ([ and ])'),
        chips<double>(
          PlaybackOptions.speeds,
          options.speed,
          PlaybackOptions.speedLabel,
          (v) => onOptions(options.copyWith(speed: v)),
        ),
        label('Aspect ratio'),
        chips<AspectMode>(
          AspectMode.values,
          options.aspect,
          (a) => a.label,
          (v) => onOptions(options.copyWith(aspect: v)),
        ),
        label('Subtitle delay  (Z and X)'),
        _DelayRow(
          keyPrefix: 'sub',
          ms: options.subtitleDelayMs,
          onChanged: (v) => onOptions(options.copyWith(subtitleDelayMs: v)),
        ),
        label('Audio delay'),
        _DelayRow(
          keyPrefix: 'audio',
          ms: options.audioDelayMs,
          onChanged: (v) => onOptions(options.copyWith(audioDelayMs: v)),
        ),
        const Divider(height: Ui.s5),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: Ui.s4),
          title: const Text('Hardware decoding'),
          subtitle: const Text(
            'Turn off if video stutters or shows artefacts.',
          ),
          value: hardwareDecoding,
          onChanged: onHardwareDecoding,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Ui.s4, 0, Ui.s4, Ui.s2),
          child: TextButton(
            onPressed: options.isDefault
                ? null
                : () => onOptions(PlaybackOptions.defaults),
            child: const Text('Reset speed, aspect and delays'),
          ),
        ),
      ],
    );
  }
}

/// `-` value `+` stepper for a delay in 0.1 s steps; tapping the value
/// resets it to zero.
class _DelayRow extends StatelessWidget {
  const _DelayRow({
    required this.keyPrefix,
    required this.ms,
    required this.onChanged,
  });
  final String keyPrefix;
  final int ms;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const step = PlaybackOptions.delayStepMs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Ui.s2),
      child: Row(
        children: [
          IconButton(
            key: Key('$keyPrefix-delay-minus'),
            tooltip: 'Earlier (-0.1 s)',
            icon: const Icon(Icons.remove_rounded),
            onPressed: () => onChanged(ms - step),
          ),
          Expanded(
            child: TextButton(
              key: Key('$keyPrefix-delay-value'),
              onPressed: ms == 0 ? null : () => onChanged(0),
              child: Text(PlaybackOptions.delayLabel(ms)),
            ),
          ),
          IconButton(
            key: Key('$keyPrefix-delay-plus'),
            tooltip: 'Later (+0.1 s)',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => onChanged(ms + step),
          ),
        ],
      ),
    );
  }
}
