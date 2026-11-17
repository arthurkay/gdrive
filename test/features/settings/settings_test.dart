import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/features/settings/settings.dart';

import '../../support/app_env.dart';

void main() {
  late AppEnv env;

  setUp(() => env = AppEnv());
  tearDown(() => env.dispose());

  test('load falls back to defaults on a fresh database', () async {
    final settings = await AppSettings.load(env.db, env.paths);
    expect(settings.syncRoot, env.paths.defaultSyncRoot);
    expect(settings.pollSeconds, 30);
    expect(settings.concurrency, 3);
    expect(settings.paused, isFalse);
    expect(settings.theme, ThemePreference.system);
    expect(settings.gridView, isFalse);
  });

  test('every setter updates state and persists', () async {
    final container = env.container();
    final controller = container.read(settingsProvider.notifier);

    await controller.setSyncRoot('/data/drive');
    await controller.setPollSeconds(60);
    await controller.setConcurrency(5);
    await controller.setPaused(false);
    await controller.setTheme(ThemePreference.dark);
    await controller.setGridView(true);

    final live = container.read(settingsProvider);
    final stored = await AppSettings.load(env.db, env.paths);
    for (final s in [live, stored]) {
      expect(s.syncRoot, '/data/drive');
      expect(s.pollSeconds, 60);
      expect(s.concurrency, 5);
      expect(s.paused, isFalse);
      expect(s.theme, ThemePreference.dark);
      expect(s.gridView, isTrue);
    }
  });

  test('out-of-range and corrupt values are clamped or ignored', () async {
    final controller = env.container().read(settingsProvider.notifier);
    await controller.setPollSeconds(1);
    await controller.setConcurrency(99);
    var stored = await AppSettings.load(env.db, env.paths);
    expect(stored.pollSeconds, 10);
    expect(stored.concurrency, 8);

    await env.db.setValue('pollSeconds', 'soon');
    await env.db.setValue('concurrency', '0');
    await env.db.setValue('theme', 'sepia');
    stored = await AppSettings.load(env.db, env.paths);
    expect(stored.pollSeconds, 30);
    expect(stored.concurrency, 1);
    expect(stored.theme, ThemePreference.system);
  });
}
