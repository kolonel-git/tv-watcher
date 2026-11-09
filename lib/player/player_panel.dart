import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'subtitle_style.dart';

enum PanelPage { root, subtitles, audio, appearance, shortcuts }

/// One selectable row in the subtitle / audio lists.
class PanelOption {
  const PanelOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
}

const shortcutList = <(String, String)>[
  ('Space', 'Play / pause'),
  ('← →', 'Back / forward 10 s'),
  ('↑ ↓', 'Volume'),
  ('M', 'Mute'),
  ('F', 'Fullscreen'),
  ('N', 'Next episode'),
  ('V', 'Cycle subtitles'),
  ('B', 'Cycle audio'),
  ('O', 'Open a file'),
  ('?', 'This list'),
  ('Esc', 'Close panel, leave fullscreen, go back'),
];

/// Settings panel docked above the control bar: subtitles, audio, subtitle
/// appearance and shortcuts as pages of one surface. Replaces separate popup
/// menus and dialogs so nothing floats away from its button.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.page,
    required this.onPage,
    required this.onClose,
    required this.subtitleOptions,
    required this.audioOptions,
    required this.currentSubtitle,
    required this.currentAudio,
    required this.onLoadSubtitleFile,
    required this.subtitleStyle,
    required this.onStyleChanged,
    required this.onResetPosition,
  });

  final PanelPage page;
  final ValueChanged<PanelPage> onPage;
  final VoidCallback onClose;
  final List<PanelOption> subtitleOptions;
  final List<PanelOption> audioOptions;
  final String currentSubtitle;
  final String currentAudio;
  final VoidCallback onLoadSubtitleFile;
  final SubtitleStyle subtitleStyle;
  final ValueChanged<SubtitleStyle> onStyleChanged;
  final VoidCallback onResetPosition;

  static String title(PanelPage p) => switch (p) {
    PanelPage.root => 'Settings',
    PanelPage.subtitles => 'Subtitles',
    PanelPage.audio => 'Audio',
    PanelPage.appearance => 'Subtitle settings',
    PanelPage.shortcuts => 'Keyboard shortcuts',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Ui.surfaceHigh,
      elevation: 10,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ui.rLg),
        side: const BorderSide(color: Ui.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 340,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                title: title(page),
                onBack: page == PanelPage.root
                    ? null
                    : () => onPage(
                        page == PanelPage.appearance
                            ? PanelPage.subtitles
                            : PanelPage.root,
                      ),
                onClose: onClose,
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: Ui.s2),
                  child: switch (page) {
                    PanelPage.root => _root(theme),
                    PanelPage.subtitles => _options(
                      subtitleOptions,
                      footer: [
                        const Divider(height: Ui.s4),
                        _Row(
                          icon: Icons.upload_file_outlined,
                          label: 'Load subtitle file…',
                          onTap: onLoadSubtitleFile,
                        ),
                        _Row(
                          icon: Icons.text_fields_rounded,
                          chevron: true,
                          label: 'Subtitle settings',
                          onTap: () => onPage(PanelPage.appearance),
                        ),
                      ],
                    ),
                    PanelPage.audio => _options(audioOptions),
                    PanelPage.appearance => SubtitleSettingsPanel(
                      initial: subtitleStyle,
                      onChanged: onStyleChanged,
                      onResetPosition: onResetPosition,
                      showTitle: false,
                      width: null,
                    ),
                    PanelPage.shortcuts => _shortcuts(theme),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _root(ThemeData theme) => Column(
    children: [
      _Row(
        icon: Icons.closed_caption_outlined,
        chevron: true,
        label: 'Subtitles',
        value: currentSubtitle,
        onTap: () => onPage(PanelPage.subtitles),
      ),
      _Row(
        icon: Icons.audiotrack_outlined,
        chevron: true,
        label: 'Audio',
        value: currentAudio,
        onTap: () => onPage(PanelPage.audio),
      ),
      const Divider(height: Ui.s4),
      _Row(
        icon: Icons.keyboard_outlined,
        chevron: true,
        label: 'Keyboard shortcuts',
        onTap: () => onPage(PanelPage.shortcuts),
      ),
    ],
  );

  Widget _options(List<PanelOption> opts, {List<Widget> footer = const []}) {
    return Column(
      children: [
        if (opts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(Ui.s4),
            child: Text(
              'Nothing available for this file.',
              style: TextStyle(color: Ui.muted),
            ),
          ),
        for (final o in opts)
          _Row(
            label: o.label,
            icon: o.icon,
            checked: o.selected,
            onTap: o.onTap,
          ),
        ...footer,
      ],
    );
  }

  Widget _shortcuts(ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Ui.s4),
    child: Column(
      children: [
        for (final (key, what) in shortcutList)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Ui.selected,
                    borderRadius: BorderRadius.circular(Ui.rSm),
                    border: Border.all(color: Ui.outline),
                  ),
                  child: Text(
                    key,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: Ui.s3),
                Expanded(
                  child: Text(
                    what,
                    style: theme.textTheme.bodySmall?.copyWith(color: Ui.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose, this.onBack});
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ui.s2, Ui.s2, Ui.s2, Ui.s2),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: onBack,
            )
          else
            const SizedBox(width: Ui.s2),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          IconButton(
            tooltip: 'Close (Esc)',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.icon,
    this.value,
    this.checked,
    this.chevron = false,
  });
  final bool chevron;
  final String label;
  final String? value;
  final IconData? icon;
  final bool? checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Ui.s4, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: checked != null
                  ? (checked!
                        ? const Icon(Icons.check_rounded, size: 18)
                        : null)
                  : (icon == null ? null : Icon(icon, size: 20)),
            ),
            const SizedBox(width: Ui.s2),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: checked == true ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: Ui.s2),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: Ui.muted),
                  ),
                ),
              ),
            if (chevron)
              const Padding(
                padding: EdgeInsets.only(left: Ui.s1),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Ui.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
