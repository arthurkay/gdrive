import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../core/db/database.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/names.dart';
import '../auth/auth_controller.dart';
import '../settings/settings.dart';
import '../transfers/transfer_manager.dart';

/// Largest text file opened for editing; bigger ones are view-only.
const maxEditableBytes = 5 * 1024 * 1024;

/// A file ready for a viewer.
class PreviewSource {
  const PreviewSource({required this.file, required this.synced});

  final File file;

  /// True when [file] is the copy in the sync folder rather than a cached
  /// download.
  final bool synced;
}

/// Gets file bytes onto disk for the built-in viewers, preferring the synced
/// copy and otherwise downloading into the preview cache.
class PreviewService {
  PreviewService({
    required AppDatabase db,
    required TransferManager transfers,
    required String cacheDir,
    required String Function() syncRoot,
  }) : _db = db,
       _transfers = transfers,
       _cacheDir = cacheDir,
       _syncRoot = syncRoot;

  final AppDatabase _db;
  final TransferManager _transfers;
  final String _cacheDir;
  final String Function() _syncRoot;
  final Map<String, Future<File>> _inFlight = {};

  /// The synced local copy of [item], if it has one that is still on disk.
  Future<File?> syncedCopy(DriveItem item) async {
    final entries = await _db.entries();
    final entry = entries.where((e) => e.fileId == item.id).firstOrNull;
    if (entry == null || entry.isFolder) return null;
    final file = File(toAbsPath(_syncRoot(), entry.relPath));
    return await file.exists() ? file : null;
  }

  /// Google-native files are fetched as PDF so the PDF viewer can show them.
  Future<PreviewSource> open(DriveItem item) async {
    if (!item.isNative) {
      final local = await syncedCopy(item);
      if (local != null) return PreviewSource(file: local, synced: true);
    }
    final version = item.modifiedTime?.millisecondsSinceEpoch ?? 0;
    final ext = item.isNative ? '.pdf' : p.extension(item.name);
    final path = p.join(_cacheDir, '${item.id}_$version$ext');
    final cached = File(path);
    if (await cached.exists()) {
      return PreviewSource(file: cached, synced: false);
    }
    final file = await (_inFlight[path] ??= _transfers
        .download(
          item,
          path,
          exportMimeType: item.isNative ? 'application/pdf' : null,
        )
        // Block body on purpose: returning the removed future here would
        // make this future wait on itself.
        .whenComplete(() {
          _inFlight.remove(path);
        }));
    return PreviewSource(file: file, synced: false);
  }

  /// Saves edited text. A synced file is written in place and uploaded by
  /// the next sync pass; anything else is uploaded directly as a new
  /// revision. Returns true when the upload already happened.
  Future<bool> saveText(
    DriveItem item,
    PreviewSource source,
    String text,
  ) async {
    await source.file.writeAsString(text, flush: true);
    if (source.synced) return false;
    await _transfers.upload(source.file.path, replaceFileId: item.id);
    return true;
  }

  Future<void> clearCache() async {
    final dir = Directory(_cacheDir);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

final previewServiceProvider = Provider<PreviewService>(
  (ref) => PreviewService(
    db: ref.watch(databaseProvider),
    transfers: ref.watch(transferManagerProvider),
    cacheDir: ref.watch(appPathsProvider).previewCache,
    syncRoot: () => ref.read(settingsProvider).syncRoot,
  ),
);

/// Direct media URL plus auth header, so audio and video can stream instead
/// of downloading first.
final mediaStreamProvider =
    FutureProvider.family<({String url, Map<String, String> headers}), String>((
      ref,
      fileId,
    ) async {
      final token = await ref.read(sessionProvider)!.accessToken();
      return (
        url: 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
        headers: {'Authorization': 'Bearer $token'},
      );
    });
