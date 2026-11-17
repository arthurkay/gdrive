import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart' as md;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart' as m;

import '../../platform/ui_kit.dart';

/// Colours and type for the shared (kit-neutral) widgets, taken from
/// whichever kit theme is active so they sit naturally inside its shell.
class AppStyle {
  const AppStyle({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.fontFamily,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color accent;
  final Color onAccent;
  final String? fontFamily;

  Color get text => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B);
  Color get muted => text.withValues(alpha: 0.62);
  Color get border => text.withValues(alpha: 0.12);
  Color get hover => text.withValues(alpha: 0.06);
  Color get selected => accent.withValues(alpha: isDark ? 0.30 : 0.16);
  Color get danger =>
      isDark ? const Color(0xFFFF8A80) : const Color(0xFFC42B1C);
  Color get success =>
      isDark ? const Color(0xFF6CCB5F) : const Color(0xFF0F7B0F);
  Color get warning =>
      isDark ? const Color(0xFFFCE100) : const Color(0xFF9D5D00);

  TextStyle get body =>
      TextStyle(fontFamily: fontFamily, fontSize: 13.5, color: text);
  TextStyle get caption =>
      TextStyle(fontFamily: fontFamily, fontSize: 12, color: muted);
  TextStyle get strong => body.copyWith(fontWeight: FontWeight.w600);
  TextStyle get title => TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: text,
  );

  static AppStyle of(BuildContext context) {
    switch (Kit.of(context)) {
      case UiKit.fluent:
        final theme = f.FluentTheme.of(context);
        final dark = theme.brightness == Brightness.dark;
        // Fluent colours are translucent (made for Mica); flatten them so
        // full-window routes are opaque.
        final background = Color.alphaBlend(
          theme.scaffoldBackgroundColor,
          dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3),
        );
        return AppStyle(
          isDark: dark,
          background: background,
          surface: Color.alphaBlend(theme.cardColor, background),
          accent: theme.accentColor.defaultBrushFor(theme.brightness),
          onAccent: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          fontFamily: theme.typography.body?.fontFamily,
        );
      case UiKit.macos:
        final theme = m.MacosTheme.of(context);
        final dark = theme.brightness == Brightness.dark;
        return AppStyle(
          isDark: dark,
          background: theme.canvasColor,
          surface: dark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF),
          accent: theme.primaryColor,
          onAccent: const Color(0xFFFFFFFF),
          fontFamily: theme.typography.body.fontFamily,
        );
      case UiKit.yaru:
        final theme = md.Theme.of(context);
        return AppStyle(
          isDark: theme.brightness == Brightness.dark,
          background: theme.colorScheme.surface,
          surface: theme.colorScheme.surfaceContainerLow,
          accent: theme.colorScheme.primary,
          onAccent: theme.colorScheme.onPrimary,
          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
        );
    }
  }
}

/// Gives kit-neutral content the text and icon defaults of the active kit.
/// Under Yaru it also provides the Material ancestor that widgets need.
class AppSurface extends StatelessWidget {
  const AppSurface({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final content = DefaultTextStyle(
      style: style.body,
      child: IconTheme(
        data: IconThemeData(color: style.text, size: 18),
        child: child,
      ),
    );
    final background = color ?? style.background;
    return Kit.of(context) == UiKit.yaru
        ? md.Material(color: background, child: content)
        : ColoredBox(color: background, child: content);
  }
}
