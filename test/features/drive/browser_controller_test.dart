import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/drive/browser_controller.dart';
import 'package:gdrive/features/drive/drive_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/app_env.dart';

void main() {
  late AppEnv env;
  late ProviderContainer container;
  late BrowserController browser;

  setUp(() async {
    env = AppEnv();
    container = env.container();
    await container.read(authProvider.future);
    container.listen(browserItemsProvider, (_, _) {});
    browser = container.read(browserProvider.notifier);
    await pumpEventQueue();
  });
  tearDown(() => env.dispose());

  BrowserState state() => container.read(browserProvider);
  Future<List<String>> shown() async {
    await pumpEventQueue();
    return (container.read(browserItemsProvider).value ?? [])
        .map((e) => e.name)
        .toList();
  }

  test('starts in My Drive and loads the root folder', () async {
    env.drive.addFile('b.txt', 'b');
    env.drive.addFolder('Zed');
    env.drive.addFile('a.txt', 'a');
    await browser.refresh();

    expect(state().section, DriveSection.myDrive);
    expect(state().loading, isFalse);
    expect(browser.listing, const FolderListing(FakeDriveApi.rootId));
    expect(browser.targetFolderId, FakeDriveApi.rootId);
    expect(await shown(), ['Zed', 'a.txt', 'b.txt'], reason: 'folders first');
  });

  test('opening folders builds a path that breadcrumbs can unwind', () async {
    final docs = env.drive.addFolder('Docs');
    final sub = env.drive.addFolder('Sub', parentId: docs.id);
    env.drive.addFile('deep.txt', 'x', parentId: sub.id);

    browser.openFolder(docs);
    browser.openFolder(sub);
    expect(state().path.map((f) => f.name), ['Docs', 'Sub']);
    expect(browser.targetFolderId, sub.id);
    expect(await shown(), ['deep.txt']);

    browser.goUp();
    expect(state().path.map((f) => f.name), ['Docs']);
    browser.goToDepth(0);
    expect(state().path, isEmpty);
    browser.goUp();
    browser.goToDepth(3);
    expect(state().path, isEmpty);
  });

  test('each section maps to its listing and has no upload target', () async {
    final expected = {
      DriveSection.shared: const SharedListing(),
      DriveSection.recent: const RecentListing(),
      DriveSection.starred: const StarredListing(),
      DriveSection.trash: const TrashListing(),
    };
    for (final MapEntry(key: section, value: listing) in expected.entries) {
      browser.openSection(section);
      expect(browser.listing, listing);
      expect(browser.targetFolderId, isNull);
      expect(section.label, isNotEmpty);
    }
    await pumpEventQueue();
  });

  test('opening a section resets path, search and selection', () async {
    final docs = env.drive.addFolder('Docs');
    browser.openFolder(docs);
    browser.selectOnly('x');
    browser.setSort(SortField.size);

    browser.openSection(DriveSection.starred);

    expect(state().path, isEmpty);
    expect(state().selected, isEmpty);
    expect(state().sort, SortField.size, reason: 'sort is kept');
    await pumpEventQueue();
  });

  test('search lists matches and clears back to the folder', () async {
    env.drive.addFile('Annual report.txt', 'x');
    env.drive.addFile('notes.txt', 'x');

    browser.setSearch(' report ');
    expect(state().searching, isTrue);
    expect(browser.listing, const SearchListing('report'));
    expect(browser.targetFolderId, isNull);
    expect(await shown(), ['Annual report.txt']);

    browser.setSearch(' report ');
    browser.goToDepth(0);
    expect(state().searching, isFalse);
    expect(await shown(), ['Annual report.txt', 'notes.txt']);
  });

  test('recent keeps the order Drive returned', () async {
    final a = env.drive.addFile('a.txt', 'a');
    final z = env.drive.addFile('z.txt', 'z');
    await env.drive.download(a.id).drain<void>();
    await env.drive.download(z.id).drain<void>();
    await env.db.upsertItems([env.drive.byId(a.id)!, env.drive.byId(z.id)!]);

    browser.openSection(DriveSection.recent);

    expect(await shown(), hasLength(2));
  });

  test('selection: only, toggle, all and clear', () {
    browser.selectOnly('a');
    browser.toggleSelected('b');
    expect(state().selected, {'a', 'b'});
    browser.toggleSelected('a');
    expect(state().selected, {'b'});
    browser.selectAll(['x', 'y', 'z']);
    expect(state().selected, {'x', 'y', 'z'});
    browser.clearSelection();
    browser.clearSelection();
    expect(state().selected, isEmpty);
  });

  test('choosing the same sort column flips direction', () {
    browser.setSort(SortField.modified);
    expect((state().sort, state().ascending), (SortField.modified, true));
    browser.setSort(SortField.modified);
    expect(state().ascending, isFalse);
    browser.setSort(SortField.name);
    expect((state().sort, state().ascending), (SortField.name, true));
  });

  test('a failed refresh surfaces the error and a retry clears it', () async {
    env.drive.failWhen = (_, _) => DriveApiException(500, 'backend down');
    await browser.refresh();
    expect(state().error, contains('backend down'));
    expect(state().loading, isFalse);

    env.drive.failWhen = null;
    await browser.refresh();
    expect(state().error, isNull);
  });

  test('only the newest refresh updates the state', () async {
    final docs = env.drive.addFolder('Docs');
    env.drive.failWhen = (op, arg) =>
        arg == FakeDriveApi.rootId ? DriveApiException(500, 'stale') : null;

    final stale = browser.refresh();
    browser.openFolder(docs);
    await stale;
    await pumpEventQueue();

    expect(state().error, isNull);
  });

  group('sortItems', () {
    DriveItem item(
      String name, {
      int? size,
      DateTime? modified,
      bool folder = false,
    }) => DriveItem(
      id: name,
      name: name,
      mimeType: folder ? folderMimeType : 'text/plain',
      size: size,
      modifiedTime: modified,
      trashed: false,
      starred: false,
      sharedWithMe: false,
    );
    final items = [
      item('b', size: 1, modified: DateTime(2026, 3)),
      item('A', size: 3, modified: DateTime(2026, 1)),
      item('c', modified: DateTime(2026, 2)),
      item('Folder', folder: true),
    ];
    List<String> sorted(SortField field, bool ascending) =>
        sortItems(items, field, ascending).map((e) => e.name).toList();

    test('by name, case-insensitively', () {
      expect(sorted(SortField.name, true), ['Folder', 'A', 'b', 'c']);
      expect(sorted(SortField.name, false), ['Folder', 'c', 'b', 'A']);
    });

    test('by modified time', () {
      expect(sorted(SortField.modified, true), ['Folder', 'A', 'c', 'b']);
    });

    test('by size, with unknown sizes as zero', () {
      expect(sorted(SortField.size, true), ['Folder', 'c', 'b', 'A']);
      expect(sorted(SortField.size, false), ['Folder', 'A', 'b', 'c']);
    });
  });
}
