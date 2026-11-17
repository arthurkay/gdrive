import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/ui/adaptive/controls.dart';
import 'package:gdrive/features/drive/browser_controller.dart';
import 'package:gdrive/features/preview/preview_page.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/shell/destinations.dart';
import 'package:path/path.dart' as p;

import '../../support/app_env.dart';
import '../../support/pump.dart';

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await settle(tester);
  }

  testWidgets('dropping files from the desktop uploads them', (tester) async {
    final dropped = File(p.join(env.temp.path, 'dropped.txt'))
      ..writeAsStringSync('from the desktop');
    await pumpGDrive(tester, env);
    final target = tester.widget<DropTarget>(find.byType(DropTarget));
    const position = Offset(400, 400);

    target.onDragEntered!(
      DropEventDetails(localPosition: position, globalPosition: position),
    );
    await tester.pump();
    target.onDragExited!(
      DropEventDetails(localPosition: position, globalPosition: position),
    );
    await tester.pump();
    target.onDragDone!(
      DropDoneDetails(
        files: [DropItemFile(dropped.path)],
        localPosition: position,
        globalPosition: position,
      ),
    );
    await pumpUntil(
      tester,
      () => shown(find.text('dropped.txt')),
      reason: 'the dropped file to upload',
    );

    final uploaded = env.drive.find('dropped.txt')!;
    expect(env.drive.textOf(uploaded.id), 'from the desktop');
    expect(find.text('dropped.txt'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dropping where there is no folder explains instead', (
    tester,
  ) async {
    final dropped = File(p.join(env.temp.path, 'dropped.txt'))
      ..writeAsStringSync('x');
    final container = await pumpGDrive(tester, env);
    container.read(navProvider.notifier).go(Destination.starred);
    await settle(tester);

    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [DropItemFile(dropped.path)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await settle(tester);

    expect(find.textContaining('Open a folder in My Drive'), findsOneWidget);
    expect(env.drive.find('dropped.txt'), isNull);
    await unmount(tester);
  });

  testWidgets('uploading a folder recreates it on Drive', (tester) async {
    File(p.join(env.temp.path, 'Album', 'one.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('1');
    env.picker.directory = p.join(env.temp.path, 'Album');
    await pumpGDrive(tester, env);

    await tester.tap(iconButton('Upload a folder'));
    await pumpUntil(
      tester,
      () => env.drive.items.any((e) => e.name == 'one.txt'),
      reason: 'the folder to upload',
    );

    final album = env.drive.find('Album')!;
    expect(env.drive.find('one.txt', parentId: album.id), isNotNull);
    await unmount(tester);
  });

  testWidgets('a cancelled picker uploads nothing', (tester) async {
    await pumpGDrive(tester, env);
    await tester.click(find.text('Upload'));
    await tester.click(iconButton('Upload a folder'));
    expect(env.drive.calls.where((c) => c.startsWith('upload')), isEmpty);
    await unmount(tester);
  });

  testWidgets('shortcuts: find, upload, refresh and quick look', (
    tester,
  ) async {
    final file = env.drive.addFile('notes.txt', 'hello');
    File(p.join(env.temp.path, 'picked.txt')).writeAsStringSync('x');
    env.picker.files = [p.join(env.temp.path, 'picked.txt')];
    await pumpGDrive(tester, env);

    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      await tester.click(find.text('notes.txt'));
      await chord(tester, modifier, LogicalKeyboardKey.keyF);
      final search = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(search.focusNode.hasFocus, isTrue);
    }

    await tester.click(find.text('notes.txt'));
    await chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyU,
    );
    await pumpUntil(
      tester,
      () => shown(find.text('picked.txt')),
      reason: 'the picked file to upload',
    );
    expect(env.drive.find('picked.txt'), isNotNull);

    await tester.click(find.text('notes.txt'));
    await chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyA);
    expect(find.text('2 selected'), findsOneWidget);

    final before = env.drive.calls.where((c) => c.startsWith('list')).length;
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await settle(tester);
    expect(
      env.drive.calls.where((c) => c.startsWith('list')).length,
      greaterThan(before),
    );

    await tester.click(find.text('notes.txt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await pumpUntil(
      tester,
      () => shown(find.text('text[plain]:hello')),
      reason: 'the preview to load',
    );
    expect(find.byType(PreviewPage), findsOneWidget);
    expect(find.text('text[plain]:hello'), findsOneWidget);
    expect(env.drive.byId(file.id), isNotNull);
    await unmount(tester);
  });

  testWidgets('Preview in the context menu opens the viewer', (tester) async {
    env.drive.addFolder('Documents');
    env.drive.addFile('notes.txt', 'hello');
    await pumpGDrive(tester, env);

    await tester.rightClick(find.text('Documents'));
    expect(find.text('Open'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester, rounds: 2);

    await tester.rightClick(find.text('notes.txt'));
    await tester.click(find.text('Preview'));
    await pumpUntil(
      tester,
      () => shown(find.text('text[plain]:hello')),
      reason: 'the preview to load',
    );
    expect(find.byType(PreviewPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('trash toolbar restores and deletes; F2 does nothing there', (
    tester,
  ) async {
    final a = env.drive.addFile('a.txt', 'x');
    final b = env.drive.addFile('b.txt', 'x');
    final folder = env.drive.addFolder('Old');
    for (final item in [a, b, folder]) {
      await env.drive.updateMetadata(item.id, trashed: true);
    }
    final container = await pumpGDrive(tester, env);
    container.read(navProvider.notifier).go(Destination.trash);
    await settle(tester);

    await tester.doubleTap(find.text('Old'));
    expect(container.read(browserProvider).path, isEmpty);

    await tester.click(find.text('a.txt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await settle(tester, rounds: 2);
    expect(find.text('Rename'), findsNothing);
    await tester.click(iconButton('Restore'));
    expect(env.drive.byId(a.id)!.trashed, isFalse);

    await tester.click(find.text('b.txt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester, rounds: 2);
    await tester.click(find.text('Cancel'));
    expect(env.drive.byId(b.id), isNotNull);
    await tester.click(iconButton('Delete forever'));
    await tester.click(find.text('Delete forever').last);
    expect(env.drive.byId(b.id), isNull);
    await unmount(tester);
  });

  testWidgets('grid: thumbnails fall back to icons; menu and open work', (
    tester,
  ) async {
    env.settings = env.settings.copyWith(gridView: true);
    final docs = env.drive.addFolder('Documents');
    final photo = env.drive.addBytes('photo.png', [1], mimeType: 'image/png');
    await env.db.upsertItems([
      photo.copyWith(thumbnailLink: const Value('https://thumbs.example/p')),
    ]);
    env.drive.failWhen = (op, arg) => null;
    final container = await pumpGDrive(tester, env);
    // The cached row keeps its thumbnail link only until the next refresh.
    await env.db.upsertItems([
      photo.copyWith(thumbnailLink: const Value('https://thumbs.example/p')),
    ]);
    final thumbnail = find.byWidgetPredicate(
      (w) => w is Image && w.image is NetworkImage,
    );
    await pumpUntil(
      tester,
      () => shown(thumbnail),
      reason: 'the thumbnail to be requested',
    );

    expect(thumbnail, findsOneWidget);
    expect(
      (tester.widget<Image>(thumbnail).image as NetworkImage).url,
      'https://thumbs.example/p',
    );
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);

    await tester.rightClick(find.text('photo.png'));
    expect(find.text('Preview'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester, rounds: 2);

    await tester.doubleTap(find.text('Documents'));
    expect(container.read(browserProvider).path.single.id, docs.id);
    await unmount(tester);
  });

  testWidgets('breadcrumbs jump back several levels', (tester) async {
    final a = env.drive.addFolder('A');
    final b = env.drive.addFolder('B', parentId: a.id);
    env.drive.addFolder('C', parentId: b.id);
    final container = await pumpGDrive(tester, env);
    await tester.doubleTap(find.text('A'));
    await tester.doubleTap(find.text('B'));
    await tester.doubleTap(find.text('C'));
    expect(container.read(browserProvider).path, hasLength(3));

    await tester.click(find.text('A'));
    expect(container.read(browserProvider).path, hasLength(1));
    await tester.click(find.text('My Drive').last);
    expect(container.read(browserProvider).path, isEmpty);
    await unmount(tester);
  });

  testWidgets('multi-select actions report how many items they touched', (
    tester,
  ) async {
    env.drive.addFile('a.txt', 'x');
    env.drive.addFile('b.txt', 'x');
    env.drive.addFolder('Folder');
    final container = await pumpGDrive(tester, env);
    container
        .read(browserProvider.notifier)
        .selectAll(env.drive.items.map((e) => e.id));
    await tester.pump();

    await tester.rightClick(find.text('a.txt'));
    expect(find.text('Rename…'), findsNothing, reason: 'single items only');
    await tester.click(
      find.text('Remove star').evaluate().isEmpty
          ? find.text('Add star')
          : find.text('Remove star'),
    );
    expect(env.drive.items.every((e) => e.starred), isTrue);

    container
        .read(browserProvider.notifier)
        .selectAll(env.drive.items.map((e) => e.id));
    await tester.pump();
    await tester.rightClick(find.text('a.txt'));
    await tester.click(find.text('Remove star'));
    expect(env.drive.items.any((e) => e.starred), isFalse);

    container
        .read(browserProvider.notifier)
        .selectAll(env.drive.items.map((e) => e.id));
    await tester.pump();
    await tester.click(iconButton('Move to Trash'));
    expect(find.text('Moved 3 items to Trash'), findsOneWidget);
    expect(find.byType(AppBanner), findsNothing);
    await unmount(tester);
  });

  testWidgets('settings page grid preference is honoured on launch', (
    tester,
  ) async {
    env.settings = env.settings.copyWith(gridView: true);
    env.drive.addFile('a.txt', 'x');
    final container = await pumpGDrive(tester, env);
    expect(container.read(settingsProvider).gridView, isTrue);
    expect(find.text('Modified'), findsNothing);
    await unmount(tester);
  });
}
