import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/oauth_config.dart';
import '../../core/db/database.dart';
import '../../core/secure/secure_store.dart';
import '../../core/util/retry.dart';
import '../drive/drive_api.dart';
import '../drive/google_drive_api.dart';
import 'auth_gateway.dart';

const credentialsKey = 'oauth_credentials';
const accountKey = 'account';

sealed class AuthState {
  const AuthState();
}

/// No OAuth client was compiled in; the app shows setup instructions.
class AuthUnconfigured extends AuthState {
  const AuthUnconfigured();
}

class SignedOut extends AuthState {
  const SignedOut({this.error});
  final String? error;
}

class SignedIn extends AuthState {
  const SignedIn(this.account);
  final DriveAccount account;
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => GoogleAuthGateway(
    config: ref.watch(oauthConfigProvider),
    // coverage:ignore-start
    // Opens the system browser; needs a real desktop.
    openBrowser: (url) async {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    },
    // coverage:ignore-end
  ),
);

/// Builds the Drive client for a session. Overridden with a fake in tests.
final driveApiFactoryProvider = Provider<DriveApi Function(AuthSession)>(
  (ref) =>
      (session) => GoogleDriveApi(session.client),
);

/// The live session, or null when signed out.
class SessionHolder extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void set(AuthSession? session) => state = session;
}

final sessionProvider = NotifierProvider<SessionHolder, AuthSession?>(
  SessionHolder.new,
);

/// Drive client for the signed-in user. Only read while signed in.
final driveApiProvider = Provider<DriveApi>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) throw StateError('Not signed in');
  return ref.watch(driveApiFactoryProvider)(session);
});

class AuthController extends AsyncNotifier<AuthState> {
  StreamSubscription<void>? _refreshSub;

  SecureStore get _store => ref.read(secureStoreProvider);
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  Future<AuthState> build() async {
    ref.onDispose(() => _refreshSub?.cancel());
    if (!ref.watch(oauthConfigProvider).isConfigured) {
      return const AuthUnconfigured();
    }
    final stored = await _store.read(credentialsKey);
    if (stored == null) return const SignedOut();

    final AuthSession session;
    try {
      session = ref.read(authGatewayProvider).restore(stored);
    } catch (_) {
      await _store.delete(credentialsKey);
      return const SignedOut(error: 'Saved sign-in was unreadable');
    }
    _adopt(session);
    try {
      return SignedIn(await _loadAccount(session));
    } catch (e) {
      if (!isTransient(e)) {
        await _drop(session);
        return const SignedOut(error: 'Your session expired. Sign in again.');
      }
      // Offline: carry on with what we knew last time.
      final cached = await _db.getValue(accountKey);
      if (cached != null) return SignedIn(DriveAccount.decode(cached));
      await _drop(session, keepCredentials: true);
      return const SignedOut(error: 'Could not reach Google Drive');
    }
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    AuthSession? session;
    try {
      session = await ref.read(authGatewayProvider).signIn();
      await _store.write(credentialsKey, session.serialize());
      _adopt(session);
      state = AsyncData(SignedIn(await _loadAccount(session)));
    } catch (e) {
      if (session != null) await _drop(session);
      state = AsyncData(SignedOut(error: 'Sign-in failed: $e'));
    }
  }

  /// Revokes the grant and removes every trace of the account from this
  /// machine except the files already in the sync folder.
  Future<void> signOut() async {
    final session = ref.read(sessionProvider);
    if (session != null) {
      try {
        await ref.read(authGatewayProvider).revoke(session);
      } catch (_) {
        // Revocation is best effort; local sign-out still proceeds.
      }
      await _drop(session);
    } else {
      await _store.delete(credentialsKey);
    }
    await _db.wipe();
    state = const AsyncData(SignedOut());
  }

  /// Refreshes quota and profile.
  Future<void> reloadAccount() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    try {
      state = AsyncData(SignedIn(await _loadAccount(session)));
    } catch (_) {
      // Keep showing the previous figures.
    }
  }

  void _adopt(AuthSession session) {
    ref.read(sessionProvider.notifier).set(session);
    _refreshSub?.cancel();
    _refreshSub = session.refreshed.listen(
      (_) => _store.write(credentialsKey, session.serialize()),
    );
  }

  Future<void> _drop(
    AuthSession session, {
    bool keepCredentials = false,
  }) async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    ref.read(sessionProvider.notifier).set(null);
    session.close();
    if (!keepCredentials) await _store.delete(credentialsKey);
  }

  Future<DriveAccount> _loadAccount(AuthSession session) async {
    final account = await ref.read(driveApiFactoryProvider)(session).about();
    await _db.setValue(accountKey, account.encode());
    return account;
  }
}

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Placeholder returned while nobody is signed in, so widgets that are
/// about to be replaced by the sign-in page can still build.
const signedOutAccount = DriveAccount(email: '', displayName: '', rootId: '');

/// The signed-in account, or [signedOutAccount].
final accountProvider = Provider<DriveAccount>((ref) {
  final state = ref.watch(authProvider).value;
  return state is SignedIn ? state.account : signedOutAccount;
});
