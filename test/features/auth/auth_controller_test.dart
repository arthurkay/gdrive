import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/config/oauth_config.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/dev/demo.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/auth/auth_gateway.dart';
import 'package:gdrive/features/drive/drive_api.dart';
import 'package:googleapis_auth/auth_io.dart'
    show AccessCredentials, AccessToken;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/app_env.dart';

void main() {
  late AppEnv env;

  tearDown(() => env.dispose());

  Future<AuthState> start() => env.container().read(authProvider.future);

  test('without an OAuth client the app asks for setup', () async {
    env = AppEnv(configured: false);
    expect(await start(), isA<AuthUnconfigured>());
  });

  test('with no saved credentials the user is signed out', () async {
    env = AppEnv(signedIn: false);
    final state = await start();
    expect(state, isA<SignedOut>());
    expect((state as SignedOut).error, isNull);
  });

  test('saved credentials restore the session and cache the account', () async {
    env = AppEnv();
    final container = env.container();

    final state = await container.read(authProvider.future);

    expect((state as SignedIn).account.email, 'demo@example.com');
    expect(container.read(sessionProvider), isNotNull);
    expect(container.read(accountProvider).rootId, 'root-id');
    expect(container.read(driveApiProvider), same(env.drive));
    expect(await env.db.getValue(accountKey), contains('demo@example.com'));
  });

  test('unreadable credentials are discarded', () async {
    env = AppEnv();
    env.gateway.failWith = const FormatException('corrupt');

    final state = await start();

    expect((state as SignedOut).error, contains('unreadable'));
    expect(env.store.values, isEmpty);
  });

  test(
    'a rejected session signs the user out and clears credentials',
    () async {
      env = AppEnv();
      env.drive.failWhen = (_, _) => DriveApiException(401, 'invalid_grant');
      final container = env.container();

      final state = await container.read(authProvider.future);

      expect((state as SignedOut).error, contains('expired'));
      expect(env.store.values, isEmpty);
      expect(container.read(sessionProvider), isNull);
    },
  );

  test('offline with a cached account stays signed in', () async {
    env = AppEnv();
    await env.db.setValue(
      accountKey,
      const DriveAccount(
        email: 'cached@example.com',
        displayName: 'Cached',
        rootId: 'r',
      ).encode(),
    );
    env.drive.failWhen = (_, _) => const SocketException('offline');

    final state = await start();

    expect((state as SignedIn).account.email, 'cached@example.com');
    expect(env.store.values, isNotEmpty);
  });

  test('offline with nothing cached keeps credentials for next time', () async {
    env = AppEnv();
    env.drive.failWhen = (_, _) => const SocketException('offline');

    final state = await start();

    expect((state as SignedOut).error, contains('Could not reach'));
    expect(env.store.values, isNotEmpty);
  });

  test('signIn stores credentials and loads the account', () async {
    env = AppEnv(signedIn: false);
    final container = env.container();
    await container.read(authProvider.future);

    await container.read(authProvider.notifier).signIn();

    expect(container.read(authProvider).value, isA<SignedIn>());
    expect(env.gateway.signIns, 1);
    expect(env.store.values[credentialsKey], isNotNull);
  });

  test('a failed sign-in reports the error and stores nothing', () async {
    env = AppEnv(signedIn: false);
    env.gateway.failWith = AuthCancelledException();
    final container = env.container();
    await container.read(authProvider.future);

    await container.read(authProvider.notifier).signIn();

    final state = container.read(authProvider).value! as SignedOut;
    expect(state.error, contains('Sign-in was cancelled'));
    expect(env.store.values, isEmpty);
  });

  test('sign-in that cannot load the account is rolled back', () async {
    env = AppEnv(signedIn: false);
    final container = env.container();
    await container.read(authProvider.future);
    env.drive.failWhen = (_, _) => DriveApiException(500, 'down');

    await container.read(authProvider.notifier).signIn();

    expect(container.read(authProvider).value, isA<SignedOut>());
    expect(env.store.values, isEmpty);
    expect(container.read(sessionProvider), isNull);
  });

  test('signOut revokes, forgets credentials and wipes local data', () async {
    env = AppEnv();
    final container = env.container();
    await container.read(authProvider.future);
    await env.db.addSelection('x', env.now);
    final session = container.read(sessionProvider)! as FakeAuthSession;

    await container.read(authProvider.notifier).signOut();

    expect(container.read(authProvider).value, isA<SignedOut>());
    expect(env.gateway.revocations, 1);
    expect(session.closed, isTrue);
    expect(env.store.values, isEmpty);
    expect(await env.db.selections(), isEmpty);
    expect(await env.db.getValue(accountKey), isNull);
    expect(() => container.read(driveApiProvider), throwsA(anything));
    expect(container.read(accountProvider), same(signedOutAccount));
  });

  test('signOut without a live session still clears credentials', () async {
    env = AppEnv();
    env.drive.failWhen = (_, _) => const SocketException('offline');
    final container = env.container();
    await container.read(authProvider.future);

    await container.read(authProvider.notifier).signOut();

    expect(env.store.values, isEmpty);
  });

  test('reloadAccount refreshes quota and tolerates failure', () async {
    env = AppEnv();
    final container = env.container();
    await container.read(authProvider.future);
    final controller = container.read(authProvider.notifier);

    env.drive.account = const DriveAccount(
      email: 'demo@example.com',
      displayName: 'Demo User',
      rootId: 'root-id',
      usageBytes: 42,
    );
    await controller.reloadAccount();
    expect(container.read(accountProvider).usageBytes, 42);

    env.drive.failWhen = (_, _) => DriveApiException(500, 'down');
    await controller.reloadAccount();
    expect(container.read(accountProvider).usageBytes, 42);
  });

  test('DriveAccount survives encoding', () {
    const account = DriveAccount(
      email: 'e',
      displayName: 'n',
      rootId: 'r',
      usageBytes: 1,
      limitBytes: 2,
    );
    final decoded = DriveAccount.decode(account.encode());
    expect(decoded.email, 'e');
    expect(decoded.displayName, 'n');
    expect(decoded.rootId, 'r');
    expect(decoded.usageBytes, 1);
    expect(decoded.limitBytes, 2);
  });

  group('GoogleAuthGateway', () {
    const config = OAuthConfig(clientId: 'id', clientSecret: 'secret');
    String credentials({required DateTime expiry}) => jsonEncode(
      AccessCredentials(
        AccessToken('Bearer', 'access-1', expiry.toUtc()),
        'refresh-1',
        OAuthConfig.scopes,
      ).toJson(),
    );

    setUp(() => env = AppEnv());

    test(
      'a restored session serialises back and exposes a valid token',
      () async {
        final gateway = GoogleAuthGateway(
          config: config,
          openBrowser: (_) async {},
          httpClient: () => MockClient((_) async => http.Response('', 500)),
        );
        final stored = credentials(
          expiry: DateTime.now().add(const Duration(hours: 1)),
        );

        final session = gateway.restore(stored);

        expect(jsonDecode(session.serialize()), jsonDecode(stored));
        expect(await session.accessToken(), 'access-1');
        expect(session.client, isNotNull);
        expect(session.refreshed, isA<Stream<void>>());
        session.close();
      },
    );

    test('an expired token is refreshed on demand', () async {
      final requests = <http.Request>[];
      final gateway = GoogleAuthGateway(
        config: config,
        openBrowser: (_) async {},
        httpClient: () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'access_token': 'access-2',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final session = gateway.restore(
        credentials(expiry: DateTime.now().subtract(const Duration(hours: 1))),
      );

      expect(await session.accessToken(), 'access-2');
      expect(requests.single.bodyFields['refresh_token'], 'refresh-1');
      session.close();
    });

    test('revoke posts the refresh token to Google', () async {
      final requests = <http.Request>[];
      final gateway = GoogleAuthGateway(
        config: config,
        openBrowser: (_) async {},
        httpClient: () => MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );
      final session = gateway.restore(
        credentials(expiry: DateTime.now().add(const Duration(hours: 1))),
      );

      await gateway.revoke(session);

      expect(
        requests.single.url.toString(),
        'https://oauth2.googleapis.com/revoke',
      );
      expect(requests.single.bodyFields['token'], 'refresh-1');
      session.close();
    });

    test('AuthCancelledException reads plainly', () {
      expect('${AuthCancelledException()}', 'Sign-in was cancelled');
    });
  });
}
