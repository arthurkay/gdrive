import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database.dart';
import '../core/util/file_kind.dart';
import '../features/auth/auth_controller.dart';
import '../features/drive/browser_controller.dart';
import '../features/preview/preview_page.dart';
import '../features/settings/settings.dart';
import '../features/sync/sync_controller.dart';
import '../shell/destinations.dart';
import 'fake_drive_api.dart';

/// What the demo should be showing once it has started, so a particular
/// view can be opened without anyone clicking. Used to take the README
/// screenshots (see `tool/screenshots.sh`).
///
/// Written as `key=value` pairs separated by `;`, for example
/// `grid;sync=Pictures;open=Pictures;select=Morning lake.png`.
class DemoScene {
  const DemoScene({
    this.signedOut = false,
    this.grid = false,
    this.hideDetails = false,
    this.theme,
    this.sync = const [],
    this.open = const [],
    this.select,
    this.page,
    this.preview,
  });

  /// Start on the sign-in page.
  final bool signedOut;

  /// Thumbnail view instead of the list.
  final bool grid;
  final bool hideDetails;
  final ThemePreference? theme;

  /// Top-level items to sync to the computer first.
  final List<String> sync;

  /// Folder path to open, outermost first.
  final List<String> open;

  /// Item in the opened folder to select.
  final String? select;

  /// Sidebar destination to finish on.
  final Destination? page;

  /// Item in the opened folder to open in the viewer.
  final String? preview;

  bool get isEmpty =>
      !signedOut &&
      !grid &&
      !hideDetails &&
      theme == null &&
      sync.isEmpty &&
      open.isEmpty &&
      select == null &&
      page == null &&
      preview == null;

  factory DemoScene.parse(String? source) {
    final values = <String, String>{};
    for (final part in (source ?? '').split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final at = trimmed.indexOf('=');
      values[at < 0 ? trimmed : trimmed.substring(0, at).trim()] = at < 0
          ? ''
          : trimmed.substring(at + 1).trim();
    }
    List<String> list(String key, String separator) => (values[key] ?? '')
        .split(separator)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    T? named<T extends Enum>(List<T> all, String key) =>
        all.where((e) => e.name == values[key]).firstOrNull;

    return DemoScene(
      signedOut: values.containsKey('signedout'),
      grid: values.containsKey('grid'),
      hideDetails: values.containsKey('nodetails'),
      theme: named(ThemePreference.values, 'theme'),
      sync: list('sync', ','),
      open: list('open', '/'),
      select: values['select'],
      page: named(Destination.values, 'page'),
      preview: values['preview'],
    );
  }
}

/// Wraps the demo app and plays a [DemoScene] once the user is signed in.
class DemoDirector extends ConsumerStatefulWidget {
  const DemoDirector({
    super.key,
    required this.scene,
    required this.drive,
    required this.child,
  });

  final DemoScene scene;
  final FakeDriveApi drive;
  final Widget child;

  @override
  ConsumerState<DemoDirector> createState() => _DemoDirectorState();
}

class _DemoDirectorState extends ConsumerState<DemoDirector> {
  static const _step = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    // Providers must not change while the first frame is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_play()));
  }

  /// Waits for [done], giving up quietly after a few seconds.
  Future<bool> _until(bool Function() done) async {
    for (var i = 0; i < 80; i++) {
      if (!mounted) return false;
      if (done()) return true;
      await Future<void>.delayed(_step);
    }
    return false;
  }

  Future<void> _play() async {
    final scene = widget.scene;
    final drive = widget.drive;
    final settings = ref.read(settingsProvider.notifier);
    if (scene.theme != null) await settings.setTheme(scene.theme!);
    if (scene.grid) await settings.setGridView(true);
    if (scene.hideDetails) await settings.setDetailsPane(false);
    if (scene.signedOut) return;
    if (!await _until(() => ref.read(authProvider).value is SignedIn)) return;

    // Sync first, so synced pictures can be their own thumbnails.
    final sync = ref.read(syncProvider.notifier);
    final synced = <String>[];
    for (final name in scene.sync) {
      final item = drive.find(name);
      if (item == null) continue;
      await sync.setSynced(item.id, true);
      if (!mounted) return;
      synced.add(item.id);
    }
    if (synced.isNotEmpty) {
      final entries = ref.read(databaseProvider);
      var count = -1;
      await _until(() {
        // Settled when a pass has finished and recorded the selections.
        entries.entries().then((rows) => count = rows.length);
        return count >= synced.length &&
            ref.read(syncProvider).phase == SyncPhase.idle &&
            ref.read(syncProvider).lastSync != null;
      });
    }
    if (!mounted) return;

    // Walk into the folder.
    final browser = ref.read(browserProvider.notifier);
    var parent = FakeDriveApi.rootId;
    for (final name in scene.open) {
      final folder = drive.find(name, parentId: parent);
      if (folder == null || !folder.isFolder) break;
      browser.openFolder(folder);
      parent = folder.id;
    }
    await browser.refresh();
    if (!mounted) return;

    DriveItem? inFolder(String? name) =>
        name == null ? null : drive.find(name, parentId: parent);

    final selected = inFolder(scene.select);
    if (selected != null) browser.selectOnly(selected.id);

    if (scene.page != null) ref.read(navProvider.notifier).go(scene.page!);

    final preview = inFolder(scene.preview);
    if (preview != null) {
      final navigator = _findNavigator();
      if (navigator == null) return;
      final siblings = drive.items
          .where((e) => e.parentId == parent && !e.isFolder && !e.trashed)
          .toList();
      unawaited(
        navigator.push(
          PreviewPage.route(
            navigator.context,
            item: preview,
            siblings: siblings,
          ),
        ),
      );
    }
  }

  /// The app's root navigator, found from here because the app owns it.
  NavigatorState? _findNavigator() {
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
