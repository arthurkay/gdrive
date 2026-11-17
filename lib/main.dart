// coverage:ignore-file
// Process start-up: native window, single-instance lock and plugin
// initialisation. Nothing here runs under `flutter test`; the pieces it
// wires together are each tested on their own.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:yaru/yaru.dart' show YaruWindowTitleBar;

import 'app.dart';
import 'core/config/app_paths.dart';
import 'core/db/database.dart';
import 'core/platform/ui_kit.dart';
import 'core/platform/window.dart';
import 'dev/demo.dart';
import 'features/settings/settings.dart';

/// `--dart-define=DEMO=true` runs against an in-memory Drive, with its own
/// database and sync folder so real data is never touched.
const _demo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  var paths = await AppPaths.resolve();
  if (_demo) {
    final dir = p.join(paths.cache, 'demo');
    final old = Directory(dir);
    if (await old.exists()) await old.delete(recursive: true);
    paths = AppPaths(
      support: dir,
      cache: p.join(dir, 'cache'),
      defaultSyncRoot: p.join(dir, 'GDrive'),
    );
  }
  await Directory(paths.support).create(recursive: true);

  final lock = await acquireInstanceLock(paths.lockFile);
  if (lock == null) {
    stderr.writeln('GDrive is already running.');
    exit(0);
  }

  final db = AppDatabase.open(paths.database);
  await db.failInterruptedTransfers();
  final settings = await AppSettings.load(db, paths);

  final kit = detectUiKit();
  final ownTitleBar = kit == UiKit.yaru && Platform.isLinux;
  await initWindow(db);
  if (ownTitleBar) await YaruWindowTitleBar.ensureInitialized();

  runApp(
    ProviderScope(
      // Failures surface in the UI with their own retry actions.
      retry: (_, _) => null,
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        uiKitProvider.overrideWithValue(kit),
        customTitleBarProvider.overrideWithValue(ownTitleBar),
        if (_demo) ...demoOverrides(),
      ],
      child: const GDriveApp(),
    ),
  );
}
