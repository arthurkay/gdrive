import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'database.g.dart';

// coverage:ignore-start
// Table declarations are read by drift's code generator at build time and
// never executed, so line coverage does not apply to them.
/// Cached Drive metadata. One row per file or folder the app has seen.
@DataClassName('DriveItem')
class DriveItems extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get mimeType => text()();
  IntColumn get size => integer().nullable()();
  TextColumn get md5 => text().nullable()();
  DateTimeColumn get modifiedTime => dateTime().nullable()();
  DateTimeColumn get viewedTime => dateTime().nullable()();
  BoolColumn get trashed => boolean().withDefault(const Constant(false))();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  BoolColumn get sharedWithMe => boolean().withDefault(const Constant(false))();
  TextColumn get thumbnailLink => text().nullable()();
  TextColumn get webViewLink => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items the user asked to keep in sync. The Drive root id means "everything".
@DataClassName('SyncSelection')
class SyncSelections extends Table {
  TextColumn get itemId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// State of a file or folder at the moment both sides last agreed.
@DataClassName('SyncEntry')
class SyncEntries extends Table {
  TextColumn get fileId => text()();

  /// Path below the sync root, always with forward slashes.
  TextColumn get relPath => text().unique()();
  BoolColumn get isFolder => boolean().withDefault(const Constant(false))();

  /// Google Docs/Sheets/Slides export: download-only.
  BoolColumn get isNative => boolean().withDefault(const Constant(false))();
  IntColumn get localSize => integer().nullable()();
  IntColumn get localMtimeMs => integer().nullable()();
  TextColumn get localMd5 => text().nullable()();
  TextColumn get remoteMd5 => text().nullable()();
  IntColumn get remoteModifiedMs => integer().nullable()();

  /// True when a native export was edited locally; those edits stay local.
  BoolColumn get localEdited => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {fileId};
}

@DataClassName('Transfer')
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `upload` or `download`.
  TextColumn get direction => text()();
  TextColumn get name => text()();
  TextColumn get localPath => text()();
  TextColumn get fileId => text().nullable()();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get doneBytes => integer().withDefault(const Constant(0))();

  /// `queued`, `running`, `done`, `failed` or `cancelled`.
  TextColumn get state => text().withDefault(const Constant('queued'))();
  TextColumn get error => text().nullable()();
  BoolColumn get fromSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('KvEntry')
class Kv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ActivityEvent')
class Activity extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();

  /// `info`, `download`, `upload`, `delete`, `conflict` or `error`.
  TextColumn get kind => text()();
  TextColumn get message => text()();
}

// coverage:ignore-end

@DriftDatabase(
  tables: [DriveItems, SyncSelections, SyncEntries, Transfers, Kv, Activity],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open(String path) => AppDatabase(
    driftDatabase(
      name: 'gdrive',
      native: DriftNativeOptions(databasePath: () async => path),
    ),
  );

  @override
  int get schemaVersion => 1;

  // ---- key/value -----------------------------------------------------------

  Future<String?> getValue(String key) async {
    final row = await (select(
      kv,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchValue(String key) => (select(
    kv,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

  Future<void> setValue(String key, String? value) async {
    if (value == null) {
      await (delete(kv)..where((t) => t.key.equals(key))).go();
    } else {
      await into(kv).insertOnConflictUpdate(KvEntry(key: key, value: value));
    }
  }

  // ---- drive items ---------------------------------------------------------

  Future<void> upsertItems(Iterable<DriveItem> items) async {
    final list = items.toList();
    if (list.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(driveItems, list));
  }

  Future<void> removeItems(Iterable<String> ids) async {
    final list = ids.toList();
    // Stay well under SQLite's bound-variable limit.
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, (i + 500).clamp(0, list.length));
      await (delete(driveItems)..where((t) => t.id.isIn(chunk))).go();
    }
  }

  Future<DriveItem?> item(String id) =>
      (select(driveItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<DriveItem>> allItems() => select(driveItems).get();

  Future<List<DriveItem>> children(String parentId) => (select(
    driveItems,
  )..where((t) => t.parentId.equals(parentId) & t.trashed.equals(false))).get();

  Stream<List<DriveItem>> watchChildren(String parentId) =>
      (select(driveItems)..where(
            (t) => t.parentId.equals(parentId) & t.trashed.equals(false),
          ))
          .watch();

  Stream<List<DriveItem>> watchStarred() => (select(
    driveItems,
  )..where((t) => t.starred.equals(true) & t.trashed.equals(false))).watch();

  Stream<List<DriveItem>> watchTrashed() =>
      (select(driveItems)..where((t) => t.trashed.equals(true))).watch();

  Stream<List<DriveItem>> watchSharedWithMe() =>
      (select(driveItems)..where(
            (t) => t.sharedWithMe.equals(true) & t.trashed.equals(false),
          ))
          .watch();

  Stream<List<DriveItem>> watchRecent({int limit = 50}) =>
      (select(driveItems)
            ..where(
              (t) =>
                  t.trashed.equals(false) &
                  t.viewedTime.isNotNull() &
                  t.mimeType.equals(folderMimeType).not(),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.viewedTime)])
            ..limit(limit))
          .watch();

  Stream<List<DriveItem>> watchSearch(String text) => (select(
    driveItems,
  )..where((t) => t.name.contains(text) & t.trashed.equals(false))).watch();

  /// Replaces the cached children of [parentId] with [items], dropping rows
  /// that no longer exist remotely.
  Future<void> replaceChildren(String parentId, List<DriveItem> items) =>
      transaction(() async {
        final keep = items.map((e) => e.id).toSet();
        final stale = (await children(
          parentId,
        )).map((e) => e.id).where((id) => !keep.contains(id));
        await removeItems(stale);
        await upsertItems(items);
      });

  /// Replaces every cached live item with [items] (a full Drive listing).
  Future<void> replaceAllLive(List<DriveItem> items) => transaction(() async {
    final keep = items.map((e) => e.id).toSet();
    final existing = await (select(
      driveItems,
    )..where((t) => t.trashed.equals(false))).get();
    await removeItems(
      existing.map((e) => e.id).where((id) => !keep.contains(id)),
    );
    await upsertItems(items);
  });

  // ---- selections ----------------------------------------------------------

  Future<List<String>> selections() async =>
      (await select(syncSelections).get()).map((e) => e.itemId).toList();

  Stream<Set<String>> watchSelections() => select(
    syncSelections,
  ).watch().map((rows) => rows.map((e) => e.itemId).toSet());

  Future<void> addSelection(String itemId, DateTime now) => into(
    syncSelections,
  ).insertOnConflictUpdate(SyncSelection(itemId: itemId, createdAt: now));

  Future<void> removeSelection(String itemId) =>
      (delete(syncSelections)..where((t) => t.itemId.equals(itemId))).go();

  // ---- sync entries --------------------------------------------------------

  Future<List<SyncEntry>> entries() => select(syncEntries).get();

  Stream<List<SyncEntry>> watchEntries() => select(syncEntries).watch();

  Future<void> putEntry(SyncEntry entry) => transaction(() async {
    // A path can only belong to one file; drop any stale owner first.
    await (delete(syncEntries)..where(
          (t) =>
              t.relPath.equals(entry.relPath) &
              t.fileId.equals(entry.fileId).not(),
        ))
        .go();
    await into(syncEntries).insertOnConflictUpdate(entry);
  });

  Future<void> removeEntry(String fileId) =>
      (delete(syncEntries)..where((t) => t.fileId.equals(fileId))).go();

  // ---- transfers -----------------------------------------------------------

  Stream<List<Transfer>> watchTransfers() =>
      (select(transfers)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  Future<int> addTransfer(TransfersCompanion row) =>
      into(transfers).insert(row);

  Future<void> updateTransfer(int id, TransfersCompanion row) =>
      (update(transfers)..where((t) => t.id.equals(id))).write(row);

  Future<Transfer?> transfer(int id) =>
      (select(transfers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> clearFinishedTransfers() => (delete(
    transfers,
  )..where((t) => t.state.isIn(const ['done', 'failed', 'cancelled']))).go();

  /// Transfers that were mid-flight when the app last quit cannot be resumed.
  Future<void> failInterruptedTransfers() =>
      (update(
        transfers,
      )..where((t) => t.state.isIn(const ['queued', 'running']))).write(
        const TransfersCompanion(
          state: Value('failed'),
          error: Value('Interrupted when the app closed'),
        ),
      );

  // ---- activity ------------------------------------------------------------

  Future<void> log(String kind, String message, DateTime at) => into(
    activity,
  ).insert(ActivityCompanion.insert(at: at, kind: kind, message: message));

  Stream<List<ActivityEvent>> watchActivity({int limit = 200}) =>
      (select(activity)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(limit))
          .watch();

  Future<void> clearActivity() => delete(activity).go();

  /// Wipes everything tied to the signed-in account.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}

const folderMimeType = 'application/vnd.google-apps.folder';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);
