import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/app.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/ui/adaptive/controls.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/preview/viewers.dart';

import 'app_env.dart';

/// Stand-ins for the viewers backed by native libraries.
class StubViewers extends ViewerFactory {
  ValueChanged<String>? onTextChanged;
  MediaSource? lastMedia;

  @override
  Widget image(File file) => Text('image:${file.path.split('/').last}');

  @override
  Widget pdf(File file) => Text('pdf:${file.path.split('.').last}');

  @override
  Widget media(MediaSource source, {required bool video}) {
    lastMedia = source;
    return Text(video ? 'video-player' : 'audio-player');
  }

  @override
  Widget text({
    required String content,
    required String? language,
    required bool readOnly,
    required ValueChanged<String> onChanged,
  }) {
    onTextChanged = onChanged;
    return Text(
      'text[${language ?? 'plain'}${readOnly ? ',ro' : ''}]:$content',
    );
  }
}

/// Channels of desktop plugins that have no implementation under test.
void silencePluginChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'macos_window_utils',
    'appkit_ui_element_colors',
    'desktop_drop',
    'window_manager',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
}

/// Pumps the app (or just [home] inside the app's theme) for [kit] against
/// the fakes in [env], in a desktop-sized window.
Future<ProviderContainer> pumpGDrive(
  WidgetTester tester,
  AppEnv env, {
  UiKit kit = UiKit.yaru,
  Widget? home,
  ViewerFactory? viewers,
  List<Override> extra = const [],
  Widget Function(Widget app)? wrap,
}) async {
  silencePluginChannels();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = env.container(
    extra: [
      uiKitProvider.overrideWithValue(kit),
      followDesktopThemeProvider.overrideWithValue(false),
      viewerFactoryProvider.overrideWithValue(viewers ?? StubViewers()),
      ...extra,
    ],
  );
  _mounted = container;
  if (home != null) {
    // Pages below the auth gate expect a signed-in account.
    await tester.runAsync(() => container.read(authProvider.future));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: (wrap ?? (app) => app)(
        home == null ? const GDriveApp() : GDriveApp(home: home),
      ),
    ),
  );
  await settle(tester);
  return container;
}

/// Lets fake-Drive calls, database streams and real file I/O finish, then
/// rebuilds. Widget tests run on a fake clock, so real I/O needs runAsync.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Pumps until [done], alternating real time (for file I/O) with frames.
/// Fails the test if the condition never holds.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  String reason = 'condition',
}) async {
  for (var i = 0; i < 600; i++) {
    if (done()) {
      await tester.pump(const Duration(milliseconds: 20));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $reason');
}

bool shown(Finder finder) => finder.evaluate().isNotEmpty;

ProviderContainer? _mounted;

/// Unmounts the app and disposes its providers, so timers and streams are
/// gone before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  _mounted?.dispose();
  _mounted = null;
  await tester.pump(const Duration(seconds: 5));
}

extension Gestures on WidgetTester {
  Future<void> doubleTap(Finder finder) async {
    await tap(finder);
    await pump(const Duration(milliseconds: 60));
    await tap(finder);
    await settle(this);
  }

  Future<void> rightClick(Finder finder) async {
    await tap(finder, buttons: kSecondaryButton);
    await settle(this, rounds: 2);
  }

  /// Taps and waits out the double-tap window so the tap is delivered.
  Future<void> click(Finder finder) async {
    await tap(finder);
    await pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
    await settle(this, rounds: 2);
  }
}

/// An [AppIconButton] by its tooltip, whichever kit renders it.
Finder iconButton(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is AppIconButton && widget.tooltip == tooltip,
);

/// A sync badge (or any labelled icon) by its accessible label.
Finder labelledIcon(String label) => find.byWidgetPredicate(
  (widget) => widget is Icon && widget.semanticLabel == label,
);
