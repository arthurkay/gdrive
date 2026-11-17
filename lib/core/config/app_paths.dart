import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Directories the app owns. Resolved once at startup and overridden in tests.
class AppPaths {
  const AppPaths({
    required this.support,
    required this.cache,
    required this.defaultSyncRoot,
  });

  /// Database, lock file, recycle folder.
  final String support;

  /// Preview downloads; safe to delete at any time.
  final String cache;

  /// Suggested sync folder until the user picks one.
  final String defaultSyncRoot;

  String get database => p.join(support, 'gdrive.sqlite');
  String get lockFile => p.join(support, 'gdrive.lock');
  String get recycle => p.join(support, 'recycle');
  String get previewCache => p.join(cache, 'preview');

  static Future<AppPaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final cache = await getApplicationCacheDirectory();
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        support.path;
    return AppPaths(
      support: support.path,
      cache: cache.path,
      defaultSyncRoot: p.join(home, 'GDrive'),
    );
  }
}

final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('appPathsProvider must be overridden'),
);
