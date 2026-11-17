import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/config/app_paths.dart';
import 'package:gdrive/core/config/oauth_config.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/secure/secure_store.dart';
import 'package:gdrive/dev/demo.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/auth/auth_gateway.dart';
import 'package:gdrive/features/drive/drive_api.dart';
import 'package:gdrive/features/drive/google_drive_api.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = OAuthConfig(clientId: 'client-id', clientSecret: 'secret');

  http.Client tokenEndpoint(List<http.Request> seen) =>
      MockClient((request) async {
        seen.add(request);
        return http.Response(
          jsonEncode({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'scope': OAuthConfig.scopes.join(' '),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

  /// Plays the part of the browser: follows the consent URL's redirect back
  /// to the app's loopback listener, as Google would after approval.
  Future<void> approve(Uri consent, {String? error}) async {
    final redirect = Uri.parse(consent.queryParameters['redirect_uri']!);
    final callback = redirect.replace(
      queryParameters: {
        'state': consent.queryParameters['state'],
        if (error == null) 'code': 'auth-code' else 'error': error,
      },
    );
    final client = HttpClient();
    final response = await (await client.getUrl(callback)).close();
    await response.drain<void>();
    client.close();
  }

  test(
    'sign-in runs the loopback consent flow and returns a session',
    () async {
      final tokenRequests = <http.Request>[];
      late Uri consent;
      final gateway = GoogleAuthGateway(
        config: config,
        httpClient: () => tokenEndpoint(tokenRequests),
        openBrowser: (url) async {
          consent = url;
          await approve(url);
        },
      );

      final session = await gateway.signIn();

      expect(consent.host, 'accounts.google.com');
      expect(consent.queryParameters['client_id'], 'client-id');
      expect(consent.queryParameters['scope'], contains('auth/drive'));
      expect(
        Uri.parse(consent.queryParameters['redirect_uri']!).host,
        anyOf('localhost', '127.0.0.1'),
      );
      expect(tokenRequests.single.bodyFields['code'], 'auth-code');
      expect(await session.accessToken(), 'access-1');
      expect(jsonDecode(session.serialize())['refreshToken'], 'refresh-1');
      session.close();
    },
  );

  test('a denied consent fails sign-in', () async {
    final gateway = GoogleAuthGateway(
      config: config,
      httpClient: () => tokenEndpoint([]),
      openBrowser: (url) => approve(url, error: 'access_denied'),
    );

    await expectLater(gateway.signIn(), throwsA(anything));
  });

  test(
    'revoke falls back to the access token when there is no refresh token',
    () async {
      final requests = <http.Request>[];
      final gateway = GoogleAuthGateway(
        config: config,
        openBrowser: (_) async {},
        httpClient: () => MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await gateway.revoke(_TokenOnlySession());

      expect(requests.single.bodyFields['token'], 'only-access');
    },
  );

  test('the default wiring uses Google for sign-in and Drive', () {
    final container = ProviderContainer(
      overrides: [oauthConfigProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);

    expect(container.read(authGatewayProvider), isA<GoogleAuthGateway>());
    expect(
      container.read(driveApiFactoryProvider)(FakeAuthSession()),
      isA<GoogleDriveApi>(),
    );
    expect(container.read(secureStoreProvider), isA<KeychainSecureStore>());
    expect(container.read(oauthConfigProvider).isConfigured, isTrue);
  });

  test('providers that must be supplied at start-up say so', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (final read in <Object Function()>[
      () => container.read(appPathsProvider),
      () => container.read(databaseProvider),
      () => container.read(initialSettingsProvider),
      () => container.read(driveApiProvider),
    ]) {
      expect(read, throwsA(anything));
    }
    expect(ProviderContainer().read(oauthConfigProvider).isConfigured, isFalse);
  });

  test('listing classes can be built at run time', () {
    final listings = <DriveListing Function()>[
      SharedListing.new,
      StarredListing.new,
      TrashListing.new,
      RecentListing.new,
      AllListing.new,
    ].map((create) => create()).toList();
    expect(listings.map((l) => l.key).toSet(), hasLength(5));
  });

  test('AppPaths.resolve finds per-user folders', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/platform/${call.method}',
        );

    final paths = await AppPaths.resolve();

    expect(paths.support, '/platform/getApplicationSupportDirectory');
    expect(paths.cache, '/platform/getApplicationCacheDirectory');
    expect(paths.defaultSyncRoot, endsWith('GDrive'));
    expect(paths.defaultSyncRoot, isNot(startsWith('/platform')));
  });
}

class _TokenOnlySession implements AuthSession {
  @override
  String serialize() => jsonEncode({
    'accessToken': {'data': 'only-access'},
    'refreshToken': null,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
