import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/util/file_kind.dart';
import 'package:gdrive/dev/demo.dart';
import 'package:gdrive/dev/demo_content.dart';
import 'package:gdrive/dev/demo_director.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/drive/browser_controller.dart';
import 'package:gdrive/features/preview/preview_page.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/shell/destinations.dart';
import 'package:path/path.dart' as p;

import '../support/app_env.dart';
import '../support/pump.dart';

void main() {
  group('demo content', () {
    testWidgets('encodePng produces an image that decodes to its pixels', (
      tester,
    ) async {
      final bytes = encodePng(3, 2, (x, y) => x == 0 ? 0xFF0000 : 0x0000FF);
      expect(bytes.sublist(1, 4), ascii.encode('PNG'));

      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        return (await codec.getNextFrame()).image;
      });
      expect((image!.width, image.height), (3, 2));
      final data = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(data!.buffer.asUint8List().sublist(0, 8), [
        255, 0, 0, 255, // red
        0, 0, 255, 255, // blue
      ]);
    });

    test('sample pictures are distinct PNGs', () {
      expect(demoPictures, hasLength(6));
      for (final MapEntry(key: name, value: bytes) in demoPictures.entries) {
        expect(name, endsWith('.png'));
        expect(bytes.sublist(1, 4), ascii.encode('PNG'), reason: name);
      }
      expect({for (final b in demoPictures.values) b.length}, hasLength(6));
    });

    test('a landscape can be drawn with or without a sun', () {
      Uint8List draw({int? sun}) => landscape(
        skyTop: 0x102030,
        skyBottom: 0xA0B0C0,
        hills: const [0x334455],
        sun: sun,
        width: 40,
        height: 24,
      );
      expect(draw(sun: 0xFFFFFF), isNot(draw()));
    });

    test('buildPdf writes a cross-reference table that matches the file', () {
      final text = latin1.decode(
        buildPdf('Report (draft)', const [r'back\slash', 'second line']),
      );
      expect(text, startsWith('%PDF-1.4'));
      expect(text.trimRight(), endsWith('%%EOF'));
      expect(text, contains(r'(Report \(draft\)) Tj'));
      expect(text, contains(r'(back\\slash) Tj'));

      final xrefAt = int.parse(
        RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!,
      );
      expect(text.substring(xrefAt), startsWith('xref\n0 7\n'));
      final offsets = RegExp(
        r'^(\d{10}) 00000 n ',
        multiLine: true,
      ).allMatches(text).map((m) => int.parse(m.group(1)!)).toList();
      expect(offsets, hasLength(6));
      for (var i = 0; i < offsets.length; i++) {
        expect(text.substring(offsets[i]), startsWith('${i + 1} 0 obj'));
      }
      final stream = RegExp(
        r'/Length (\d+) >>\nstream\n([\s\S]*?)endstream',
      ).firstMatch(text)!;
      expect(stream.group(2)!.length, int.parse(stream.group(1)!));
    });

    test('the demo Drive has folders, pictures, a PDF, code and Docs', () {
      final drive = seededDrive();
      final pictures = drive.find('Pictures')!;
      expect(
        drive.items.where((e) => e.parentId == pictures.id),
        hasLength(demoPictures.length),
      );
      expect(drive.find('Quarterly report.pdf')!.kind, FileKind.pdf);
      expect(drive.find('Budget 2026')!.isNative, isTrue);
      final projects = drive.find('Projects')!;
      expect(
        drive.textOf(drive.find('word_count.dart', parentId: projects.id)!.id),
        demoCode,
      );
      expect(demoNotes, contains('# Team notes'));
      expect(demoReportLines, isNotEmpty);
    });

    test('demoOverrides can start signed in or signed out', () {
      expect(demoOverrides(), hasLength(4));
      expect(
        demoOverrides(drive: seededDrive(), signedIn: false),
        hasLength(4),
      );
    });
  });

  group('DemoScene.parse', () {
    test('nothing given means nothing to do', () {
      expect(DemoScene.parse(null).isEmpty, isTrue);
      expect(DemoScene.parse('  ;; ').isEmpty, isTrue);
      expect(const DemoScene().isEmpty, isTrue);
    });

    test('reads every option', () {
      final scene = DemoScene.parse(
        ' theme=dark ; grid; nodetails; sync= Pictures , Documents ;'
        'open=Documents/Reports; select=Q3 summary.txt; page=activity;'
        'preview=notes.txt; signedout',
      );
      expect(scene.isEmpty, isFalse);
      expect(scene.theme, ThemePreference.dark);
      expect(scene.grid, isTrue);
      expect(scene.hideDetails, isTrue);
      expect(scene.sync, ['Pictures', 'Documents']);
      expect(scene.open, ['Documents', 'Reports']);
      expect(scene.select, 'Q3 summary.txt');
      expect(scene.page, Destination.activity);
      expect(scene.preview, 'notes.txt');
      expect(scene.signedOut, isTrue);
    });

    test('unknown values are ignored', () {
      final scene = DemoScene.parse('theme=sepia;page=nowhere;colour=red');
      expect(scene.theme, isNull);
      expect(scene.page, isNull);
      expect(scene.isEmpty, isTrue);
    });

    test('each option alone makes the scene non-empty', () {
      for (final source in [
        'signedout',
        'grid',
        'nodetails',
        'theme=light',
        'sync=A',
        'open=A',
        'select=a',
        'page=settings',
        'preview=a',
      ]) {
        expect(DemoScene.parse(source).isEmpty, isFalse, reason: source);
      }
    });
  });

  group('DemoDirector', () {
    late AppEnv env;

    setUp(() => env = AppEnv(paused: false));
    tearDown(() => env.dispose());

    Future<dynamic> play(
      WidgetTester tester,
      String scene, {
      StubViewers? viewers,
    }) async {
      final container = await pumpGDrive(
        tester,
        env,
        viewers: viewers,
        wrap: (app) => DemoDirector(
          scene: DemoScene.parse(scene),
          drive: env.drive,
          child: app,
        ),
      );
      await settle(tester, rounds: 6);
      return container;
    }

    testWidgets('opens a folder in thumbnail view and selects an item', (
      tester,
    ) async {
      final docs = env.drive.addFolder('Documents');
      final reports = env.drive.addFolder('Reports', parentId: docs.id);
      final file = env.drive.addFile('Q3.txt', 'x', parentId: reports.id);
      final container = await play(
        tester,
        'theme=dark;grid;nodetails;open=Documents/Reports;select=Q3.txt',
      );

      final settings = container.read(settingsProvider) as AppSettings;
      expect(settings.theme, ThemePreference.dark);
      expect(settings.gridView, isTrue);
      expect(settings.detailsPane, isFalse);
      final state = container.read(browserProvider) as BrowserState;
      expect(state.path.map((f) => f.name), ['Documents', 'Reports']);
      expect(state.selected, {file.id});
      expect(find.text('Files'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('names that do not exist are skipped', (tester) async {
      env.drive.addFile('plain.txt', 'x');
      final container = await play(
        tester,
        'open=plain.txt/Deeper;select=missing;preview=missing;sync=missing',
      );

      final state = container.read(browserProvider) as BrowserState;
      expect(state.path, isEmpty);
      expect(state.selected, isEmpty);
      expect(find.byType(PreviewPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('finishes on the requested page', (tester) async {
      final container = await play(tester, 'page=settings');
      expect(container.read(navProvider), Destination.settings);
      expect(find.text('Sync folder'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('opens the viewer on a file', (tester) async {
      env.drive.addFile('a.txt', 'first');
      env.drive.addFile('b.txt', 'second');
      env.drive.addFolder('Folder');
      await play(tester, 'preview=b.txt', viewers: StubViewers());
      await pumpUntil(
        tester,
        () => shown(find.text('text[plain]:second')),
        reason: 'the preview to load',
      );

      expect(find.byType(PreviewPage), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget, reason: 'files only');
      await unmount(tester);
    });

    testWidgets('syncs the named items before showing them', (tester) async {
      final pictures = env.drive.addFolder('Pictures');
      env.drive.addBytes(
        'a.png',
        [1, 2, 3],
        parentId: pictures.id,
        mimeType: 'image/png',
      );
      await play(tester, 'sync=Pictures;open=Pictures');
      final local = File(p.join(env.syncRoot, 'Pictures', 'a.png'));
      await pumpUntil(tester, local.existsSync, reason: 'the sync to finish');
      await pumpUntil(
        tester,
        () => shown(labelledIcon('Synced')),
        reason: 'the synced badge',
      );

      expect(await env.db.selections(), [pictures.id]);
      await unmount(tester);
    });

    testWidgets('a signed-out scene stays on the sign-in page', (tester) async {
      await env.dispose();
      env = AppEnv(signedIn: false);
      final container = await play(tester, 'signedout;theme=light;grid');

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(container.read(authProvider).value, isA<SignedOut>());
      expect(
        (container.read(settingsProvider) as AppSettings).gridView,
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets('gives up quietly if sign-in never happens', (tester) async {
      await env.dispose();
      env = AppEnv(signedIn: false);
      await play(tester, 'page=settings');
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Sign in with Google'), findsOneWidget);
      await unmount(tester);
    });
  });
}
