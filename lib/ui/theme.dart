import 'package:flutter/material.dart';

/// Design tokens. Neutral and quiet: the artwork carries the screen, the UI
/// stays out of its way. One warm off-white accent, no brand colour.
class Ui {
  Ui._();

  // Surfaces, darkest to lightest.
  static const bg = Color(0xFF0C0C0E);
  static const surface = Color(0xFF151518);
  static const surfaceHigh = Color(0xFF1E1E22);
  static const surfaceHover = Color(0xFF19191D);
  static const selected = Color(0xFF232328);

  // Lines and text.
  static const outline = Color(0x1FFFFFFF);
  static const text = Color(0xFFEDEBE6);
  static const muted = Color(0xFFA3A19B); // secondary text, >= 7:1 on bg
  static const dim = Color(0xFF86847E); // tertiary text, >= 4.5:1 on bg

  /// The only accent: warm off-white (primary buttons, progress, focus).
  static const accent = Color(0xFFEDEBE6);
  static const onAccent = Color(0xFF111113);

  /// Used sparingly for "needs attention" labels.
  static const attention = Color(0xFFE0B25A);

  // Radii and spacing scale.
  static const rSm = 6.0;
  static const rMd = 10.0;
  static const rLg = 14.0;

  /// How long an undo snackbar stays up.
  static const undoDuration = Duration(seconds: 8);

  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0;

  /// Scrim behind text that sits on artwork or video.
  static const scrim = Color(0xCC000000);

  static const fontFamily = 'Poppins';
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final scheme =
      const ColorScheme.dark(
        primary: Ui.accent,
        onPrimary: Ui.onAccent,
        secondary: Ui.accent,
        onSecondary: Ui.onAccent,
        surface: Ui.surface,
        onSurface: Ui.text,
        onSurfaceVariant: Ui.muted,
        outline: Ui.outline,
        outlineVariant: Ui.outline,
        error: Color(0xFFE5736A),
      ).copyWith(
        surfaceContainerLowest: Ui.bg,
        surfaceContainerLow: Ui.surface,
        surfaceContainer: Ui.surface,
        surfaceContainerHigh: Ui.surfaceHigh,
        surfaceContainerHighest: Ui.surfaceHigh,
      );

  final text = base.textTheme
      .apply(
        fontFamily: Ui.fontFamily,
        bodyColor: Ui.text,
        displayColor: Ui.text,
      )
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 15, height: 1.45),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
        bodySmall: const TextStyle(fontSize: 12, height: 1.35),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      )
      .apply(
        fontFamily: Ui.fontFamily,
        bodyColor: Ui.text,
        displayColor: Ui.text,
      );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Ui.rMd),
    side: const BorderSide(color: Ui.outline),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Ui.bg,
    canvasColor: Ui.surface,
    textTheme: text,
    primaryTextTheme: text,
    splashFactory: NoSplash.splashFactory,
    hoverColor: const Color(0x0FFFFFFF),
    highlightColor: Colors.transparent,
    focusColor: const Color(0x1AFFFFFF),
    dividerTheme: const DividerThemeData(
      color: Ui.outline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Ui.text, size: 22),
    ),
    // Menus: dark surface, hairline border, anchored below their button.
    popupMenuTheme: PopupMenuThemeData(
      color: Ui.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      elevation: 8,
      shape: shape,
      position: PopupMenuPosition.under,
      menuPadding: const EdgeInsets.symmetric(vertical: Ui.s2),
      textStyle: text.bodyMedium,
      labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Ui.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ui.rLg),
        side: const BorderSide(color: Ui.outline),
      ),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium?.copyWith(color: Ui.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Ui.surfaceHigh,
      contentTextStyle: text.bodyMedium,
      actionTextColor: Ui.accent,
      width: 460,
      shape: shape,
      elevation: 6,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Ui.surfaceHigh,
        borderRadius: BorderRadius.circular(Ui.rSm),
        border: Border.all(color: Ui.outline),
      ),
      textStyle: text.bodySmall,
      waitDuration: const Duration(milliseconds: 500),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Ui.text,
        hoverColor: const Color(0x14FFFFFF),
        focusColor: const Color(0x1FFFFFFF),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ui.accent,
        foregroundColor: Ui.onAccent,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ui.rSm + 2),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ui.text,
        side: const BorderSide(color: Ui.outline),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ui.rSm + 2),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Ui.text,
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ui.rSm + 2),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Ui.selected,
      side: const BorderSide(color: Ui.outline),
      labelStyle: text.bodySmall,
      checkmarkColor: Ui.text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ui.rLg + 6),
      ),
      showCheckmark: false,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Ui.accent : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Ui.onAccent),
      side: const BorderSide(color: Ui.muted, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Ui.onAccent : Ui.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Ui.accent : Ui.selected,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Ui.accent,
      inactiveTrackColor: Color(0x33FFFFFF),
      thumbColor: Ui.accent,
      overlayColor: Color(0x1FFFFFFF),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Ui.accent,
      linearTrackColor: Color(0x33FFFFFF),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: const WidgetStatePropertyAll(Color(0x33FFFFFF)),
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(6),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Ui.accent,
      selectionColor: Color(0x40EDEBE6),
      selectionHandleColor: Ui.accent,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: Ui.accent,
      textColor: Ui.onAccent,
      textStyle: text.labelSmall,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Ui.muted,
      textColor: Ui.text,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
