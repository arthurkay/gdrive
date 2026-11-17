import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/util/names.dart';

class LocalNode {
  const LocalNode({required this.isDir, this.size = 0, this.mtimeMs = 0});

  final bool isDir;
  final int size;
  final int mtimeMs;
}

/// Lists what is on disk inside the synced parts of [root], keyed by path
/// relative to it. Symlinks and editor/OS temp files are skipped.
Future<Map<String, LocalNode>> scanLocal({
  required String root,
  required Iterable<String> dirs,
  required Iterable<String> files,
}) async {
  final found = <String, LocalNode>{};

  Future<void> walk(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (isIgnoredLocalName(p.basename(entity.path))) continue;
      final rel = toRelPath(root, entity.path);
      if (entity is Directory) {
        found[rel] = const LocalNode(isDir: true);
        await walk(entity);
      } else if (entity is File) {
        final stat = await entity.stat();
        found[rel] = LocalNode(
          isDir: false,
          size: stat.size,
          mtimeMs: stat.modified.millisecondsSinceEpoch,
        );
      }
    }
  }

  // Skip scopes nested inside a broader one that is walked anyway.
  final roots = dirs.toSet();
  for (final dir in roots) {
    if (roots.any((o) => o != dir && (o.isEmpty || dir.startsWith('$o/')))) {
      continue;
    }
    final directory = Directory(toAbsPath(root, dir));
    if (!await directory.exists()) continue;
    if (dir.isNotEmpty) found[dir] = const LocalNode(isDir: true);
    await walk(directory);
  }
  for (final file in files) {
    final stat = await File(toAbsPath(root, file)).stat();
    if (stat.type == FileSystemEntityType.file) {
      found[file] = LocalNode(
        isDir: false,
        size: stat.size,
        mtimeMs: stat.modified.millisecondsSinceEpoch,
      );
    }
  }
  return found;
}
