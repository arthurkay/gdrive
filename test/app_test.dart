import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/platform/ui_kit.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:gdrive/features/auth/auth_controller.dart';
import 'package:gdrive/features/auth/auth_gateway.dart';
import 'package:gdrive/features/settings/settings.dart';
import 'package:gdrive/shell/destinations.dart';

import 'support/app_env.dart';
import 'support/pump.dart';

void main() {
  late AppEnv env;

  tearDown(() => env.dispose());

  for (final kit in UiKit.values) {
    group('${kit.name} kit', () {
      testWidgets('asks for setup when no OAuth client is configured', (
        tester,
      ) async {
        env = AppEnv(configured: false);
        await pumpGDrive(tester, env, kit: kit);

        expect(find.text('Google sign-in is not set up yet'), findsOneWidget);
        expect(find.textContaining('config/oauth.json'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('signs in from the sign-in page and shows the Drive', (
        tester,
      ) async {
        env = AppEnv(signedIn: false);
        env.drive.addFile('welcome.txt', 'hi');
        await pumpGDrive(tester, env, kit: kit);
        expect(find.text('Sign in with Google'), findsOneWidget);

        await tester.tap(find.text('Sign in with Google'));
        await settle(tester);

        expect(find.text('welcome.txt'), findsOneWidget);
        expect(find.text('demo@example.com'), findsOneWidget);
        expect(env.gateway.signIns, 1);
        await unmount(tester);
      });

      testWidgets('shows why sign-in failed', (tester) async {
        env = AppEnv(signedIn: false);
        env.gateway.failWith = AuthCancelledException();
        await pumpGDrive(tester, env, kit: kit);

        await tester.tap(find.text('Sign in with Google'));
        await settle(tester);

        expect(find.textContaining('Sign-in was cancelled'), findsOneWidget);
        expect(find.text('Sign in with Google'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('restores a saved session straight into the shell', (
        tester,
      ) async {
        env = AppEnv();
        env.drive.addFolder('Documents');
        await pumpGDrive(tester, env, kit: kit);

        expect(find.text('Documents'), findsOneWidget);
        for (final destination in Destination.values) {
          expect(find.text(destination.label), findsWidgets);
        }
        await unmount(tester);
      });

      testWidgets('every sidebar destination opens its page', (tester) async {
        env = AppEnv();
        final container = await pumpGDrive(tester, env, kit: kit);

        Future<void> go(Destination d) async {
          await tester.tap(find.text(d.label).first);
          await settle(tester);
          expect(container.read(navProvider), d);
        }

        await go(Destination.transfers);
        expect(
          find.text('Uploads and downloads will appear here'),
          findsOneWidget,
        );
        await go(Destination.activity);
        expect(find.text('Sync now'), findsOneWidget);
        await go(Destination.settings);
        expect(find.text('Sync folder'), findsOneWidget);
        await go(Destination.trash);
        expect(find.text('Trash is empty'), findsOneWidget);
        await go(Destination.starred);
        expect(find.text('No starred items'), findsOneWidget);
        await go(Destination.shared);
        expect(find.text('Nothing shared with you yet'), findsOneWidget);
        await go(Destination.recent);
        expect(find.text('No recent files'), findsOneWidget);
        await go(Destination.myDrive);
        expect(find.text('This folder is empty'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('signing out returns to the sign-in page', (tester) async {
        env = AppEnv();
        final container = await pumpGDrive(tester, env, kit: kit);

        await tester.runAsync(
          () => container.read(authProvider.notifier).signOut(),
        );
        await settle(tester);

        expect(find.text('Sign in with Google'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('follows the theme preference', (tester) async {
        env = AppEnv();
        env.settings = env.settings.copyWith(theme: ThemePreference.dark);
        final container = await pumpGDrive(tester, env, kit: kit);
        expect(find.text('My Drive'), findsWidgets);

        await container
            .read(settingsProvider.notifier)
            .setTheme(ThemePreference.light);
        await settle(tester);
        expect(find.text('My Drive'), findsWidgets);
        await unmount(tester);
      });
    });
  }

  testWidgets('an expired session lands on sign-in with an explanation', (
    tester,
  ) async {
    env = AppEnv();
    env.drive.failWhen = (_, _) => DriveApiException(401, 'invalid_grant');
    await pumpGDrive(tester, env);

    expect(find.textContaining('session expired'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the transfers badge counts work in flight', (tester) async {
    env = AppEnv();
    final container = await pumpGDrive(tester, env);
    expect(container.read(activeTransfersProvider), 0);
    await unmount(tester);
  });
}
