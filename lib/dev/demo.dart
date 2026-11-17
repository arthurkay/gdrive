import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../core/config/oauth_config.dart';
import '../core/secure/secure_store.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_gateway.dart';
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

/// A small Drive with one of each kind of file.
FakeDriveApi seededDrive() {
  final drive = FakeDriveApi();
  final docs = drive.addFolder('Documents');
  final reports = drive.addFolder('Reports', parentId: docs.id);
  final media = drive.addFolder('Media');
  drive.addFolder('Empty folder');
  drive.addFile(
    'README.md',
    '# Welcome to GDrive\n\nThis is the demo account. Nothing here touches '
        'a real Google Drive.\n\n- Double-click a file to preview it\n'
        '- Right-click for more actions\n- Drop files onto the list to upload\n',
  );
  drive.addFile(
    'notes.txt',
    'Meeting notes\n\n1. Ship the sync engine\n2. Test on Windows and macOS\n',
    parentId: docs.id,
  );
  drive.addFile(
    'config.json',
    '{\n  "name": "gdrive",\n  "sync": true,\n  "interval": 30\n}\n',
    parentId: docs.id,
    mimeType: 'application/json',
  );
  drive.addFile(
    'main.dart',
    "void main() {\n  print('Hello from the demo Drive');\n}\n",
    parentId: docs.id,
  );
  drive.addFile(
    'q3-summary.txt',
    'Revenue up, costs flat.',
    parentId: reports.id,
  );
  drive.addNative('Project plan', _tinyPdf, parentId: docs.id);
  drive.addNative(
    'Budget 2026',
    _tinyPdf,
    mimeType: 'application/vnd.google-apps.spreadsheet',
  );
  drive.addBytes(
    'one-page.pdf',
    utf8.encode(_tinyPdf),
    mimeType: 'application/pdf',
  );
  drive.addBytes(
    'gradient.png',
    base64Decode(_tinyPng),
    parentId: media.id,
    mimeType: 'image/png',
  );
  drive.addBytes(
    'archive.zip',
    List.filled(2048, 0),
    mimeType: 'application/zip',
  );
  return drive;
}

/// Provider overrides that swap Google for the in-memory fakes. Applied when
/// the app is built with `--dart-define=DEMO=true`.
List<Override> demoOverrides() {
  final drive = seededDrive();
  return [
    oauthConfigProvider.overrideWithValue(
      const OAuthConfig(clientId: 'demo', clientSecret: 'demo'),
    ),
    // Start signed in; signing out leads to the sign-in page as usual.
    secureStoreProvider.overrideWithValue(
      InMemorySecureStore()
        ..values[credentialsKey] = FakeAuthSession().serialize(),
    ),
    authGatewayProvider.overrideWithValue(FakeAuthGateway()),
    driveApiFactoryProvider.overrideWithValue((_) => drive),
  ];
}

const _tinyPng =
    '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'
    '8e/tfPMP/9bBNzr51y6+3s2/9PC1Xv65j6/2808DfGWQfxziy8N8aYTXRvniGK+O88oEL0'
    '/yhSlemubzM7w4y+fmeGGezy7w/CKfWeK5ZT69wrOrPLPG0+t8aoOnNvnkFk9u88QOj+/y'
    'iT0e0/FxPY8a+JiRR0x81MzDFj5i5SEbD9p5wMGHnXzIxf9z80EP/9fLB3z8g5/3B/j7IO'
    '8L8XcA74X4W5j3IPwNyrsx/hrnXSR/RfFOmr9keQfHX/C8XeDPRd4m8Wcyb1X5U423lPmT'
    'Cm+u8sc13lTnjxq8sckftnjDB3/wyeu/+P1vXvfD/wJlW23Z9/Zs80/2rSPb6My+dmXr3d'
    'mXnmytN/vcl632Z58GspXB7ONQtjycLY1ktdFscSyrjmeViaw8mS1MZaXpbH4mK85mc3NZ'
    'YT6bXcjyi9nMUpZbzqZXsuxqllnL0uvZ1EaW2swmt7LkdpbYyeK72cReFtNl4/osasjGjF'
    'nElI2as7AlG7FmIVsWtGcBRzbszIZc2X/ubNCT/evNBnzZB3/WH8jeB7O+UPYOyHqh7C2c'
    '9SDZGzTrxrLXeNZFZq+orJPOXrJZB5e94LN2IXsuZm1S9kzOWtXsqZa1lLMnlay5mj2uZU'
    '317FEja2xmD1tZw0f24DOr/8ruf2d1P9lfIKHVJry3C80/wluH0OgUXruEerfw0iPUeoXn'
    'PqHaLzwNCJVB4XFIKA8LpRFBGxWKY4I6LigTgjwpFKYEaVrIzwjirJCbE4R5Ibsg8ItCZk'
    'ngloX0isCuCsyaQK8LqQ2B2hSSWwK5LRA7Ar4rJPYETCfE9QJqEGJGATEJUbMAW4SIVYBs'
    'AmgXAIcQdgohl/DPLQQ9wl+vEPAJD37BHxDug4IvJNwBghcSbmHBgwg3qODGhGtccJHCFS'
    'U4aeGSFRyccMELdkE4FwWbJJzJglUVTjXBUhZOKoK5KhzXBFNdOGoIxqZw2BIMH8LBp6D/'
    'Eva/Bd2P8AuUa7Xl3ttzzT+5t45cozP32pWrd+deenK13txzX67an3sayFUGc49DufJwrj'
    'SS00ZzxbGcOp5TJnLyZK4wlZOmc/mZnDiby83lhPlcdiHHL+YySzluOZdeybGrOWYtR6/n'
    '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';

const _tinyPdf = '''%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
4 0 obj<</Length 68>>stream
BT /F1 28 Tf 72 700 Td (GDrive demo document) Tj ET
endstream
endobj
5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000052 00000 n 
0000000101 00000 n 
0000000209 00000 n 
0000000322 00000 n 
trailer<</Size 6/Root 1 0 R>>
startxref
383
%%EOF
''';
