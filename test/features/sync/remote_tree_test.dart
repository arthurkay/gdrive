import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/features/sync/local_scanner.dart';
import 'package:gdrive/features/sync/remote_tree.dart';
import 'package:path/path.dart' as p;

DriveItem node(
  String id, {
  String? parent = 'root',
  String? name,
  bool folder = false,
  bool trashed = false,
  String? mimeType,
}) => DriveItem(
  id: id,
  parentId: parent,
  name: name ?? id,
  mimeType: mimeType ?? (folder ? folderMimeType : 'text/plain'),
  trashed: trashed,
  starred: false,
  sharedWithMe: false,
);

void main() {
  group('buildRemoteTree', () {
    final items = [
      node('docs', folder: true, name: 'Docs'),
      node('a', parent: 'docs', name: 'a.txt'),
      node('sub', parent: 'docs', folder: true, name: 'Sub'),
      node('b', parent: 'sub', name: 'b.txt'),
      node('top', name: 'top.txt'),
      node('gone', name: 'gone.txt', trashed: true),
      node('form', mimeType: 'application/vnd.google-apps.form'),
      node(
        'doc',
        name: 'Plan',
        mimeType: 'application/vnd.google-apps.document',
      ),
      node('orphan', parent: 'elsewhere', name: 'orphan.txt'),
    ];

    RemoteTree build(List<String> selections) =>
        buildRemoteTree(items: items, selections: selections, rootId: 'root');

    test('root selection covers everything live and syncable', () {
      final tree = build(['root']);
      expect(tree.byPath.keys.toSet(), {
        'Docs',
        'Docs/a.txt',
        'Docs/Sub',
        'Docs/Sub/b.txt',
        'top.txt',
        'Plan.docx',
      });
      expect(tree.scopeDirs, {''});
      expect(tree.inScope('anything/at/all.txt'), isTrue);
      expect(tree.pathById['b'], 'Docs/Sub/b.txt');
    });

    test('folder selection covers its subtree only', () {
      final tree = build(['sub']);
      expect(tree.byPath.keys.toSet(), {'Docs/Sub', 'Docs/Sub/b.txt'});
      expect(tree.scopeDirs, {'Docs/Sub'});
      expect(tree.inScope('Docs/Sub/new.txt'), isTrue);
      expect(tree.inScope('Docs/Sub'), isTrue);
      expect(tree.inScope('Docs/Subway.txt'), isFalse);
      expect(tree.inScope('Docs/a.txt'), isFalse);
    });

    test('file selection covers that file alone', () {
      final tree = build(['a']);
      expect(tree.byPath.keys, ['Docs/a.txt']);
      expect(tree.scopeFiles, {'Docs/a.txt'});
      expect(tree.scopeDirs, isEmpty);
      expect(tree.inScope('Docs/a.txt'), isTrue);
      expect(tree.inScope('Docs/other.txt'), isFalse);
    });

    test('a selection inside another selected folder is not duplicated', () {
      final tree = build(['docs', 'a', 'sub']);
      expect(tree.byPath.keys.where((k) => k.endsWith('a.txt')), hasLength(1));
      expect(tree.scopeDirs, {'Docs', 'Docs/Sub'});
      expect(tree.scopeFiles, isEmpty);
    });

    test('items outside My Drive land under Shared with me', () {
      final tree = build(['orphan']);
      expect(tree.byPath.keys, ['Shared with me/orphan.txt']);
    });

    test('missing, trashed and unsyncable selections are stale', () {
      final tree = build(['nope', 'gone', 'form', 'top']);
      expect(tree.staleSelections, unorderedEquals(['nope', 'gone', 'form']));
      expect(tree.byPath.keys, ['top.txt']);
    });

    test('descendants and move keep the indexes consistent', () {
      final tree = build(['root']);
      expect(tree.descendants('Docs').map((e) => e.id).toSet(), {
        'a',
        'sub',
        'b',
      });
      tree.move('top.txt', 'Docs/top.txt', items[4]);
      expect(tree.byPath.containsKey('top.txt'), isFalse);
      expect(tree.pathById['top'], 'Docs/top.txt');
    });

    test('siblings that collide on disk are numbered by id', () {
      final tree = buildRemoteTree(
        items: [
          node('2', name: 'Same.txt'),
          node('1', name: 'same.txt'),
          node('3', name: 'same.txt'),
          node('4', name: 'a:b'),
          node('5', name: 'a?b'),
        ],
        selections: ['root'],
        rootId: 'root',
      );
      expect(tree.pathById, {
        '1': 'same.txt',
        '2': 'Same (2).txt',
        '3': 'same (3).txt',
        '4': 'a_b',
        '5': 'a_b (2)',
      });
    });

    test('export extension is not doubled', () {
      expect(
        localNameOf(
          node(
            'd',
            name: 'Plan.DOCX',
            mimeType: 'application/vnd.google-apps.document',
          ),
        ),
        'Plan.DOCX',
      );
      expect(
        localNameOf(
          node(
            's',
            name: 'Budget',
            mimeType: 'application/vnd.google-apps.spreadsheet',
          ),
        ),
        'Budget.xlsx',
      );
    });

    test('a parent cycle does not hang path building', () {
      final tree = buildRemoteTree(
        items: [
          node('x', parent: 'y', folder: true),
          node('y', parent: 'x', folder: true),
        ],
        selections: ['x'],
        rootId: 'root',
      );
      expect(tree.byPath.keys.first, startsWith('Shared with me/'));
    });
  });

  group('scanLocal', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('gdrive_scan_');
      for (final file in [
        'A/one.txt',
        'A/B/two.txt',
        'C/three.txt',
        'top.txt',
      ]) {
        File(p.join(root.path, file))
          ..createSync(recursive: true)
          ..writeAsStringSync(file);
      }
      File(p.join(root.path, 'A', 'x.part')).writeAsStringSync('partial');
      Directory(p.join(root.path, 'A', 'Empty')).createSync();
    });
    tearDown(() => root.delete(recursive: true));

    test('walks the whole root for the empty scope', () async {
      final found = await scanLocal(root: root.path, dirs: [''], files: []);
      expect(found.keys.toSet(), {
        'A',
        'A/one.txt',
        'A/B',
        'A/B/two.txt',
        'A/Empty',
        'C',
        'C/three.txt',
        'top.txt',
      });
      expect(found['A']!.isDir, isTrue);
      expect(found['top.txt']!.size, 'top.txt'.length);
      expect(found['top.txt']!.mtimeMs, greaterThan(0));
    });

    test('limits itself to the given folders and files', () async {
      final found = await scanLocal(
        root: root.path,
        dirs: ['A/B', 'Missing'],
        files: ['top.txt', 'absent.txt'],
      );
      expect(found.keys.toSet(), {'A/B', 'A/B/two.txt', 'top.txt'});
    });

    test('does not walk a nested scope twice', () async {
      final found = await scanLocal(
        root: root.path,
        dirs: ['A', 'A/B'],
        files: [],
      );
      expect(found.keys.where((k) => k == 'A/B/two.txt'), hasLength(1));
      expect(found.containsKey('C'), isFalse);
    });

    test('skips symlinks', () async {
      Link(p.join(root.path, 'link')).createSync(p.join(root.path, 'C'));
      final found = await scanLocal(root: root.path, dirs: [''], files: []);
      expect(found.containsKey('link'), isFalse);
      expect(found.containsKey('link/three.txt'), isFalse);
    });
  });
}
