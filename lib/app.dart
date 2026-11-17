import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart' as md;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart' as m;
import 'package:yaru/yaru.dart' as y;

import 'core/platform/ui_kit.dart';
import 'core/ui/adaptive/app_style.dart';
import 'core/ui/adaptive/controls.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_pages.dart';
import 'features/settings/settings.dart';
import 'features/sync/sync_controller.dart';
import 'shell/shells.dart';

final uiKitProvider = Provider<UiKit>((ref) => detectUiKit());

/// Whether the app draws its own title bar (Yaru on Linux). Off by default
/// so tests and other platforms keep the native frame.
final customTitleBarProvider = Provider<bool>((ref) => false);

/// Whether the Yaru theme follows the desktop's accent colour. Needs the
/// GNOME settings service, so tests turn it off.
final followDesktopThemeProvider = Provider<bool>((ref) => true);

/// Root widget: picks the app class for the active kit and applies the
/// theme preference.
class GDriveApp extends ConsumerWidget {
  const GDriveApp({super.key, this.home = const AuthGate()});

  /// First route. Tests pass a single page to see it inside a kit's theme.
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(uiKitProvider);
    final mode = switch (ref.watch(settingsProvider.select((s) => s.theme))) {
      ThemePreference.system => md.ThemeMode.system,
      ThemePreference.light => md.ThemeMode.light,
      ThemePreference.dark => md.ThemeMode.dark,
    };
    final ownTitleBar = ref.watch(customTitleBarProvider);
    const title = 'GDrive';

    md.MaterialApp material(md.ThemeData light, md.ThemeData dark) =>
        md.MaterialApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          home: home,
          // Above the navigator, so every route keeps the window controls.
          builder: (context, child) => ownTitleBar
              ? md.Material(
                  child: Column(
                    children: [
                      const y.YaruWindowTitleBar(title: Text(title)),
                      Expanded(child: child!),
                    ],
                  ),
                )
              : child!,
        );

    return Kit(
      kit: kit,
      child: switch (kit) {
        UiKit.fluent => f.FluentApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: f.FluentThemeData(brightness: Brightness.light),
          darkTheme: f.FluentThemeData(brightness: Brightness.dark),
          themeMode: mode,
          home: home,
        ),
        UiKit.macos => m.MacosApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: m.MacosThemeData.light(),
          darkTheme: m.MacosThemeData.dark(),
          themeMode: mode,
          home: home,
        ),
        UiKit.yaru =>
          ref.watch(followDesktopThemeProvider)
              ? y.YaruTheme(
                  builder: (context, yaru, _) =>
                      material(yaru.theme, yaru.darkTheme),
                )
              : material(y.yaruLight, y.yaruDark),
      },
    );
  }
}

/// Shows setup, sign-in or the main window depending on the auth state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return switch (auth) {
      AsyncData(value: AuthUnconfigured()) => const SetupPage(),
      AsyncData(value: SignedOut(:final error)) => SignInPage(error: error),
      AsyncData(value: SignedIn()) => const _SignedIn(),
      AsyncError(:final error) => SignInPage(error: '$error'),
      // Loading with a previous value means a sign-in is in progress.
      _ when auth.hasValue => const SignInPage(busy: true),
      _ => const AppSurface(child: Center(child: AppSpinner(size: 28))),
    };
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the sync scheduler alive for as long as the user is signed in.
    ref.watch(syncProvider.select((s) => s.phase));
    return const AppShell();
  }
}
