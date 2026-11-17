import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/preview/preview_service.dart';
import 'package:path/path.dart' as p;

import '../../support/app_env.dart';

void main() {
  late AppEnv env;
  late PreviewService service;

  setUp(() {
    env = AppEnv();
    service = env.container().read(previewServiceProvider);
  });
  tearDown(() => env.dispose());

  Future<File> syncedFile(DriveItem item, String rel, String content) async {
    final file = File(p.join(env.syncRoot, rel))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    await env.db.putEntry(
      SyncEntry(
        fileId: item.id,
        relPath: rel,
        isFolder: false,
        isNative: false,
        localEdited: false,
      ),
    );
    return file;
  }

  test('an unsynced file is downloaded into the cache once', () async {
    final item = env.drive.addFile('a.txt', 'alpha');

    final first = await service.open(item);
    final second = await service.open(item);

    expect(first.synced, isFalse);
    expect(first.file.readAsStringSync(), 'alpha');
    expect(p.isWithin(env.paths.previewCache, first.file.path), isTrue);
    expect(second.file.path, first.file.path);
    expect(
      env.drive.calls.where((c) => c.startsWith('download')),
      hasLength(1),
    );
  });

  test('concurrent opens share one download', () async {
    final item = env.drive.addFile('a.txt', 'alpha');

    final results = await Future.wait([service.open(item), service.open(item)]);

    expect(results[0].file.path, results[1].file.path);
    expect(
      env.drive.calls.where((c) => c.startsWith('download')),
      hasLength(1),
    );
  });

  test('a new version is fetched again', () async {
    final item = env.drive.addFile('a.txt', 'v1');
    await service.open(item);

    final edited = env.drive.edit(item.id, 'v2');
    final source = await service.open(edited);

    expect(source.file.readAsStringSync(), 'v2');
  });

  test('the synced copy is preferred over downloading', () async {
    final item = env.drive.addFile('a.txt', 'remote');
    final local = await syncedFile(item, 'Docs/a.txt', 'local copy');

    final source = await service.open(item);

    expect(source.synced, isTrue);
    expect(source.file.path, local.path);
    expect(env.drive.calls.where((c) => c.startsWith('download')), isEmpty);
  });

  test('a synced record whose file is gone falls back to the cache', () async {
    final item = env.drive.addFile('a.txt', 'remote');
    (await syncedFile(item, 'a.txt', 'x')).deleteSync();

    expect(await service.syncedCopy(item), isNull);
    expect((await service.open(item)).synced, isFalse);
  });

  test('folders never count as a synced copy', () async {
    final folder = env.drive.addFolder('Docs');
    await env.db.putEntry(
      SyncEntry(
        fileId: folder.id,
        relPath: 'Docs',
        isFolder: true,
        isNative: false,
        localEdited: false,
      ),
    );
    expect(await service.syncedCopy(folder), isNull);
  });

  test(
    'Google Docs are exported as PDF even when synced as Office files',
    () async {
      final doc = env.drive.addNative('Plan', 'pdf bytes');
      await syncedFile(doc, 'Plan.docx', 'docx bytes');

      final source = await service.open(doc);

      expect(source.synced, isFalse);
      expect(source.file.path, endsWith('.pdf'));
      expect(source.file.readAsStringSync(), 'pdf bytes');
    },
  );

  test('saving an unsynced text file uploads a new revision', () async {
    final item = env.drive.addFile('a.txt', 'v1');
    final source = await service.open(item);

    final uploaded = await service.saveText(item, source, 'v2');

    expect(uploaded, isTrue);
    expect(env.drive.textOf(item.id), 'v2');
  });

  test(
    'saving a synced text file writes in place for sync to upload',
    () async {
      final item = env.drive.addFile('a.txt', 'v1');
      final local = await syncedFile(item, 'a.txt', 'v1');
      final source = await service.open(item);

      final uploaded = await service.saveText(item, source, 'v2');

      expect(uploaded, isFalse);
      expect(local.readAsStringSync(), 'v2');
      expect(env.drive.textOf(item.id), 'v1');
    },
  );

  test('clearCache removes downloaded previews', () async {
    final item = env.drive.addFile('a.txt', 'alpha');
    final source = await service.open(item);

    await service.clearCache();
    await service.clearCache();

    expect(source.file.existsSync(), isFalse);
  });

  test('media streams straight from Drive with the session token', () async {
    final container = env.container();
    await container.read(authProvider.future);

    final stream = await container.read(mediaStreamProvider('file-1').future);

    expect(stream.url, contains('/files/file-1?alt=media'));
    expect(stream.headers['Authorization'], 'Bearer fake-token');
  });
}
