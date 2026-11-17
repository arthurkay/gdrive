import 'dart:io';

import 'package:drift/native.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/sync/sync_engine.dart';
import 'package:gdrive/features/transfers/transfer_manager.dart';
import 'package:path/path.dart' as p;

AppDatabase memoryDatabase() => AppDatabase(NativeDatabase.memory());

/// A fake Drive, a temp sync folder and a real engine wired between them.
class SyncHarness {
  SyncHarness._(this.temp, this.db, this.drive) {
    transfers = TransferManager(
      db: db,
      api: () => drive,
      clock: () => now,
      sleep: (_) async {},
    );
    engine = newEngine();
  }

  static Future<SyncHarness> create() async => SyncHarness._(
    await Directory.systemTemp.createTemp('gdrive_test_'),
    memoryDatabase(),
    FakeDriveApi(),
  );

  final Directory temp;
  final AppDatabase db;
  final FakeDriveApi drive;
  late final TransferManager transfers;
  late SyncEngine engine;
  DateTime now = DateTime(2026, 11, 17, 9);
  int _mtimeBump = 0;

  String get root => p.join(temp.path, 'sync');
  String get recycle => p.join(temp.path, 'recycle');

  /// A fresh engine over the same state, as after an app restart.
  SyncEngine newEngine() => SyncEngine(
    db: db,
    api: () => drive,
    transfers: transfers,
    clock: () => now,
    syncRoot: () => root,
    rootId: () => FakeDriveApi.rootId,
    recycleDir: recycle,
  );

  Future<void> select(String id) => db.addSelection(id, now);
  Future<void> selectAll() => select(FakeDriveApi.rootId);

  Future<SyncReport> sync({bool allowMassDelete = false}) =>
      engine.run(allowMassDelete: allowMassDelete);

  File local(String rel) => File(p.joinAll([root, ...rel.split('/')]));
  Directory localDir(String rel) =>
      Directory(p.joinAll([root, ...rel.split('/')]));

  bool has(String rel) => local(rel).existsSync();
  String read(String rel) => local(rel).readAsStringSync();

  /// Writes a local file with a modification time later than any before it,
  /// so same-size edits are still seen as changes.
  void write(String rel, String content) {
    final file = local(rel)..createSync(recursive: true);
    file.writeAsStringSync(content);
    file.setLastModifiedSync(
      DateTime(2027).add(Duration(seconds: 2 * ++_mtimeBump)),
    );
  }

  /// Relative paths of every file in the sync folder, sorted.
  List<String> localFiles() {
    final dir = Directory(root);
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.split(p.relative(f.path, from: root)).join('/'))
        .toList()
      ..sort();
  }

  List<String> recycled() {
    final dir = Directory(recycle);
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList()
      ..sort();
  }

  /// Calls made to the fake since [mark], filtered to [operation].
  List<String> callsTo(String operation, {int since = 0}) => drive.calls
      .skip(since)
      .where((c) => c.startsWith('$operation:'))
      .toList();

  Future<List<String>> activity(String kind) async =>
      (await db.watchActivity().first)
          .where((e) => e.kind == kind)
          .map((e) => e.message)
          .toList();

  Future<void> dispose() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}
