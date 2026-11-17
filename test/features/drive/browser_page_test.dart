import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/drive/browser_controller.dart';
import 'package:gdrive/features/drive/browser_page.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/features/sync/sync_controller.dart';
import 'package:gdrive/shell/destinations.dart';
import 'package:path/path.dart' as p;

import '../../support/app_env.dart';
import '../../support/pump.dart';

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText).last, text);
    await tester.pump();
  }

  for (final kit in UiKit.values) {
    group('${kit.name} kit', () {
      testWidgets('lists a folder, opens subfolders and walks back', (
        tester,
      ) async {
        final docs = env.drive.addFolder('Documents');
        env.drive.addFile('inside.txt', 'x', parentId: docs.id);
        env.drive.addFile('top.txt', 'hello');
        await pumpGDrive(tester, env, kit: kit);
        expect(find.text('top.txt'), findsOneWidget);
        expect(find.text('5 B'), findsOneWidget);

        await tester.doubleTap(find.text('Documents'));
        expect(find.text('inside.txt'), findsOneWidget);
        expect(find.text('top.txt'), findsNothing);

        await tester.click(iconButton('Up one level'));
        expect(find.text('top.txt'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('context menu renames, stars and trashes', (tester) async {
        final file = env.drive.addFile('draft.txt', 'x');
        await pumpGDrive(tester, env, kit: kit);

        await tester.rightClick(find.text('draft.txt'));
        expect(find.text('Sync to this computer'), findsOneWidget);
        await tester.click(find.text('Rename…'));
        await type(tester, 'final.txt');
        await tester.click(find.text('Rename').last);
        expect(env.drive.byId(file.id)!.name, 'final.txt');
        expect(find.text('final.txt'), findsOneWidget);

        await tester.rightClick(find.text('final.txt'));
        await tester.click(find.text('Add star'));
        expect(env.drive.byId(file.id)!.starred, isTrue);

        await tester.rightClick(find.text('final.txt'));
        await tester.click(find.text('Move to Trash'));
        expect(env.drive.byId(file.id)!.trashed, isTrue);
        expect(find.text('final.txt'), findsNothing);
        expect(find.textContaining('to Trash'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('creates a folder and uploads picked files', (tester) async {
        final upload = File(p.join(env.temp.path, 'photo.png'))
          ..writeAsStringSync('png');
        env.picker.files = [upload.path];
        await pumpGDrive(tester, env, kit: kit);

        await tester.click(iconButton('New folder'));
        await type(tester, 'Projects');
        await tester.click(find.text('Create'));
        expect(env.drive.find('Projects'), isNotNull);
        expect(find.text('Projects'), findsOneWidget);

        await tester.click(find.text('Upload'));
        await pumpUntil(
          tester,
          () => shown(find.text('photo.png')),
          reason: 'the upload to finish',
        );
        expect(env.drive.find('photo.png'), isNotNull);
        expect(find.text('photo.png'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('trash can restore, delete forever and be emptied', (
        tester,
      ) async {
        final a = env.drive.addFile('a.txt', 'x');
        final b = env.drive.addFile('b.txt', 'x');
        final c = env.drive.addFile('c.txt', 'x');
        for (final item in [a, b, c]) {
          await env.drive.updateMetadata(item.id, trashed: true);
        }
        final container = await pumpGDrive(tester, env, kit: kit);
        container.read(navProvider.notifier).go(Destination.trash);
        await settle(tester);

        await tester.rightClick(find.text('a.txt'));
        await tester.click(find.text('Restore'));
        expect(env.drive.byId(a.id)!.trashed, isFalse);

        await tester.rightClick(find.text('b.txt'));
        await tester.click(find.text('Delete forever'));
        expect(find.textContaining('cannot be undone'), findsOneWidget);
        await tester.click(find.text('Delete forever').last);
        expect(env.drive.byId(b.id), isNull);

        await tester.click(find.text('Empty Trash'));
        await tester.click(find.text('Empty Trash').last);
        expect(env.drive.byId(c.id), isNull);
        expect(find.text('Trash is empty'), findsOneWidget);
        await unmount(tester);
      });
    });
  }

  testWidgets('search shows matches and clearing returns to the folder', (
    tester,
  ) async {
    env.drive.addFile('Annual report.txt', 'x');
    env.drive.addFile('notes.txt', 'x');
    await pumpGDrive(tester, env);

    await tester.enterText(find.byType(EditableText).first, 'report');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Results for "report"'), findsOneWidget);
    expect(find.text('notes.txt'), findsNothing);
    expect(find.text('Annual report.txt'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '');
    await settle(tester);
    expect(find.text('notes.txt'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('search with no matches says so', (tester) async {
    final container = await pumpGDrive(tester, env);
    container.read(browserProvider.notifier).setSearch('zzz');
    await settle(tester);
    expect(find.text('No results'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('selection follows click, ctrl-click, shift-click and ctrl-A', (
    tester,
  ) async {
    for (final name in ['a.txt', 'b.txt', 'c.txt', 'd.txt']) {
      env.drive.addFile(name, 'x', id: name);
    }
    final container = await pumpGDrive(tester, env);
    Set<String> selected() => container.read(browserProvider).selected;

    await tester.click(find.text('a.txt'));
    expect(selected(), {'a.txt'});
    expect(find.text('1 selected'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.click(find.text('c.txt'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(selected(), {'a.txt', 'c.txt'});

    await tester.click(find.text('b.txt'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.click(find.text('d.txt'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(selected(), {'b.txt', 'c.txt', 'd.txt'});

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.click(find.text('a.txt'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(selected(), {'a.txt', 'b.txt'});

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(selected(), hasLength(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(selected(), isEmpty);
    await unmount(tester);
  });

  testWidgets('keyboard: Delete trashes, F2 renames, Enter opens', (
    tester,
  ) async {
    final docs = env.drive.addFolder('Documents');
    final file = env.drive.addFile('old.txt', 'x');
    await pumpGDrive(tester, env);

    await tester.click(find.text('old.txt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await settle(tester, rounds: 2);
    await type(tester, 'new.txt');
    await tester.click(find.text('Rename').last);
    expect(env.drive.byId(file.id)!.name, 'new.txt');

    await tester.click(find.text('new.txt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(env.drive.byId(file.id)!.trashed, isTrue);

    await tester.click(find.text('Documents'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('This folder is empty'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await settle(tester);
    expect(find.text('Documents'), findsWidgets);
    expect(env.drive.byId(docs.id)!.trashed, isFalse);
    await unmount(tester);
  });

  testWidgets('toolbar acts on the selection', (tester) async {
    final file = env.drive.addFile('a.txt', 'alpha');
    env.picker.directory = p.join(env.temp.path, 'downloads');
    Directory(env.picker.directory!).createSync();
    await pumpGDrive(tester, env);
    await tester.click(find.text('a.txt'));

    await tester.click(iconButton('Download'));
    await pumpUntil(
      tester,
      () => shown(find.text('Download complete')),
      reason: 'the download to finish',
    );
    expect(
      File(p.join(env.picker.directory!, 'a.txt')).readAsStringSync(),
      'alpha',
    );

    await tester.click(iconButton('More actions'));
    await tester.click(find.text('Make a copy'));
    expect(env.drive.find('Copy of a.txt'), isNotNull);

    await tester.click(find.text('a.txt'));
    await tester.click(iconButton('Move to Trash'));
    expect(env.drive.byId(file.id)!.trashed, isTrue);
    await unmount(tester);
  });

  testWidgets('move picks a destination folder', (tester) async {
    final target = env.drive.addFolder('Archive');
    final inner = env.drive.addFolder('2026', parentId: target.id);
    final file = env.drive.addFile('a.txt', 'x');
    await pumpGDrive(tester, env);

    await tester.rightClick(find.text('a.txt'));
    await tester.click(find.text('Move…'));
    await settle(tester);
    await tester.click(find.text('Archive').last);
    await settle(tester);
    await tester.click(find.text('2026'));
    await settle(tester);
    expect(find.text('No folders here'), findsOneWidget);
    await tester.click(iconButton('Up one level').last);
    await settle(tester);
    await tester.click(find.text('Move here'));

    expect(env.drive.byId(file.id)!.parentId, target.id);
    expect(env.drive.byId(inner.id)!.parentId, target.id);
    await unmount(tester);
  });

  testWidgets('details and open-in-browser', (tester) async {
    final file = env.drive.addFile('a.txt', 'alpha');
    await env.drive.updateMetadata(file.id, starred: true);
    await pumpGDrive(tester, env);

    await tester.rightClick(find.text('a.txt'));
    await tester.click(find.text('Details'));
    expect(find.text('text/plain'), findsOneWidget);
    expect(find.text('Owned by me'), findsOneWidget);
    await tester.click(find.text('Close'));

    await tester.rightClick(find.text('a.txt'));
    await tester.click(find.text('Open in browser'));
    expect(find.text('No web link for this item'), findsOneWidget);
    expect(env.launched, isEmpty);

    await env.db.upsertItems([
      env.drive
          .byId(file.id)!
          .copyWith(webViewLink: const Value('https://drive.example/a')),
    ]);
    await settle(tester);
    await tester.rightClick(find.text('a.txt'));
    await tester.click(find.text('Open in browser'));
    expect(env.launched.single.toString(), 'https://drive.example/a');
    await unmount(tester);
  });

  testWidgets('sync toggles select items and the whole Drive', (tester) async {
    final docs = env.drive.addFolder('Documents');
    env.drive.addFile('inside.txt', 'x', parentId: docs.id);
    final container = await pumpGDrive(tester, env);
    Future<List<String>> selections() => env.db.selections();

    await tester.rightClick(find.text('Documents'));
    await tester.click(find.text('Sync to this computer'));
    expect(await tester.runAsync(selections), [docs.id]);
    expect(labelledIcon('Waiting to sync'), findsOneWidget);

    await tester.doubleTap(find.text('Documents'));
    await tester.rightClick(find.text('inside.txt'));
    expect(find.text('Synced with its folder'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester, rounds: 2);
    container.read(browserProvider.notifier).goUp();
    await settle(tester);

    await tester.rightClick(find.text('Documents'));
    await tester.click(find.text('Stop syncing'));
    expect(await tester.runAsync(selections), isEmpty);

    await tester.click(find.text('Sync all of My Drive'));
    expect(await tester.runAsync(selections), [FakeDriveApi.rootId]);
    await tester.click(find.text('Stop syncing all'));
    expect(await tester.runAsync(selections), isEmpty);
    await unmount(tester);
  });

  testWidgets('synced and locally edited items show their badge', (
    tester,
  ) async {
    final a = env.drive.addFile('a.txt', 'x');
    final b = env.drive.addFile('b.txt', 'x');
    env.drive.addFile('c.txt', 'x');
    SyncEntry entry(DriveItem item, {bool edited = false}) => SyncEntry(
      fileId: item.id,
      relPath: item.name,
      isFolder: false,
      isNative: false,
      localEdited: edited,
    );
    await env.db.putEntry(entry(a));
    await env.db.putEntry(entry(b, edited: true));
    await pumpGDrive(tester, env);

    expect(labelledIcon('Synced'), findsOneWidget);
    expect(labelledIcon('Local edits not uploaded'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('grid view shows the same items and persists', (tester) async {
    env.drive.addFolder('Documents');
    env.drive.addFile('a.txt', 'x');
    final container = await pumpGDrive(tester, env);

    await tester.click(iconButton('Thumbnail view'));
    expect(container.read(settingsProvider).gridView, isTrue);
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('Modified'), findsNothing);

    await tester.click(find.text('a.txt'));
    expect(container.read(browserProvider).selected, hasLength(1));
    await tester.click(iconButton('List view'));
    expect(find.text('Modified'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('column headers sort', (tester) async {
    env.drive.addFile('small.txt', 'x');
    env.drive.addFile('big.txt', 'xxxxxxxxxx');
    final container = await pumpGDrive(tester, env);

    await tester.click(find.text('Size'));
    expect(container.read(browserProvider).sort, SortField.size);
    expect(
      tester.getTopLeft(find.text('small.txt')).dy,
      lessThan(tester.getTopLeft(find.text('big.txt')).dy),
    );
    await tester.click(find.text('Size'));
    expect(
      tester.getTopLeft(find.text('big.txt')).dy,
      lessThan(tester.getTopLeft(find.text('small.txt')).dy),
    );
    await tester.click(find.text('Modified'));
    await tester.click(find.text('Name'));
    expect(container.read(browserProvider).sort, SortField.name);
    await unmount(tester);
  });

  testWidgets('a failed refresh offers a retry', (tester) async {
    env.drive.addFile('a.txt', 'x');
    final container = await pumpGDrive(tester, env);
    env.drive.failWhen = (op, _) =>
        op == 'list' ? DriveApiException(500, 'backend down') : null;

    await tester.click(iconButton('Refresh'));
    expect(find.textContaining('backend down'), findsOneWidget);

    env.drive.failWhen = null;
    await tester.click(find.text('Retry'));
    expect(find.textContaining('backend down'), findsNothing);
    expect(container.read(browserProvider).error, isNull);
    await unmount(tester);
  });

  testWidgets('an action that fails reports the error', (tester) async {
    env.drive.addFile('a.txt', 'x');
    await pumpGDrive(tester, env);
    env.drive.failWhen = (op, _) =>
        op == 'updateMetadata' ? DriveApiException(403, 'read only') : null;

    await tester.rightClick(find.text('a.txt'));
    await tester.click(find.text('Move to Trash'));

    expect(find.textContaining('read only'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('uploading is refused where there is no target folder', (
    tester,
  ) async {
    final container = await pumpGDrive(tester, env);
    container.read(navProvider.notifier).go(Destination.starred);
    await settle(tester);

    final context = tester.element(find.byType(BrowserPage));
    final page = tester.state(find.byType(BrowserPage));
    expect(page.mounted, isTrue);
    expect(context.mounted, isTrue);
    expect(container.read(browserProvider.notifier).targetFolderId, isNull);
    await unmount(tester);
  });

  testWidgets('a pending mass deletion is shown with both choices', (
    tester,
  ) async {
    await env.dispose();
    env = AppEnv(paused: false);
    for (var i = 0; i < 8; i++) {
      env.drive.addFile('f$i.txt', 'content $i');
    }
    final container = await pumpGDrive(tester, env);
    final sync = container.read(syncProvider.notifier);

    /// Sync passes mix real file I/O with work queued on the test's fake
    /// clock, so alternate real time with pumps until [done].
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await settle(tester, rounds: 1);
      }
    }

    bool idle() => container.read(syncProvider).phase == SyncPhase.idle;
    File local(int i) => File(p.join(env.syncRoot, 'f$i.txt'));

    await tester.runAsync(() => sync.setSynced(FakeDriveApi.rootId, true));
    await waitFor(() => local(7).existsSync() && idle());
    for (var i = 0; i < 6; i++) {
      local(i).deleteSync();
    }
    await tester.runAsync(sync.syncNow);
    await settle(tester);

    expect(find.textContaining('about to remove 6 files'), findsOneWidget);
    await tester.tap(find.text('Remove them'));
    await waitFor(
      () => env.drive.items.where((i) => i.trashed).length == 6 && idle(),
    );
    await settle(tester);
    expect(env.drive.items.where((i) => i.trashed), hasLength(6));
    expect(find.textContaining('about to remove'), findsNothing);
    await unmount(tester);
  });

  test('badgeFor reflects sync state', () {
    final item = DriveItem(
      id: 'x',
      name: 'x',
      mimeType: 'text/plain',
      trashed: false,
      starred: false,
      sharedWithMe: false,
    );
    final form = item.copyWith(mimeType: 'application/vnd.google-apps.form');
    SyncBadge badge(
      DriveItem i, {
      Set<String> selections = const {},
      bool parent = false,
    }) => badgeFor(
      i,
      selections: selections,
      entries: const {},
      parentInScope: parent,
    );
    expect(badge(item), SyncBadge.none);
    expect(badge(item, selections: {'x'}), SyncBadge.waiting);
    expect(badge(item, parent: true), SyncBadge.waiting);
    expect(badge(form, parent: true), SyncBadge.none);
  });
}
