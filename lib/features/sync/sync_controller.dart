import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watcher/watcher.dart';

import '../../core/clock.dart';
import '../../core/config/app_paths.dart';
import '../../core/db/database.dart';
import '../auth/auth_controller.dart';
import '../settings/settings.dart';
import '../transfers/transfer_manager.dart';
import 'sync_engine.dart';

enum SyncPhase { idle, syncing, paused, needsConfirmation, error }

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.message,
    this.lastSync,
    this.pendingDeletes,
  });

  final SyncPhase phase;

  /// Error text, or a summary of the last pass.
  final String? message;
  final DateTime? lastSync;

  /// Deletions waiting for the user's go-ahead.
  final int? pendingDeletes;
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  // One engine per session: its in-memory index belongs to that account.
  ref.watch(sessionProvider);
  return SyncEngine(
    db: ref.watch(databaseProvider),
    api: () => ref.read(driveApiProvider),
    transfers: ref.watch(transferManagerProvider),
    clock: ref.watch(clockProvider),
    syncRoot: () => ref.read(settingsProvider).syncRoot,
    rootId: () => ref.read(accountProvider).rootId,
    recycleDir: ref.watch(appPathsProvider).recycle,
    concurrency: () => ref.read(settingsProvider).concurrency,
  );
});

/// Emits whenever something changes inside the given folder. Replaced in
/// tests, where file-system watchers and real timers are unwelcome.
final folderWatcherProvider = Provider<Stream<void> Function(String path)>(
  (ref) =>
      (path) => DirectoryWatcher(path).events.map((_) {}),
);

/// Decides when sync passes run: on demand, on a timer, and when the local
/// folder changes. Passes never overlap.
class SyncController extends Notifier<SyncStatus> {
  Timer? _poll;
  Timer? _debounce;
  StreamSubscription<void>? _watch;
  String? _watchedRoot;
  bool _running = false;
  bool _again = false;

  static const debounce = Duration(seconds: 2);

  @override
  SyncStatus build() {
    final settings = ref.watch(settingsProvider);
    final signedIn = ref.watch(sessionProvider) != null;
    ref.onDispose(_stop);
    _stop();
    // Signed out: no timers, no passes.
    if (!signedIn) return const SyncStatus();
    if (settings.paused) return const SyncStatus(phase: SyncPhase.paused);
    _poll = Timer.periodic(
      Duration(seconds: settings.pollSeconds),
      (_) => syncNow(),
    );
    Future.microtask(syncNow);
    return const SyncStatus();
  }

  void _stop() {
    _poll?.cancel();
    _debounce?.cancel();
    _watch?.cancel();
    _watch = null;
    _watchedRoot = null;
  }

  void _watchFolder(String root) {
    if (_watchedRoot == root || !Directory(root).existsSync()) return;
    _watch?.cancel();
    _watchedRoot = root;
    _watch = ref.read(folderWatcherProvider)(root).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(debounce, syncNow);
    }, onError: (_) => _watchedRoot = null);
  }

  /// Runs a pass now, or queues one more if a pass is already running.
  Future<void> syncNow({bool allowMassDelete = false}) async {
    if (!ref.mounted || ref.read(sessionProvider) == null) return;
    if (state.phase == SyncPhase.paused) return;
    if (state.phase == SyncPhase.needsConfirmation && !allowMassDelete) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        state = SyncStatus(phase: SyncPhase.syncing, lastSync: state.lastSync);
        final report = await ref
            .read(syncEngineProvider)
            .run(allowMassDelete: allowMassDelete);
        if (!ref.mounted) return;
        _watchFolder(ref.read(settingsProvider).syncRoot);
        if (report.pendingDeletes != null) {
          state = SyncStatus(
            phase: SyncPhase.needsConfirmation,
            pendingDeletes: report.pendingDeletes,
            lastSync: state.lastSync,
          );
          return;
        }
        allowMassDelete = false;
        // A conflict leaves a renamed copy behind that still needs uploading.
        if (report.conflicts > 0) _again = true;
        state = SyncStatus(
          message: describe(report),
          lastSync: ref.read(clockProvider)(),
        );
      } while (_again && ref.mounted && state.phase != SyncPhase.paused);
    } catch (e) {
      if (ref.mounted) {
        state = SyncStatus(
          phase: SyncPhase.error,
          message: '$e',
          lastSync: state.lastSync,
        );
      }
    } finally {
      _running = false;
    }
  }

  /// Approves the deletions a pass stopped to ask about.
  Future<void> confirmDeletes() => syncNow(allowMassDelete: true);

  Future<void> setPaused(bool paused) =>
      ref.read(settingsProvider.notifier).setPaused(paused);

  /// Starts or stops syncing a file, a folder, or (with the root id) all of
  /// Drive. Stopping leaves files on both sides untouched.
  Future<void> setSynced(String itemId, bool synced) async {
    final db = ref.read(databaseProvider);
    if (synced) {
      await db.addSelection(itemId, ref.read(clockProvider)());
    } else {
      await db.removeSelection(itemId);
    }
    if (state.phase == SyncPhase.error) state = const SyncStatus();
    unawaited(syncNow());
  }

  static String describe(SyncReport report) {
    if (!report.changedAnything && report.errors == 0) return 'Up to date';
    final parts = [
      if (report.downloads > 0) '${report.downloads} downloaded',
      if (report.uploads > 0) '${report.uploads} uploaded',
      if (report.moves > 0) '${report.moves} moved',
      if (report.deletedLocal + report.trashedRemote > 0)
        '${report.deletedLocal + report.trashedRemote} removed',
      if (report.conflicts > 0) '${report.conflicts} conflicts',
      if (report.errors > 0) '${report.errors} failed',
    ];
    return parts.join(', ');
  }
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Ids the user explicitly chose to sync.
final selectionsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).watchSelections(),
);

/// Sync records by Drive file id, for per-item status badges.
final syncEntriesProvider = StreamProvider<Map<String, SyncEntry>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchEntries()
      .map((rows) => {for (final row in rows) row.fileId: row}),
);

final activityProvider = StreamProvider<List<ActivityEvent>>(
  (ref) => ref.watch(databaseProvider).watchActivity(),
);
