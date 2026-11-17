import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/features/drive/drive_api.dart';
import 'package:gdrive/features/drive/google_drive_api.dart';
import 'package:googleapis/drive/v3.dart' as g;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Records requests and answers them from [respond].
class Recorder {
  final List<http.Request> requests = [];
  late http.Response Function(http.Request request) respond;

  http.Client get client => MockClient((request) async {
    requests.add(request);
    return respond(request);
  });

  http.Request get last => requests.last;
}

http.Response json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const fileJson = {
  'id': 'f1',
  'name': 'report.pdf',
  'mimeType': 'application/pdf',
  'parents': ['p1'],
  'size': '2048',
  'md5Checksum': 'abc',
  'modifiedTime': '2026-03-02T10:00:00.000Z',
  'viewedByMeTime': '2026-03-03T10:00:00.000Z',
  'trashed': false,
  'starred': true,
  'sharedWithMeTime': '2026-01-01T00:00:00.000Z',
  'thumbnailLink': 'https://thumb',
  'webViewLink': 'https://view',
};

void main() {
  late Recorder http_;
  late GoogleDriveApi api;

  setUp(() {
    http_ = Recorder();
    api = GoogleDriveApi(http_.client);
  });

  test('itemFromFile maps every field and tolerates missing ones', () {
    final full = itemFromFile(g.File.fromJson(fileJson));
    expect(full.id, 'f1');
    expect(full.parentId, 'p1');
    expect(full.size, 2048);
    expect(full.md5, 'abc');
    expect(full.modifiedTime, DateTime.utc(2026, 3, 2, 10));
    expect(full.viewedTime, DateTime.utc(2026, 3, 3, 10));
    expect(full.starred, isTrue);
    expect(full.sharedWithMe, isTrue);
    expect(full.thumbnailLink, 'https://thumb');
    expect(full.webViewLink, 'https://view');

    final bare = itemFromFile(g.File(id: 'x'));
    expect(bare.name, '');
    expect(bare.mimeType, 'application/octet-stream');
    expect(bare.parentId, isNull);
    expect(bare.size, isNull);
    expect(bare.trashed, isFalse);
    expect(bare.sharedWithMe, isFalse);
  });

  test('queryFor builds Drive search expressions and escapes quotes', () {
    expect(
      queryFor(const FolderListing("it's")),
      r"'it\'s' in parents and trashed = false",
    );
    expect(queryFor(const SharedListing()), contains('sharedWithMe = true'));
    expect(queryFor(const StarredListing()), contains('starred = true'));
    expect(queryFor(const TrashListing()), 'trashed = true');
    expect(queryFor(const AllListing()), 'trashed = false');
    expect(queryFor(const RecentListing()), contains('viewedByMeTime'));
    expect(
      queryFor(const SearchListing(r"a\b'c")),
      r"name contains 'a\\b\'c' and trashed = false",
    );
  });

  test('listings compare by what they list', () {
    expect(const FolderListing('a'), const FolderListing('a'));
    expect(const FolderListing('a'), isNot(const FolderListing('b')));
    expect(
      const SearchListing('x').hashCode,
      const SearchListing('x').hashCode,
    );
    expect({
      const SharedListing().key,
      const StarredListing().key,
      const TrashListing().key,
      const RecentListing().key,
      const AllListing().key,
    }, hasLength(5));
  });

  test('about combines the profile, quota and root id', () async {
    http_.respond = (request) => request.url.path.endsWith('/about')
        ? json({
            'user': {'emailAddress': 'me@example.com', 'displayName': 'Me'},
            'storageQuota': {'usage': '100', 'limit': '1000'},
          })
        : json({'id': 'real-root'});

    final account = await api.about();

    expect(account.email, 'me@example.com');
    expect(account.displayName, 'Me');
    expect(account.rootId, 'real-root');
    expect(account.usageBytes, 100);
    expect(account.limitBytes, 1000);
  });

  test('list follows every page', () async {
    http_.respond = (request) =>
        request.url.queryParameters['pageToken'] == null
        ? json({
            'nextPageToken': 'next',
            'files': [fileJson],
          })
        : json({
            'files': [
              {...fileJson, 'id': 'f2'},
            ],
          });

    final items = await api.list(const FolderListing('p1'));

    expect(items.map((e) => e.id), ['f1', 'f2']);
    expect(http_.requests, hasLength(2));
    expect(http_.requests.first.url.queryParameters['q'], contains("'p1'"));
  });

  test('recent asks for one ordered page', () async {
    http_.respond = (_) => json({
      'nextPageToken': 'ignored',
      'files': [fileJson],
    });

    await api.list(const RecentListing());

    expect(http_.requests, hasLength(1));
    expect(http_.last.url.queryParameters['orderBy'], 'viewedByMeTime desc');
    expect(http_.last.url.queryParameters['pageSize'], '50');
  });

  test(
    'get, createFolder, copy and updateMetadata send the right calls',
    () async {
      http_.respond = (_) => json(fileJson);

      expect((await api.get('f1')).name, 'report.pdf');
      expect(http_.last.method, 'GET');

      await api.createFolder('New', 'p1');
      final created = jsonDecode(http_.last.body) as Map<String, dynamic>;
      expect(created['mimeType'], folderMimeType);
      expect(created['parents'], ['p1']);

      await api.copy('f1', name: 'Copy', parentId: 'p2');
      expect(http_.last.url.path, endsWith('/files/f1/copy'));
      expect(jsonDecode(http_.last.body)['parents'], ['p2']);

      await api.copy('f1');
      expect(
        (jsonDecode(http_.last.body) as Map).containsKey('parents'),
        isFalse,
      );

      await api.updateMetadata(
        'f1',
        name: 'n',
        starred: true,
        trashed: true,
        addParent: 'p2',
        removeParent: 'p1',
      );
      expect(http_.last.method, 'PATCH');
      expect(http_.last.url.queryParameters['addParents'], 'p2');
      expect(http_.last.url.queryParameters['removeParents'], 'p1');
      expect(jsonDecode(http_.last.body), {
        'name': 'n',
        'starred': true,
        'trashed': true,
      });
    },
  );

  test('download and export stream the bytes', () async {
    http_.respond = (_) => http.Response.bytes(
      [1, 2, 3],
      200,
      headers: {'content-type': 'application/octet-stream'},
    );

    final downloaded = await api.download('f1').expand((c) => c).toList();
    expect(downloaded, [1, 2, 3]);
    expect(http_.last.url.queryParameters['alt'], 'media');

    final exported = await api
        .export('f1', 'application/pdf')
        .expand((c) => c)
        .toList();
    expect(exported, [1, 2, 3]);
    expect(http_.last.url.path, endsWith('/files/f1/export'));
    expect(http_.last.url.queryParameters['mimeType'], 'application/pdf');
  });

  test('upload and updateContent use resumable sessions', () async {
    final bodies = <List<int>>[];
    http_.respond = (request) {
      if (request.url.queryParameters['uploadType'] == 'resumable' &&
          request.headers['content-range'] == null) {
        return http.Response(
          '',
          200,
          headers: {'location': 'https://upload.example/session-1'},
        );
      }
      bodies.add(request.bodyBytes);
      return json(fileJson);
    };
    final modified = DateTime.utc(2026, 5, 1);

    final created = await api.upload(
      name: 'report.pdf',
      parentId: 'p1',
      data: Stream.value([1, 2, 3]),
      length: 3,
      modifiedTime: modified,
    );
    expect(created.id, 'f1');
    final start = http_.requests.first;
    expect(start.method, 'POST');
    expect(jsonDecode(start.body), {
      'modifiedTime': '2026-05-01T00:00:00.000Z',
      'name': 'report.pdf',
      'parents': ['p1'],
    });
    expect(bodies.single, [1, 2, 3]);

    http_.requests.clear();
    await api.updateContent(
      'f1',
      data: Stream.value([9, 9]),
      length: 2,
      modifiedTime: modified,
    );
    expect(http_.requests.first.method, 'PATCH');
    expect(http_.requests.first.url.path, endsWith('/files/f1'));
    expect(bodies.last, [9, 9]);
  });

  test('delete, emptyTrash and startPageToken', () async {
    http_.respond = (request) => request.url.path.endsWith('startPageToken')
        ? json({'startPageToken': '77'})
        : http.Response('', 204);

    await api.delete('f1');
    expect(http_.last.method, 'DELETE');
    await api.emptyTrash();
    expect(http_.last.url.path, endsWith('/files/trash'));
    expect(await api.startPageToken(), '77');
  });

  test('changes pages through and separates removals', () async {
    http_.respond = (request) =>
        request.url.queryParameters['pageToken'] == '10'
        ? json({
            'nextPageToken': '11',
            'changes': [
              {'fileId': 'f1', 'file': fileJson},
              {'fileId': 'gone', 'removed': true},
              {'removed': true},
            ],
          })
        : json({
            'newStartPageToken': '12',
            'changes': [
              {'fileId': 'nofile'},
            ],
          });

    final result = await api.changes('10');

    expect(result.nextToken, '12');
    expect(result.changes.map((c) => c.fileId), ['f1', 'gone', 'nofile']);
    expect(result.changes[0].item!.name, 'report.pdf');
    expect(result.changes[0].removed, isFalse);
    expect(result.changes[1].removed, isTrue);
    expect(result.changes[2].removed, isTrue);
  });

  test('changes keeps the old token if Drive returns none', () async {
    http_.respond = (_) => json({'changes': <Object>[]});
    expect((await api.changes('10')).nextToken, '10');
  });

  test('API errors become DriveApiException with status and reason', () async {
    http_.respond = (_) => json({
      'error': {
        'code': 403,
        'message': 'Rate limit exceeded',
        'errors': [
          {'reason': 'userRateLimitExceeded', 'message': 'x', 'domain': 'd'},
        ],
      },
    }, status: 403);

    await expectLater(
      api.get('f1'),
      throwsA(
        isA<DriveApiException>()
            .having((e) => e.status, 'status', 403)
            .having((e) => e.message, 'message', contains('userRateLimit'))
            .having(isTransient, 'transient', isTrue),
      ),
    );
    await expectLater(
      api.download('f1').drain<void>(),
      throwsA(isA<DriveApiException>()),
    );
  });
}
