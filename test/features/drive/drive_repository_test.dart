import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/drive/drive_api.dart';
import 'package:gdrive/features/drive/drive_repository.dart';
import 'package:gdrive/features/transfers/transfer_manager.dart';
import 'package:path/path.dart' as p;

import '../../support/harness.dart';

void main() {
  late AppDatabase db;
  late FakeDriveApi drive;
  late DriveRepository repo;
  late Directory temp;
  const root = FakeDriveApi.rootId;

  setUp(() async {
    db = memoryDatabase();
    drive = FakeDriveApi();
    temp = await Directory.systemTemp.createTemp('gdrive_repo_');
    repo = DriveRepository(
      db: db,
      api: () => drive,
      transfers: TransferManager(
        db: db,
        api: () => drive,
        clock: DateTime.now,
        sleep: (_) async {},
      ),
    );
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<List<String>> names(DriveListing listing) async =>
      (await repo.watch(listing).first).map((e) => e.name).toList()..sort();

  test('refreshing a folder mirrors it into the cache', () async {
    drive.addFile('a.txt', 'a');
    final b = drive.addFile('b.txt', 'b');
    await repo.refresh(const FolderListing(root));
    expect(await names(const FolderListing(root)), ['a.txt', 'b.txt']);

    drive.purge(b.id);
    drive.addFile('c.txt', 'c');
    await repo.refresh(const FolderListing(root));
    expect(await names(const FolderListing(root)), ['a.txt', 'c.txt']);
  });

  test('refreshing Starred clears stars removed elsewhere', () async {
    final a = drive.addFile('a.txt', 'a');
    await repo.setStarred(a, true);
    expect(await names(const StarredListing()), ['a.txt']);

    await drive.updateMetadata(a.id, starred: false);
    await repo.refresh(const StarredListing());
    expect(await names(const StarredListing()), isEmpty);
  });

  test('refreshing Trash drops items purged elsewhere', () async {
    final a = drive.addFile('a.txt', 'a');
    await repo.trash(a);
    expect(await names(const TrashListing()), ['a.txt']);

    drive.purge(a.id);
    await repo.refresh(const TrashListing());
    expect(await names(const TrashListing()), isEmpty);
  });

  test('shared, recent, search and all listings populate the cache', () async {
    drive.addFile('theirs.txt', 'x', sharedWithMe: true);
    final viewed = drive.addFile('viewed.txt', 'x');
    await drive.download(viewed.id).drain<void>();
    drive.addFile('Annual report.txt', 'x');

    await repo.refresh(const SharedListing());
    expect(await names(const SharedListing()), ['theirs.txt']);

    await repo.refresh(const RecentListing());
    expect(await names(const RecentListing()), ['viewed.txt']);

    await repo.refresh(const SearchListing('report'));
    expect(await names(const SearchListing('report')), ['Annual report.txt']);

    await repo.refresh(const AllListing());
    expect(await names(const AllListing()), hasLength(3));
  });

  test('management actions hit Drive and update the cache', () async {
    final folder = await repo.createFolder('  Projects ', root);
    expect(folder.name, 'Projects');

    final file = drive.addFile('draft.txt', 'text');
    final renamed = await repo.rename(file, 'final.txt');
    expect(drive.byId(file.id)!.name, 'final.txt');

    final moved = await repo.move(renamed, folder.id);
    expect(moved.parentId, folder.id);
    expect(await names(FolderListing(folder.id)), ['final.txt']);

    final copy = await repo.copy(moved);
    expect(copy.id, isNot(file.id));
    expect(copy.parentId, folder.id);

    final trashed = await repo.trash(moved);
    expect(trashed.trashed, isTrue);
    final restored = await repo.restore(trashed);
    expect(restored.trashed, isFalse);

    await repo.deleteForever(restored);
    expect(drive.byId(file.id), isNull);
    expect(await db.item(file.id), isNull);
  });

  test('a cached viewed time survives a metadata update', () async {
    final file = drive.addFile('a.txt', 'a');
    final viewed = DateTime(2026, 5, 1);
    await db.upsertItems([file.copyWith(viewedTime: Value(viewed))]);

    await repo.rename(file, 'b.txt');

    expect((await db.item(file.id))!.viewedTime, viewed);
  });

  test('emptyTrash purges on Drive and in the cache', () async {
    final a = drive.addFile('a.txt', 'a');
    await repo.trash(a);

    await repo.emptyTrash();

    expect(drive.byId(a.id), isNull);
    expect(await names(const TrashListing()), isEmpty);
  });

  test('failures propagate without touching the cache', () async {
    final a = drive.addFile('a.txt', 'a');
    await repo.refresh(const FolderListing(root));
    drive.failWhen = (_, _) => DriveApiException(500, 'down');

    await expectLater(
      repo.rename(a, 'b.txt'),
      throwsA(isA<DriveApiException>()),
    );
    expect((await db.item(a.id))!.name, 'a.txt');
  });

  test('uploadPaths sends files and recreates folder structure', () async {
    File(p.join(temp.path, 'solo.txt')).writeAsStringSync('solo');
    File(p.join(temp.path, 'Album', 'one.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('1');
    File(p.join(temp.path, 'Album', 'Inner', 'two.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('2');
    File(p.join(temp.path, 'Album', '.DS_Store')).writeAsStringSync('junk');

    final failed = await repo.uploadPaths([
      p.join(temp.path, 'solo.txt'),
      p.join(temp.path, 'Album'),
      p.join(temp.path, 'does-not-exist'),
    ], root);

    expect(failed, 0);
    final album = drive.find('Album')!;
    final inner = drive.find('Inner', parentId: album.id)!;
    expect(drive.find('solo.txt'), isNotNull);
    expect(drive.find('one.txt', parentId: album.id), isNotNull);
    expect(drive.find('two.txt', parentId: inner.id), isNotNull);
    expect(drive.find('.DS_Store', parentId: album.id), isNull);
  });

  test('uploadPaths counts failures and carries on', () async {
    File(p.join(temp.path, 'good.txt')).writeAsStringSync('ok');
    File(p.join(temp.path, 'bad.txt')).writeAsStringSync('no');
    drive.failWhen = (op, arg) => op == 'upload' && arg == 'bad.txt'
        ? DriveApiException(403, 'quota')
        : null;

    final failed = await repo.uploadPaths([
      p.join(temp.path, 'good.txt'),
      p.join(temp.path, 'bad.txt'),
    ], root);

    expect(failed, 1);
    expect(drive.find('good.txt'), isNotNull);
  });

  test('uploadPaths counts a folder that cannot be created', () async {
    Directory(p.join(temp.path, 'Album')).createSync();
    drive.failWhen = (op, _) =>
        op == 'createFolder' ? DriveApiException(403, 'no') : null;

    expect(await repo.uploadPaths([p.join(temp.path, 'Album')], root), 1);
  });

  test('downloadTo saves folders recursively without overwriting', () async {
    final docs = drive.addFolder('Docs');
    drive.addFile('a.txt', 'alpha', parentId: docs.id);
    final sub = drive.addFolder('Sub', parentId: docs.id);
    drive.addNative('Plan', 'docx', parentId: sub.id);
    drive.addBytes(
      'Survey',
      [],
      parentId: docs.id,
      mimeType: 'application/vnd.google-apps.form',
    );
    Directory(p.join(temp.path, 'Docs')).createSync();

    final failed = await repo.downloadTo(docs, temp.path);

    expect(failed, 0);
    final target = p.join(temp.path, 'Docs (2)');
    expect(File(p.join(target, 'a.txt')).readAsStringSync(), 'alpha');
    expect(File(p.join(target, 'Sub', 'Plan.docx')).readAsStringSync(), 'docx');
    expect(Directory(target).listSync(), hasLength(2));
  });

  test('downloadTo reports failed files and failed listings', () async {
    final a = drive.addFile('a.txt', 'alpha');
    drive.failWhen = (op, _) =>
        op == 'download' ? DriveApiException(403, 'no') : null;
    expect(await repo.downloadTo(a, temp.path), 1);

    final docs = drive.addFolder('Docs');
    drive.failWhen = (op, _) =>
        op == 'list' ? DriveApiException(500, 'down') : null;
    expect(await repo.downloadTo(docs, temp.path), 1);
  });
}
