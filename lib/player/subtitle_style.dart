import 'dart:convert';

import 'package:flutter/material.dart';

/// How subtitles look. Saved as one JSON string in the settings table.
class SubtitleStyle {
  const SubtitleStyle({
    this.size = 26,
    this.colorValue = 0xFFFFFFFF,
    this.backgroundOpacity = 0.4,
    this.bold = true,
    this.outline = true,
  });

  static const defaults = SubtitleStyle();
  static const minSize = 14.0;
  static const maxSize = 64.0;

  /// Colors offered in the settings (ARGB).
  static const colors = <int>[
    0xFFFFFFFF, // white
    0xFFFFE066, // yellow
    0xFF7CE7FF, // cyan
    0xFF8CFF8C, // green
    0xFFFF9EC7, // pink
  ];

  final double size;
  final int colorValue;
  final double backgroundOpacity;
  final bool bold;
  final bool outline;

  Color get color => Color(colorValue);

  SubtitleStyle copyWith({
    double? size,
    int? colorValue,
    double? backgroundOpacity,
    bool? bold,
    bool? outline,
  }) => SubtitleStyle(
    size: size ?? this.size,
    colorValue: colorValue ?? this.colorValue,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    bold: bold ?? this.bold,
    outline: outline ?? this.outline,
  );

  TextStyle get textStyle => TextStyle(
    fontSize: size,
    height: 1.25,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
    shadows: outline
        ? const [
            Shadow(blurRadius: 2, color: Colors.black),
            Shadow(blurRadius: 5, color: Colors.black),
            Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black),
            Shadow(offset: Offset(-1, -1), blurRadius: 1, color: Colors.black),
          ]
        : null,
  );

  Color get backgroundColor =>
      Colors.black.withValues(alpha: backgroundOpacity);

  String encode() => jsonEncode({
    'size': size,
    'color': colorValue,
    'bg': backgroundOpacity,
    'bold': bold,
    'outline': outline,
  });

  /// Tolerant: bad or missing input gives defaults, bad fields are ignored.
  static SubtitleStyle decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return defaults;
      double? num01(Object? v, double lo, double hi) =>
          v is num ? v.toDouble().clamp(lo, hi) : null;
      return SubtitleStyle(
        size: num01(m['size'], minSize, maxSize) ?? defaults.size,
        colorValue: m['color'] is int ? m['color'] as int : defaults.colorValue,
        backgroundOpacity: num01(m['bg'], 0, 0.9) ?? defaults.backgroundOpacity,
        bold: m['bold'] is bool ? m['bold'] as bool : defaults.bold,
        outline: m['outline'] is bool ? m['outline'] as bool : defaults.outline,
      );
    } catch (_) {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SubtitleStyle &&
      other.size == size &&
      other.colorValue == colorValue &&
      other.backgroundOpacity == backgroundOpacity &&
      other.bold == bold &&
      other.outline == outline;

  @override
  int get hashCode =>
      Object.hash(size, colorValue, backgroundOpacity, bold, outline);
}

/// Panel with live-preview controls. [onChanged] fires on every edit.
class SubtitleSettingsPanel extends StatefulWidget {
  const SubtitleSettingsPanel({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onResetPosition,
    this.showTitle = true,
    this.width = 320,
  });

  final SubtitleStyle initial;
  final ValueChanged<SubtitleStyle> onChanged;

  /// Puts the subtitles back at their default spot (bottom centre).
  final VoidCallback? onResetPosition;

  /// Show the title row (off when embedded in a panel that has a header).
  final bool showTitle;

  /// Fixed width, or null to fill the parent.
  final double? width;

  @override
  State<SubtitleSettingsPanel> createState() => _SubtitleSettingsPanelState();
}

class _SubtitleSettingsPanelState extends State<SubtitleSettingsPanel> {
  late SubtitleStyle _s = widget.initial;

  void _set(SubtitleStyle s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: widget.width,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.showTitle)
                  Expanded(
                    child: Text(
                      'Subtitle settings',
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: () => _set(SubtitleStyle.defaults),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Size  ${_s.size.round()}', style: theme.textTheme.bodySmall),
            Slider(
              key: const Key('sub-size'),
              value: _s.size,
              min: SubtitleStyle.minSize,
              max: SubtitleStyle.maxSize,
              onChanged: (v) => _set(_s.copyWith(size: v.roundToDouble())),
            ),
            Text(
              'Background  ${(_s.backgroundOpacity * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              key: const Key('sub-bg'),
              value: _s.backgroundOpacity,
              min: 0,
              max: 0.9,
              onChanged: (v) => _set(_s.copyWith(backgroundOpacity: v)),
            ),
            const SizedBox(height: 4),
            Text('Color', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                for (final c in SubtitleStyle.colors)
                  InkWell(
                    key: Key('sub-color-$c'),
                    customBorder: const CircleBorder(),
                    onTap: () => _set(_s.copyWith(colorValue: c)),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _s.colorValue == c
                              ? theme.colorScheme.primary
                              : Colors.white24,
                          width: _s.colorValue == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('sub-bold'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Bold'),
              value: _s.bold,
              onChanged: (v) => _set(_s.copyWith(bold: v)),
            ),
            SwitchListTile(
              key: const Key('sub-outline'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Outline / shadow'),
              value: _s.outline,
              onChanged: (v) => _set(_s.copyWith(outline: v)),
            ),
            if (widget.onResetPosition != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('sub-reset-pos'),
                  onPressed: widget.onResetPosition,
                  icon: const Icon(Icons.vertical_align_bottom, size: 18),
                  label: const Text('Reset position'),
                ),
              ),
            Text(
              'Tip: drag subtitles to move them, double-click to reset.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
