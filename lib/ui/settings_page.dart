import 'package:flutter/material.dart';

import '../settings/settings_controller.dart';
import '../settings/user_settings.dart';
import 'settings_widgets.dart';
import 'theme.dart';

/// Settings screen: every [UserSettings] field, saved as soon as it changes.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.controllerOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: controller == null
          ? const Center(child: Text('Settings are not available.'))
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _Body(controller: controller),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final SettingsController controller;

  UserSettings get s => controller.value;
  void _set(UserSettings next) => controller.update(next);

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all settings?'),
        content: const Text(
          'Every setting on this page goes back to its default. Your '
          'library, watch progress and subtitle choices are not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final langs = <(String?, String)>[
      (null, 'Default (${controller.envLanguage})'),
      for (final (code, name) in metadataLanguages) (code, '$name ($code)'),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ui.s5, Ui.s4, Ui.s5, Ui.s6),
          children: [
            SettingsSection(
              title: 'Playback',
              rows: [
                SwitchSetting(
                  title: 'Autoplay next episode',
                  help: 'Show the next-episode card and play it automatically.',
                  value: s.autoplay,
                  onChanged: (v) => _set(s.copyWith(autoplay: v)),
                ),
                SliderSetting(
                  title: 'Card appears before the end',
                  value: s.autoplayLeadSeconds,
                  min: UserSettings.leadRange.$1,
                  max: UserSettings.leadRange.$2,
                  unit: ' s',
                  enabled: s.autoplay,
                  onChanged: (v) => _set(s.copyWith(autoplayLeadSeconds: v)),
                ),
                SliderSetting(
                  title: 'Countdown length',
                  value: s.autoplayCountdownSeconds,
                  min: UserSettings.countdownRange.$1,
                  max: UserSettings.countdownRange.$2,
                  unit: ' s',
                  enabled: s.autoplay,
                  onChanged: (v) =>
                      _set(s.copyWith(autoplayCountdownSeconds: v)),
                ),
                ChoiceSetting<ResumeBehavior>(
                  title: 'When an episode was left partway',
                  help: 'Autoplay never asks; it resumes unless set to start over.',
                  value: s.resume,
                  options: [
                    for (final r in ResumeBehavior.values) (r, r.label),
                  ],
                  onChanged: (v) => _set(s.copyWith(resume: v)),
                ),
                ChoiceSetting<int>(
                  title: 'Skip step',
                  help: 'Arrow keys and the skip buttons.',
                  value: s.skipStepSeconds,
                  options: [
                    for (final v in UserSettings.skipSteps) (v, '$v seconds'),
                  ],
                  onChanged: (v) => _set(s.copyWith(skipStepSeconds: v)),
                ),
                SliderSetting(
                  title: 'Hide controls after',
                  help: 'Idle time before the control bar fades.',
                  value: s.controlsHideSeconds,
                  min: UserSettings.hideRange.$1,
                  max: UserSettings.hideRange.$2,
                  unit: ' s',
                  onChanged: (v) => _set(s.copyWith(controlsHideSeconds: v)),
                ),
                SliderSetting(
                  title: 'Counts as watched at',
                  help:
                      'Share of an episode played before it is marked watched.',
                  value: s.watchedPercent,
                  min: UserSettings.watchedRange.$1,
                  max: UserSettings.watchedRange.$2,
                  unit: ' %',
                  onChanged: (v) => _set(s.copyWith(watchedPercent: v)),
                ),
                ChoiceSetting<VolumeMode>(
                  title: 'Starting volume',
                  value: s.volumeMode,
                  options: [for (final m in VolumeMode.values) (m, m.label)],
                  onChanged: (v) => _set(s.copyWith(volumeMode: v)),
                ),
                SliderSetting(
                  title: 'Fixed volume',
                  value: s.fixedVolume,
                  min: UserSettings.volumeRange.$1,
                  max: UserSettings.volumeRange.$2,
                  unit: ' %',
                  enabled: s.volumeMode == VolumeMode.fixed,
                  onChanged: (v) => _set(s.copyWith(fixedVolume: v)),
                ),
              ],
            ),
            SettingsSection(
              title: 'Library',
              rows: [
                ChoiceSetting<String?>(
                  title: 'Metadata language',
                  help:
                      'Used for titles and descriptions fetched from now on. '
                      'Use Refresh metadata on a show to re-fetch it.',
                  value: s.metadataLanguage,
                  options: langs,
                  onChanged: (v) => _set(
                    v == null
                        ? s.copyWith(clearMetadataLanguage: true)
                        : s.copyWith(metadataLanguage: v),
                  ),
                ),
                ChoiceSetting<ShowSort>(
                  title: 'Home sort order',
                  value: s.homeSort,
                  options: [for (final o in ShowSort.values) (o, o.label)],
                  onChanged: (v) => _set(s.copyWith(homeSort: v)),
                ),
                ChoiceSetting<PosterSize>(
                  title: 'Poster size',
                  value: s.posterSize,
                  options: [for (final p in PosterSize.values) (p, p.label)],
                  onChanged: (v) => _set(s.copyWith(posterSize: v)),
                ),
                SwitchSetting(
                  title: 'Show specials',
                  help: 'Season 0 episodes on the show page.',
                  value: s.showSpecials,
                  onChanged: (v) => _set(s.copyWith(showSpecials: v)),
                ),
                SwitchSetting(
                  title: 'Show missing files',
                  help: 'List episodes whose file is gone, greyed out.',
                  value: s.showMissing,
                  onChanged: (v) => _set(s.copyWith(showMissing: v)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset all settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
