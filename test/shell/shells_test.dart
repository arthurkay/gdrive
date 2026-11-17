import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/app.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/features/sync/sync_controller.dart';
import 'package:gdrive/shell/destinations.dart';
import 'package:yaru/yaru.dart' show YaruWindowTitleBar;

import '../support/app_env.dart';
import '../support/pump.dart';

Iterable<PlatformMenuItem> flatten(Iterable<PlatformMenuItem> items) sync* {
  for (final item in items) {
    if (item is PlatformMenu) {
      yield* flatten(item.menus);
    } else {
      yield item;
    }
  }
}

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  testWidgets('on macOS the shell provides a native menu bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final container = await pumpGDrive(tester, env, kit: UiKit.macos);
      final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
      final items = {for (final item in flatten(bar.menus)) item.label: item};
      expect(bar.menus.map((m) => m.label), ['GDrive', 'View', 'Sync']);

      items['Settings…']!.onSelected!();
      await settle(tester);
      expect(container.read(navProvider), Destination.settings);

      items['Trash']!.onSelected!();
      await settle(tester);
      expect(container.read(navProvider), Destination.trash);

      items['Resume Syncing']!.onSelected!();
      await settle(tester);
      expect(container.read(settingsProvider).paused, isFalse);
      items['Pause Syncing']!.onSelected!();
      await settle(tester);
      expect(container.read(syncProvider).phase, SyncPhase.paused);

      final listed = env.drive.calls.length;
      items['Refresh']!.onSelected!();
      items['Sync Now']!.onSelected!();
      await settle(tester);
      expect(env.drive.calls.length, greaterThan(listed));
      await unmount(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('off macOS the macOS shell has no native menu bar', (
    tester,
  ) async {
    env.settings = env.settings.copyWith(theme: ThemePreference.dark);
    await pumpGDrive(tester, env, kit: UiKit.macos);
    expect(find.byType(PlatformMenuBar), findsNothing);
    expect(find.text('My Drive'), findsWidgets);
    await unmount(tester);
  });

  for (final kit in UiKit.values) {
    testWidgets(
      '${kit.name}: the sidebar shows how many transfers are active',
      (tester) async {
        final container = await pumpGDrive(tester, env, kit: kit);
        expect(container.read(activeTransfersProvider), 0);

        for (final state in ['queued', 'running', 'done']) {
          final id = await env.db.addTransfer(
            TransfersCompanion.insert(
              direction: 'upload',
              name: '$state.bin',
              localPath: '/tmp/$state.bin',
              createdAt: env.now,
            ),
          );
          await env.db.updateTransfer(
            id,
            TransfersCompanion(state: Value(state)),
          );
        }
        await settle(tester);

        expect(container.read(activeTransfersProvider), 2);
        expect(find.text('2'), findsOneWidget);
        expect(find.textContaining('2 transfers in progress'), findsOneWidget);
        await unmount(tester);
      },
    );
  }

  testWidgets('status bar reflects each sync phase', (tester) async {
    env = AppEnv(paused: true);
    final container = await pumpGDrive(tester, env);
    expect(find.text('Sync is paused'), findsOneWidget);

    await container.read(settingsProvider.notifier).setPaused(false);
    await pumpUntil(
      tester,
      () => shown(find.textContaining('Up to date')),
      reason: 'the first sync pass',
    );
    expect(find.textContaining('Up to date'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Yaru draws its own title bar above every route when asked', (
    tester,
  ) async {
    await pumpGDrive(
      tester,
      env,
      extra: [customTitleBarProvider.overrideWithValue(true)],
    );
    expect(find.byType(YaruWindowTitleBar), findsOneWidget);
    expect(find.text('My Drive'), findsWidgets);
    await unmount(tester);
  });

  test('destinations map onto Drive sections and app pages', () {
    expect(Destination.myDrive.section, isNotNull);
    expect(Destination.trash.isFooter, isFalse);
    expect(Destination.transfers.section, isNull);
    expect(Destination.settings.isFooter, isTrue);
    expect(Destination.values.where((d) => d.isFooter), hasLength(3));
  });
}
