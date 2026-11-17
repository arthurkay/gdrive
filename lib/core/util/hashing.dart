import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

const _isolateThreshold = 4 * 1024 * 1024;

Future<String> _hash(String path) async =>
    (await md5.bind(File(path).openRead()).first).toString();

/// MD5 of a file, the checksum Drive reports. Large files are hashed off the
/// UI isolate.
Future<String> md5OfFile(String path) async {
  final size = await File(path).length();
  return size < _isolateThreshold
      ? _hash(path)
      : Isolate.run(() => _hash(path));
}
