import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/ui/adaptive/controls.dart';
import 'package:gdrive/core/ui/notice.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/drive/drive_api.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/features/settings/settings_page.dart';
import 'package:gdrive/features/sync/activity_page.dart';
import 'package:gdrive/features/sync/sync_controller.dart';
import 'package:gdrive/features/transfers/transfers_page.dart';
import 'package:path/path.dart' as p;

import '../support/app_env.dart';
import '../support/pump.dart';

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  Future<int> transfer(
    String name, {
    String direction = 'download',
    String state = 'queued',
    int done = 0,
    int total = 0,
    String? error,
    bool fromSync = false,
  }) async {
    final id = await env.db.addTransfer(
      TransfersCompanion.insert(
        direction: direction,
        name: name,
        localPath: '/tmp/$name',
        createdAt: env.now,
        fromSync: Value(fromSync),
        totalBytes: Value(total),
      ),
    );
    await env.db.updateTransfer(
      id,
      TransfersCompanion(
        state: Value(state),
        doneBytes: Value(done),
        error: Value(error),
      ),
    );
    return id;
  }

  for (final kit in UiKit.values) {
    group('${kit.name} kit', () {
      testWidgets('transfers page shows each state and clears finished', (
        tester,
      ) async {
        await transfer('waiting.bin');
        await transfer('moving.bin', state: 'running', done: 512, total: 2048);
        await transfer('unknown.bin', state: 'running');
        await transfer(
          'sent.txt',
          direction: 'upload',
          state: 'done',
          total: 2048,
          fromSync: true,
        );
        await transfer('got.txt', state: 'done', total: 10);
        await transfer('broken.bin', state: 'failed', error: 'quota exceeded');
        await transfer('stopped.bin', state: 'cancelled');
        await pumpGDrive(tester, env, kit: kit, home: const TransfersPage());

        expect(find.text('Waiting'), findsOneWidget);
        expect(find.text('512 B of 2.0 KB'), findsOneWidget);
        expect(find.text('Uploaded · 2.0 KB'), findsOneWidget);
        expect(find.text('Downloaded · 10 B'), findsOneWidget);
        expect(find.text('Failed: quota exceeded'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('sync'), findsOneWidget);
        expect(find.byType(AppProgressBar), findsNWidgets(2));
        expect(iconButton('Cancel'), findsNWidgets(3));

        await tester.click(find.text('Clear finished'));
        expect(find.text('sent.txt'), findsNothing);
        expect(find.text('broken.bin'), findsNothing);
        expect(find.text('waiting.bin'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('settings change and persist', (tester) async {
        final container = await pumpGDrive(
          tester,
          env,
          kit: kit,
          home: const NoticeHost(child: SettingsPage()),
        );
        AppSettings settings() => container.read(settingsProvider);
        expect(find.textContaining('demo@example.com'), findsOneWidget);
        expect(find.textContaining('3.0 GB of 15.0 GB used'), findsOneWidget);

        await tester.click(find.text('Dark'));
        expect(settings().theme, ThemePreference.dark);
        await tester.click(find.text('5 min'));
        expect(settings().pollSeconds, 300);
        await tester.click(find.text('8'));
        expect(settings().concurrency, 8);
        await tester.click(find.byType(AppSwitch));
        expect(settings().paused, isFalse);

        env.picker.directory = p.join(env.temp.path, 'elsewhere');
        await tester.click(find.text('Change…'));
        expect(settings().syncRoot, env.picker.directory);
        expect(find.textContaining('Sync folder changed'), findsOneWidget);
        expect(await env.db.getValue('syncRoot'), env.picker.directory);
        await unmount(tester);
      });

      testWidgets('activity page lists events and controls sync', (
        tester,
      ) async {
        for (final kind in [
          'download',
          'upload',
          'delete',
          'conflict',
          'error',
          'info',
        ]) {
          await env.db.log(kind, 'a $kind happened', env.now);
        }
        final container = await pumpGDrive(
          tester,
          env,
          kit: kit,
          home: const ActivityPage(),
        );
        expect(find.text('a conflict happened'), findsOneWidget);
        expect(find.text('Sync is paused'), findsOneWidget);
        expect(find.text('17 Nov 09:00'), findsNWidgets(6));

        await tester.click(find.text('Clear'));
        expect(find.text('a conflict happened'), findsNothing);
        expect(find.textContaining('Sync to this computer'), findsOneWidget);

        await tester.click(find.text('Resume sync'));
        await settle(tester);
        expect(container.read(settingsProvider).paused, isFalse);
        expect(find.text('Pause sync'), findsOneWidget);
        await tester.click(find.text('Sync now'));
        await settle(tester);
        expect(find.textContaining('Up to date'), findsOneWidget);

        await tester.click(find.text('Pause sync'));
        await settle(tester);
        expect(container.read(syncProvider).phase, SyncPhase.paused);
        await unmount(tester);
      });
    });
  }

  testWidgets('cancelling a running transfer from the page', (tester) async {
    final id = await transfer('moving.bin', state: 'running', total: 10);
    await pumpGDrive(tester, env, home: const TransfersPage());

    await tester.click(iconButton('Cancel'));

    // The manager marks it; the running transfer notices at its next chunk.
    expect((await env.db.transfer(id))!.state, 'running');
    await unmount(tester);
  });

  testWidgets('sign out asks first and then signs out', (tester) async {
    final container = await pumpGDrive(
      tester,
      env,
      home: const NoticeHost(child: SettingsPage()),
    );

    await tester.click(find.text('Sign out'));
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.click(find.text('Cancel'));
    expect(container.read(authProvider).value, isA<SignedIn>());

    await tester.click(find.text('Sign out'));
    await tester.tap(find.text('Sign out').last);
    await settle(tester);
    expect(container.read(authProvider).value, isA<SignedOut>());
    expect(env.gateway.revocations, 1);
    await unmount(tester);
  });

  testWidgets('cancelling the folder picker leaves the sync folder alone', (
    tester,
  ) async {
    final container = await pumpGDrive(
      tester,
      env,
      home: const NoticeHost(child: SettingsPage()),
    );
    final before = container.read(settingsProvider).syncRoot;

    await tester.click(find.text('Change…'));

    expect(container.read(settingsProvider).syncRoot, before);
    await unmount(tester);
  });

  testWidgets('clearing the preview cache removes its files', (tester) async {
    final cached = File(p.join(env.paths.previewCache, 'x.txt'))
      ..createSync(recursive: true);
    await pumpGDrive(
      tester,
      env,
      home: const NoticeHost(child: SettingsPage()),
    );

    await tester.tap(find.text('Clear'));
    await pumpUntil(
      tester,
      () => shown(find.text('Preview cache cleared')),
      reason: 'the cache to clear',
    );

    expect(cached.existsSync(), isFalse);
    expect(find.text('Preview cache cleared'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('unlimited storage and a missing name are described sensibly', (
    tester,
  ) async {
    env.drive.account = const DriveAccount(
      email: 'me@example.com',
      displayName: '',
      rootId: 'root-id',
      usageBytes: 1024,
    );
    await pumpGDrive(
      tester,
      env,
      home: const NoticeHost(child: SettingsPage()),
    );

    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('me@example.com · 1.0 KB used'), findsOneWidget);
    await unmount(tester);
  });

  test('syncSummary describes each phase', () {
    final at = DateTime(2026, 11, 17, 9, 5);
    expect(syncSummary(const SyncStatus()), 'Ready');
    expect(
      syncSummary(SyncStatus(message: 'Up to date', lastSync: at)),
      'Up to date · last synced 09:05',
    );
    expect(syncSummary(const SyncStatus(phase: SyncPhase.syncing)), 'Syncing…');
    expect(
      syncSummary(const SyncStatus(phase: SyncPhase.paused)),
      'Sync is paused',
    );
    expect(
      syncSummary(const SyncStatus(phase: SyncPhase.needsConfirmation)),
      'Waiting for your confirmation',
    );
    expect(
      syncSummary(const SyncStatus(phase: SyncPhase.error)),
      'Sync stopped with an error',
    );
  });
}
