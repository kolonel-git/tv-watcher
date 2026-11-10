import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/backup_service.dart';
import '../data/data_actions.dart';
import '../data/database.dart';
import '../settings/settings_controller.dart';
import '../settings/user_settings.dart';
import 'settings_widgets.dart';
import 'theme.dart';

/// Settings screen: every [UserSettings] field, saved as soon as it changes.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.db,
    this.actions = const PlatformDataActions(),
  });
  final AppDatabase db;

  /// File dialogs and Explorer; replaced in tests.
  final DataActions actions;

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.controllerOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: controller == null
          ? const Center(child: Text('Settings are not available.'))
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) =>
                  _Body(controller: controller, db: db, actions: actions),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.db,
    required this.actions,
  });
  final SettingsController controller;
  final AppDatabase db;
  final DataActions actions;

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

  void _say(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context) async {
    try {
      final json = await BackupService(db).exportJson();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final saved = await actions.saveBackup(
        'tv-watcher-backup-$stamp.json',
        utf8.encode(json),
      );
      if (context.mounted && saved) _say(context, 'Backup saved.');
    } catch (e) {
      if (context.mounted) _say(context, 'Could not save the backup: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final text = await actions.pickBackup();
      if (text == null) return;
      final file = BackupFile.parse(text);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: Text(
            '${file.episodes.length} episodes with watch progress and '
            '${file.settings.length} settings'
            '${file.exportedAt == null ? '' : ', saved ${file.exportedAt!.toLocal().toString().substring(0, 16)}'}.\n\n'
            'Where this computer has newer progress for an episode it is kept. '
            'Settings in the backup replace the current ones.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final report = await BackupService(db).restore(file);
      await controller.reload();
      if (context.mounted) {
        _say(
          context,
          'Restored ${report.restored} episodes'
          '${report.keptLocal > 0 ? ', kept ${report.keptLocal} newer here' : ''}'
          '${report.notInLibrary > 0 ? ', ${report.notInLibrary} not in this library' : ''}.',
        );
      }
    } on BackupFormatException catch (e) {
      if (context.mounted) _say(context, e.message);
    } catch (e) {
      if (context.mounted) _say(context, 'Could not read the backup: $e');
    }
  }

  Future<void> _openFolder(BuildContext context) async {
    try {
      await actions.openFolder(await actions.dataFolder());
    } catch (e) {
      if (context.mounted) _say(context, 'Could not open the folder: $e');
    }
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
                SwitchSetting(
                  title: 'Hardware decoding',
                  help: 'Let the GPU decode video. Turn off if it stutters.',
                  value: s.hardwareDecoding,
                  onChanged: (v) => _set(s.copyWith(hardwareDecoding: v)),
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
            SettingsSection(
              title: 'Data',
              rows: [
                SettingRow(
                  title: 'Back up progress and settings',
                  help: 'Saves a JSON file. No TMDB token, no media files.',
                  control: OutlinedButton(
                    onPressed: () => _export(context),
                    child: const Text('Export...'),
                  ),
                ),
                SettingRow(
                  title: 'Restore from a backup',
                  help: 'Keeps newer progress already on this computer.',
                  control: OutlinedButton(
                    onPressed: () => _import(context),
                    child: const Text('Import...'),
                  ),
                ),
                SettingRow(
                  title: 'Data folder',
                  help: 'Where the library database is stored.',
                  control: OutlinedButton(
                    onPressed: () => _openFolder(context),
                    child: const Text('Open'),
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: 'About',
              rows: [
                SettingRow(
                  title: '$appName $appVersion (build $appBuild)',
                  help:
                      'Local only: no accounts, no telemetry. The only network '
                      'calls go to TMDB for show information and artwork.',
                  control: const SizedBox.shrink(),
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
