import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/demo.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/features/sync/sync_controller.dart';
import 'package:gdrive/features/sync/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../support/app_env.dart';

class MockEngine extends Mock implements SyncEngine {}

void main() {
  late AppEnv env;

  tearDown(() => env.dispose());

  /// Signs in and starts the controller; returns once it is idle.
  Future<ProviderContainer> start({bool paused = false}) async {
    env = AppEnv(paused: paused);
    final container = env.container();
    await container.read(authProvider.future);
    container.listen(syncProvider, (_, _) {});
    await settle(container);
    return container;
  }

  File local(String rel) => File(p.join(env.syncRoot, rel));

  test('starting up runs a pass and reports it', () async {
    final container = await start();

    final status = container.read(syncProvider);
    expect(status.phase, SyncPhase.idle);
    expect(status.message, 'Up to date');
    expect(status.lastSync, env.now);
  });

  test('selecting an item syncs it; deselecting leaves files alone', () async {
    final container = await start();
    final file = env.drive.addFile('a.txt', 'alpha');
    final sync = container.read(syncProvider.notifier);

    await sync.setSynced(file.id, true);
    await settle(container);
    expect(local('a.txt').readAsStringSync(), 'alpha');
    expect(container.read(syncProvider).message, '1 downloaded');
    expect(await env.latest(container, selectionsProvider), {file.id});
    expect((await env.latest(container, syncEntriesProvider)).keys, [file.id]);

    await sync.setSynced(file.id, false);
    await settle(container);
    expect(local('a.txt').existsSync(), isTrue);
    expect(env.drive.byId(file.id)!.trashed, isFalse);
  });

  test(
    'a conflict triggers a follow-up pass that uploads the kept copy',
    () async {
      final container = await start();
      final file = env.drive.addFile('a.txt', 'base');
      final sync = container.read(syncProvider.notifier);
      await sync.setSynced(FakeDriveApi.rootId, true);
      await settle(container);

      env.drive.edit(file.id, 'from drive');
      local('a.txt')
        ..writeAsStringSync('from disk')
        ..setLastModifiedSync(DateTime(2027));
      await sync.syncNow();
      await settle(container);

      expect(env.drive.find('a (conflicted copy 2026-11-17).txt'), isNotNull);
      final activity = await env.latest(container, activityProvider);
      expect(activity.any((e) => e.kind == 'conflict'), isTrue);
    },
  );

  test('a large deletion waits for confirmation, then proceeds', () async {
    final container = await start();
    for (var i = 0; i < 8; i++) {
      env.drive.addFile('f$i.txt', 'content $i');
    }
    final sync = container.read(syncProvider.notifier);
    await sync.setSynced(FakeDriveApi.rootId, true);
    await settle(container);
    for (var i = 0; i < 6; i++) {
      local('f$i.txt').deleteSync();
    }

    await sync.syncNow();
    var status = container.read(syncProvider);
    expect(status.phase, SyncPhase.needsConfirmation);
    expect(status.pendingDeletes, 6);

    await sync.syncNow();
    expect(
      env.drive.items.where((i) => i.trashed),
      isEmpty,
      reason: 'plain passes do nothing while confirmation is pending',
    );

    await sync.confirmDeletes();
    status = container.read(syncProvider);
    expect(status.phase, SyncPhase.idle);
    expect(status.message, '6 removed');
    expect(env.drive.items.where((i) => i.trashed), hasLength(6));
  });

  test(
    'an engine failure becomes an error state that a retry clears',
    () async {
      final container = await start();
      final file = env.drive.addFile('a.txt', 'alpha');
      final sync = container.read(syncProvider.notifier);
      env.drive.failWhen = (_, _) => DriveApiException(500, 'backend down');

      await sync.setSynced(file.id, true);
      await settle(container);
      var status = container.read(syncProvider);
      expect(status.phase, SyncPhase.error);
      expect(status.message, contains('backend down'));

      env.drive.failWhen = null;
      await sync.setSynced(file.id, true);
      await settle(container);
      status = container.read(syncProvider);
      expect(status.phase, SyncPhase.idle);
      expect(local('a.txt').existsSync(), isTrue);
    },
  );

  test('paused means no passes until resumed', () async {
    final container = await start(paused: true);
    final file = env.drive.addFile('a.txt', 'alpha');
    final sync = container.read(syncProvider.notifier);
    expect(container.read(syncProvider).phase, SyncPhase.paused);

    await sync.setSynced(file.id, true);
    await settle(container);
    expect(local('a.txt').existsSync(), isFalse);

    await sync.setPaused(false);
    await settle(container);
    expect(container.read(syncProvider).phase, SyncPhase.idle);
    expect(local('a.txt').existsSync(), isTrue);

    await sync.setPaused(true);
    expect(container.read(syncProvider).phase, SyncPhase.paused);
  });

  test('describe summarises a pass', () {
    expect(SyncController.describe(SyncReport()), 'Up to date');
    expect(
      SyncController.describe(
        SyncReport()
          ..downloads = 2
          ..uploads = 1
          ..moves = 1
          ..deletedLocal = 1
          ..trashedRemote = 2
          ..conflicts = 1
          ..errors = 3,
      ),
      '2 downloaded, 1 uploaded, 1 moved, 3 removed, 1 conflicts, 3 failed',
    );
    expect(SyncController.describe(SyncReport()..errors = 1), '1 failed');
  });

  group('scheduling', () {
    late MockEngine engine;
    late StreamController<void> folderEvents;

    ProviderContainer scheduled(FakeAsync async, {Completer<void>? gate}) {
      env = AppEnv(paused: false);
      Directory(env.syncRoot).createSync(recursive: true);
      engine = MockEngine();
      folderEvents = StreamController<void>.broadcast();
      when(
        () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
      ).thenAnswer((_) async {
        if (gate != null) await gate.future;
        return SyncReport();
      });
      env.watcher = (_) => folderEvents.stream;
      final container = env.container(
        extra: [syncEngineProvider.overrideWithValue(engine)],
      );
      container.read(sessionProvider.notifier).set(FakeAuthSession());
      container.listen(syncProvider, (_, _) {});
      async.flushMicrotasks();
      return container;
    }

    int runs() => verify(
      () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
    ).callCount;

    test('polls on the configured interval', () {
      fakeAsync((async) {
        scheduled(async);
        expect(runs(), 1, reason: 'initial pass');

        async.elapse(const Duration(seconds: 29));
        verifyNever(
          () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
        );
        async.elapse(const Duration(seconds: 1));
        expect(runs(), 1);
        async.elapse(const Duration(seconds: 60));
        expect(runs(), 2);
        folderEvents.close();
      });
    });

    test('a burst of local changes becomes one debounced pass', () {
      fakeAsync((async) {
        scheduled(async);
        clearInteractions(engine);

        for (var i = 0; i < 5; i++) {
          folderEvents.add(null);
          async.elapse(const Duration(milliseconds: 300));
        }
        verifyNever(
          () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
        );
        async.elapse(SyncController.debounce);
        expect(runs(), 1);
        folderEvents.close();
      });
    });

    test('requests during a pass collapse into one follow-up', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        final container = scheduled(async, gate: gate);
        final sync = container.read(syncProvider.notifier);
        expect(container.read(syncProvider).phase, SyncPhase.syncing);

        sync.syncNow();
        sync.syncNow();
        sync.syncNow();
        async.flushMicrotasks();
        expect(runs(), 1, reason: 'still the first pass');

        gate.complete();
        async.flushMicrotasks();
        expect(runs(), 1, reason: 'exactly one follow-up');
        expect(container.read(syncProvider).phase, SyncPhase.idle);
        folderEvents.close();
      });
    });

    test('changing the interval reschedules the poll', () {
      fakeAsync((async) {
        final container = scheduled(async);
        container.read(settingsProvider.notifier).setPollSeconds(300);
        async.flushMicrotasks();
        // The controller restarts with the new interval and syncs at once.
        container.read(syncProvider);
        async.flushMicrotasks();
        clearInteractions(engine);

        async.elapse(const Duration(seconds: 299));
        verifyNever(
          () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
        );
        async.elapse(const Duration(seconds: 1));
        expect(runs(), 1);
        folderEvents.close();
      });
    });

    test('signing out stops all syncing', () {
      fakeAsync((async) {
        final container = scheduled(async);
        container.read(sessionProvider.notifier).set(null);
        container.read(syncProvider);
        async.flushMicrotasks();
        clearInteractions(engine);

        folderEvents.add(null);
        container.read(syncProvider.notifier).syncNow();
        async.elapse(const Duration(minutes: 10));

        verifyNever(
          () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
        );
        expect(async.periodicTimerCount, 0);
        folderEvents.close();
      });
    });

    test('disposing stops the timers', () {
      fakeAsync((async) {
        final container = scheduled(async);
        container.dispose();
        clearInteractions(engine);
        async.elapse(const Duration(minutes: 10));
        verifyNever(
          () => engine.run(allowMassDelete: any(named: 'allowMassDelete')),
        );
        expect(async.periodicTimerCount, 0);
        folderEvents.close();
      });
    });
  });
}

/// Waits until no sync pass is running. Real file I/O is involved, so this
/// polls rather than pumping microtasks.
Future<void> settle(ProviderContainer container) async {
  for (var i = 0; i < 400; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final phase = container.read(syncProvider).phase;
    if (phase != SyncPhase.syncing && i > 2) return;
  }
  fail('sync did not settle');
}
