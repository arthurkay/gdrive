import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../db/database.dart';

const _boundsKey = 'windowBounds';
const minimumWindowSize = Size(900, 580);
const defaultWindowSize = Size(1180, 760);

String encodeBounds(Rect r) =>
    [r.left, r.top, r.width, r.height].map((v) => v.round()).join(',');

/// Parses saved bounds, rejecting anything malformed or smaller than the
/// minimum window size.
Rect? decodeBounds(String? value) {
  final parts = value?.split(',').map(double.tryParse).toList();
  if (parts == null || parts.length != 4 || parts.contains(null)) return null;
  if (parts[2]! < minimumWindowSize.width ||
      parts[3]! < minimumWindowSize.height) {
    return null;
  }
  return Rect.fromLTWH(parts[0]!, parts[1]!, parts[2]!, parts[3]!);
}

// coverage:ignore-start
// Talks to the native window through window_manager; needs a real desktop.
/// Sizes and shows the window, restoring where the user last left it, and
/// keeps saving its bounds as they change.
Future<void> initWindow(AppDatabase db) async {
  await windowManager.ensureInitialized();
  final saved = decodeBounds(await db.getValue(_boundsKey));
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'GDrive',
      size: saved?.size ?? defaultWindowSize,
      minimumSize: minimumWindowSize,
      center: saved == null,
    ),
    () async {
      if (saved != null) await windowManager.setPosition(saved.topLeft);
      if (!Platform.isMacOS) {
        // macOS takes its icon from the app bundle.
        await windowManager.setIcon(
          p.join(
            p.dirname(Platform.resolvedExecutable),
            'data',
            'flutter_assets',
            'assets',
            'logo_256.png',
          ),
        );
      }
      await windowManager.show();
      await windowManager.focus();
    },
  );
  windowManager.addListener(_BoundsSaver(db));
}

class _BoundsSaver with WindowListener {
  _BoundsSaver(this._db);

  final AppDatabase _db;
  Timer? _debounce;

  void _save() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (await windowManager.isFullScreen() ||
          await windowManager.isMaximized()) {
        return;
      }
      await _db.setValue(
        _boundsKey,
        encodeBounds(await windowManager.getBounds()),
      );
    });
  }

  @override
  void onWindowResized() => _save();

  @override
  void onWindowMoved() => _save();
}

// coverage:ignore-end

/// Takes the lock that marks this as the only running copy. Returns null if
/// another copy holds it. Keep the returned handle open for the app's life.
Future<RandomAccessFile?> acquireInstanceLock(String path) async {
  final handle = await File(path).open(mode: FileMode.write);
  try {
    await handle.lock(FileLock.exclusive);
    return handle;
  } on FileSystemException {
    await handle.close();
    return null;
  }
}
