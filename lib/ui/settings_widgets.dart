import 'package:flutter/material.dart';

import 'theme.dart';

/// A titled group of setting rows on one surface.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Ui.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Ui.s1, bottom: Ui.s2),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Ui.muted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: Ui.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Ui.rMd),
              side: const BorderSide(color: Ui.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label (and optional help text) on the left, a control on the right.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.help,
    required this.control,
    this.enabled = true,
  });
  final String title;
  final String? help;
  final Widget control;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Ui.s4,
            vertical: Ui.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium),
                    if (help != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          help!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Ui.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Ui.s4),
              control,
            ],
          ),
        ),
      ),
    );
  }
}

/// On/off row.
class SwitchSetting extends StatelessWidget {
  const SwitchSetting({
    super.key,
    required this.title,
    this.help,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final String title;
  final String? help;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SettingRow(
    title: title,
    help: help,
    enabled: enabled,
    control: Switch(value: value, onChanged: onChanged),
  );
}

/// Pick one of a few options from a dropdown.
class ChoiceSetting<T> extends StatelessWidget {
  const ChoiceSetting({
    super.key,
    required this.title,
    this.help,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });
  final String title;
  final String? help;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SettingRow(
    title: title,
    help: help,
    enabled: enabled,
    control: SizedBox(
      width: 260,
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyMedium,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(Ui.rMd),
        dropdownColor: Ui.surfaceHigh,
        items: [
          for (final (v, label) in options)
            DropdownMenuItem<T>(
              value: v,
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

/// Whole-number slider. Shows the value while dragging and saves once, when
/// the drag ends, so a drag is one write rather than dozens.
class SliderSetting extends StatefulWidget {
  const SliderSetting({
    super.key,
    required this.title,
    this.help,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
    this.enabled = true,
  });
  final String title;
  final String? help;
  final int value;
  final int min;
  final int max;
  final String unit;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  State<SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<SliderSetting> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final shown = _drag ?? widget.value.toDouble();
    return SettingRow(
      title: widget.title,
      help: widget.help,
      enabled: widget.enabled,
      control: SizedBox(
        width: 280,
        child: Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context)
                    .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
                child: Slider(
                  value: shown.clamp(
                    widget.min.toDouble(),
                    widget.max.toDouble(),
                  ),
                  min: widget.min.toDouble(),
                  max: widget.max.toDouble(),
                  divisions: widget.max - widget.min,
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    setState(() => _drag = null);
                    widget.onChanged(v.round());
                  },
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${shown.round()}${widget.unit}',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
