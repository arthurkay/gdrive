import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The native look the app wears: Fluent on Windows, macOS on macOS, Yaru
/// on Linux.
enum UiKit { fluent, macos, yaru }

/// Picks the kit for this machine. `--dart-define=UI_KIT=fluent|macos|yaru`
/// forces one, so every shell can be exercised from any desktop.
UiKit detectUiKit({
  String override = const String.fromEnvironment('UI_KIT'),
  TargetPlatform? platform,
}) {
  for (final kit in UiKit.values) {
    if (kit.name == override) return kit;
  }
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows => UiKit.fluent,
    TargetPlatform.macOS => UiKit.macos,
    _ => UiKit.yaru,
  };
}

/// Makes the active kit available to the adaptive widgets below it.
class Kit extends InheritedWidget {
  const Kit({super.key, required this.kit, required super.child});

  final UiKit kit;

  static UiKit of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Kit>()?.kit ?? UiKit.yaru;

  @override
  bool updateShouldNotify(Kit oldWidget) => oldWidget.kit != kit;
}
