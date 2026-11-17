import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/config/app_paths.dart';
import 'package:gdrive/core/config/oauth_config.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/platform/window.dart';
import 'package:gdrive/core/secure/secure_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('detectUiKit', () {
    test('follows the platform', () {
      UiKit on(TargetPlatform platform) =>
          detectUiKit(override: '', platform: platform);
      expect(on(TargetPlatform.windows), UiKit.fluent);
      expect(on(TargetPlatform.macOS), UiKit.macos);
      expect(on(TargetPlatform.linux), UiKit.yaru);
    });

    test('an explicit override wins; a bad one is ignored', () {
      for (final kit in UiKit.values) {
        expect(
          detectUiKit(override: kit.name, platform: TargetPlatform.linux),
          kit,
        );
      }
      expect(
        detectUiKit(override: 'gtk', platform: TargetPlatform.windows),
        UiKit.fluent,
      );
    });
  });

  testWidgets('Kit exposes the kit to descendants and defaults to Yaru', (
    tester,
  ) async {
    late UiKit seen;
    final probe = Builder(
      builder: (context) {
        seen = Kit.of(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(probe);
    expect(seen, UiKit.yaru);
    await tester.pumpWidget(Kit(kit: UiKit.macos, child: probe));
    expect(seen, UiKit.macos);
    await tester.pumpWidget(Kit(kit: UiKit.fluent, child: probe));
    expect(seen, UiKit.fluent);
  });

  group('window bounds', () {
    test('round-trip through storage', () {
      const bounds = Rect.fromLTWH(120, 80, 1280, 800);
      expect(encodeBounds(bounds), '120,80,1280,800');
      expect(decodeBounds(encodeBounds(bounds)), bounds);
    });

    test('garbage and undersized values are rejected', () {
      expect(decodeBounds(null), isNull);
      expect(decodeBounds(''), isNull);
      expect(decodeBounds('1,2,3'), isNull);
      expect(decodeBounds('a,b,c,d'), isNull);
      expect(decodeBounds('0,0,200,800'), isNull);
      expect(decodeBounds('0,0,1200,100'), isNull);
    });
  });

  test('the instance lock creates and holds the lock file', () async {
    final dir = await Directory.systemTemp.createTemp('gdrive_lock_');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'gdrive.lock');

    final handle = await acquireInstanceLock(path);

    expect(handle, isNotNull);
    expect(File(path).existsSync(), isTrue);
    await handle!.close();
  });

  test('OAuthConfig knows when it has not been filled in', () {
    expect(
      const OAuthConfig(clientId: '', clientSecret: '').isConfigured,
      isFalse,
    );
    expect(
      const OAuthConfig(
        clientId: 'YOUR_CLIENT_ID.apps.googleusercontent.com',
        clientSecret: 'x',
      ).isConfigured,
      isFalse,
    );
    expect(
      const OAuthConfig(clientId: 'abc', clientSecret: 'x').isConfigured,
      isTrue,
    );
    expect(const OAuthConfig.fromEnvironment().isConfigured, isFalse);
    expect(OAuthConfig.scopes.first, endsWith('/auth/drive'));
  });

  test('AppPaths derives its files from the base folders', () {
    const paths = AppPaths(support: '/s', cache: '/c', defaultSyncRoot: '/h/G');
    expect(paths.database, p.join('/s', 'gdrive.sqlite'));
    expect(paths.lockFile, p.join('/s', 'gdrive.lock'));
    expect(paths.recycle, p.join('/s', 'recycle'));
    expect(paths.previewCache, p.join('/c', 'preview'));
  });

  test('the in-memory store reads back what was written', () async {
    final store = InMemorySecureStore();
    expect(await store.read('k'), isNull);
    await store.write('k', 'v');
    expect(await store.read('k'), 'v');
    await store.delete('k');
    expect(await store.read('k'), isNull);
  });

  test('the keychain store delegates to the platform vault', () async {
    final storage = MockStorage();
    when(() => storage.read(key: 'k')).thenAnswer((_) async => 'secret');
    when(() => storage.write(key: 'k', value: 'v')).thenAnswer((_) async {});
    when(() => storage.delete(key: 'k')).thenAnswer((_) async {});
    final store = KeychainSecureStore(storage);

    expect(await store.read('k'), 'secret');
    await store.write('k', 'v');
    await store.delete('k');

    verify(() => storage.write(key: 'k', value: 'v')).called(1);
    verify(() => storage.delete(key: 'k')).called(1);
  });
}
