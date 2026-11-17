import 'dart:collection';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/clock.dart';
import '../../core/db/database.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/hashing.dart';
import '../../core/util/names.dart';
import '../../core/util/retry.dart';
import '../drive/drive_api.dart';
import '../transfers/transfer_manager.dart';
import 'local_scanner.dart';
import 'reconciler.dart';
import 'remote_tree.dart';

const changesTokenKey = 'changesToken';

/// Outcome of one sync pass.
class SyncReport {
  int downloads = 0;
  int uploads = 0;
  int deletedLocal = 0;
  int trashedRemote = 0;
  int conflicts = 0;
  int moves = 0;
  int errors = 0;

  /// Set when the pass stopped to ask before deleting this many files.
  int? pendingDeletes;

  bool get changedAnything =>
      downloads + uploads + deletedLocal + trashedRemote + conflicts + moves >
      0;
}

/// The sync folder vanished while files were still tracked in it. Syncing
/// would read that as "everything was deleted", so the pass refuses to run.
class SyncRootMissing implements Exception {
  SyncRootMissing(this.path);
  final String path;

  @override
  String toString() => 'Sync folder not found: $path';
}

class _Action {
  _Action(this.decision, this.path, {this.local, this.remote, this.base});

  final SyncDecision decision;
  final String path;
  final LocalNode? local;
  final DriveItem? remote;
  final SyncEntry? base;
}

/// Two-way sync between the selected parts of Drive and a local folder.
///
/// Each [run] is one pass: bring the Drive index up to date, look at the
/// disk, decide per file with [decide], then carry the decisions out.
/// Nothing is deleted permanently on either side.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required DriveApi Function() api,
    required TransferManager transfers,
    required Clock clock,
    required String Function() syncRoot,
    required String Function() rootId,
    required this.recycleDir,
    int Function()? concurrency,
  }) : _db = db,
       _api = api,
       _transfers = transfers,
       _clock = clock,
       _syncRoot = syncRoot,
       _rootId = rootId,
       _concurrency = concurrency ?? (() => 3);

  final AppDatabase _db;
  final DriveApi Function() _api;
  final TransferManager _transfers;
  final Clock _clock;
  final String Function() _syncRoot;
  final String Function() _rootId;
  final int Function() _concurrency;

  /// Where locally deleted files wait for [recycleRetention] before removal.
  final String recycleDir;
  static const recycleRetention = Duration(days: 30);

  /// Selections fully listed since the app started.
  final Set<String> _crawled = {};
  final Map<String, Future<String>> _folderCreations = {};

  late RemoteTree _tree;
  late String _root;

  Future<SyncReport> run({bool allowMassDelete = false}) async {
    final report = SyncReport();
    _root = _syncRoot();
    _folderCreations.clear();
    final selections = await _db.selections();
    var base = await _db.entries();

    if (selections.isEmpty) {
      // Nothing is synced any more; local files stay where they are.
      for (final entry in base) {
        await _db.removeEntry(entry.fileId);
      }
      return report;
    }

    final rootDir = Directory(_root);
    if (!await rootDir.exists()) {
      if (base.any((e) => !e.isFolder)) throw SyncRootMissing(_root);
      await rootDir.create(recursive: true);
    }

    await _refreshRemote(selections);
    _tree = buildRemoteTree(
      items: await _db.allItems(),
      selections: selections,
      rootId: _rootId(),
    );
    for (final id in _tree.staleSelections) {
      await _db.removeSelection(id);
      _crawled.remove(id);
      await _log('info', 'Stopped syncing an item that is no longer on Drive');
    }

    final inScope = <SyncEntry>[];
    for (final entry in base) {
      if (_tree.inScope(entry.relPath)) {
        inScope.add(entry);
      } else {
        await _db.removeEntry(entry.fileId);
      }
    }
    base = await _followRemoteMoves(inScope, report);

    final local = await scanLocal(
      root: _root,
      dirs: _tree.scopeDirs,
      files: _tree.scopeFiles,
    );
    base = await _followLocalMoves(base, local, report);

    final plan = await _plan(base, local, report);

    final deletions = plan.actions
        .where(
          (a) =>
              a.decision == SyncDecision.deleteLocal ||
              a.decision == SyncDecision.trashRemote,
        )
        .length;
    final tracked = base.where((e) => !e.isFolder).length;
    if (!allowMassDelete &&
        needsDeleteConfirmation(deletions: deletions, tracked: tracked)) {
      report.pendingDeletes = deletions;
      return report;
    }

    final queue = Queue.of(plan.actions);
    final trashed = <String>{};
    await Future.wait(
      List.generate(_concurrency().clamp(1, 16), (_) async {
        while (queue.isNotEmpty) {
          final action = queue.removeFirst();
          try {
            await _execute(action, report, trashed);
          } catch (e) {
            report.errors++;
            await _log('error', '${action.path}: $e');
          }
        }
      }),
    );

    await _finishFolders(plan, report, trashed);
    await _purgeRecycle();
    return report;
  }

  // ---- remote index --------------------------------------------------------

  Future<void> _refreshRemote(List<String> selections) async {
    var token = await _db.getValue(changesTokenKey);
    if (token != null) {
      try {
        token = await _applyChanges(token);
      } on DriveApiException catch (e) {
        if (e.status != 410 && e.status != 400) rethrow;
        token = null; // The token expired; index from scratch.
      }
    }
    if (token == null) {
      token = await _api().startPageToken();
      _crawled.clear();
    }
    for (final id in selections) {
      if (_crawled.contains(id)) continue;
      await _crawl(id);
      _crawled.add(id);
    }
    // Saved last: if the crawl fails, the next pass starts over.
    await _db.setValue(changesTokenKey, token);
  }

  Future<String> _applyChanges(String token) async {
    final result = await _api().changes(token);
    if (result.changes.isEmpty) return result.nextToken;
    final known = {for (final item in await _db.allItems()) item.id};
    final removed = <String>[];
    final changed = <DriveItem>[];
    for (final change in result.changes) {
      if (change.removed || change.item == null) {
        removed.add(change.fileId);
      } else {
        changed.add(change.item!);
      }
    }
    await _db.removeItems(removed);
    await _db.upsertItems(changed);
    // A folder moved or shared into view arrives without its contents.
    for (final item in changed) {
      if (item.isFolder && !item.trashed && !known.contains(item.id)) {
        await _crawlFolder(item.id);
      }
    }
    return result.nextToken;
  }

  Future<void> _crawl(String id) async {
    if (id == _rootId()) {
      await _db.replaceAllLive(await _api().list(const AllListing()));
      return;
    }
    final DriveItem item;
    try {
      item = await _api().get(id);
    } on DriveApiException catch (e) {
      if (!e.isNotFound) rethrow;
      await _db.removeItems([id]);
      return;
    }
    await _db.upsertItems([item]);
    // The ancestors give the item its path below the sync root.
    var parent = item.parentId;
    while (parent != null &&
        parent != _rootId() &&
        await _db.item(parent) == null) {
      final ancestor = await _api().get(parent);
      await _db.upsertItems([ancestor]);
      parent = ancestor.parentId;
    }
    if (item.isFolder && !item.trashed) await _crawlFolder(id);
  }

  Future<void> _crawlFolder(String id) async {
    final pending = Queue.of([id]);
    while (pending.isNotEmpty) {
      final folder = pending.removeFirst();
      final children = await _api().list(FolderListing(folder));
      await _db.replaceChildren(folder, children);
      pending.addAll(children.where((c) => c.isFolder).map((c) => c.id));
    }
  }

  // ---- renames and moves ---------------------------------------------------

  /// Applies Drive-side renames and moves to the local folder, so they are
  /// not mistaken for a delete plus a new file.
  Future<List<SyncEntry>> _followRemoteMoves(
    List<SyncEntry> base,
    SyncReport report,
  ) async {
    final entries = {for (final e in base) e.fileId: e};
    final order = [...base]
      ..sort((a, b) => a.relPath.length.compareTo(b.relPath.length));
    final touched = <String>{};

    for (final original in order) {
      final entry = entries[original.fileId];
      if (entry == null) continue;
      final target = _tree.pathById[entry.fileId];
      if (target == null || target == entry.relPath) continue;

      final from = toAbsPath(_root, entry.relPath);
      final to = toAbsPath(_root, target);
      final exists =
          await FileSystemEntity.type(from, followLinks: false) !=
          FileSystemEntityType.notFound;
      final blocked =
          await FileSystemEntity.type(to, followLinks: false) !=
          FileSystemEntityType.notFound;
      final prefix = '${entry.relPath}/';
      final affected = entries.values
          .where(
            (e) =>
                e.fileId == entry.fileId ||
                (entry.isFolder && e.relPath.startsWith(prefix)),
          )
          .toList();

      if (exists && blocked) {
        // Something else already sits at the new path. Forget the old
        // records so both copies are treated as new rather than deleted.
        for (final e in affected) {
          entries.remove(e.fileId);
          await _db.removeEntry(e.fileId);
        }
        continue;
      }
      if (exists) {
        await Directory(p.dirname(to)).create(recursive: true);
        if (entry.isFolder) {
          await Directory(from).rename(to);
        } else {
          await File(from).rename(to);
        }
        report.moves++;
        await _log('info', 'Moved ${entry.relPath} to $target');
      }
      for (final e in affected) {
        final path = e.fileId == entry.fileId
            ? target
            : '$target/${e.relPath.substring(prefix.length)}';
        entries[e.fileId] = e.copyWith(relPath: path);
        touched.add(e.fileId);
      }
    }
    for (final id in touched) {
      final entry = entries[id];
      if (entry != null) await _db.putEntry(entry);
    }
    return entries.values.toList();
  }

  /// Detects files renamed or moved on disk (same bytes, new path) and
  /// applies the same move on Drive.
  Future<List<SyncEntry>> _followLocalMoves(
    List<SyncEntry> base,
    Map<String, LocalNode> local,
    SyncReport report,
  ) async {
    final basePaths = {for (final e in base) e.relPath};
    final missing = base
        .where(
          (e) =>
              !e.isFolder &&
              !e.isNative &&
              e.localMd5 != null &&
              (e.localSize ?? 0) > 0 &&
              !local.containsKey(e.relPath) &&
              _tree.byPath[e.relPath]?.id == e.fileId &&
              _tree.byPath[e.relPath]?.md5 == e.remoteMd5,
        )
        .toList();
    if (missing.isEmpty) return base;

    final result = {for (final e in base) e.fileId: e};
    final unknown = local.entries
        .where(
          (e) =>
              !e.value.isDir &&
              !basePaths.contains(e.key) &&
              !_tree.byPath.containsKey(e.key),
        )
        .toList();

    for (final candidate in unknown) {
      final sameSize = missing
          .where((e) => e.localSize == candidate.value.size)
          .toList();
      if (sameSize.isEmpty) continue;
      try {
        final hash = await md5OfFile(toAbsPath(_root, candidate.key));
        final entry = sameSize.where((e) => e.localMd5 == hash).firstOrNull;
        if (entry == null) continue;
        final remote = _tree.byPath[entry.relPath]!;
        final newParent = relParent(candidate.key);
        final newName = relName(candidate.key);
        final parentChanged = newParent != relParent(entry.relPath);
        final parentId = parentChanged
            ? await _ensureRemoteFolder(newParent)
            : null;
        final moved = await _api().updateMetadata(
          remote.id,
          name: newName != relName(entry.relPath) ? newName : null,
          addParent: parentId,
          removeParent: parentChanged ? remote.parentId : null,
        );
        await _db.upsertItems([moved]);
        _tree.move(entry.relPath, candidate.key, moved);
        final updated = entry.copyWith(
          relPath: candidate.key,
          localMtimeMs: Value(candidate.value.mtimeMs),
          remoteModifiedMs: Value(moved.modifiedTime?.millisecondsSinceEpoch),
        );
        await _db.putEntry(updated);
        result[entry.fileId] = updated;
        missing.remove(entry);
        report.moves++;
        await _log(
          'info',
          'Moved ${entry.relPath} to ${candidate.key} on Drive',
        );
      } catch (e) {
        report.errors++;
        await _log('error', '${candidate.key}: $e');
      }
    }
    return result.values.toList();
  }

  Future<String> _ensureRemoteFolder(String rel) {
    if (rel.isEmpty) return Future.value(_rootId());
    final existing = _tree.byPath[rel];
    if (existing != null && existing.isFolder) return Future.value(existing.id);
    return _folderCreations[rel] ??= () async {
      if (rel == sharedFolderName) {
        throw StateError('New items cannot be added to "$sharedFolderName"');
      }
      final parentId = await _ensureRemoteFolder(relParent(rel));
      final folder = await _api().createFolder(relName(rel), parentId);
      await _db.upsertItems([folder]);
      _tree.add(rel, folder);
      await _db.putEntry(
        SyncEntry(
          fileId: folder.id,
          relPath: rel,
          isFolder: true,
          isNative: false,
          localEdited: false,
        ),
      );
      return folder.id;
    }();
  }

  // ---- planning ------------------------------------------------------------

  Future<_Plan> _plan(
    List<SyncEntry> base,
    Map<String, LocalNode> local,
    SyncReport report,
  ) async {
    final plan = _Plan();
    final baseByPath = {for (final e in base) e.relPath: e};
    final paths = SplayTreeSet<String>.of([
      ..._tree.byPath.keys,
      ...local.keys,
      ...baseByPath.keys,
    ]);

    for (final path in paths) {
      if (!_tree.inScope(path)) continue;
      final remote = _tree.byPath[path];
      final node = local[path];
      var entry = baseByPath[path];
      // A different Drive file now owns this path; the old record is moot.
      if (entry != null && remote != null && entry.fileId != remote.id) {
        entry = null;
      }
      try {
        final remoteIsFolder = remote?.isFolder;
        final localIsFolder = node?.isDir;
        if (remoteIsFolder != null &&
            localIsFolder != null &&
            remoteIsFolder != localIsFolder) {
          report.errors++;
          await _log(
            'error',
            '$path is a folder on one side and a file on the other; skipped',
          );
          continue;
        }
        final isFolder =
            remoteIsFolder ?? localIsFolder ?? entry?.isFolder ?? false;
        if (isFolder) {
          await _planFolder(plan, path, node, remote, entry);
        } else {
          final action = await _planFile(path, node, remote, entry);
          if (action != null) plan.actions.add(action);
        }
      } catch (e) {
        report.errors++;
        await _log('error', '$path: $e');
      }
    }
    return plan;
  }

  Future<void> _planFolder(
    _Plan plan,
    String path,
    LocalNode? node,
    DriveItem? remote,
    SyncEntry? entry,
  ) async {
    SyncEntry record(String id) => SyncEntry(
      fileId: id,
      relPath: path,
      isFolder: true,
      isNative: false,
      localEdited: false,
    );
    if (remote != null && node != null) {
      if (entry == null) await _db.putEntry(record(remote.id));
    } else if (remote != null) {
      if (entry != null) {
        plan.locallyDeletedFolders.add(path);
      } else {
        await Directory(toAbsPath(_root, path)).create(recursive: true);
        await _db.putEntry(record(remote.id));
      }
    } else if (node != null) {
      if (entry != null) {
        plan.remotelyDeletedFolders[path] = entry.fileId;
      } else {
        await _ensureRemoteFolder(path);
      }
    } else if (entry != null) {
      await _db.removeEntry(entry.fileId);
    }
  }

  Future<_Action?> _planFile(
    String path,
    LocalNode? node,
    DriveItem? remote,
    SyncEntry? entry,
  ) async {
    final native = remote?.isNative ?? entry?.isNative ?? false;
    final abs = toAbsPath(_root, path);
    var localChanged = false;
    var remoteChanged = false;
    var sameContent = false;
    String? localMd5;

    if (node != null && entry != null) {
      if (node.size != entry.localSize || node.mtimeMs != entry.localMtimeMs) {
        localMd5 = await md5OfFile(abs);
        localChanged = localMd5 != entry.localMd5;
        if (!localChanged) {
          // Touched but not edited: remember the new timestamp.
          entry = entry.copyWith(localMtimeMs: Value(node.mtimeMs));
          await _db.putEntry(entry);
        }
      }
    }
    if (remote != null && entry != null) {
      remoteChanged = native
          ? remote.modifiedTime?.millisecondsSinceEpoch !=
                entry.remoteModifiedMs
          : remote.md5 != entry.remoteMd5;
    }
    if (node != null &&
        remote != null &&
        !native &&
        (entry == null || (localChanged && remoteChanged)) &&
        node.size == remote.size) {
      localMd5 ??= await md5OfFile(abs);
      sameContent = localMd5 == remote.md5;
    }

    final decision = decide(
      local: node != null,
      remote: remote != null,
      base: entry != null,
      localChanged: localChanged,
      remoteChanged: remoteChanged,
      sameContent: sameContent,
      native: native,
    );
    if (decision == SyncDecision.none) return null;
    if (decision == SyncDecision.markLocalEdited && entry!.localEdited) {
      return null;
    }
    return _Action(decision, path, local: node, remote: remote, base: entry);
  }

  // ---- execution -----------------------------------------------------------

  Future<void> _execute(
    _Action action,
    SyncReport report,
    Set<String> trashed,
  ) async {
    final path = action.path;
    final abs = toAbsPath(_root, path);
    switch (action.decision) {
      case SyncDecision.none:
        break;

      case SyncDecision.download:
        await _download(action.remote!, path);
        report.downloads++;
        await _log('download', 'Downloaded $path');

      case SyncDecision.upload:
        final item = await _transfers.upload(
          abs,
          replaceFileId: action.remote!.id,
          fromSync: true,
        );
        await _recordUpload(item, path, action.local!);
        report.uploads++;
        await _log('upload', 'Uploaded changes to $path');

      case SyncDecision.uploadNew:
        final parentId = await _ensureRemoteFolder(relParent(path));
        final item = await _transfers.upload(
          abs,
          parentId: parentId,
          name: relName(path),
          fromSync: true,
        );
        await _recordUpload(item, path, action.local!);
        report.uploads++;
        await _log('upload', 'Uploaded $path');

      case SyncDecision.link:
        final remote = action.remote!;
        await _db.putEntry(
          SyncEntry(
            fileId: remote.id,
            relPath: path,
            isFolder: false,
            isNative: false,
            localSize: action.local!.size,
            localMtimeMs: action.local!.mtimeMs,
            localMd5: remote.md5,
            remoteMd5: remote.md5,
            remoteModifiedMs: remote.modifiedTime?.millisecondsSinceEpoch,
            localEdited: false,
          ),
        );

      case SyncDecision.conflict:
        final copy = await _freeConflictPath(path);
        await File(abs).rename(toAbsPath(_root, copy));
        report.conflicts++;
        await _log(
          'conflict',
          '$path changed on both sides; your version was kept as '
              '${relName(copy)}',
        );
        await _download(action.remote!, path);
        report.downloads++;

      case SyncDecision.deleteLocal:
        await _recycle(path);
        await _db.removeEntry(action.base!.fileId);
        report.deletedLocal++;
        await _log('delete', 'Removed $path (deleted on Drive)');

      case SyncDecision.trashRemote:
        final item = await _api().updateMetadata(
          action.remote!.id,
          trashed: true,
        );
        await _db.upsertItems([item]);
        await _db.removeEntry(action.base!.fileId);
        trashed.add(item.id);
        report.trashedRemote++;
        await _log('delete', 'Moved $path to Drive trash (deleted locally)');

      case SyncDecision.forget:
        await _db.removeEntry(action.base!.fileId);

      case SyncDecision.markLocalEdited:
        await _db.putEntry(action.base!.copyWith(localEdited: true));
        await _log(
          'info',
          '$path is a Google Docs export; local edits are not uploaded',
        );
    }
  }

  Future<void> _download(DriveItem remote, String path) async {
    final file = await _transfers.download(
      remote,
      toAbsPath(_root, path),
      fromSync: true,
    );
    final stat = await file.stat();
    await _db.putEntry(
      SyncEntry(
        fileId: remote.id,
        relPath: path,
        isFolder: false,
        isNative: remote.isNative,
        localSize: stat.size,
        localMtimeMs: stat.modified.millisecondsSinceEpoch,
        localMd5: remote.isNative || remote.md5 == null
            ? await md5OfFile(file.path)
            : remote.md5,
        remoteMd5: remote.md5,
        remoteModifiedMs: remote.modifiedTime?.millisecondsSinceEpoch,
        localEdited: false,
      ),
    );
  }

  Future<void> _recordUpload(DriveItem item, String path, LocalNode node) {
    _tree.add(path, item);
    return _db.putEntry(
      SyncEntry(
        fileId: item.id,
        relPath: path,
        isFolder: false,
        isNative: false,
        localSize: node.size,
        localMtimeMs: node.mtimeMs,
        // What Drive received. If the file changed mid-upload the next pass
        // sees a different hash and uploads again.
        localMd5: item.md5,
        remoteMd5: item.md5,
        remoteModifiedMs: item.modifiedTime?.millisecondsSinceEpoch,
        localEdited: false,
      ),
    );
  }

  Future<String> _freeConflictPath(String path) async {
    final parent = relParent(path);
    final name = conflictName(relName(path), _clock());
    var candidate = relJoin(parent, name);
    for (var n = 2; await File(toAbsPath(_root, candidate)).exists(); n++) {
      candidate = relJoin(parent, numberedName(name, n));
    }
    return candidate;
  }

  /// Moves a local file into the app's recycle folder instead of deleting it.
  Future<void> _recycle(String path) async {
    final source = File(toAbsPath(_root, path));
    if (!await source.exists()) return;
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(_clock());
    final dest = File(toAbsPath(p.join(recycleDir, stamp), path));
    await dest.parent.create(recursive: true);
    try {
      await source.rename(dest.path);
    } on FileSystemException {
      // Different volume: copy, then remove the original.
      await source.copy(dest.path);
      await source.delete();
    }
  }

  // ---- folders -------------------------------------------------------------

  Future<void> _finishFolders(
    _Plan plan,
    SyncReport report,
    Set<String> trashed,
  ) async {
    int deepestFirst(String a, String b) => b.length.compareTo(a.length);

    for (final path
        in plan.locallyDeletedFolders.toList()..sort(deepestFirst)) {
      final remote = _tree.byPath[path];
      if (remote == null) continue;
      try {
        final survivors = _tree
            .descendants(path)
            .where((item) => !trashed.contains(item.id));
        if (survivors.isEmpty) {
          final item = await _api().updateMetadata(remote.id, trashed: true);
          await _db.upsertItems([item]);
          await _db.removeEntry(remote.id);
          trashed.add(remote.id);
        } else {
          // Drive still has content here, so the folder comes back.
          await Directory(toAbsPath(_root, path)).create(recursive: true);
        }
      } catch (e) {
        report.errors++;
        await _log('error', '$path: $e');
      }
    }

    final gone = plan.remotelyDeletedFolders.keys.toList()..sort(deepestFirst);
    for (final path in gone) {
      try {
        final dir = Directory(toAbsPath(_root, path));
        if (await dir.exists() && await dir.list().isEmpty) await dir.delete();
        await _db.removeEntry(plan.remotelyDeletedFolders[path]!);
      } catch (e) {
        report.errors++;
        await _log('error', '$path: $e');
      }
    }
  }

  Future<void> _purgeRecycle() async {
    final dir = Directory(recycleDir);
    if (!await dir.exists()) return;
    final cutoff = _clock().subtract(recycleRetention);
    await for (final batch in dir.list()) {
      if ((await batch.stat()).modified.isBefore(cutoff)) {
        await batch.delete(recursive: true);
      }
    }
  }

  Future<void> _log(String kind, String message) =>
      _db.log(kind, message, _clock());
}

class _Plan {
  final List<_Action> actions = [];

  /// Tracked folders missing on disk but present on Drive.
  final List<String> locallyDeletedFolders = [];

  /// Tracked folders missing on Drive but present on disk: path -> old id.
  final Map<String, String> remotelyDeletedFolders = {};
}
