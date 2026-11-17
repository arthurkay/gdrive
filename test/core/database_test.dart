import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';

import '../support/harness.dart';

DriveItem file(
  String id, {
  String? parent = 'root',
  String? name,
  bool trashed = false,
  bool starred = false,
  bool shared = false,
  DateTime? viewed,
  String mimeType = 'text/plain',
}) => DriveItem(
  id: id,
  parentId: parent,
  name: name ?? id,
  mimeType: mimeType,
  trashed: trashed,
  starred: starred,
  sharedWithMe: shared,
  viewedTime: viewed,
);

SyncEntry entry(String id, String path) => SyncEntry(
  fileId: id,
  relPath: path,
  isFolder: false,
  isNative: false,
  localEdited: false,
);

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 17);

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('key/value store reads, overwrites, watches and deletes', () async {
    expect(await db.getValue('k'), isNull);
    final seen = <String?>[];
    final sub = db.watchValue('k').listen(seen.add);

    // Watchers coalesce rapid writes, so let each one be delivered.
    await db.setValue('k', 'one');
    await pumpEventQueue();
    await db.setValue('k', 'two');
    await pumpEventQueue();
    expect(await db.getValue('k'), 'two');
    await db.setValue('k', null);
    await pumpEventQueue();
    expect(await db.getValue('k'), isNull);

    await sub.cancel();
    expect(seen, [null, 'one', 'two', null]);
  });

  test('items upsert, look up and remove in bulk', () async {
    await db.upsertItems([]);
    await db.upsertItems([for (var i = 0; i < 1200; i++) file('f$i')]);
    await db.upsertItems([file('f1', name: 'renamed')]);

    expect((await db.item('f1'))!.name, 'renamed');
    expect(await db.allItems(), hasLength(1200));

    await db.removeItems([]);
    await db.removeItems([for (var i = 0; i < 1199; i++) 'f$i']);
    expect((await db.allItems()).single.id, 'f1199');
  });

  test('listing queries filter by parent, flags and name', () async {
    await db.upsertItems([
      file('a'),
      file('b', trashed: true),
      file('c', parent: 'other', starred: true),
      file('d', parent: null, shared: true),
      file('e', viewed: DateTime(2026, 1, 2), name: 'Quarterly report'),
      file('f', viewed: DateTime(2026, 1, 3)),
      file('g', viewed: DateTime(2026, 1, 4), mimeType: folderMimeType),
    ]);
    Future<List<String>> ids(Stream<List<DriveItem>> s) async =>
        (await s.first).map((e) => e.id).toList();

    expect((await db.children('root')).map((e) => e.id), ['a', 'e', 'f', 'g']);
    expect(await ids(db.watchChildren('other')), ['c']);
    expect(await ids(db.watchStarred()), ['c']);
    expect(await ids(db.watchTrashed()), ['b']);
    expect(await ids(db.watchSharedWithMe()), ['d']);
    expect(await ids(db.watchRecent()), ['f', 'e'], reason: 'newest first');
    expect(await ids(db.watchRecent(limit: 1)), ['f']);
    expect(await ids(db.watchSearch('report')), ['e']);
  });

  test('replaceChildren drops rows Drive no longer lists', () async {
    await db.upsertItems([
      file('a'),
      file('b'),
      file('t', trashed: true),
      file('x', parent: 'other'),
    ]);

    await db.replaceChildren('root', [file('b', name: 'b2'), file('c')]);

    final ids = (await db.allItems()).map((e) => e.id).toSet();
    expect(ids, {'b', 'c', 't', 'x'});
    expect((await db.item('b'))!.name, 'b2');
  });

  test('replaceAllLive keeps trashed rows and replaces the rest', () async {
    await db.upsertItems([file('a'), file('t', trashed: true)]);

    await db.replaceAllLive([file('b', parent: 'other')]);

    expect((await db.allItems()).map((e) => e.id).toSet(), {'b', 't'});
  });

  test('selections add once, list, watch and remove', () async {
    await db.addSelection('x', now);
    await db.addSelection('x', now);
    await db.addSelection('y', now);
    expect(await db.selections(), unorderedEquals(['x', 'y']));
    expect(await db.watchSelections().first, {'x', 'y'});

    await db.removeSelection('x');
    expect(await db.selections(), ['y']);
  });

  test('a path belongs to one sync entry at a time', () async {
    await db.putEntry(entry('one', 'a.txt'));
    await db.putEntry(entry('two', 'a.txt'));
    expect((await db.entries()).single.fileId, 'two');

    await db.putEntry(entry('two', 'b.txt'));
    expect((await db.watchEntries().first).single.relPath, 'b.txt');

    await db.removeEntry('two');
    expect(await db.entries(), isEmpty);
  });

  test('transfers are listed newest first and can be cleared', () async {
    TransfersCompanion row(String name) => TransfersCompanion.insert(
      direction: 'upload',
      name: name,
      localPath: '/tmp/$name',
      createdAt: now,
    );
    final first = await db.addTransfer(row('first'));
    final second = await db.addTransfer(row('second'));
    final third = await db.addTransfer(row('third'));
    await db.updateTransfer(
      first,
      const TransfersCompanion(state: Value('done')),
    );
    await db.updateTransfer(
      second,
      const TransfersCompanion(state: Value('running')),
    );

    expect((await db.watchTransfers().first).map((t) => t.name), [
      'third',
      'second',
      'first',
    ]);
    expect((await db.transfer(first))!.state, 'done');

    await db.failInterruptedTransfers();
    expect((await db.transfer(second))!.state, 'failed');
    expect((await db.transfer(third))!.error, contains('Interrupted'));

    await db.clearFinishedTransfers();
    expect(await db.watchTransfers().first, isEmpty);
  });

  test('activity is logged newest first, limited, and clearable', () async {
    for (var i = 0; i < 5; i++) {
      await db.log('info', 'event $i', now);
    }
    final recent = await db.watchActivity(limit: 2).first;
    expect(recent.map((e) => e.message), ['event 4', 'event 3']);

    await db.clearActivity();
    expect(await db.watchActivity().first, isEmpty);
  });

  test('wipe empties every table', () async {
    await db.upsertItems([file('a')]);
    await db.addSelection('a', now);
    await db.putEntry(entry('a', 'a.txt'));
    await db.setValue('k', 'v');
    await db.log('info', 'x', now);

    await db.wipe();

    expect(await db.allItems(), isEmpty);
    expect(await db.selections(), isEmpty);
    expect(await db.entries(), isEmpty);
    expect(await db.getValue('k'), isNull);
    expect(await db.watchActivity().first, isEmpty);
  });
}
