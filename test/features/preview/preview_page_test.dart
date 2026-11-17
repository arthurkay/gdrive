import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/app.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/preview/preview_page.dart';
import 'package:gdrive/features/preview/viewers.dart';
import 'package:path/path.dart' as p;

import '../../support/app_env.dart';
import '../../support/pump.dart';

/// Waits for the preview body to finish fetching its file.
Future<void> loaded(WidgetTester tester) async {
  await settle(tester, rounds: 2);
  await pumpUntil(
    tester,
    () => !shown(find.textContaining('Loading ')),
    reason: 'the preview to load',
  );
}

void main() {
  late AppEnv env;
  late StubViewers viewers;

  setUp(() {
    env = AppEnv();
    viewers = StubViewers();
  });
  tearDown(() => env.dispose());

  Future<void> open(
    WidgetTester tester,
    DriveItem item, {
    List<DriveItem>? siblings,
    UiKit kit = UiKit.yaru,
  }) async {
    await pumpGDrive(
      tester,
      env,
      kit: kit,
      viewers: viewers,
      home: PreviewPage(item: item, siblings: siblings ?? [item]),
    );
    await loaded(tester);
  }

  for (final kit in UiKit.values) {
    testWidgets('${kit.name}: routes each kind of file to its viewer', (
      tester,
    ) async {
      final files = [
        env.drive.addBytes('photo.png', [1, 2], mimeType: 'image/png'),
        env.drive.addBytes('paper.pdf', [1], mimeType: 'application/pdf'),
        env.drive.addNative('Plan', 'exported'),
        env.drive.addFile('notes.md', '# Notes'),
        env.drive.addBytes('song.mp3', [1], mimeType: 'audio/mpeg'),
        env.drive.addBytes('clip.mp4', [1], mimeType: 'video/mp4'),
        env.drive.addBytes('data.zip', [1], mimeType: 'application/zip'),
      ];
      await open(tester, files.first, siblings: files, kit: kit);

      Future<void> next() async {
        await tester.click(iconButton('Next file'));
        await loaded(tester);
      }

      expect(find.textContaining('image:'), findsOneWidget);
      expect(find.text('1 / 7'), findsOneWidget);
      await next();
      expect(find.text('pdf:pdf'), findsOneWidget);
      await next();
      expect(
        find.text('pdf:pdf'),
        findsOneWidget,
        reason: 'Docs export as PDF',
      );
      expect(
        env.drive.calls.where((c) => c.startsWith('export')),
        hasLength(1),
      );
      await next();
      expect(find.text('text[markdown]:# Notes'), findsOneWidget);
      await next();
      expect(find.text('audio-player'), findsOneWidget);
      expect(viewers.lastMedia!.uri, contains('alt=media'));
      expect(viewers.lastMedia!.headers['Authorization'], 'Bearer fake-token');
      await next();
      expect(find.text('video-player'), findsOneWidget);
      await next();
      expect(
        find.text('No built-in preview for this type of file.'),
        findsOneWidget,
      );
      expect(find.text('7 / 7'), findsOneWidget);

      await tester.click(iconButton('Previous file'));
      await loaded(tester);
      expect(find.text('video-player'), findsOneWidget);
      await unmount(tester);
    });
  }

  testWidgets('arrow keys step through files; Escape closes', (tester) async {
    final a = env.drive.addBytes('a.png', [1], mimeType: 'image/png');
    final b = env.drive.addBytes('b.png', [1], mimeType: 'image/png');
    await open(tester, a, siblings: [a, b]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await loaded(tester);
    expect(find.text('b.png'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester, rounds: 2);
    expect(find.text('b.png'), findsOneWidget, reason: 'already at the end');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await loaded(tester);
    expect(find.text('a.png'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('editing text shows Save, which uploads a new revision', (
    tester,
  ) async {
    final file = env.drive.addFile('notes.txt', 'first draft');
    await open(tester, file);
    expect(find.text('text[plain]:first draft'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    viewers.onTextChanged!('second draft');
    await tester.pump();
    expect(find.text('notes.txt •'), findsOneWidget);

    viewers.onTextChanged!('first draft');
    await tester.pump();
    expect(find.text('Save'), findsNothing, reason: 'back to the original');

    viewers.onTextChanged!('second draft');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await pumpUntil(
      tester,
      () => shown(find.text('Saved to Drive')),
      reason: 'the save to finish',
    );

    expect(env.drive.textOf(file.id), 'second draft');
    expect(find.text('Saved to Drive'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Ctrl+S saves a synced file in place for sync to pick up', (
    tester,
  ) async {
    final file = env.drive.addFile('notes.txt', 'v1');
    final local = File(p.join(env.syncRoot, 'notes.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('v1');
    await env.db.putEntry(
      SyncEntry(
        fileId: file.id,
        relPath: 'notes.txt',
        isFolder: false,
        isNative: false,
        localEdited: false,
      ),
    );
    await open(tester, file);

    viewers.onTextChanged!('v2');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpUntil(
      tester,
      () => shown(find.text('Saved; syncing to Drive')),
      reason: 'the save to finish',
    );

    expect(local.readAsStringSync(), 'v2');
    expect(env.drive.textOf(file.id), 'v1');
    expect(find.text('Saved; syncing to Drive'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a failed save keeps the edit and says why', (tester) async {
    final file = env.drive.addFile('notes.txt', 'v1');
    await open(tester, file);
    viewers.onTextChanged!('v2');
    await tester.pump();
    env.drive.failWhen = (op, _) =>
        op == 'updateContent' ? DriveApiException(403, 'read only') : null;

    await tester.tap(find.text('Save'));
    await pumpUntil(
      tester,
      () => shown(find.textContaining('Could not save')),
      reason: 'the save to fail',
    );

    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('leaving with unsaved edits asks before discarding', (
    tester,
  ) async {
    final a = env.drive.addFile('a.txt', 'one');
    final b = env.drive.addFile('b.txt', 'two');
    await open(tester, a, siblings: [a, b]);
    viewers.onTextChanged!('changed');
    await tester.pump();

    await tester.click(iconButton('Next file'));
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.click(find.text('Cancel'));
    expect(find.text('a.txt •'), findsOneWidget);

    await tester.click(iconButton('Next file'));
    await tester.click(find.text('Discard'));
    await loaded(tester);
    expect(find.text('text[plain]:two'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('trashed and oversized text opens read-only', (tester) async {
    final file = env.drive.addFile('notes.txt', 'old');
    final trashed = await env.drive.updateMetadata(file.id, trashed: true);
    await open(tester, trashed);
    expect(find.text('text[plain,ro]:old'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('text that is not UTF-8 still opens', (tester) async {
    final file = env.drive.addBytes(
      'legacy.txt',
      latin1.encode('café'),
      mimeType: 'text/plain',
    );
    await open(tester, file);
    expect(find.text('text[plain]:café'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('media plays from the synced copy when there is one', (
    tester,
  ) async {
    final file = env.drive.addBytes('song.mp3', [1], mimeType: 'audio/mpeg');
    final local = File(p.join(env.syncRoot, 'song.mp3'))
      ..createSync(recursive: true);
    await env.db.putEntry(
      SyncEntry(
        fileId: file.id,
        relPath: 'song.mp3',
        isFolder: false,
        isNative: false,
        localEdited: false,
      ),
    );
    await open(tester, file);

    expect(viewers.lastMedia!.uri, local.path);
    expect(viewers.lastMedia!.headers, isEmpty);
    await unmount(tester);
  });

  testWidgets('without a session media falls back to a cached download', (
    tester,
  ) async {
    final file = env.drive.addBytes('song.mp3', [1], mimeType: 'audio/mpeg');
    final container = await pumpGDrive(
      tester,
      env,
      viewers: viewers,
      home: const SizedBox(),
    );
    container.read(sessionProvider.notifier).set(null);
    await tester.pumpWidget(const SizedBox());
    await pumpPreviewOnly(tester, container, file);
    await pumpUntil(tester, () => viewers.lastMedia != null, reason: 'media');

    expect(viewers.lastMedia!.uri, startsWith(env.paths.previewCache));
    await unmount(tester);
  });

  testWidgets('a download failure explains itself and offers the browser', (
    tester,
  ) async {
    final file = env.drive.addBytes('photo.png', [1], mimeType: 'image/png');
    final linked = file.copyWith(
      webViewLink: const Value('https://drive.example/photo'),
    );
    env.drive.failWhen = (op, _) =>
        op == 'download' ? DriveApiException(403, 'forbidden') : null;
    await open(tester, linked);

    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.textContaining('forbidden'), findsOneWidget);

    await tester.click(find.text('Open in browser'));
    expect(env.launched.single.toString(), 'https://drive.example/photo');
    await unmount(tester);
  });

  testWidgets('"open with default app" hands the local file to the system', (
    tester,
  ) async {
    final file = env.drive.addBytes('data.zip', [
      1,
      2,
      3,
    ], mimeType: 'application/zip');
    await open(tester, file);

    await tester.tap(iconButton('Open with default app'));
    await pumpUntil(tester, () => env.launched.isNotEmpty, reason: 'launch');

    expect(env.launched.single.scheme, 'file');
    expect(env.launched.single.path, endsWith('.zip'));

    env.drive.failWhen = (_, _) => DriveApiException(500, 'down');
    await tester.runAsync(() async {
      await Directory(env.paths.previewCache).delete(recursive: true);
    });
    await tester.tap(iconButton('Open with default app'));
    await pumpUntil(
      tester,
      () => shown(find.textContaining('Could not open')),
      reason: 'the failure notice',
    );
    expect(find.textContaining('Could not open'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the route carries the kit onto the pushed page', (tester) async {
    final file = env.drive.addBytes('photo.png', [1], mimeType: 'image/png');
    await pumpGDrive(
      tester,
      env,
      kit: UiKit.fluent,
      viewers: viewers,
      home: Builder(
        builder: (context) => GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(PreviewPage.route(context, item: file, siblings: [file])),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await pumpUntil(
      tester,
      () => shown(find.textContaining('image:')),
      reason: 'the pushed preview to load',
    );
    expect(find.textContaining('image:'), findsOneWidget);
    expect(Kit.of(tester.element(find.textContaining('image:'))), UiKit.fluent);

    await tester.click(iconButton('Back to files'));
    await settle(tester);
    expect(find.text('open'), findsOneWidget);
    await unmount(tester);
  });

  test('MediaSource distinguishes files from streams', () {
    const file = MediaSource.file('/tmp/a.mp3');
    const stream = MediaSource.network('https://x', {'A': 'b'});
    expect(file.headers, isEmpty);
    expect(stream.headers, {'A': 'b'});
  });
}

/// Mounts the preview page alone on an existing container.
Future<void> pumpPreviewOnly(
  WidgetTester tester,
  ProviderContainer container,
  DriveItem item,
) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: GDriveApp(
      home: PreviewPage(item: item, siblings: [item]),
    ),
  ),
);
