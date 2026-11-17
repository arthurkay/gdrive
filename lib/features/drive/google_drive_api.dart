import 'package:googleapis/drive/v3.dart' as g;
import 'package:http/http.dart' as http;

import '../../core/db/database.dart';
import '../../core/util/retry.dart';
import 'drive_api.dart';

const _fields =
    'id,name,mimeType,parents,size,md5Checksum,modifiedTime,viewedByMeTime,'
    'trashed,starred,sharedWithMeTime,thumbnailLink,webViewLink';

DriveItem itemFromFile(g.File f) => DriveItem(
  id: f.id!,
  parentId: (f.parents?.isNotEmpty ?? false) ? f.parents!.first : null,
  name: f.name ?? '',
  mimeType: f.mimeType ?? 'application/octet-stream',
  size: f.size == null ? null : int.tryParse(f.size!),
  md5: f.md5Checksum,
  modifiedTime: f.modifiedTime,
  viewedTime: f.viewedByMeTime,
  trashed: f.trashed ?? false,
  starred: f.starred ?? false,
  sharedWithMe: f.sharedWithMeTime != null,
  thumbnailLink: f.thumbnailLink,
  webViewLink: f.webViewLink,
);

String queryFor(DriveListing listing) => switch (listing) {
  FolderListing(:final folderId) =>
    "'${_escape(folderId)}' in parents and trashed = false",
  SharedListing() => 'sharedWithMe = true and trashed = false',
  StarredListing() => 'starred = true and trashed = false',
  TrashListing() => 'trashed = true',
  AllListing() => 'trashed = false',
  RecentListing() =>
    "trashed = false and mimeType != '$folderMimeType' and "
        "viewedByMeTime > '1970-01-01T00:00:00'",
  SearchListing(:final text) =>
    "name contains '${_escape(text)}' and trashed = false",
};

String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

/// [DriveApi] backed by the Drive v3 REST API.
class GoogleDriveApi implements DriveApi {
  GoogleDriveApi(http.Client client) : _api = g.DriveApi(client);

  final g.DriveApi _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on g.DetailedApiRequestError catch (e) {
      final reason = e.errors.isEmpty ? '' : ' (${e.errors.first.reason})';
      throw DriveApiException(e.status ?? 0, '${e.message}$reason');
    }
  }

  @override
  Future<DriveAccount> about() => _guard(() async {
    final about = await _api.about.get($fields: 'user,storageQuota');
    final root = await _api.files.get('root', $fields: 'id') as g.File;
    final quota = about.storageQuota;
    return DriveAccount(
      email: about.user?.emailAddress ?? '',
      displayName: about.user?.displayName ?? '',
      rootId: root.id!,
      usageBytes: int.tryParse(quota?.usage ?? ''),
      limitBytes: int.tryParse(quota?.limit ?? ''),
    );
  });

  @override
  Future<List<DriveItem>> list(DriveListing listing) => _guard(() async {
    final recent = listing is RecentListing;
    final items = <DriveItem>[];
    String? token;
    do {
      final page = await _api.files.list(
        q: queryFor(listing),
        pageToken: token,
        pageSize: recent ? 50 : 1000,
        orderBy: recent ? 'viewedByMeTime desc' : null,
        $fields: 'nextPageToken,files($_fields)',
      );
      items.addAll((page.files ?? const []).map(itemFromFile));
      token = recent ? null : page.nextPageToken;
    } while (token != null);
    return items;
  });

  @override
  Future<DriveItem> get(String id) => _guard(
    () async =>
        itemFromFile(await _api.files.get(id, $fields: _fields) as g.File),
  );

  @override
  Stream<List<int>> download(String id) async* {
    final media = await _guard(
      () => _api.files.get(
        id,
        downloadOptions: g.DownloadOptions.fullMedia,
        acknowledgeAbuse: false,
      ),
    );
    yield* (media as g.Media).stream;
  }

  @override
  Stream<List<int>> export(String id, String mimeType) async* {
    final media = await _guard(
      () => _api.files.export(
        id,
        mimeType,
        downloadOptions: g.DownloadOptions.fullMedia,
      ),
    );
    yield* media!.stream;
  }

  @override
  Future<DriveItem> createFolder(String name, String parentId) => _guard(
    () async => itemFromFile(
      await _api.files.create(
        g.File(name: name, mimeType: folderMimeType, parents: [parentId]),
        $fields: _fields,
      ),
    ),
  );

  @override
  Future<DriveItem> upload({
    required String name,
    required String parentId,
    required Stream<List<int>> data,
    required int length,
    DateTime? modifiedTime,
  }) => _guard(
    () async => itemFromFile(
      await _api.files.create(
        g.File(
          name: name,
          parents: [parentId],
          modifiedTime: modifiedTime?.toUtc(),
        ),
        uploadMedia: g.Media(data, length),
        uploadOptions: g.ResumableUploadOptions(),
        $fields: _fields,
      ),
    ),
  );

  @override
  Future<DriveItem> updateContent(
    String id, {
    required Stream<List<int>> data,
    required int length,
    DateTime? modifiedTime,
  }) => _guard(
    () async => itemFromFile(
      await _api.files.update(
        g.File(modifiedTime: modifiedTime?.toUtc()),
        id,
        uploadMedia: g.Media(data, length),
        uploadOptions: g.ResumableUploadOptions(),
        $fields: _fields,
      ),
    ),
  );

  @override
  Future<DriveItem> updateMetadata(
    String id, {
    String? name,
    bool? starred,
    bool? trashed,
    String? addParent,
    String? removeParent,
  }) => _guard(
    () async => itemFromFile(
      await _api.files.update(
        g.File(name: name, starred: starred, trashed: trashed),
        id,
        addParents: addParent,
        removeParents: removeParent,
        $fields: _fields,
      ),
    ),
  );

  @override
  Future<DriveItem> copy(String id, {String? name, String? parentId}) => _guard(
    () async => itemFromFile(
      await _api.files.copy(
        g.File(name: name, parents: parentId == null ? null : [parentId]),
        id,
        $fields: _fields,
      ),
    ),
  );

  @override
  Future<void> delete(String id) => _guard(() => _api.files.delete(id));

  @override
  Future<void> emptyTrash() => _guard(() => _api.files.emptyTrash());

  @override
  Future<String> startPageToken() => _guard(
    () async => (await _api.changes.getStartPageToken()).startPageToken!,
  );

  @override
  Future<DriveChanges> changes(String pageToken) => _guard(() async {
    final changes = <DriveChange>[];
    String? token = pageToken;
    String? next;
    while (token != null) {
      final page = await _api.changes.list(
        token,
        pageSize: 1000,
        includeRemoved: true,
        restrictToMyDrive: false,
        $fields:
            'nextPageToken,newStartPageToken,'
            'changes(fileId,removed,file($_fields))',
      );
      for (final c in page.changes ?? const <g.Change>[]) {
        if (c.fileId == null) continue;
        final removed = (c.removed ?? false) || c.file == null;
        changes.add(
          DriveChange(
            fileId: c.fileId!,
            removed: removed,
            item: removed ? null : itemFromFile(c.file!),
          ),
        );
      }
      next = page.newStartPageToken ?? next;
      token = page.nextPageToken;
    }
    return DriveChanges(changes: changes, nextToken: next ?? pageToken);
  });
}
