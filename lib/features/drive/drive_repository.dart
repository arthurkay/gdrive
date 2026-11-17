import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/names.dart';
import '../auth/auth_controller.dart';
import '../sync/remote_tree.dart';
import '../transfers/transfer_manager.dart';
import 'drive_api.dart';

/// File management on Drive. Reads come from the local cache so the browser
/// is instant and works offline; every write goes to Drive first and is then
/// mirrored into the cache.
class DriveRepository {
  DriveRepository({
    required AppDatabase db,
    required DriveApi Function() api,
    required TransferManager transfers,
  }) : _db = db,
       _api = api,
       _transfers = transfers;

  final AppDatabase _db;
  final DriveApi Function() _api;
  final TransferManager _transfers;

  Stream<List<DriveItem>> watch(DriveListing listing) => switch (listing) {
    FolderListing(:final folderId) => _db.watchChildren(folderId),
    SharedListing() => _db.watchSharedWithMe(),
    StarredListing() => _db.watchStarred(),
    TrashListing() => _db.watchTrashed(),
    RecentListing() => _db.watchRecent(),
    SearchListing(:final text) => _db.watchSearch(text),
    AllListing() => _db.select(_db.driveItems).watch(),
  };

  /// Fetches [listing] from Drive and reconciles the cache with it.
  Future<void> refresh(DriveListing listing) async {
    final items = await _api().list(listing);
    final ids = items.map((e) => e.id).toSet();
    switch (listing) {
      case FolderListing(:final folderId):
        await _db.replaceChildren(folderId, items);
      case AllListing():
        await _db.replaceAllLive(items);
      case TrashListing():
        final cached = await _db.watchTrashed().first;
        await _db.removeItems(
          cached.map((e) => e.id).where((id) => !ids.contains(id)),
        );
        await _db.upsertItems(items);
      case StarredListing():
        final cached = await _db.watchStarred().first;
        await _db.upsertItems([
          for (final item in cached)
            if (!ids.contains(item.id)) item.copyWith(starred: false),
          ...items,
        ]);
      case SharedListing() || RecentListing() || SearchListing():
        await _db.upsertItems(items);
    }
  }

  Future<DriveItem> createFolder(String name, String parentId) =>
      _store(_api().createFolder(name.trim(), parentId));

  Future<DriveItem> rename(DriveItem item, String name) =>
      _store(_api().updateMetadata(item.id, name: name.trim()));

  Future<DriveItem> move(DriveItem item, String newParentId) => _store(
    _api().updateMetadata(
      item.id,
      addParent: newParentId,
      removeParent: item.parentId,
    ),
  );

  Future<DriveItem> copy(DriveItem item) =>
      _store(_api().copy(item.id, parentId: item.parentId));

  Future<DriveItem> setStarred(DriveItem item, bool starred) =>
      _store(_api().updateMetadata(item.id, starred: starred));

  Future<DriveItem> trash(DriveItem item) =>
      _store(_api().updateMetadata(item.id, trashed: true));

  Future<DriveItem> restore(DriveItem item) =>
      _store(_api().updateMetadata(item.id, trashed: false));

  /// Permanent; the UI confirms first.
  Future<void> deleteForever(DriveItem item) async {
    await _api().delete(item.id);
    await _db.removeItems([item.id]);
  }

  Future<void> emptyTrash() async {
    await _api().emptyTrash();
    final cached = await _db.watchTrashed().first;
    await _db.removeItems(cached.map((e) => e.id));
  }

  /// Uploads files and whole folders from disk into [parentId]. Returns how
  /// many files failed.
  Future<int> uploadPaths(Iterable<String> paths, String parentId) async {
    var failed = 0;
    final uploads = <Future<void>>[];

    Future<void> visit(String path, String parent) async {
      if (isIgnoredLocalName(p.basename(path))) return;
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        final folder = await createFolder(p.basename(path), parent);
        await for (final child in Directory(path).list(followLinks: false)) {
          await visit(child.path, folder.id);
        }
      } else if (type == FileSystemEntityType.file) {
        uploads.add(
          _transfers
              .upload(path, parentId: parent)
              .then<void>((_) {}, onError: (_) => failed++),
        );
      }
    }

    for (final path in paths) {
      try {
        await visit(path, parentId);
      } catch (_) {
        failed++;
      }
    }
    await Future.wait(uploads);
    return failed;
  }

  /// Saves [item] (recursively for folders) into [directory]. Returns how
  /// many files failed.
  Future<int> downloadTo(DriveItem item, String directory) async {
    var failed = 0;
    final downloads = <Future<void>>[];

    Future<void> visit(DriveItem current, String dir) async {
      if (current.isUnsyncable) return;
      final target = await _freePath(p.join(dir, localNameOf(current)));
      if (current.isFolder) {
        await Directory(target).create(recursive: true);
        for (final child in await _api().list(FolderListing(current.id))) {
          await visit(child, target);
        }
      } else {
        downloads.add(
          _transfers
              .download(current, target)
              .then<void>((_) {}, onError: (_) => failed++),
        );
      }
    }

    try {
      await visit(item, directory);
    } catch (_) {
      failed++;
    }
    await Future.wait(downloads);
    return failed;
  }

  Future<String> _freePath(String path) async {
    var candidate = path;
    for (
      var n = 2;
      await FileSystemEntity.type(candidate) != FileSystemEntityType.notFound;
      n++
    ) {
      candidate = p.join(p.dirname(path), numberedName(p.basename(path), n));
    }
    return candidate;
  }

  Future<DriveItem> _store(Future<DriveItem> call) async {
    final item = await call;
    // Listings omit viewedTime on some responses; keep what we had.
    final previous = await _db.item(item.id);
    await _db.upsertItems([
      item.viewedTime == null && previous?.viewedTime != null
          ? item.copyWith(viewedTime: Value(previous!.viewedTime))
          : item,
    ]);
    return item;
  }
}

final driveRepositoryProvider = Provider<DriveRepository>(
  (ref) => DriveRepository(
    db: ref.watch(databaseProvider),
    api: () => ref.read(driveApiProvider),
    transfers: ref.watch(transferManagerProvider),
  ),
);
