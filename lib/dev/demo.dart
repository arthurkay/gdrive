import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../core/config/oauth_config.dart';
import '../core/secure/secure_store.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_gateway.dart';
import 'demo_content.dart';
import 'fake_drive_api.dart';

/// A session that never touches the network.
class FakeAuthSession implements AuthSession {
  FakeAuthSession([this.token = 'fake-token']);

  final String token;
  bool closed = false;

  @override
  http.Client get client => http.Client();

  @override
  String serialize() => jsonEncode({'token': token});

  @override
  Stream<void> get refreshed => const Stream.empty();

  @override
  Future<String> accessToken() async => token;

  @override
  void close() => closed = true;
}

/// Sign-in that succeeds immediately, for the demo build and for tests.
class FakeAuthGateway implements AuthGateway {
  int signIns = 0;
  int revocations = 0;

  /// Set to make the next [signIn] or [restore] fail.
  Object? failWith;

  @override
  Future<AuthSession> signIn() async {
    if (failWith != null) throw failWith!;
    signIns++;
    return FakeAuthSession();
  }

  @override
  AuthSession restore(String serialized) {
    if (failWith != null) throw failWith!;
    return FakeAuthSession(
      (jsonDecode(serialized) as Map<String, dynamic>)['token'] as String,
    );
  }

  @override
  Future<void> revoke(AuthSession session) async => revocations++;
}

/// A small Drive with folders, pictures, documents and one of each kind
/// of file the app treats differently.
FakeDriveApi seededDrive() {
  final drive = FakeDriveApi();
  final docs = drive.addFolder('Documents');
  final reports = drive.addFolder('Reports', parentId: docs.id);
  final pictures = drive.addFolder('Pictures');
  final projects = drive.addFolder('Projects');
  drive.addFolder('Archive');

  drive.addFile(
    'README.md',
    '# Welcome to GDrive\n\nThis is the demo account. Nothing here touches '
        'a real Google Drive.\n\n- Double-click a file to preview it\n'
        '- Right-click for more actions\n- Drop files onto the list to upload\n',
  );
  drive.addFile('Team notes.md', demoNotes);
  drive.addBytes(
    'Quarterly report.pdf',
    buildPdf('Quarterly report', demoReportLines),
    mimeType: 'application/pdf',
  );
  drive.addNative(
    'Budget 2026',
    utf8.decode(buildPdf('Budget 2026', const ['Exported from Sheets.'])),
    mimeType: 'application/vnd.google-apps.spreadsheet',
  );
  drive.addBytes(
    'Backup.zip',
    List.filled(48 * 1024, 0),
    mimeType: 'application/zip',
  );

  drive.addFile(
    'Meeting notes.txt',
    'Meeting notes\n\n1. Ship the sync engine\n2. Test on Windows and macOS\n',
    parentId: docs.id,
  );
  drive.addFile(
    'settings.json',
    '{\n  "name": "gdrive",\n  "sync": true,\n  "interval": 30\n}\n',
    parentId: docs.id,
    mimeType: 'application/json',
  );
  drive.addNative(
    'Project plan',
    utf8.decode(buildPdf('Project plan', const ['Exported from Docs.'])),
    parentId: docs.id,
  );
  drive.addFile(
    'Q3 summary.txt',
    'Revenue up, costs flat.',
    parentId: reports.id,
  );

  drive.addFile('word_count.dart', demoCode, parentId: projects.id);
  drive.addFile(
    'build.sh',
    '#!/bin/sh\nset -e\nflutter test\nflutter build linux --release\n',
    parentId: projects.id,
  );

  for (final MapEntry(key: name, value: bytes) in demoPictures.entries) {
    drive.addBytes(name, bytes, parentId: pictures.id, mimeType: 'image/png');
  }
  return drive;
}

/// Provider overrides that swap Google for the in-memory fakes. Applied when
/// the app is built with `--dart-define=DEMO=true`.
List<Override> demoOverrides({FakeDriveApi? drive, bool signedIn = true}) {
  final api = drive ?? seededDrive();
  final store = InMemorySecureStore();
  // Start signed in unless asked otherwise; signing out leads to the
  // sign-in page as usual.
  if (signedIn) store.values[credentialsKey] = FakeAuthSession().serialize();
  return [
    oauthConfigProvider.overrideWithValue(
      const OAuthConfig(clientId: 'demo', clientSecret: 'demo'),
    ),
    secureStoreProvider.overrideWithValue(store),
    authGatewayProvider.overrideWithValue(FakeAuthGateway()),
    driveApiFactoryProvider.overrideWithValue((_) => api),
  ];
}
