import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/core/db/database.dart';
import 'package:gdrive/core/util/file_kind.dart';
import 'package:gdrive/core/util/format.dart';
import 'package:gdrive/core/util/hashing.dart';
import 'package:gdrive/core/util/names.dart';
import 'package:gdrive/core/util/retry.dart';
import 'package:http/http.dart' as http;

DriveItem item(String name, String mimeType) => DriveItem(
  id: name,
  name: name,
  mimeType: mimeType,
  trashed: false,
  starred: false,
  sharedWithMe: false,
);

void main() {
  group('sanitizeName', () {
    test('replaces characters that are illegal on any desktop', () {
      expect(sanitizeName('a/b\\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
      expect(sanitizeName('tab\there'), 'tab_here');
    });

    test('strips trailing dots and spaces', () {
      expect(sanitizeName('report. . '), 'report');
    });

    test('never returns an empty or relative name', () {
      expect(sanitizeName(''), '_');
      expect(sanitizeName('..'), '_');
      expect(sanitizeName('   '), '_');
    });

    test('prefixes names Windows reserves', () {
      expect(sanitizeName('CON'), '_CON');
      expect(sanitizeName('nul.txt'), '_nul.txt');
      expect(sanitizeName('console.txt'), 'console.txt');
    });
  });

  test('numberedName and conflictName keep the extension last', () {
    expect(numberedName('report.pdf', 2), 'report (2).pdf');
    expect(numberedName('README', 3), 'README (3)');
    expect(
      conflictName('report.pdf', DateTime(2026, 3, 9)),
      'report (conflicted copy 2026-03-09).pdf',
    );
  });

  test('isIgnoredLocalName covers temp and system files only', () {
    for (final name in [
      'movie.mp4.part',
      'x.TMP',
      '.notes.swp',
      '~\$budget.xlsx',
      '.~lock.doc#',
      '.DS_Store',
      'Thumbs.db',
      'desktop.ini',
    ]) {
      expect(isIgnoredLocalName(name), isTrue, reason: name);
    }
    for (final name in ['notes.txt', '.gitignore', 'part.txt']) {
      expect(isIgnoredLocalName(name), isFalse, reason: name);
    }
  });

  test('relative path helpers round-trip', () {
    final root = Directory.systemTemp.path;
    final abs = toAbsPath(root, 'a/b/c.txt');
    expect(toRelPath(root, abs), 'a/b/c.txt');
    expect(toAbsPath(root, ''), root);
    expect(relParent('a/b/c.txt'), 'a/b');
    expect(relParent('c.txt'), '');
    expect(relName('a/b/c.txt'), 'c.txt');
    expect(relJoin('', 'c.txt'), 'c.txt');
    expect(relJoin('a', 'c.txt'), 'a/c.txt');
  });

  test('formatBytes picks a readable unit', () {
    expect(formatBytes(null), '—');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(150 * 1024 * 1024), '150 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    expect(formatBytes(5000 * 1024 * 1024 * 1024), '4.9 TB');
  });

  test('formatDate shortens recent dates', () {
    final now = DateTime(2026, 11, 17, 15);
    expect(formatDate(null), '—');
    expect(formatDate(DateTime(2026, 11, 17, 9, 5), now: now), '09:05');
    expect(formatDate(DateTime(2026, 3, 2), now: now), '2 Mar');
    expect(formatDate(DateTime(2024, 3, 2), now: now), '2 Mar 2024');
  });

  test('formatDuration shows hours only when needed', () {
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
  });

  group('file kinds', () {
    test('classifies by MIME type, then extension', () {
      expect(fileKindOf(folderMimeType, 'x'), FileKind.folder);
      expect(fileKindOf('image/png', 'x.png'), FileKind.image);
      expect(fileKindOf('video/mp4', 'x'), FileKind.video);
      expect(fileKindOf('audio/mpeg', 'x'), FileKind.audio);
      expect(fileKindOf('application/pdf', 'x'), FileKind.pdf);
      expect(fileKindOf('application/octet-stream', 'x.PDF'), FileKind.pdf);
      expect(fileKindOf('text/plain', 'x'), FileKind.text);
      expect(fileKindOf('application/json', 'x'), FileKind.text);
      expect(fileKindOf('application/octet-stream', 'x.dart'), FileKind.text);
      expect(fileKindOf('application/zip', 'x.zip'), FileKind.other);
      expect(
        fileKindOf('application/vnd.google-apps.document', 'x'),
        FileKind.googleDoc,
      );
      expect(
        fileKindOf('application/vnd.google-apps.form', 'x'),
        FileKind.other,
      );
    });

    test('item helpers separate exportable from unsyncable types', () {
      final doc = item('Plan', 'application/vnd.google-apps.document');
      final form = item('Survey', 'application/vnd.google-apps.form');
      final folder = item('Docs', folderMimeType);
      expect(doc.isNative, isTrue);
      expect(doc.isUnsyncable, isFalse);
      expect(doc.kind, FileKind.googleDoc);
      expect(form.isNative, isFalse);
      expect(form.isUnsyncable, isTrue);
      expect(folder.isFolder, isTrue);
      expect(folder.isUnsyncable, isFalse);
    });

    test('every native type has an export target', () {
      for (final export in nativeExports.values) {
        expect(export.extension, startsWith('.'));
        expect(export.mimeType, isNotEmpty);
      }
    });

    test('highlight language follows the extension', () {
      expect(highlightLanguageOf('main.dart'), 'dart');
      expect(highlightLanguageOf('DATA.JSON'), 'json');
      expect(highlightLanguageOf('notes.txt'), isNull);
    });
  });

  group('withRetry', () {
    test('retries transient failures with growing delays', () async {
      final delays = <Duration>[];
      var attempts = 0;
      final result = await withRetry(
        () async {
          if (++attempts < 3) throw DriveApiException(503, 'busy');
          return 'ok';
        },
        retryIf: isTransient,
        sleep: (d) async => delays.add(d),
        random: Random(1),
      );
      expect(result, 'ok');
      expect(attempts, 3);
      expect(delays, hasLength(2));
      expect(delays[1], greaterThan(delays[0]));
    });

    test('gives up after the last attempt', () async {
      var attempts = 0;
      await expectLater(
        withRetry(
          () async {
            attempts++;
            throw DriveApiException(500, 'down');
          },
          retryIf: isTransient,
          maxAttempts: 3,
          sleep: (_) async {},
        ),
        throwsA(isA<DriveApiException>()),
      );
      expect(attempts, 3);
    });

    test('does not retry permanent failures', () async {
      var attempts = 0;
      await expectLater(
        withRetry(
          () async {
            attempts++;
            throw DriveApiException(404, 'gone');
          },
          retryIf: isTransient,
          sleep: (_) async {},
        ),
        throwsA(isA<DriveApiException>()),
      );
      expect(attempts, 1);
    });
  });

  test('isTransient recognises rate limits and network errors', () {
    expect(isTransient(DriveApiException(429, 'slow down')), isTrue);
    expect(isTransient(DriveApiException(502, 'bad gateway')), isTrue);
    expect(
      isTransient(DriveApiException(403, 'quota (userRateLimitExceeded)')),
      isTrue,
    );
    expect(isTransient(DriveApiException(403, 'forbidden')), isFalse);
    expect(isTransient(DriveApiException(401, 'unauthorised')), isFalse);
    expect(isTransient(const SocketException('offline')), isTrue);
    expect(isTransient(TimeoutException('slow')), isTrue);
    expect(isTransient(const HttpException('reset')), isTrue);
    expect(isTransient(http.ClientException('dns')), isTrue);
    expect(isTransient(StateError('bug')), isFalse);
  });

  test('DriveApiException describes itself', () {
    final error = DriveApiException(404, 'File not found');
    expect(error.isNotFound, isTrue);
    expect('$error', 'Drive error 404: File not found');
  });

  test('md5OfFile matches known digests for small and large files', () async {
    final dir = await Directory.systemTemp.createTemp('gdrive_hash_');
    addTearDown(() => dir.delete(recursive: true));
    final small = File('${dir.path}/small')..writeAsStringSync('hello');
    final large = File('${dir.path}/large')
      ..writeAsBytesSync(List.filled(5 * 1024 * 1024, 0));

    expect(await md5OfFile(small.path), '5d41402abc4b2a76b9719d911017c592');
    expect(await md5OfFile(large.path), '5f363e0e58a95f06cbe9bbc662c5dfb6');
  });
}
