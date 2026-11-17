import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;

import '../core/db/database.dart';
import '../core/util/file_kind.dart';
import '../core/util/retry.dart';
import '../features/drive/drive_api.dart';

/// In-memory Google Drive. Backs the test suite and the `DEMO=true` build,
/// and behaves like the real service where the app depends on it: stable
/// ids, md5 checksums, trash, duplicate names, and a change feed.
class FakeDriveApi implements DriveApi {
  FakeDriveApi({DateTime? start})
    : _now = start ?? DateTime.utc(2026, 1, 1, 12);

  static const rootId = 'root-id';

  final Map<String, DriveItem> _items = {};
  final Map<String, List<int>> _bytes = {};
  final List<DriveChange> _log = [];
  DateTime _now;
  int _nextId = 1;

  /// Every call as `operation:argument`, for assertions.
  final List<String> calls = [];

  /// Return an error to make the matching call fail.
  Object? Function(String operation, String argument)? failWhen;

  DriveAccount account = const DriveAccount(
    email: 'demo@example.com',
    displayName: 'Demo User',
    rootId: rootId,
    usageBytes: 3 * 1024 * 1024 * 1024,
    limitBytes: 15 * 1024 * 1024 * 1024,
  );

  // ---- test helpers --------------------------------------------------------

  Iterable<DriveItem> get items => _items.values;

  DriveItem? byId(String id) => _items[id];

  /// Live (untrashed) item called [name] under [parentId].
  DriveItem? find(String name, {String parentId = rootId}) {
    for (final item in _items.values) {
      if (item.name == name && item.parentId == parentId && !item.trashed) {
        return item;
      }
    }
    return null;
  }

  List<int>? bytesOf(String id) => _bytes[id];

  String? textOf(String id) =>
      _bytes[id] == null ? null : utf8.decode(_bytes[id]!);

  DriveItem addFolder(String name, {String parentId = rootId, String? id}) =>
      _put(
        DriveItem(
          id: id ?? 'id${_nextId++}',
          parentId: parentId,
          name: name,
          mimeType: folderMimeType,
          modifiedTime: _tick(),
          trashed: false,
          starred: false,
          sharedWithMe: false,
        ),
      );

  DriveItem addFile(
    String name,
    String content, {
    String parentId = rootId,
    String? id,
    String mimeType = 'text/plain',
    bool sharedWithMe = false,
  }) => addBytes(
    name,
    utf8.encode(content),
    parentId: sharedWithMe ? null : parentId,
    id: id,
    mimeType: mimeType,
    sharedWithMe: sharedWithMe,
  );

  DriveItem addBytes(
    String name,
    List<int> bytes, {
    String? parentId = rootId,
    String? id,
    String mimeType = 'application/octet-stream',
    bool sharedWithMe = false,
  }) {
    final fileId = id ?? 'id${_nextId++}';
    _bytes[fileId] = bytes;
    return _put(
      DriveItem(
        id: fileId,
        parentId: parentId,
        name: name,
        mimeType: mimeType,
        size: bytes.length,
        md5: md5.convert(bytes).toString(),
        modifiedTime: _tick(),
        trashed: false,
        starred: false,
        sharedWithMe: sharedWithMe,
      ),
    );
  }

  /// A Google Doc/Sheet/Slides file; [content] is what an export returns.
  DriveItem addNative(
    String name,
    String content, {
    String parentId = rootId,
    String mimeType = 'application/vnd.google-apps.document',
  }) {
    final id = 'id${_nextId++}';
    _bytes[id] = utf8.encode(content);
    return _put(
      DriveItem(
        id: id,
        parentId: parentId,
        name: name,
        mimeType: mimeType,
        modifiedTime: _tick(),
        trashed: false,
        starred: false,
        sharedWithMe: false,
      ),
    );
  }

  /// Simulates an edit made elsewhere.
  DriveItem edit(String id, String content) {
    final item = _require(id);
    final bytes = utf8.encode(content);
    _bytes[id] = bytes;
    return _put(
      item.isNative
          ? item.copyWith(modifiedTime: Value(_tick()))
          : item.copyWith(
              size: Value(bytes.length),
              md5: Value(md5.convert(bytes).toString()),
              modifiedTime: Value(_tick()),
            ),
    );
  }

  /// Simulates a permanent delete made elsewhere.
  void purge(String id) {
    for (final child in _items.values.where((e) => e.parentId == id).toList()) {
      purge(child.id);
    }
    _items.remove(id);
    _bytes.remove(id);
    _log.add(DriveChange(fileId: id, removed: true));
  }

  // ---- DriveApi ------------------------------------------------------------

  @override
  Future<DriveAccount> about() async {
    _call('about', '');
    return account;
  }

  @override
  Future<List<DriveItem>> list(DriveListing listing) async {
    switch (listing) {
      case FolderListing(:final folderId):
        _call('list', folderId);
        final parent = folderId == 'root' ? rootId : folderId;
        return _where((e) => e.parentId == parent && !_effectivelyTrashed(e));
      case SharedListing():
        _call('list', 'shared');
        return _where((e) => e.sharedWithMe && !e.trashed);
      case StarredListing():
        _call('list', 'starred');
        return _where((e) => e.starred && !_effectivelyTrashed(e));
      case TrashListing():
        _call('list', 'trash');
        return _where((e) => e.trashed);
      case AllListing():
        _call('list', 'all');
        return _where((e) => !_effectivelyTrashed(e));
      case RecentListing():
        _call('list', 'recent');
        final recent = _where(
          (e) => !e.isFolder && !_effectivelyTrashed(e) && e.viewedTime != null,
        )..sort((a, b) => b.viewedTime!.compareTo(a.viewedTime!));
        return recent.take(50).toList();
      case SearchListing(:final text):
        _call('list', 'search:$text');
        final needle = text.toLowerCase();
        return _where(
          (e) =>
              e.name.toLowerCase().contains(needle) && !_effectivelyTrashed(e),
        );
    }
  }

  @override
  Future<DriveItem> get(String id) async {
    _call('get', id);
    return _require(id == 'root' ? rootId : id);
  }

  @override
  Stream<List<int>> download(String id) async* {
    _call('download', id);
    final item = _require(id);
    if (item.isNative || item.isFolder) {
      throw DriveApiException(
        403,
        'Only files with binary content can be '
        'downloaded (fileNotDownloadable)',
      );
    }
    _items[id] = item.copyWith(viewedTime: Value(_now));
    yield* _chunks(_bytes[id]!);
  }

  @override
  Stream<List<int>> export(String id, String mimeType) async* {
    _call('export', id);
    final item = _require(id);
    if (!item.isNative) {
      throw DriveApiException(403, 'Export only supports Docs Editors files');
    }
    _items[id] = item.copyWith(viewedTime: Value(_now));
    yield* _chunks(_bytes[id]!);
  }

  @override
  Future<DriveItem> createFolder(String name, String parentId) async {
    _call('createFolder', name);
    _require(parentId);
    return addFolder(name, parentId: parentId);
  }

  @override
  Future<DriveItem> upload({
    required String name,
    required String parentId,
    required Stream<List<int>> data,
    required int length,
    DateTime? modifiedTime,
  }) async {
    final bytes = await _collect(data);
    _call('upload', name);
    _require(parentId);
    final item = addBytes(
      name,
      bytes,
      parentId: parentId,
      mimeType: _mime(name),
    );
    return modifiedTime == null
        ? item
        : _items[item.id] = item.copyWith(modifiedTime: Value(modifiedTime));
  }

  @override
  Future<DriveItem> updateContent(
    String id, {
    required Stream<List<int>> data,
    required int length,
    DateTime? modifiedTime,
  }) async {
    final bytes = await _collect(data);
    _call('updateContent', id);
    final item = _require(id);
    _bytes[id] = bytes;
    return _put(
      item.copyWith(
        size: Value(bytes.length),
        md5: Value(md5.convert(bytes).toString()),
        modifiedTime: Value(modifiedTime ?? _tick()),
      ),
    );
  }

  @override
  Future<DriveItem> updateMetadata(
    String id, {
    String? name,
    bool? starred,
    bool? trashed,
    String? addParent,
    String? removeParent,
  }) async {
    _call('updateMetadata', id);
    final item = _require(id);
    if (addParent != null) _require(addParent);
    return _put(
      item.copyWith(
        name: name,
        starred: starred,
        trashed: trashed,
        parentId: addParent == null ? const Value.absent() : Value(addParent),
        modifiedTime: Value(_tick()),
      ),
    );
  }

  @override
  Future<DriveItem> copy(String id, {String? name, String? parentId}) async {
    _call('copy', id);
    final source = _require(id);
    final newId = 'id${_nextId++}';
    if (_bytes[id] != null) _bytes[newId] = List.of(_bytes[id]!);
    return _put(
      source.copyWith(
        id: newId,
        name: name ?? 'Copy of ${source.name}',
        parentId: parentId == null ? const Value.absent() : Value(parentId),
        starred: false,
        modifiedTime: Value(_tick()),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    _call('delete', id);
    _require(id);
    purge(id);
  }

  @override
  Future<void> emptyTrash() async {
    _call('emptyTrash', '');
    for (final item in _where((e) => e.trashed)) {
      if (_items.containsKey(item.id)) purge(item.id);
    }
  }

  @override
  Future<String> startPageToken() async {
    _call('startPageToken', '');
    return '${_log.length}';
  }

  @override
  Future<DriveChanges> changes(String pageToken) async {
    _call('changes', pageToken);
    final from = int.parse(pageToken);
    // Like Drive, report each file once with its latest state.
    final latest = <String, DriveChange>{};
    for (final change in _log.skip(from)) {
      final current = _items[change.fileId];
      latest[change.fileId] = current == null
          ? DriveChange(fileId: change.fileId, removed: true)
          : DriveChange(fileId: change.fileId, item: current);
    }
    return DriveChanges(
      changes: latest.values.toList(),
      nextToken: '${_log.length}',
    );
  }

  // ---- internals -----------------------------------------------------------

  void _call(String operation, String argument) {
    calls.add('$operation:$argument');
    final error = failWhen?.call(operation, argument);
    if (error != null) throw error;
  }

  DateTime _tick() => _now = _now.add(const Duration(seconds: 1));

  DriveItem _put(DriveItem item) {
    _items[item.id] = item;
    _log.add(DriveChange(fileId: item.id, item: item));
    return item;
  }

  DriveItem _require(String id) =>
      _items[id] ??
      (id == rootId
          ? DriveItem(
              id: rootId,
              name: 'My Drive',
              mimeType: folderMimeType,
              trashed: false,
              starred: false,
              sharedWithMe: false,
            )
          : throw DriveApiException(404, 'File not found: $id (notFound)'));

  List<DriveItem> _where(bool Function(DriveItem) test) =>
      _items.values.where(test).toList();

  /// Trashing a folder hides everything inside it.
  bool _effectivelyTrashed(DriveItem item) {
    DriveItem? current = item;
    while (current != null) {
      if (current.trashed) return true;
      current = current.parentId == null ? null : _items[current.parentId];
    }
    return false;
  }

  Stream<List<int>> _chunks(List<int> bytes) async* {
    const size = 64 * 1024;
    for (var i = 0; i < bytes.length; i += size) {
      yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
    }
  }

  Future<List<int>> _collect(Stream<List<int>> data) async {
    final out = <int>[];
    await for (final chunk in data) {
      out.addAll(chunk);
    }
    return out;
  }

  String _mime(String name) => switch (name.split('.').last.toLowerCase()) {
    'txt' || 'md' => 'text/plain',
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'mp3' => 'audio/mpeg',
    'mp4' => 'video/mp4',
    _ => 'application/octet-stream',
  };
}
