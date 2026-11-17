import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/util/file_kind.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/demo.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/drive/drive_api.dart';

/// The fake stands in for Google Drive everywhere else in the suite, so its
/// own behaviour is pinned down here.
void main() {
  late FakeDriveApi drive;
  const root = FakeDriveApi.rootId;

  setUp(() => drive = FakeDriveApi());

  Future<List<String>> names(DriveListing listing) async =>
      (await drive.list(listing)).map((e) => e.name).toList()..sort();

  test('files carry size, checksum and increasing timestamps', () {
    final a = drive.addFile('a.txt', 'hello');
    final b = drive.addFile('b.txt', 'hello');
    expect(a.size, 5);
    expect(a.md5, '5d41402abc4b2a76b9719d911017c592');
    expect(b.modifiedTime!.isAfter(a.modifiedTime!), isTrue);
    expect(a.id, isNot(b.id));
    expect(drive.textOf(a.id), 'hello');
    expect(drive.textOf('missing'), isNull);
  });

  test('trashing a folder hides its contents from listings', () async {
    final docs = drive.addFolder('Docs');
    final inner = drive.addFile('a.txt', 'x', parentId: docs.id);
    await drive.updateMetadata(inner.id, starred: true);
    await drive.updateMetadata(docs.id, trashed: true);

    expect(await names(const FolderListing(root)), isEmpty);
    expect(await names(FolderListing(docs.id)), isEmpty);
    expect(await names(const StarredListing()), isEmpty);
    expect(await names(const AllListing()), isEmpty);
    expect(await names(const SearchListing('a')), isEmpty);
    expect(await names(const TrashListing()), ['Docs']);
    expect(drive.find('Docs'), isNull);
  });

  test('the "root" alias resolves to My Drive', () async {
    drive.addFile('a.txt', 'x');
    expect(await names(const FolderListing('root')), ['a.txt']);
    expect((await drive.get('root')).id, root);
    expect((await drive.get(root)).name, 'My Drive');
  });

  test('downloads mark files as viewed for the recent list', () async {
    final a = drive.addFile('a.txt', 'x');
    drive.addFile('b.txt', 'x');
    expect(await names(const RecentListing()), isEmpty);

    await drive.download(a.id).drain<void>();

    expect(await names(const RecentListing()), ['a.txt']);
  });

  test('download and export refuse the wrong kind of file', () async {
    final doc = drive.addNative('Plan', 'x');
    final file = drive.addFile('a.txt', 'x');
    final folder = drive.addFolder('Docs');

    await expectLater(drive.download(doc.id).drain<void>(), throwsA(anything));
    await expectLater(
      drive.download(folder.id).drain<void>(),
      throwsA(anything),
    );
    await expectLater(
      drive.export(file.id, 'application/pdf').drain<void>(),
      throwsA(anything),
    );
    expect(
      await drive.export(doc.id, 'application/pdf').expand((c) => c).toList(),
      'x'.codeUnits,
    );
  });

  test('unknown ids are 404s', () async {
    await expectLater(
      drive.get('nope'),
      throwsA(
        isA<DriveApiException>().having((e) => e.isNotFound, '404', true),
      ),
    );
    await expectLater(drive.createFolder('x', 'nope'), throwsA(anything));
    await expectLater(drive.delete('nope'), throwsA(anything));
  });

  test('copy duplicates bytes under a new id', () async {
    final a = drive.addFile('a.txt', 'alpha');
    final folder = drive.addFolder('Docs');

    final plain = await drive.copy(a.id);
    final placed = await drive.copy(a.id, name: 'b.txt', parentId: folder.id);

    expect(plain.name, 'Copy of a.txt');
    expect(plain.parentId, root);
    expect(placed.parentId, folder.id);
    expect(drive.textOf(placed.id), 'alpha');
    drive.bytesOf(placed.id)![0] = 0;
    expect(drive.textOf(a.id), 'alpha', reason: 'independent bytes');
  });

  test('uploads infer a MIME type from the extension', () async {
    Future<String> typeOf(String name) async => (await drive.upload(
      name: name,
      parentId: root,
      data: Stream.value([1]),
      length: 1,
      modifiedTime: DateTime.utc(2025),
    )).mimeType;

    expect(await typeOf('a.md'), 'text/plain');
    expect(await typeOf('a.pdf'), 'application/pdf');
    expect(await typeOf('a.png'), 'image/png');
    expect(await typeOf('a.JPG'), 'image/jpeg');
    expect(await typeOf('a.mp3'), 'audio/mpeg');
    expect(await typeOf('a.mp4'), 'video/mp4');
    expect(await typeOf('a.bin'), 'application/octet-stream');
    expect(drive.find('a.md')!.modifiedTime, DateTime.utc(2025));
  });

  test(
    'the change feed reports each file once with its latest state',
    () async {
      final token = await drive.startPageToken();
      final a = drive.addFile('a.txt', 'v1');
      drive.edit(a.id, 'v2');
      final b = drive.addFile('b.txt', 'x');
      drive.purge(b.id);

      final result = await drive.changes(token);

      expect(result.changes, hasLength(2));
      final byId = {for (final c in result.changes) c.fileId: c};
      expect(byId[a.id]!.item!.md5, drive.byId(a.id)!.md5);
      expect(byId[b.id]!.removed, isTrue);
      expect((await drive.changes(result.nextToken)).changes, isEmpty);
    },
  );

  test('purging a folder removes everything inside it', () {
    final docs = drive.addFolder('Docs');
    final inner = drive.addFile('a.txt', 'x', parentId: docs.id);
    drive.purge(docs.id);
    expect(drive.byId(inner.id), isNull);
    expect(drive.items, isEmpty);
  });

  test('emptyTrash purges only trashed items', () async {
    final keep = drive.addFile('keep.txt', 'x');
    final gone = drive.addFile('gone.txt', 'x');
    await drive.updateMetadata(gone.id, trashed: true);

    await drive.emptyTrash();

    expect(drive.byId(keep.id), isNotNull);
    expect(drive.byId(gone.id), isNull);
  });

  test('editing a Google Doc bumps its time but adds no checksum', () {
    final doc = drive.addNative('Plan', 'v1');
    final edited = drive.edit(doc.id, 'v2');
    expect(edited.md5, isNull);
    expect(edited.modifiedTime!.isAfter(doc.modifiedTime!), isTrue);
  });

  test('calls are recorded and can be made to fail', () async {
    await drive.about();
    expect(drive.calls, ['about:']);
    drive.failWhen = (op, _) => op == 'about' ? StateError('boom') : null;
    await expectLater(drive.about(), throwsStateError);
  });

  test('the demo Drive has one of every previewable kind', () {
    final kinds = seededDrive().items.map((e) => e.kind).toSet();
    expect(
      kinds,
      containsAll(
        FileKind.values.toSet()..removeAll({FileKind.video, FileKind.audio}),
      ),
    );
  });

  test('demo wiring replaces every external boundary', () async {
    expect(demoOverrides(), hasLength(4));
    final gateway = FakeAuthGateway();
    final session = await gateway.signIn();
    expect(await session.accessToken(), 'fake-token');
    expect(session.client, isNotNull);
    expect(await session.refreshed.isEmpty, isTrue);
    expect(gateway.restore(session.serialize()), isA<FakeAuthSession>());
    await gateway.revoke(session);
    expect((gateway.signIns, gateway.revocations), (1, 1));
  });
}
