import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../../core/config/oauth_config.dart';

/// A signed-in Google session: an HTTP client that attaches and refreshes
/// the access token, plus the credentials in a form that can be stored.
abstract interface class AuthSession {
  http.Client get client;

  /// Credentials as JSON, for the secure store.
  String serialize();

  /// Fires whenever the access token is refreshed.
  Stream<void> get refreshed;

  /// A currently valid access token, for players that fetch media directly.
  Future<String> accessToken();

  void close();
}

/// Boundary over Google's OAuth endpoints and the system browser.
abstract interface class AuthGateway {
  /// Runs the consent flow in the browser and returns the new session.
  Future<AuthSession> signIn();

  /// Rebuilds a session from [AuthSession.serialize] output.
  AuthSession restore(String serialized);

  Future<void> revoke(AuthSession session);
}

class AuthCancelledException implements Exception {
  @override
  String toString() => 'Sign-in was cancelled';
}

class GoogleAuthGateway implements AuthGateway {
  GoogleAuthGateway({
    required OAuthConfig config,
    required Future<void> Function(Uri url) openBrowser,
    http.Client Function()? httpClient,
  }) : _clientId = ClientId(config.clientId, config.clientSecret),
       _openBrowser = openBrowser,
       _newClient = httpClient ?? http.Client.new;

  final ClientId _clientId;
  final Future<void> Function(Uri url) _openBrowser;
  final http.Client Function() _newClient;

  @override
  Future<AuthSession> signIn() async {
    final base = _newClient();
    try {
      final credentials = await obtainAccessCredentialsViaUserConsent(
        _clientId,
        OAuthConfig.scopes,
        base,
        (url) => _openBrowser(Uri.parse(url)),
        customPostAuthPage: _donePage,
      );
      return GoogleAuthSession(_clientId, credentials, base);
    } catch (_) {
      base.close();
      rethrow;
    }
  }

  @override
  AuthSession restore(String serialized) => GoogleAuthSession(
    _clientId,
    AccessCredentials.fromJson(jsonDecode(serialized) as Map<String, dynamic>),
    _newClient(),
  );

  @override
  Future<void> revoke(AuthSession session) async {
    final json = jsonDecode(session.serialize()) as Map<String, dynamic>;
    final token = json['refreshToken'] ?? (json['accessToken'] as Map)['data'];
    final client = _newClient();
    try {
      await client.post(
        Uri.https('oauth2.googleapis.com', '/revoke'),
        body: {'token': token},
      );
    } finally {
      client.close();
    }
  }

  static const _donePage =
      '<!doctype html><html><body style="font-family:sans-serif;'
      'text-align:center;margin-top:4em"><h2>GDrive is signed in</h2>'
      '<p>You can close this tab and return to the app.</p></body></html>';
}

class GoogleAuthSession implements AuthSession {
  GoogleAuthSession(this._clientId, AccessCredentials credentials, this._base)
    : _client = autoRefreshingClient(_clientId, credentials, _base);

  final ClientId _clientId;
  final http.Client _base;
  final AutoRefreshingAuthClient _client;

  @override
  http.Client get client => _client;

  @override
  String serialize() => jsonEncode(_client.credentials.toJson());

  @override
  Stream<void> get refreshed => _client.credentialUpdates;

  @override
  Future<String> accessToken() async {
    final current = _client.credentials;
    if (!current.accessToken.hasExpired) return current.accessToken.data;
    // Standalone refresh; the auto-refreshing client refreshes itself again
    // on its next request.
    final fresh = await refreshCredentials(_clientId, current, _base);
    return fresh.accessToken.data;
  }

  @override
  void close() {
    _client.close();
    _base.close();
  }
}
