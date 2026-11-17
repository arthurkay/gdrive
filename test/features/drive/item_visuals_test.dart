import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/ui/adaptive/app_style.dart';
import 'package:gdrive/core/ui/app_logo.dart';
import 'package:gdrive/core/util/file_kind.dart';
import 'package:gdrive/features/drive/browser_controller.dart';
import 'package:gdrive/features/drive/item_visuals.dart';
import 'package:gdrive/features/preview/preview_page.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:path/path.dart' as p;

import '../../support/app_env.dart';
import '../../support/pump.dart';

DriveItem item(String name, String mimeType, {int? size}) => DriveItem(
  id: name,
  name: name,
  mimeType: mimeType,
  size: size,
  trashed: false,
  starred: false,
  sharedWithMe: false,
);

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  test('kindLabel names each type in plain words', () {
    expect(kindLabel(item('Docs', folderMimeType)), 'Folder');
    expect(kindLabel(item('a.png', 'image/png')), 'PNG image');
    expect(kindLabel(item('clip.mp4', 'video/mp4')), 'MP4 video');
    expect(kindLabel(item('song.mp3', 'audio/mpeg')), 'MP3 audio');
    expect(kindLabel(item('paper.pdf', 'application/pdf')), 'PDF document');
    expect(kindLabel(item('notes.txt', 'text/plain')), 'TXT text file');
    expect(kindLabel(item('LICENSE', 'text/plain')), 'Text file');
    expect(kindLabel(item('data.zip', 'application/zip')), 'ZIP file');
    expect(kindLabel(item('blob', 'application/octet-stream')), 'File');
    const apps = 'application/vnd.google-apps.';
    expect(kindLabel(item('Plan', '${apps}document')), 'Google Docs');
    expect(kindLabel(item('Budget', '${apps}spreadsheet')), 'Google Sheets');
    expect(kindLabel(item('Deck', '${apps}presentation')), 'Google Slides');
    expect(kindLabel(item('Sketch', '${apps}drawing')), 'Google Drawings');
  });

  test('largerThumbnail asks for a bigger rendition when it can', () {
    expect(
      largerThumbnail('https://lh3.example/abc=s220'),
      'https://lh3.example/abc=s480',
    );
    expect(
      largerThumbnail('https://lh3.example/abc=s220', size: 800),
      'https://lh3.example/abc=s800',
    );
    expect(
      largerThumbnail('https://drive.example/thumb?id=1'),
      'https://drive.example/thumb?id=1',
    );
  });

  test('DetailsPane summarises counts and sizes', () {
    final items = [
      item('A', folderMimeType),
      item('B', folderMimeType),
      item('a.txt', 'text/plain', size: 1024),
      item('b.txt', 'text/plain', size: 1024),
      item('c.txt', 'text/plain'),
    ];
    expect(DetailsPane.describe(items), '2 folders · 3 files');
    expect(DetailsPane.describe(items.take(1)), '1 folder');
    expect(DetailsPane.describe(items.skip(4)), '1 file');
    expect(DetailsPane.describe(const []), '0 files');
    expect(DetailsPane.totalBytes(items), 2048);
  });

  testWidgets('every kind has its own colour in light and dark', (
    tester,
  ) async {
    for (final theme in [ThemePreference.light, ThemePreference.dark]) {
      env.settings = env.settings.copyWith(theme: theme);
      late AppStyle style;
      await pumpGDrive(
        tester,
        env,
        home: Builder(
          builder: (context) {
            style = AppStyle.of(context);
            return const SizedBox();
          },
        ),
      );
      final colours = {for (final k in FileKind.values) kindColor(style, k)};
      expect(colours, hasLength(FileKind.values.length));
      await unmount(tester);
      await env.dispose();
      env = AppEnv();
    }
  });

  for (final kit in UiKit.values) {
    testWidgets('${kit.name}: thumbnail view groups folders and files', (
      tester,
    ) async {
      env.settings = env.settings.copyWith(gridView: true);
      final docs = env.drive.addFolder('Documents');
      env.drive.addFile('notes.txt', 'hello');
      env.drive.addBytes('photo.png', [1, 2, 3], mimeType: 'image/png');
      env.drive.addNative('Plan', 'x');
      final container = await pumpGDrive(tester, env, kit: kit);

      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.byType(ItemThumbnail), findsNWidgets(3));
      expect(find.textContaining('Google Docs · '), findsOneWidget);
      expect(find.textContaining('5 B · '), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Documents')).dy,
        lessThan(tester.getTopLeft(find.text('notes.txt')).dy),
      );

      await tester.click(find.text('photo.png'));
      expect(container.read(browserProvider).selected, hasLength(1));
      await tester.doubleTap(find.text('Documents'));
      expect(container.read(browserProvider).path.single.id, docs.id);
      expect(find.text('Folders'), findsNothing);
      await unmount(tester);
    });

    testWidgets('${kit.name}: details pane follows the selection', (
      tester,
    ) async {
      env.settings = env.settings.copyWith(detailsPane: true);
      env.drive.addFolder('Documents');
      final notes = env.drive.addFile('notes.txt', 'hello');
      await env.drive.updateMetadata(notes.id, starred: true);
      env.drive.addFile('other.txt', '1234567890');
      env.picker.directory = p.join(env.temp.path, 'out');
      Directory(env.picker.directory!).createSync();
      final container = await pumpGDrive(tester, env, kit: kit);
      final pane = find.byType(DetailsPane);
      Finder inPane(String text) =>
          find.descendant(of: pane, matching: find.text(text));

      // Nothing selected: the folder itself.
      expect(inPane('My Drive'), findsOneWidget);
      expect(inPane('1 folder · 2 files'), findsOneWidget);
      expect(inPane('15 B'), findsOneWidget);

      // One file.
      await tester.click(find.text('notes.txt'));
      expect(inPane('notes.txt'), findsOneWidget);
      expect(inPane('TXT text file'), findsOneWidget);
      expect(inPane('Not synced to this computer'), findsOneWidget);
      expect(inPane('Starred'), findsOneWidget);
      expect(inPane('Me'), findsOneWidget);
      expect(
        find.descendant(of: pane, matching: find.byType(ItemThumbnail)),
        findsOneWidget,
      );

      // Several items.
      container
          .read(browserProvider.notifier)
          .selectAll(env.drive.items.map((e) => e.id));
      await tester.pump();
      expect(inPane('3 items selected'), findsOneWidget);
      await tester.tap(inPane('Download'));
      await pumpUntil(
        tester,
        () => shown(find.text('Download complete')),
        reason: 'the download to finish',
      );
      expect(
        File(p.join(env.picker.directory!, 'notes.txt')).existsSync(),
        isTrue,
      );

      // A folder opens from the pane.
      await tester.click(find.text('Documents').first);
      expect(inPane('Folder'), findsOneWidget);
      expect(inPane('Size'), findsNothing);
      await tester.tap(inPane('Open'));
      await settle(tester);
      expect(container.read(browserProvider).path, hasLength(1));
      expect(inPane('Documents'), findsOneWidget);
      expect(inPane('0 files'), findsOneWidget);
      await unmount(tester);
    });
  }

  testWidgets('Preview in the details pane opens the viewer', (tester) async {
    env.settings = env.settings.copyWith(detailsPane: true);
    env.drive.addFile('notes.txt', 'hello');
    await pumpGDrive(tester, env);

    await tester.click(find.text('notes.txt'));
    await tester.tap(find.text('Preview'));
    await pumpUntil(
      tester,
      () => shown(find.text('text[plain]:hello')),
      reason: 'the preview to load',
    );
    expect(find.byType(PreviewPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('details pane shows sync state, sharing and search context', (
    tester,
  ) async {
    env.settings = env.settings.copyWith(detailsPane: true);
    final synced = env.drive.addFile('synced.txt', 'x');
    final edited = env.drive.addFile('edited.txt', 'x');
    final waiting = env.drive.addFile('waiting.txt', 'x');
    env.drive.addFile('theirs.txt', 'x', sharedWithMe: true);
    SyncEntry entry(DriveItem i, bool localEdited) => SyncEntry(
      fileId: i.id,
      relPath: i.name,
      isFolder: false,
      isNative: false,
      localEdited: localEdited,
    );
    await env.db.putEntry(entry(synced, false));
    await env.db.putEntry(entry(edited, true));
    await env.db.addSelection(waiting.id, env.now);
    final container = await pumpGDrive(tester, env);
    final pane = find.byType(DetailsPane);
    Finder inPane(String text) =>
        find.descendant(of: pane, matching: find.text(text));

    await tester.click(find.text('synced.txt'));
    expect(inPane('Synced to this computer'), findsOneWidget);
    await tester.click(find.text('edited.txt'));
    expect(inPane('Local edits are not uploaded'), findsOneWidget);
    await tester.click(find.text('waiting.txt'));
    expect(inPane('Waiting to sync'), findsOneWidget);

    container.read(browserProvider.notifier).setSearch('theirs');
    await settle(tester);
    expect(inPane('Search results'), findsOneWidget);
    await tester.click(find.text('theirs.txt'));
    expect(inPane('Shared with me'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('trashed items offer no open or download in the pane', (
    tester,
  ) async {
    env.settings = env.settings.copyWith(detailsPane: true);
    final gone = env.drive.addFile('gone.txt', 'x');
    await env.drive.updateMetadata(gone.id, trashed: true);
    final container = await pumpGDrive(tester, env);
    container.read(browserProvider.notifier).openSection(DriveSection.trash);
    await settle(tester);

    await tester.click(find.text('gone.txt'));
    final pane = find.byType(DetailsPane);
    expect(
      find.descendant(of: pane, matching: find.text('gone.txt')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pane, matching: find.text('Preview')),
      findsNothing,
    );
    expect(
      find.descendant(of: pane, matching: find.text('Download')),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('the details toggle hides, shows and persists', (tester) async {
    env.drive.addFile('notes.txt', 'hello');
    final container = await pumpGDrive(tester, env);
    expect(find.byType(DetailsPane), findsNothing);

    await tester.click(iconButton('Show details'));
    expect(find.byType(DetailsPane), findsOneWidget);
    expect(container.read(settingsProvider).detailsPane, isTrue);
    expect(await env.db.getValue('detailsPane'), 'true');

    await tester.click(iconButton('Hide details'));
    expect(find.byType(DetailsPane), findsNothing);
    expect((await AppSettings.load(env.db, env.paths)).detailsPane, isFalse);
    await unmount(tester);
  });

  testWidgets('the details pane gives way in a narrow window', (tester) async {
    env.settings = env.settings.copyWith(detailsPane: true);
    await pumpGDrive(tester, env);
    expect(find.byType(DetailsPane), findsOneWidget);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    expect(find.byType(DetailsPane), findsNothing);
    await unmount(tester);
  });

  testWidgets('a synced image is its own thumbnail', (tester) async {
    env.settings = env.settings.copyWith(gridView: true);
    final photo = env.drive.addBytes('photo.png', [1], mimeType: 'image/png');
    final doc = env.drive.addBytes('paper.pdf', [
      1,
    ], mimeType: 'application/pdf');
    for (final i in [photo, doc]) {
      await env.db.putEntry(
        SyncEntry(
          fileId: i.id,
          relPath: 'Pictures/${i.name}',
          isFolder: false,
          isNative: false,
          localEdited: false,
        ),
      );
    }
    await pumpGDrive(tester, env);
    await settle(tester);

    final local = find.byWidgetPredicate(
      (w) => w is Image && w.image is ResizeImage,
    );
    expect(local, findsOneWidget, reason: 'only the image, not the PDF');
    final file =
        ((tester.widget<Image>(local).image as ResizeImage).imageProvider
                as FileImage)
            .file;
    expect(file.path, p.join(env.syncRoot, 'Pictures', 'photo.png'));
    await unmount(tester);
  });

  testWidgets('a Drive thumbnail is used in the details pane too', (
    tester,
  ) async {
    env.settings = env.settings.copyWith(detailsPane: true);
    final photo = env.drive.addBytes('photo.png', [1], mimeType: 'image/png');
    await pumpGDrive(tester, env);
    await env.db.upsertItems([
      photo.copyWith(thumbnailLink: const Value('https://lh3.example/p=s220')),
    ]);
    await settle(tester);

    await tester.click(find.text('photo.png'));
    final network = find.byWidgetPredicate(
      (w) => w is Image && w.image is NetworkImage,
    );
    await pumpUntil(tester, () => shown(network), reason: 'the thumbnail');
    final image = tester.widget<Image>(network).image as NetworkImage;
    expect(image.url, 'https://lh3.example/p=s480');
    expect(image.headers, {'Authorization': 'Bearer fake-token'});
    await unmount(tester);
  });

  for (final kit in UiKit.values) {
    testWidgets('${kit.name}: the logo is on the sign-in page and sidebar', (
      tester,
    ) async {
      env = AppEnv(signedIn: false);
      await pumpGDrive(tester, env, kit: kit);
      expect(find.byType(AppLogo), findsOneWidget);
      expect(tester.getSize(find.byType(AppLogo)), const Size(84, 84));

      await tester.tap(find.text('Sign in with Google'));
      await settle(tester);
      expect(find.byType(AppLogo), findsOneWidget);
      expect(tester.getSize(find.byType(AppLogo)), const Size(22, 22));
      await unmount(tester);
    });
  }

  test('the logo asset is bundled', () {
    expect(File(AppLogo.asset).existsSync(), isTrue);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- ${AppLogo.asset}'),
    );
  });
}
