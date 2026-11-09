import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/player/player_panel.dart';
import 'package:tv_watcher/player/subtitle_style.dart';
import 'package:tv_watcher/ui/theme.dart';

Widget host(Widget child) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(body: Center(child: child)),
);

PlayerPanel panel({
  PanelPage page = PanelPage.root,
  ValueChanged<PanelPage>? onPage,
  VoidCallback? onClose,
  List<PanelOption> subs = const [],
  List<PanelOption> audio = const [],
}) => PlayerPanel(
  page: page,
  onPage: onPage ?? (_) {},
  onClose: onClose ?? () {},
  subtitleOptions: subs,
  audioOptions: audio,
  currentSubtitle: 'English',
  currentAudio: 'Auto',
  onLoadSubtitleFile: () {},
  subtitleStyle: SubtitleStyle.defaults,
  onStyleChanged: (_) {},
  onResetPosition: () {},
);

void main() {
  testWidgets('root lists the pages with their current values', (t) async {
    PanelPage? went;
    await t.pumpWidget(host(panel(onPage: (p) => went = p)));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('English'), findsOneWidget); // current subtitle
    expect(find.text('Auto'), findsOneWidget); // current audio
    expect(find.text('Subtitle settings'), findsNothing);
    await t.tap(find.text('Keyboard shortcuts'));
    expect(went, PanelPage.shortcuts);
  });

  testWidgets('subtitle page shows ticks and fires option taps', (t) async {
    var picked = '';
    await t.pumpWidget(
      host(
        panel(
          page: PanelPage.subtitles,
          subs: [
            PanelOption(
              label: 'Off',
              selected: false,
              onTap: () => picked = 'off',
            ),
            PanelOption(
              label: 'English',
              selected: true,
              onTap: () => picked = 'en',
            ),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Load subtitle file…'), findsOneWidget);
    await t.tap(find.text('Off'));
    expect(picked, 'off');
  });

  testWidgets('subtitle settings live under the subtitles page only', (
    t,
  ) async {
    PanelPage? went;
    await t.pumpWidget(
      host(panel(page: PanelPage.subtitles, onPage: (p) => went = p)),
    );
    await t.tap(find.text('Subtitle settings'));
    expect(went, PanelPage.appearance);

    // Back from the settings page returns to the subtitles page.
    await t.pumpWidget(
      host(panel(page: PanelPage.appearance, onPage: (p) => went = p)),
    );
    await t.tap(find.byTooltip('Back'));
    expect(went, PanelPage.subtitles);
  });

  testWidgets('empty audio page says so; back and close work', (t) async {
    PanelPage? went;
    var closed = false;
    await t.pumpWidget(
      host(
        panel(
          page: PanelPage.audio,
          onPage: (p) => went = p,
          onClose: () => closed = true,
        ),
      ),
    );
    expect(find.text('Nothing available for this file.'), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    expect(went, PanelPage.root);
    await t.tap(find.byTooltip('Close (Esc)'));
    expect(closed, isTrue);
  });

  testWidgets('shortcuts page lists the keys', (t) async {
    await t.pumpWidget(host(panel(page: PanelPage.shortcuts)));
    expect(find.text('Space'), findsOneWidget);
    expect(find.text('Play / pause'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  test('theme: menus anchor under their button, one accent, no brand red', () {
    final th = buildTheme();
    expect(th.popupMenuTheme.position, PopupMenuPosition.under);
    expect(th.colorScheme.primary, Ui.accent);
    expect(th.scaffoldBackgroundColor, Ui.bg);
    // Text on the page background stays readable (>= 4.5:1).
    double lum(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final l1 = lum(a), l2 = lum(b);
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(ratio(Ui.text, Ui.bg), greaterThan(7));
    expect(ratio(Ui.muted, Ui.bg), greaterThan(4.5));
    expect(ratio(Ui.dim, Ui.bg), greaterThan(4.5));
    expect(ratio(Ui.onAccent, Ui.accent), greaterThan(7));
  });
}
