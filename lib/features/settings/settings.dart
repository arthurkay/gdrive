import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_paths.dart';
import '../../core/db/database.dart';

enum ThemePreference { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.syncRoot,
    this.pollSeconds = 30,
    this.concurrency = 3,
    this.paused = false,
    this.theme = ThemePreference.system,
    this.gridView = false,
    this.detailsPane = true,
  });

  /// Local folder that mirrors Drive.
  final String syncRoot;

  /// How often Drive is asked for changes.
  final int pollSeconds;

  /// Simultaneous transfers.
  final int concurrency;
  final bool paused;
  final ThemePreference theme;
  final bool gridView;

  /// Whether the browser shows the details panel beside the files.
  final bool detailsPane;

  AppSettings copyWith({
    String? syncRoot,
    int? pollSeconds,
    int? concurrency,
    bool? paused,
    ThemePreference? theme,
    bool? gridView,
    bool? detailsPane,
  }) => AppSettings(
    syncRoot: syncRoot ?? this.syncRoot,
    pollSeconds: pollSeconds ?? this.pollSeconds,
    concurrency: concurrency ?? this.concurrency,
    paused: paused ?? this.paused,
    theme: theme ?? this.theme,
    gridView: gridView ?? this.gridView,
    detailsPane: detailsPane ?? this.detailsPane,
  );

  static Future<AppSettings> load(AppDatabase db, AppPaths paths) async {
    Future<int?> number(String key) async =>
        int.tryParse(await db.getValue(key) ?? '');
    final theme = await db.getValue('theme');
    return AppSettings(
      syncRoot: await db.getValue('syncRoot') ?? paths.defaultSyncRoot,
      pollSeconds: (await number('pollSeconds') ?? 30).clamp(10, 3600),
      concurrency: (await number('concurrency') ?? 3).clamp(1, 8),
      paused: await db.getValue('paused') == 'true',
      theme: ThemePreference.values.firstWhere(
        (t) => t.name == theme,
        orElse: () => ThemePreference.system,
      ),
      gridView: await db.getValue('gridView') == 'true',
      detailsPane: await db.getValue('detailsPane') != 'false',
    );
  }
}

/// Settings loaded before the first frame, see `main.dart`.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) =>
      throw UnimplementedError('initialSettingsProvider must be overridden'),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> setSyncRoot(String path) async {
    state = state.copyWith(syncRoot: path);
    await _db.setValue('syncRoot', path);
  }

  Future<void> setPollSeconds(int seconds) async {
    final value = seconds.clamp(10, 3600);
    state = state.copyWith(pollSeconds: value);
    await _db.setValue('pollSeconds', '$value');
  }

  Future<void> setConcurrency(int count) async {
    final value = count.clamp(1, 8);
    state = state.copyWith(concurrency: value);
    await _db.setValue('concurrency', '$value');
  }

  Future<void> setPaused(bool paused) async {
    state = state.copyWith(paused: paused);
    await _db.setValue('paused', '$paused');
  }

  Future<void> setTheme(ThemePreference theme) async {
    state = state.copyWith(theme: theme);
    await _db.setValue('theme', theme.name);
  }

  Future<void> setDetailsPane(bool shown) async {
    state = state.copyWith(detailsPane: shown);
    await _db.setValue('detailsPane', '$shown');
  }

  Future<void> setGridView(bool grid) async {
    state = state.copyWith(gridView: grid);
    await _db.setValue('gridView', '$grid');
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
