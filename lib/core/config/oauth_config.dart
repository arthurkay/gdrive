import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Google OAuth "Desktop app" client, supplied at build time with
/// `--dart-define-from-file=config/oauth.json`.
class OAuthConfig {
  const OAuthConfig({required this.clientId, required this.clientSecret});

  const OAuthConfig.fromEnvironment()
    : clientId = const String.fromEnvironment('GOOGLE_CLIENT_ID'),
      clientSecret = const String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  final String clientId;
  final String clientSecret;

  bool get isConfigured =>
      clientId.trim().isNotEmpty && !clientId.startsWith('YOUR_');

  static const scopes = [
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
}

final oauthConfigProvider = Provider<OAuthConfig>(
  (ref) => const OAuthConfig.fromEnvironment(),
);
