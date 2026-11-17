import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/ui/adaptive/app_icons.dart';
import 'package:gdrive/core/ui/adaptive/app_style.dart';
import 'package:gdrive/core/ui/adaptive/controls.dart';
import 'package:gdrive/core/ui/adaptive/dialogs.dart';
import 'package:gdrive/core/ui/adaptive/menu.dart';
import 'package:gdrive/core/ui/notice.dart';
import 'package:gdrive/core/util/file_kind.dart';
import 'package:gdrive/features/preview/viewers.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/features/sync/sync_banner.dart';
import 'package:gdrive/features/sync/sync_controller.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';

import '../support/app_env.dart';
import '../support/pump.dart';

class FixedSync extends SyncController {
  FixedSync(this.status);

  final SyncStatus status;
  int retries = 0;
  int confirmations = 0;

  @override
  SyncStatus build() => status;

  @override
  Future<void> syncNow({bool allowMassDelete = false}) async => retries++;

  @override
  Future<void> confirmDeletes() async => confirmations++;
}

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  for (final kit in UiKit.values) {
    group('${kit.name} kit', () {
      testWidgets('controls respond to input', (tester) async {
        var pressed = 0;
        var toggled = false;
        var checked = false;
        var typed = '';
        var submitted = '';
        await pumpGDrive(
          tester,
          env,
          kit: kit,
          home: AppSurface(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  AppButton(
                    label: 'Primary',
                    primary: true,
                    icon: AppIcons.of(context).upload,
                    onPressed: () => pressed++,
                  ),
                  AppButton(label: 'Plain', onPressed: () => pressed++),
                  const AppButton(label: 'Disabled', onPressed: null),
                  AppIconButton(
                    icon: AppIcons.of(context).refresh,
                    tooltip: 'Refresh',
                    onPressed: () => pressed++,
                  ),
                  AppIconButton(
                    icon: AppIcons.of(context).trash,
                    tooltip: 'Unavailable',
                    onPressed: null,
                  ),
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      placeholder: 'Type here',
                      prefixIcon: AppIcons.of(context).search,
                      onChanged: (v) => typed = v,
                      onSubmitted: (v) => submitted = v,
                    ),
                  ),
                  AppSwitch(
                    value: toggled,
                    onChanged: (v) => setState(() => toggled = v),
                  ),
                  AppCheckbox(
                    value: checked,
                    onChanged: (v) => setState(() => checked = v),
                  ),
                  const SizedBox(width: 200, child: AppProgressBar(value: 0.4)),
                  const SizedBox(width: 200, child: AppProgressBar()),
                  const AppSpinner(),
                  for (final kind in BannerKind.values)
                    AppBanner(
                      message: 'banner ${kind.name}',
                      kind: kind,
                      action: AppButton(
                        label: 'Act',
                        onPressed: () => pressed++,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.text('Primary'));
        await tester.tap(find.text('Plain'));
        await tester.tap(find.text('Disabled'));
        await tester.tap(iconButton('Refresh'));
        await tester.tap(iconButton('Unavailable'), warnIfMissed: false);
        await tester.tap(find.text('Act').first);
        expect(pressed, 4);

        await tester.enterText(find.byType(EditableText), 'hello');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect((typed, submitted), ('hello', 'hello'));

        await tester.tap(find.byType(AppSwitch));
        await tester.tap(find.byType(AppCheckbox));
        await tester.pump(const Duration(milliseconds: 300));
        expect((toggled, checked), (true, true));

        for (final kind in BannerKind.values) {
          expect(find.text('banner ${kind.name}'), findsOneWidget);
        }
        await unmount(tester);
      });

      testWidgets('dialogs confirm, cancel, inform and prompt', (tester) async {
        late BuildContext context;
        await pumpGDrive(
          tester,
          env,
          kit: kit,
          home: Builder(
            builder: (c) {
              context = c;
              return const AppSurface(child: SizedBox.expand());
            },
          ),
        );

        var confirm = showConfirm(
          context,
          title: 'Delete it?',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
        );
        await settle(tester, rounds: 2);
        expect(find.text('This cannot be undone.'), findsOneWidget);
        await tester.click(find.text('Delete'));
        expect(await confirm, isTrue);

        confirm = showConfirm(context, title: 'Sure?', message: 'Really?');
        await settle(tester, rounds: 2);
        await tester.click(find.text('Cancel'));
        expect(await confirm, isFalse);

        final message = showMessage(
          context,
          title: 'Done',
          message: 'All good',
        );
        await settle(tester, rounds: 2);
        expect(find.text('Cancel'), findsNothing);
        await tester.click(find.text('OK'));
        await message;

        var prompt = showPrompt(
          context,
          title: 'Name',
          initial: 'old',
          confirmLabel: 'Save',
        );
        await settle(tester, rounds: 2);
        await tester.enterText(find.byType(EditableText), '  new name ');
        await tester.click(find.text('Save'));
        expect(await prompt, 'new name');

        prompt = showPrompt(context, title: 'Name', confirmLabel: 'Save');
        await settle(tester, rounds: 2);
        await tester.click(find.text('Save'));
        expect(find.text('Name'), findsOneWidget, reason: 'empty is refused');
        await tester.enterText(find.byType(EditableText), 'typed');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester, rounds: 2);
        expect(await prompt, 'typed');

        prompt = showPrompt(context, title: 'Name', initial: 'kept');
        await settle(tester, rounds: 2);
        await tester.click(find.text('Cancel'));
        expect(await prompt, isNull);
        await unmount(tester);
      });

      testWidgets('context menu runs items, skips disabled, dismisses', (
        tester,
      ) async {
        late BuildContext context;
        final chosen = <String>[];
        await pumpGDrive(
          tester,
          env,
          kit: kit,
          home: Builder(
            builder: (c) {
              context = c;
              return const AppSurface(child: SizedBox.expand());
            },
          ),
        );
        void open() => showAppMenu(
          context,
          position: const Offset(1270, 790),
          items: [
            AppMenuItem(
              label: 'Open',
              icon: AppIcons.of(context).file,
              onSelected: () => chosen.add('open'),
            ),
            const AppMenuItem.divider(),
            AppMenuItem(
              label: 'Locked',
              enabled: false,
              onSelected: () => chosen.add('locked'),
            ),
            AppMenuItem(
              label: 'Delete',
              destructive: true,
              onSelected: () => chosen.add('delete'),
            ),
          ],
        );

        open();
        await settle(tester, rounds: 2);
        final menu = tester.getRect(find.text('Open'));
        expect(menu.right, lessThan(1280), reason: 'kept on screen');
        expect(tester.getRect(find.text('Delete')).bottom, lessThan(800));

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.text('Open')));
        await tester.pump();
        await gesture.removePointer();

        await tester.click(find.text('Locked'));
        expect(find.text('Open'), findsOneWidget, reason: 'still open');
        await tester.click(find.text('Delete'));
        expect(chosen, ['delete']);
        expect(find.text('Open'), findsNothing);

        open();
        await settle(tester, rounds: 2);
        await tester.tapAt(const Offset(10, 10));
        await settle(tester, rounds: 2);
        expect(find.text('Open'), findsNothing);
        expect(chosen, ['delete']);
        await unmount(tester);
      });

      testWidgets('style and icons resolve in light and dark', (tester) async {
        for (final theme in [ThemePreference.light, ThemePreference.dark]) {
          env.settings = env.settings.copyWith(theme: theme);
          late AppStyle style;
          late AppIcons icons;
          await pumpGDrive(
            tester,
            env,
            kit: kit,
            home: Builder(
              builder: (context) {
                style = AppStyle.of(context);
                icons = AppIcons.of(context);
                return const SizedBox();
              },
            ),
          );
          expect(style.isDark, theme == ThemePreference.dark);
          expect(style.background.a, 1.0, reason: 'opaque for full routes');
          expect(style.text, isNot(style.background));
          for (final colour in [
            style.muted,
            style.border,
            style.hover,
            style.selected,
            style.danger,
            style.success,
            style.warning,
            style.surface,
            style.accent,
            style.onAccent,
          ]) {
            expect(colour, isA<Color>());
          }
          expect(style.title.fontSize, greaterThan(style.caption.fontSize!));
          expect(style.strong.fontWeight, FontWeight.w600);

          final all = [
            for (final kind in FileKind.values) icons.forKind(kind),
            icons.myDrive,
            icons.shared,
            icons.recent,
            icons.starred,
            icons.star,
            icons.trash,
            icons.transfers,
            icons.activity,
            icons.settings,
            icons.upload,
            icons.download,
            icons.newFolder,
            icons.refresh,
            icons.search,
            icons.grid,
            icons.list,
            icons.back,
            icons.chevron,
            icons.up,
            icons.more,
            icons.sync,
            icons.synced,
            icons.warning,
            icons.error,
            icons.pause,
            icons.play,
            icons.close,
            icons.rename,
            icons.move,
            icons.copy,
            icons.restore,
            icons.openExternal,
            icons.info,
            icons.zoomIn,
            icons.zoomOut,
            icons.rotate,
            icons.save,
            icons.account,
            icons.volume,
            icons.fullscreen,
            icons.next,
            icons.previous,
          ];
          expect(all.every((icon) => icon.codePoint > 0), isTrue);
          await unmount(tester);
          await env.dispose();
          env = AppEnv();
        }
      });

      testWidgets('sync banner asks about deletions and reports errors', (
        tester,
      ) async {
        final pending = FixedSync(
          const SyncStatus(
            phase: SyncPhase.needsConfirmation,
            pendingDeletes: 12,
          ),
        );
        final container = await pumpGDrive(
          tester,
          env,
          kit: kit,
          home: const AppSurface(child: Column(children: [SyncBanner()])),
          extra: [syncProvider.overrideWith(() => pending)],
        );
        expect(find.textContaining('remove 12 files'), findsOneWidget);
        await tester.tap(find.text('Remove them'));
        expect(pending.confirmations, 1);
        await tester.tap(find.text('Pause sync'));
        await tester.pump();
        expect(container.read(settingsProvider).paused, isTrue);
        await unmount(tester);
      });
    });
  }

  testWidgets('sync banner offers a retry after an error and hides when idle', (
    tester,
  ) async {
    final failed = FixedSync(
      const SyncStatus(phase: SyncPhase.error, message: 'disk full'),
    );
    await pumpGDrive(
      tester,
      env,
      home: const AppSurface(child: Column(children: [SyncBanner()])),
      extra: [syncProvider.overrideWith(() => failed)],
    );
    expect(find.text('Sync stopped: disk full'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(failed.retries, 1);
    await unmount(tester);

    await env.dispose();
    env = AppEnv();
    await pumpGDrive(
      tester,
      env,
      home: const AppSurface(child: Column(children: [SyncBanner()])),
      extra: [syncProvider.overrideWith(() => FixedSync(const SyncStatus()))],
    );
    expect(find.byType(AppBanner), findsNothing);
    await unmount(tester);
  });

  testWidgets('notices appear, replace each other, and time out', (
    tester,
  ) async {
    final container = await pumpGDrive(
      tester,
      env,
      home: const NoticeHost(child: AppSurface(child: SizedBox.expand())),
    );
    final notices = container.read(noticeProvider.notifier);

    notices.show('first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    notices.show('second', isError: true);
    await tester.pump();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    await tester.pump(NoticeController.lifetime);
    expect(find.text('second'), findsNothing);

    notices.show('tap me');
    await tester.pump();
    await tester.tap(find.text('tap me'));
    await tester.pump();
    expect(find.text('tap me'), findsNothing);
    await unmount(tester);
  });

  testWidgets('hoverable reports pointer enter and exit', (tester) async {
    await pumpGDrive(
      tester,
      env,
      home: Center(
        child: Hoverable(
          builder: (_, hovered) => SizedBox(
            width: 100,
            height: 100,
            child: Text(hovered ? 'over' : 'out'),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(Hoverable)));
    await tester.pump();
    expect(find.text('over'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('out'), findsOneWidget);
    await mouse.removePointer();
    await unmount(tester);
  });

  group('viewers', () {
    testWidgets('seek bar maps taps and drags to positions', (tester) async {
      final seeks = <Duration>[];
      await pumpGDrive(
        tester,
        env,
        home: Center(
          child: SizedBox(
            width: 200,
            child: SeekBar(
              position: const Duration(seconds: 30),
              duration: const Duration(seconds: 120),
              onSeek: seeks.add,
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(SeekBar));

      await tester.tapAt(Offset(bar.left + 100, bar.center.dy));
      expect(seeks.last, const Duration(seconds: 60));
      await tester.dragFrom(
        Offset(bar.left + 100, bar.center.dy),
        const Offset(200, 0),
      );
      expect(seeks.last, const Duration(seconds: 120));
      await unmount(tester);
    });

    testWidgets('seek bar ignores input before the duration is known', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await pumpGDrive(
        tester,
        env,
        home: Center(
          child: SizedBox(
            width: 200,
            child: SeekBar(
              position: Duration.zero,
              duration: Duration.zero,
              onSeek: seeks.add,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SeekBar));
      expect(seeks, isEmpty);
      await unmount(tester);
    });

    testWidgets('image viewer zooms, resets and rotates', (tester) async {
      final file = File(p.join(env.temp.path, 'missing.png'));
      await pumpGDrive(
        tester,
        env,
        home: AppSurface(child: ImageViewer(file: file)),
      );
      InteractiveViewer viewer() =>
          tester.widget(find.byType(InteractiveViewer));
      double scale() =>
          viewer().transformationController!.value.getMaxScaleOnAxis();

      await tester.tap(iconButton('Zoom in'));
      await tester.tap(iconButton('Zoom in'));
      expect(scale(), closeTo(1.5625, 0.001));
      await tester.tap(iconButton('Zoom out'));
      expect(scale(), closeTo(1.25, 0.001));
      await tester.tap(iconButton('Fit to window'));
      expect(scale(), 1.0);

      await tester.tap(iconButton('Rotate'));
      await tester.pump();
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        1,
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(iconButton('Rotate'));
      }
      await tester.pump();
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        0,
      );

      await pumpUntil(
        tester,
        () => shown(find.text('This image could not be displayed')),
        reason: 'the image load to fail',
      );
      expect(find.text('This image could not be displayed'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the default factory builds the real viewers', (tester) async {
      const factory = ViewerFactory();
      expect(factory.image(File('x')), isA<ImageViewer>());
      expect(
        factory.text(
          content: 'x',
          language: 'dart',
          readOnly: true,
          onChanged: (_) {},
        ),
        isA<TextPane>(),
      );
      expect(factory.pdf(File('x')).runtimeType.toString(), 'PdfPane');
      expect(
        factory
            .media(const MediaSource.file('x'), video: true)
            .runtimeType
            .toString(),
        'MediaPane',
      );
    });

    testWidgets('text pane shows content with highlighting and line numbers', (
      tester,
    ) async {
      final changes = <String>[];
      await pumpGDrive(
        tester,
        env,
        home: AppSurface(
          child: TextPane(
            content: 'void main() {}\n// second line',
            language: 'dart',
            readOnly: false,
            onChanged: changes.add,
          ),
        ),
      );
      await settle(tester);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(editor.controller!.text, 'void main() {}\n// second line');
      expect(editor.readOnly, isFalse);
      expect(editor.style!.codeTheme, isNotNull, reason: 'Dart is highlighted');

      editor.controller!.text = 'edited';
      await tester.pump();
      expect(changes.last, 'edited');

      // Find panel: opens, reports matches, steps and closes.
      final finder = editor.findController!;
      finder.findMode();
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'edit');
      // Matching runs off the UI isolate, so give it real time.
      for (var i = 0; i < 60 && find.text('1 of 1').evaluate().isEmpty; i++) {
        await settle(tester, rounds: 1);
      }
      expect(find.text('1 of 1'), findsOneWidget);
      await tester.tap(iconButton('Next match'));
      await tester.tap(iconButton('Previous match'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(iconButton('Close find'));
      await tester.pump();
      expect(find.text('1 of 1'), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 1));
      await unmount(tester);
    });

    testWidgets('plain text pane wraps and can be read-only', (tester) async {
      await pumpGDrive(
        tester,
        env,
        home: AppSurface(
          child: TextPane(
            content: 'just words',
            language: null,
            readOnly: true,
            onChanged: (_) {},
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(TextPane), findsOneWidget);
      await unmount(tester);
    });
  });
}
