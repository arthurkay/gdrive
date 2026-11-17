import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/transfers/transfer_manager.dart';
import 'package:path/path.dart' as p;

import '../../support/harness.dart';

void main() {
  late AppDatabase db;
  late FakeDriveApi drive;
  late Directory temp;
  late TransferManager manager;
  var limit = 3;

  setUp(() async {
    db = memoryDatabase();
    drive = FakeDriveApi();
    temp = await Directory.systemTemp.createTemp('gdrive_transfer_');
    limit = 3;
    manager = TransferManager(
      db: db,
      api: () => drive,
      clock: () => DateTime(2026, 11, 17),
      concurrency: () => limit,
      sleep: (_) async {},
    );
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  String path(String name) => p.join(temp.path, name);
  Future<List<Transfer>> rows() => db.watchTransfers().first;

  test('download writes the file and records a finished transfer', () async {
    final item = drive.addFile('a.txt', 'alpha');

    final file = await manager.download(item, path('out/a.txt'));

    expect(file.readAsStringSync(), 'alpha');
    expect(File(path('out/a.txt.part')).existsSync(), isFalse);
    final row = (await rows()).single;
    expect(row.direction, 'download');
    expect(row.state, 'done');
    expect(row.doneBytes, 5);
    expect(row.fromSync, isFalse);
  });

  test('download exports Google Docs', () async {
    final doc = drive.addNative('Plan', 'exported');

    final file = await manager.download(doc, path('Plan.docx'), fromSync: true);

    expect(file.readAsStringSync(), 'exported');
    expect(drive.calls, contains('export:${doc.id}'));
    expect((await rows()).single.fromSync, isTrue);
  });

  test('download can force an export format', () async {
    final doc = drive.addNative('Plan', 'as pdf');

    await manager.download(
      doc,
      path('Plan.pdf'),
      exportMimeType: 'application/pdf',
    );

    expect(File(path('Plan.pdf')).readAsStringSync(), 'as pdf');
  });

  test('a failed download leaves no partial file behind', () async {
    final item = drive.addFile('a.txt', 'alpha');
    drive.failWhen = (op, _) =>
        op == 'download' ? DriveApiException(403, 'forbidden') : null;

    await expectLater(
      manager.download(item, path('a.txt')),
      throwsA(isA<DriveApiException>()),
    );

    expect(temp.listSync(), isEmpty);
    final row = (await rows()).single;
    expect(row.state, 'failed');
    expect(row.error, contains('forbidden'));
  });

  test('a checksum mismatch is an error, not a file', () async {
    final item = drive.addFile('a.txt', 'alpha');
    drive.bytesOf(item.id)![0] ^= 0xFF;

    await expectLater(
      manager.download(item, path('a.txt')),
      throwsA(
        isA<ChecksumMismatch>().having((e) => '$e', 'text', contains('a.txt')),
      ),
    );
    expect(temp.listSync(), isEmpty);
  });

  test('upload creates a file and caches its metadata', () async {
    File(path('new.txt')).writeAsStringSync('hello');

    final item = await manager.upload(
      path('new.txt'),
      parentId: FakeDriveApi.rootId,
    );

    expect(drive.textOf(item.id), 'hello');
    expect(await db.item(item.id), isNotNull);
    final row = (await rows()).single;
    expect(row.direction, 'upload');
    expect(row.state, 'done');
    expect(row.fileId, item.id);
  });

  test('upload can rename and can replace an existing file', () async {
    File(path('local.txt')).writeAsStringSync('v2');
    final existing = drive.addFile('remote.txt', 'v1');

    final renamed = await manager.upload(
      path('local.txt'),
      parentId: FakeDriveApi.rootId,
      name: 'renamed.txt',
    );
    final replaced = await manager.upload(
      path('local.txt'),
      replaceFileId: existing.id,
    );

    expect(renamed.name, 'renamed.txt');
    expect(replaced.id, existing.id);
    expect(drive.textOf(existing.id), 'v2');
  });

  test('transient upload failures are retried from the start', () async {
    File(path('a.txt')).writeAsStringSync('alpha');
    var failures = 2;
    drive.failWhen = (op, _) => op == 'upload' && failures-- > 0
        ? DriveApiException(503, 'busy')
        : null;

    final item = await manager.upload(
      path('a.txt'),
      parentId: FakeDriveApi.rootId,
    );

    expect(drive.textOf(item.id), 'alpha');
    expect((await rows()).single.state, 'done');
  });

  test('a cancelled transfer stops and is marked cancelled', () async {
    final item = drive.addBytes('big.bin', List.filled(300 * 1024, 7));
    late int id;
    final sub = db.watchTransfers().listen((list) {
      if (list.isNotEmpty) manager.cancel(id = list.first.id);
    });

    await expectLater(
      manager.download(item, path('big.bin')),
      throwsA(
        isA<TransferCancelled>().having((e) => '$e', 'text', 'Cancelled'),
      ),
    );
    await sub.cancel();

    expect((await db.transfer(id))!.state, 'cancelled');
    expect(File(path('big.bin')).existsSync(), isFalse);
  });

  test('no more than the configured number run at once', () async {
    limit = 2;
    var running = 0;
    var peak = 0;
    final gate = Completer<void>();
    drive.failWhen = (op, _) {
      if (op == 'download') {
        running++;
        peak = running > peak ? running : peak;
      }
      return null;
    };
    final items = [
      for (var i = 0; i < 6; i++) drive.addFile('f$i.txt', 'content $i'),
    ];

    final downloads = [
      for (final item in items)
        manager.download(item, path(item.name)).whenComplete(() => running--),
    ];
    gate.complete();
    await Future.wait(downloads);

    expect(peak, lessThanOrEqualTo(2));
    expect((await rows()).every((r) => r.state == 'done'), isTrue);
  });

  test('large transfers report byte progress', () async {
    final bytes = List.filled(2 * 1024 * 1024, 1);
    final item = drive.addBytes('big.bin', bytes);

    await manager.download(item, path('big.bin'));

    final row = (await rows()).single;
    expect(row.doneBytes, bytes.length);
    expect(row.totalBytes, bytes.length);
  });
}
