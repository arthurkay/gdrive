import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:gdrive/core/clock.dart';
import 'package:gdrive/core/config/app_paths.dart';
import 'package:gdrive/core/config/oauth_config.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/platform/system.dart';
import 'package:gdrive/core/secure/secure_store.dart';
import 'package:gdrive/dev/demo.dart';
import 'package:gdrive/dev/fake_drive_api.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/features/sync/sync_controller.dart';
import 'package:gdrive/features/transfers/transfer_manager.dart';
import 'package:path/path.dart' as p;

import 'harness.dart';

class FakeFilePicker implements FilePicker {
  List<String> files = [];
  String? directory;

  @override
  Future<List<String>> pickFiles() async => files;

  @override
  Future<String?> pickDirectory({String? title}) async => directory;
}

/// Everything outside the app replaced with fakes: Drive, Google sign-in,
/// the credential vault, the clock, pickers and the file-system watcher.
class AppEnv {
  AppEnv({bool configured = true, bool signedIn = true, bool paused = true})
    : temp = Directory.systemTemp.createTempSync('gdrive_env_') {
    paths = AppPaths(
      support: p.join(temp.path, 'support'),
      cache: p.join(temp.path, 'cache'),
      defaultSyncRoot: p.join(temp.path, 'sync'),
    );
    // The details pane repeats names and actions shown in the list, so it is
    // off by default here and switched on by the tests that cover it.
    settings = AppSettings(
      syncRoot: paths.defaultSyncRoot,
      paused: paused,
      detailsPane: false,
    );
    config = configured
        ? const OAuthConfig(clientId: 'client', clientSecret: 'secret')
        : const OAuthConfig(clientId: '', clientSecret: '');
    if (signedIn) {
      store.values[credentialsKey] = FakeAuthSession().serialize();
    }
  }

  final Directory temp;
  final AppDatabase db = memoryDatabase();
  final FakeDriveApi drive = FakeDriveApi();
  final InMemorySecureStore store = InMemorySecureStore();
  final FakeAuthGateway gateway = FakeAuthGateway();
  final FakeFilePicker picker = FakeFilePicker();
  final List<Uri> launched = [];
  late final AppPaths paths;
  late final OAuthConfig config;
  late AppSettings settings;
  DateTime now = DateTime(2026, 11, 17, 9);

  /// Stands in for the file-system watcher; silent unless a test replaces it.
  Stream<void> Function(String path) watcher = (_) => const Stream.empty();

  String get syncRoot => settings.syncRoot;

  List<Override> get overrides => [
    appPathsProvider.overrideWithValue(paths),
    databaseProvider.overrideWithValue(db),
    initialSettingsProvider.overrideWithValue(settings),
    oauthConfigProvider.overrideWithValue(config),
    secureStoreProvider.overrideWithValue(store),
    authGatewayProvider.overrideWithValue(gateway),
    driveApiFactoryProvider.overrideWithValue((_) => drive),
    clockProvider.overrideWithValue(() => now),
    filePickerProvider.overrideWithValue(picker),
    launcherProvider.overrideWithValue((uri) async => launched.add(uri)),
    folderWatcherProvider.overrideWithValue((path) => watcher(path)),
    transferManagerProvider.overrideWith(
      (ref) => TransferManager(
        db: db,
        api: () => drive,
        clock: () => now,
        sleep: (_) async {},
      ),
    ),
  ];

  /// A container with the environment applied; disposed with the test.
  ProviderContainer container({List<Override> extra = const []}) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [...overrides, ...extra],
    );
    _containers.add(container);
    return container;
  }

  final List<ProviderContainer> _containers = [];

  /// Current value of a stream-backed provider. Riverpod pauses providers
  /// nobody listens to, so this listens first.
  Future<T> latest<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    final sub = container.listen(provider, (_, _) {});
    for (var i = 0; i < 50 && !sub.read().hasValue; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final value = sub.read().requireValue;
    sub.close();
    return value;
  }

  Future<void> dispose() async {
    for (final container in _containers) {
      container.dispose(); // A no-op for containers already disposed.
    }
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}
