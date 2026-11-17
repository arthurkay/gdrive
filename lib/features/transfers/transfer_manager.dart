import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/clock.dart';
import '../../core/db/database.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/hashing.dart';
import '../../core/util/retry.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_api.dart';
import '../settings/settings.dart';

class TransferCancelled implements Exception {
  @override
  String toString() => 'Cancelled';
}

class ChecksumMismatch implements Exception {
  ChecksumMismatch(this.name);
  final String name;

  @override
  String toString() => 'Downloaded data for "$name" failed verification';
}

/// Runs uploads and downloads with bounded concurrency, records progress in
/// the database for the UI, and retries transient failures.
class TransferManager {
  TransferManager({
    required AppDatabase db,
    required DriveApi Function() api,
    required Clock clock,
    int Function()? concurrency,
    Sleeper sleep = Future<void>.delayed,
  }) : _db = db,
       _api = api,
       _clock = clock,
       _concurrency = concurrency ?? (() => 3),
       _sleep = sleep;

  final AppDatabase _db;
  final DriveApi Function() _api;
  final Clock _clock;
  final int Function() _concurrency;
  final Sleeper _sleep;

  final Queue<Completer<void>> _waiting = Queue();
  final Set<int> _cancelled = {};
  int _running = 0;

  /// Downloads [item] to [destPath], exporting Google-native files. The file
  /// appears at [destPath] only once complete and verified.
  Future<File> download(
    DriveItem item,
    String destPath, {
    bool fromSync = false,
    String? exportMimeType,
  }) async {
    final id = await _db.addTransfer(
      TransfersCompanion.insert(
        direction: 'download',
        name: item.name,
        localPath: destPath,
        fileId: Value(item.id),
        totalBytes: Value(item.size ?? 0),
        fromSync: Value(fromSync),
        createdAt: _clock(),
      ),
    );
    return _run(id, () async {
      final part = File('$destPath.part');
      await part.parent.create(recursive: true);
      final export = exportMimeType ?? nativeExports[item.mimeType]?.mimeType;
      final sink = part.openWrite();
      try {
        final stream = export != null
            ? _api().export(item.id, export)
            : _api().download(item.id);
        await _pump(id, stream, sink.add);
        await sink.close();
        if (export == null && item.md5 != null) {
          if (await md5OfFile(part.path) != item.md5) {
            throw ChecksumMismatch(item.name);
          }
        }
        return await part.rename(destPath);
      } catch (_) {
        await sink.close().catchError((_) {});
        if (await part.exists()) await part.delete();
        rethrow;
      }
    });
  }

  /// Uploads [localPath] as a new file in [parentId], or as a new revision of
  /// [replaceFileId].
  Future<DriveItem> upload(
    String localPath, {
    String? parentId,
    String? replaceFileId,
    String? name,
    bool fromSync = false,
  }) async {
    assert((parentId == null) != (replaceFileId == null));
    final file = File(localPath);
    final stat = await file.stat();
    final uploadName = name ?? p.basename(localPath);
    final id = await _db.addTransfer(
      TransfersCompanion.insert(
        direction: 'upload',
        name: uploadName,
        localPath: localPath,
        fileId: Value(replaceFileId),
        totalBytes: Value(stat.size),
        fromSync: Value(fromSync),
        createdAt: _clock(),
      ),
    );
    return _run(id, () async {
      final length = await file.length();
      final data = _counted(id, file.openRead());
      final item = replaceFileId != null
          ? await _api().updateContent(
              replaceFileId,
              data: data,
              length: length,
              modifiedTime: stat.modified,
            )
          : await _api().upload(
              name: uploadName,
              parentId: parentId!,
              data: data,
              length: length,
              modifiedTime: stat.modified,
            );
      await _db.upsertItems([item]);
      await _db.updateTransfer(id, TransfersCompanion(fileId: Value(item.id)));
      return item;
    });
  }

  /// Stops a queued or running transfer at its next chunk.
  void cancel(int id) => _cancelled.add(id);

  Future<T> _run<T>(int id, Future<T> Function() body) async {
    await _acquire();
    try {
      if (_cancelled.contains(id)) throw TransferCancelled();
      await _db.updateTransfer(
        id,
        const TransfersCompanion(state: Value('running')),
      );
      final result = await withRetry(
        () async {
          await _db.updateTransfer(
            id,
            const TransfersCompanion(doneBytes: Value(0)),
          );
          return body();
        },
        retryIf: isTransient,
        sleep: _sleep,
      );
      final row = await _db.transfer(id);
      await _db.updateTransfer(
        id,
        TransfersCompanion(
          state: const Value('done'),
          doneBytes: Value(row?.totalBytes ?? 0),
        ),
      );
      return result;
    } on TransferCancelled {
      await _db.updateTransfer(
        id,
        const TransfersCompanion(state: Value('cancelled')),
      );
      rethrow;
    } catch (e) {
      await _db.updateTransfer(
        id,
        TransfersCompanion(state: const Value('failed'), error: Value('$e')),
      );
      rethrow;
    } finally {
      _cancelled.remove(id);
      _release();
    }
  }

  Future<void> _pump(
    int id,
    Stream<List<int>> stream,
    void Function(List<int>) write,
  ) async {
    await for (final chunk in _counted(id, stream)) {
      write(chunk);
    }
  }

  /// Passes [source] through, recording progress and honouring cancellation.
  Stream<List<int>> _counted(int id, Stream<List<int>> source) async* {
    var done = 0;
    var reported = 0;
    final watch = Stopwatch()..start();
    await for (final chunk in source) {
      if (_cancelled.contains(id)) throw TransferCancelled();
      done += chunk.length;
      if (watch.elapsedMilliseconds >= 250 && done != reported) {
        watch.reset();
        reported = done;
        await _db.updateTransfer(
          id,
          TransfersCompanion(doneBytes: Value(done)),
        );
      }
      yield chunk;
    }
    if (done != reported) {
      await _db.updateTransfer(
        id,
        TransfersCompanion(doneBytes: Value(done), totalBytes: Value(done)),
      );
    }
  }

  Future<void> _acquire() async {
    if (_running < _concurrency()) {
      _running++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }
}

final transferManagerProvider = Provider<TransferManager>(
  (ref) => TransferManager(
    db: ref.watch(databaseProvider),
    api: () => ref.read(driveApiProvider),
    clock: ref.watch(clockProvider),
    concurrency: () => ref.read(settingsProvider).concurrency,
  ),
);

final transfersProvider = StreamProvider<List<Transfer>>(
  (ref) => ref.watch(databaseProvider).watchTransfers(),
);
