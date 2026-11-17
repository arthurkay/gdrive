import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/sync/sync_engine.dart';

import '../../support/harness.dart';

void main() {
  late SyncHarness h;

  setUp(() async => h = await SyncHarness.create());
  tearDown(() => h.dispose());

  group('first sync', () {
    test('downloads a selected folder with its subfolders', () async {
      final docs = h.drive.addFolder('Docs');
      final sub = h.drive.addFolder('2026', parentId: docs.id);
      h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
      h.drive.addFile('b.txt', 'beta', parentId: sub.id);
      h.drive.addFolder('Empty', parentId: docs.id);
      h.drive.addFile('outside.txt', 'not selected');
      await h.select(docs.id);

      final report = await h.sync();

      expect(report.downloads, 2);
      expect(report.errors, 0);
      expect(h.localFiles(), ['Docs/2026/b.txt', 'Docs/a.txt']);
      expect(h.read('Docs/a.txt'), 'alpha');
      expect(h.localDir('Docs/Empty').existsSync(), isTrue);
      expect(await h.activity('download'), hasLength(2));
    });

    test('syncs the whole Drive when the root is selected', () async {
      final docs = h.drive.addFolder('Docs');
      h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
      h.drive.addFile('top.txt', 'top');
      await h.selectAll();

      await h.sync();

      expect(h.localFiles(), ['Docs/a.txt', 'top.txt']);
    });

    test('syncs a single selected file at its Drive path', () async {
      final docs = h.drive.addFolder('Docs');
      final a = h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
      h.drive.addFile('b.txt', 'beta', parentId: docs.id);
      await h.select(a.id);

      await h.sync();

      expect(h.localFiles(), ['Docs/a.txt']);
    });

    test(
      'puts selected items from outside My Drive under Shared with me',
      () async {
        final shared = h.drive.addFile('theirs.txt', 'x', sharedWithMe: true);
        await h.select(shared.id);

        await h.sync();

        expect(h.localFiles(), ['Shared with me/theirs.txt']);
      },
    );

    test('a second pass with nothing changed transfers nothing', () async {
      h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();
      await h.sync();
      final mark = h.drive.calls.length;

      final report = await h.sync();

      expect(report.changedAnything, isFalse);
      expect(h.callsTo('download', since: mark), isEmpty);
      expect(h.callsTo('upload', since: mark), isEmpty);
      expect(h.callsTo('updateContent', since: mark), isEmpty);
    });

    test('numbers Drive files that share a name', () async {
      h.drive.addFile('same.txt', 'one', id: 'a');
      h.drive.addFile('same.txt', 'two', id: 'b');
      await h.selectAll();

      await h.sync();

      expect(h.read('same.txt'), 'one');
      expect(h.read('same (2).txt'), 'two');
    });

    test('makes Drive names safe for the local disk', () async {
      h.drive.addFile('a/b:c?.txt', 'x');
      await h.selectAll();

      await h.sync();

      expect(h.localFiles(), ['a_b_c_.txt']);
    });

    test('skips Google types that cannot be exported', () async {
      h.drive.addBytes(
        'Survey',
        [],
        mimeType: 'application/vnd.google-apps.form',
      );
      h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();

      final report = await h.sync();

      expect(report.errors, 0);
      expect(h.localFiles(), ['a.txt']);
    });

    test('links identical files that already exist on both sides', () async {
      h.drive.addFile('a.txt', 'alpha');
      h.write('a.txt', 'alpha');
      await h.selectAll();

      final report = await h.sync();

      expect(report.changedAnything, isFalse);
      expect(h.callsTo('download'), isEmpty);
      expect(h.callsTo('upload'), isEmpty);
      expect((await h.db.entries()).single.relPath, 'a.txt');
    });

    test('keeps both versions when an untracked local file differs', () async {
      h.drive.addFile('a.txt', 'from drive');
      h.write('a.txt', 'from disk');
      await h.selectAll();

      final report = await h.sync();

      expect(report.conflicts, 1);
      expect(h.read('a.txt'), 'from drive');
      expect(h.read('a (conflicted copy 2026-11-17).txt'), 'from disk');
    });
  });

  group('changes on Drive', () {
    test('an edit is downloaded', () async {
      final a = h.drive.addFile('a.txt', 'v1');
      await h.selectAll();
      await h.sync();

      h.drive.edit(a.id, 'v2 from drive');
      final report = await h.sync();

      expect(report.downloads, 1);
      expect(h.read('a.txt'), 'v2 from drive');
    });

    test('a new file arrives through the change feed', () async {
      final docs = h.drive.addFolder('Docs');
      await h.select(docs.id);
      await h.sync();
      final mark = h.drive.calls.length;

      h.drive.addFile('late.txt', 'hello', parentId: docs.id);
      await h.sync();

      expect(h.read('Docs/late.txt'), 'hello');
      expect(h.callsTo('list', since: mark), isEmpty, reason: 'no re-crawl');
    });

    test(
      'a folder that appears with contents is listed and downloaded',
      () async {
        await h.selectAll();
        await h.sync();

        // Simulate a folder whose children predate the change token.
        final folder = h.drive.addFolder('Moved in');
        h.drive.addFile('inside.txt', 'x', parentId: folder.id);
        await h.sync();

        expect(h.read('Moved in/inside.txt'), 'x');
      },
    );

    test('a trashed file goes to the local recycle folder', () async {
      final a = h.drive.addFile('a.txt', 'alpha');
      h.drive.addFile('keep.txt', 'keep');
      await h.selectAll();
      await h.sync();

      await h.drive.updateMetadata(a.id, trashed: true);
      final report = await h.sync();

      expect(report.deletedLocal, 1);
      expect(h.localFiles(), ['keep.txt']);
      expect(h.recycled(), ['a.txt']);
      expect(await h.db.entries(), hasLength(1));
    });

    test(
      'a permanently deleted file goes to the local recycle folder',
      () async {
        final a = h.drive.addFile('a.txt', 'alpha');
        await h.selectAll();
        await h.sync();

        h.drive.purge(a.id);
        await h.sync();

        expect(h.localFiles(), isEmpty);
        expect(h.recycled(), ['a.txt']);
      },
    );

    test('a deleted file that was edited locally is uploaded again', () async {
      final a = h.drive.addFile('a.txt', 'v1');
      await h.selectAll();
      await h.sync();

      h.drive.purge(a.id);
      h.write('a.txt', 'local work');
      final report = await h.sync();

      expect(report.deletedLocal, 0);
      expect(report.uploads, 1);
      expect(h.read('a.txt'), 'local work');
      expect(h.drive.textOf(h.drive.find('a.txt')!.id), 'local work');
    });

    test('a rename is applied locally without downloading again', () async {
      final a = h.drive.addFile('old.txt', 'alpha');
      await h.selectAll();
      await h.sync();
      final mark = h.drive.calls.length;

      await h.drive.updateMetadata(a.id, name: 'new.txt');
      final report = await h.sync();

      expect(report.moves, 1);
      expect(h.localFiles(), ['new.txt']);
      expect(h.callsTo('download', since: mark), isEmpty);
      expect((await h.db.entries()).single.relPath, 'new.txt');
    });

    test('a folder rename moves the local folder and its files', () async {
      final docs = h.drive.addFolder('Docs');
      h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
      await h.selectAll();
      await h.sync();
      final mark = h.drive.calls.length;

      await h.drive.updateMetadata(docs.id, name: 'Papers');
      await h.sync();

      expect(h.localFiles(), ['Papers/a.txt']);
      expect(h.localDir('Docs').existsSync(), isFalse);
      expect(h.callsTo('download', since: mark), isEmpty);
      expect(h.drive.find('a.txt', parentId: docs.id)!.trashed, isFalse);
    });

    test('a rename onto an occupied local path loses nothing', () async {
      final a = h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();
      await h.sync();

      h.write('b.txt', 'unrelated local file');
      await h.drive.updateMetadata(a.id, name: 'b.txt');
      await h.sync();
      await h.sync();

      final contents = h.localFiles().map(h.read).toSet();
      expect(contents, containsAll(['alpha', 'unrelated local file']));
      expect(h.drive.byId(a.id)!.trashed, isFalse);
    });

    test('a trashed folder removes its local files and the folder', () async {
      final docs = h.drive.addFolder('Docs');
      h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
      h.drive.addFile('keep.txt', 'keep');
      await h.selectAll();
      await h.sync();

      await h.drive.updateMetadata(docs.id, trashed: true);
      await h.sync();

      expect(h.localFiles(), ['keep.txt']);
      expect(h.localDir('Docs').existsSync(), isFalse);
      expect(h.recycled(), ['a.txt']);
    });

    test(
      'a trashed folder keeps local files that were never uploaded',
      () async {
        final docs = h.drive.addFolder('Docs');
        h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
        await h.selectAll();
        await h.sync();

        await h.drive.updateMetadata(docs.id, trashed: true);
        h.write('Docs/new.txt', 'brand new');
        await h.sync();
        await h.sync();

        expect(h.read('Docs/new.txt'), 'brand new');
        final recreated = h.drive.find('Docs')!;
        expect(recreated.id, isNot(docs.id));
        expect(h.drive.find('new.txt', parentId: recreated.id), isNotNull);
      },
    );
  });

  group('changes on disk', () {
    test('an edit is uploaded as a new revision of the same file', () async {
      final a = h.drive.addFile('a.txt', 'v1');
      await h.selectAll();
      await h.sync();

      h.write('a.txt', 'v2 from disk');
      final report = await h.sync();

      expect(report.uploads, 1);
      expect(h.drive.textOf(a.id), 'v2 from disk');
      expect(h.callsTo('upload'), isEmpty, reason: 'no duplicate file');
    });

    test('a same-size edit is still detected', () async {
      final a = h.drive.addFile('a.txt', 'aaaa');
      await h.selectAll();
      await h.sync();

      h.write('a.txt', 'bbbb');
      await h.sync();

      expect(h.drive.textOf(a.id), 'bbbb');
    });

    test('touching a file without editing it uploads nothing', () async {
      h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();
      await h.sync();
      final mark = h.drive.calls.length;

      h.write('a.txt', 'alpha');
      final report = await h.sync();
      await h.sync();

      expect(report.uploads, 0);
      expect(h.callsTo('updateContent', since: mark), isEmpty);
    });

    test('a new file in a synced folder is uploaded', () async {
      final docs = h.drive.addFolder('Docs');
      await h.select(docs.id);
      await h.sync();

      h.write('Docs/new.txt', 'hello');
      final report = await h.sync();

      expect(report.uploads, 1);
      final uploaded = h.drive.find('new.txt', parentId: docs.id)!;
      expect(h.drive.textOf(uploaded.id), 'hello');
    });

    test('a new file outside the synced folders is left alone', () async {
      final docs = h.drive.addFolder('Docs');
      await h.select(docs.id);
      await h.sync();

      h.write('elsewhere.txt', 'private');
      final report = await h.sync();

      expect(report.uploads, 0);
      expect(h.drive.find('elsewhere.txt'), isNull);
    });

    test('new nested folders are created once on Drive', () async {
      await h.selectAll();
      await h.sync();

      h.write('New/Deep/one.txt', '1');
      h.write('New/Deep/two.txt', '2');
      h.localDir('New/Hollow').createSync(recursive: true);
      await h.sync();

      final created = h.drive.find('New')!;
      final deep = h.drive.find('Deep', parentId: created.id)!;
      expect(h.drive.find('one.txt', parentId: deep.id), isNotNull);
      expect(h.drive.find('two.txt', parentId: deep.id), isNotNull);
      expect(h.drive.find('Hollow', parentId: created.id), isNotNull);
      expect(h.callsTo('createFolder'), hasLength(3));

      final mark = h.drive.calls.length;
      await h.sync();
      expect(h.callsTo('createFolder', since: mark), isEmpty);
    });

    test('a deleted file is moved to Drive trash, never purged', () async {
      final a = h.drive.addFile('a.txt', 'alpha');
      h.drive.addFile('keep.txt', 'keep');
      await h.selectAll();
      await h.sync();

      h.local('a.txt').deleteSync();
      final report = await h.sync();

      expect(report.trashedRemote, 1);
      expect(h.drive.byId(a.id)!.trashed, isTrue);
      expect(h.callsTo('delete'), isEmpty);
      expect(h.localFiles(), ['keep.txt']);
    });

    test('a deleted file that changed on Drive comes back', () async {
      final a = h.drive.addFile('a.txt', 'v1');
      await h.selectAll();
      await h.sync();

      h.local('a.txt').deleteSync();
      h.drive.edit(a.id, 'v2');
      final report = await h.sync();

      expect(report.trashedRemote, 0);
      expect(h.read('a.txt'), 'v2');
      expect(h.drive.byId(a.id)!.trashed, isFalse);
    });

    test('a rename is applied on Drive without uploading again', () async {
      final a = h.drive.addFile('old.txt', 'some content');
      await h.selectAll();
      await h.sync();
      final mark = h.drive.calls.length;

      h.local('old.txt').renameSync(h.local('new.txt').path);
      final report = await h.sync();

      expect(report.moves, 1);
      expect(h.drive.byId(a.id)!.name, 'new.txt');
      expect(h.drive.byId(a.id)!.trashed, isFalse);
      expect(h.callsTo('upload', since: mark), isEmpty);
      expect(h.localFiles(), ['new.txt']);
    });

    test('a move to another folder changes the parent on Drive', () async {
      final a = h.drive.addFile('a.txt', 'some content');
      final docs = h.drive.addFolder('Docs');
      await h.selectAll();
      await h.sync();

      h.local('a.txt').renameSync(h.local('Docs/a.txt').path);
      await h.sync();

      expect(h.drive.byId(a.id)!.parentId, docs.id);
      expect(h.callsTo('upload'), isEmpty);
    });

    test('a renamed folder keeps the same Drive files', () async {
      final docs = h.drive.addFolder('Docs');
      final a = h.drive.addFile('a.txt', 'some content', parentId: docs.id);
      await h.selectAll();
      await h.sync();

      h.localDir('Docs').renameSync(h.localDir('Papers').path);
      await h.sync();

      final papers = h.drive.find('Papers')!;
      expect(h.drive.byId(a.id)!.parentId, papers.id);
      expect(h.drive.byId(a.id)!.trashed, isFalse);
      expect(h.drive.byId(docs.id)!.trashed, isTrue);
      expect(h.callsTo('upload'), isEmpty);
    });

    test('a deleted folder is trashed on Drive with its files', () async {
      final docs = h.drive.addFolder('Docs');
      final a = h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
      h.drive.addFile('keep.txt', 'keep');
      await h.selectAll();
      await h.sync();

      h.localDir('Docs').deleteSync(recursive: true);
      await h.sync();

      expect(h.drive.byId(a.id)!.trashed, isTrue);
      expect(h.drive.byId(docs.id)!.trashed, isTrue);
      expect(h.callsTo('delete'), isEmpty);
    });

    test(
      'a deleted folder is restored if Drive has newer content in it',
      () async {
        final docs = h.drive.addFolder('Docs');
        final a = h.drive.addFile('a.txt', 'v1', parentId: docs.id);
        await h.selectAll();
        await h.sync();

        h.localDir('Docs').deleteSync(recursive: true);
        h.drive.edit(a.id, 'v2');
        await h.sync();

        expect(h.drive.byId(docs.id)!.trashed, isFalse);
        expect(h.read('Docs/a.txt'), 'v2');
      },
    );

    test('temporary and partial files are never uploaded', () async {
      await h.selectAll();
      await h.sync();

      h.write('movie.mp4.part', 'x');
      h.write('.DS_Store', 'x');
      h.write('~\$report.docx', 'x');
      h.write('real.txt', 'x');
      await h.sync();

      expect(h.callsTo('upload'), ['upload:real.txt']);
    });
  });

  group('conflicts', () {
    test('edits on both sides keep both versions', () async {
      final a = h.drive.addFile('a.txt', 'base');
      await h.selectAll();
      await h.sync();

      h.drive.edit(a.id, 'drive edit');
      h.write('a.txt', 'local edit');
      final report = await h.sync();

      expect(report.conflicts, 1);
      expect(h.read('a.txt'), 'drive edit');
      expect(h.read('a (conflicted copy 2026-11-17).txt'), 'local edit');
      expect(h.drive.textOf(a.id), 'drive edit');
      expect(await h.activity('conflict'), hasLength(1));

      // The kept copy is then uploaded as its own file.
      await h.sync();
      final copy = h.drive.find('a (conflicted copy 2026-11-17).txt')!;
      expect(h.drive.textOf(copy.id), 'local edit');
    });

    test('a second conflict on the same day gets its own name', () async {
      final a = h.drive.addFile('a.txt', 'base');
      await h.selectAll();
      await h.sync();
      for (final round in ['one', 'two']) {
        h.drive.edit(a.id, 'drive $round');
        h.write('a.txt', 'local $round');
        await h.sync();
      }

      expect(h.read('a (conflicted copy 2026-11-17).txt'), 'local one');
      expect(h.read('a (conflicted copy 2026-11-17) (2).txt'), 'local two');
    });

    test('identical edits on both sides are not a conflict', () async {
      final a = h.drive.addFile('a.txt', 'base');
      await h.selectAll();
      await h.sync();

      h.drive.edit(a.id, 'same edit');
      h.write('a.txt', 'same edit');
      final report = await h.sync();

      expect(report.conflicts, 0);
      expect(h.localFiles(), ['a.txt']);
    });

    test('a folder on one side and a file on the other is reported', () async {
      h.drive.addFolder('thing');
      h.write('thing', 'I am a file');
      await h.selectAll();

      final report = await h.sync();

      expect(report.errors, 1);
      expect(h.read('thing'), 'I am a file');
    });
  });

  group('Google Docs', () {
    test('are exported with an Office extension', () async {
      h.drive.addNative('Plan', 'docx bytes');
      h.drive.addNative(
        'Budget',
        'xlsx bytes',
        mimeType: 'application/vnd.google-apps.spreadsheet',
      );
      await h.selectAll();

      await h.sync();

      expect(h.localFiles(), ['Budget.xlsx', 'Plan.docx']);
      expect(h.read('Plan.docx'), 'docx bytes');
      expect(h.callsTo('export'), hasLength(2));
    });

    test('are exported again when the document changes', () async {
      final doc = h.drive.addNative('Plan', 'v1');
      await h.selectAll();
      await h.sync();

      h.drive.edit(doc.id, 'v2');
      await h.sync();

      expect(h.read('Plan.docx'), 'v2');
    });

    test('local edits to an export are flagged, not uploaded', () async {
      final doc = h.drive.addNative('Plan', 'v1');
      await h.selectAll();
      await h.sync();

      h.write('Plan.docx', 'edited in Word');
      final report = await h.sync();
      await h.sync();

      expect(report.uploads, 0);
      expect(h.read('Plan.docx'), 'edited in Word');
      expect(h.drive.textOf(doc.id), 'v1');
      expect((await h.db.entries()).single.localEdited, isTrue);
      expect(await h.activity('info'), hasLength(1));
    });

    test('an edited export is kept when the document changes too', () async {
      final doc = h.drive.addNative('Plan', 'v1');
      await h.selectAll();
      await h.sync();

      h.write('Plan.docx', 'edited in Word');
      await h.sync();
      h.drive.edit(doc.id, 'v2');
      await h.sync();

      expect(h.read('Plan.docx'), 'v2');
      expect(
        h.read('Plan (conflicted copy 2026-11-17).docx'),
        'edited in Word',
      );
    });
  });

  group('safety', () {
    Future<void> seed(int count) async {
      for (var i = 0; i < count; i++) {
        h.drive.addFile('f$i.txt', 'content $i');
      }
      await h.selectAll();
      await h.sync();
    }

    test('a large local deletion pauses for confirmation', () async {
      await seed(8);
      for (var i = 0; i < 6; i++) {
        h.local('f$i.txt').deleteSync();
      }

      final report = await h.sync();

      expect(report.pendingDeletes, 6);
      expect(h.drive.items.where((i) => i.trashed), isEmpty);
    });

    test('a confirmed large deletion goes ahead', () async {
      await seed(8);
      for (var i = 0; i < 6; i++) {
        h.local('f$i.txt').deleteSync();
      }

      final report = await h.sync(allowMassDelete: true);

      expect(report.trashedRemote, 6);
      expect(h.drive.items.where((i) => i.trashed), hasLength(6));
    });

    test('a large Drive deletion pauses before touching local files', () async {
      await seed(8);
      for (final item in h.drive.items.take(6).toList()) {
        h.drive.purge(item.id);
      }

      final report = await h.sync();

      expect(report.pendingDeletes, 6);
      expect(h.localFiles(), hasLength(8));
    });

    test(
      'a missing sync folder stops the pass instead of emptying Drive',
      () async {
        await seed(3);
        Directory(h.root).deleteSync(recursive: true);

        await expectLater(h.sync(), throwsA(isA<SyncRootMissing>()));
        expect(h.drive.items.where((i) => i.trashed), isEmpty);
      },
    );

    test('deselecting keeps files on both sides', () async {
      await seed(3);

      await h.db.removeSelection(FakeDriveApi.rootId);
      final report = await h.sync();

      expect(report.changedAnything, isFalse);
      expect(h.localFiles(), hasLength(3));
      expect(h.drive.items.where((i) => i.trashed), isEmpty);
      expect(await h.db.entries(), isEmpty);
    });

    test(
      'deselecting one folder leaves it alone but keeps syncing the rest',
      () async {
        final a = h.drive.addFolder('A');
        final b = h.drive.addFolder('B');
        final inA = h.drive.addFile('a.txt', 'a', parentId: a.id);
        h.drive.addFile('b.txt', 'b', parentId: b.id);
        await h.select(a.id);
        await h.select(b.id);
        await h.sync();

        await h.db.removeSelection(a.id);
        h.local('A/a.txt').deleteSync();
        h.write('B/new.txt', 'n');
        await h.sync();

        expect(h.drive.byId(inA.id)!.trashed, isFalse);
        expect(h.drive.find('new.txt', parentId: b.id), isNotNull);
      },
    );

    test(
      'a selection that vanished from Drive is dropped, files stay',
      () async {
        final docs = h.drive.addFolder('Docs');
        h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
        await h.select(docs.id);
        await h.sync();

        h.drive.purge(docs.id);
        await h.sync();

        expect(await h.db.selections(), isEmpty);
        expect(h.read('Docs/a.txt'), 'alpha');
      },
    );

    test('a failed listing aborts the pass with nothing deleted', () async {
      await seed(3);
      h.engine = h.newEngine(); // restart forces a full listing
      h.drive.failWhen = (op, _) =>
          op == 'list' ? DriveApiException(500, 'backend error') : null;

      await expectLater(h.sync(), throwsA(isA<DriveApiException>()));
      expect(h.localFiles(), hasLength(3));
    });

    test('one failing file does not stop the others', () async {
      final bad = h.drive.addFile('bad.txt', 'x');
      h.drive.addFile('good.txt', 'y');
      await h.selectAll();
      h.drive.failWhen = (op, arg) => op == 'download' && arg == bad.id
          ? DriveApiException(403, 'forbidden')
          : null;

      final report = await h.sync();

      expect(report.errors, 1);
      expect(report.downloads, 1);
      expect(h.localFiles(), ['good.txt']);
      expect(h.has('bad.txt.part'), isFalse);

      h.drive.failWhen = null;
      await h.sync();
      expect(h.localFiles(), ['bad.txt', 'good.txt']);
    });

    test('transient failures are retried within the pass', () async {
      h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();
      var failures = 2;
      h.drive.failWhen = (op, _) => op == 'download' && failures-- > 0
          ? DriveApiException(503, 'try later')
          : null;

      final report = await h.sync();

      expect(report.errors, 0);
      expect(h.read('a.txt'), 'alpha');
    });

    test('corrupted downloads are rejected', () async {
      final a = h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();
      await h.db.upsertItems([a]);
      // Make the reported checksum disagree with the bytes served.
      h.drive.failWhen = (op, _) {
        if (op == 'download') h.drive.bytesOf(a.id)![0] ^= 0xFF;
        return null;
      };

      final report = await h.sync();

      expect(report.errors, 1);
      expect(h.localFiles(), isEmpty);
    });

    test('an expired change token triggers a fresh listing', () async {
      h.drive.addFile('a.txt', 'alpha');
      await h.selectAll();
      await h.sync();

      h.drive.addFile('b.txt', 'beta');
      var failed = false;
      h.drive.failWhen = (op, _) {
        if (op != 'changes' || failed) return null;
        failed = true;
        return DriveApiException(410, 'token expired');
      };
      await h.sync();

      expect(h.localFiles(), ['a.txt', 'b.txt']);
    });

    test('state survives an app restart', () async {
      final a = h.drive.addFile('a.txt', 'v1');
      await h.selectAll();
      await h.sync();

      h.engine = h.newEngine();
      h.drive.edit(a.id, 'v2');
      final report = await h.sync();

      expect(report.downloads, 1);
      expect(report.conflicts, 0);
      expect(h.read('a.txt'), 'v2');
    });

    test('recycled files are purged after the retention period', () async {
      final a = h.drive.addFile('a.txt', 'alpha');
      h.drive.addFile('keep.txt', 'keep');
      await h.selectAll();
      await h.sync();
      await h.drive.updateMetadata(a.id, trashed: true);
      await h.sync();
      expect(h.recycled(), ['a.txt']);

      h.now = h.now.add(const Duration(days: 31));
      // Recycle batches age by their on-disk timestamp.
      for (final dir in Directory(h.recycle).listSync()) {
        Process.runSync('touch', ['-d', '2020-01-01', dir.path]);
      }
      await h.sync();

      expect(h.recycled(), isEmpty);
    });

    test('with nothing selected the engine does nothing', () async {
      h.drive.addFile('a.txt', 'alpha');

      final report = await h.sync();

      expect(report.changedAnything, isFalse);
      expect(h.drive.calls, isEmpty);
      expect(await h.db.selections(), isA<List<String>>());
    });
  });

  test('cached metadata matches Drive after a pass', () async {
    final docs = h.drive.addFolder('Docs');
    h.drive.addFile('a.txt', 'alpha', parentId: docs.id);
    await h.selectAll();
    await h.sync();

    final cached = await h.db.allItems();
    expect(cached.map((DriveItem i) => i.name).toSet(), {'Docs', 'a.txt'});
  });
}
