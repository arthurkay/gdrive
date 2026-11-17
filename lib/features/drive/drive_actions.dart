import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/platform/system.dart';
import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/ui/adaptive/dialogs.dart';
import '../../core/ui/notice.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/format.dart';
import '../auth/auth_controller.dart';
import '../preview/preview_page.dart';
import '../sync/sync_controller.dart';
import 'browser_controller.dart';
import 'drive_api.dart';
import 'drive_repository.dart';

String _count(List<DriveItem> items) =>
    items.length == 1 ? '"${items.single.name}"' : '${items.length} items';

/// What the user can do to Drive items, with the prompts and feedback that
/// go with each. Shared by the toolbar, context menu and keyboard shortcuts.
class DriveActions {
  DriveActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  DriveRepository get _repo => ref.read(driveRepositoryProvider);
  BrowserController get _browser => ref.read(browserProvider.notifier);
  NoticeController get _notice => ref.read(noticeProvider.notifier);

  Future<void> _run(
    Future<void> Function() body, {
    String? done,
    bool refresh = false,
  }) async {
    try {
      await body();
      if (done != null) _notice.show(done);
    } catch (e) {
      _notice.show('$e', isError: true);
    }
    if (refresh) await _browser.refresh();
  }

  Future<void> _each(
    List<DriveItem> items,
    Future<void> Function(DriveItem) action, {
    required String done,
  }) => _run(() async {
    for (final item in items) {
      await action(item);
    }
    _browser.clearSelection();
  }, done: done);

  void open(DriveItem item, List<DriveItem> siblings) {
    if (item.isFolder) {
      if (!item.trashed) _browser.openFolder(item);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      PreviewPage.route(
        context,
        item: item,
        siblings: siblings.where((e) => !e.isFolder).toList(),
      ),
    );
  }

  Future<void> newFolder() async {
    final parent = _browser.targetFolderId;
    if (parent == null) return;
    final name = await showPrompt(
      context,
      title: 'New folder',
      placeholder: 'Folder name',
      confirmLabel: 'Create',
    );
    if (name == null) return;
    await _run(() => _repo.createFolder(name, parent), done: 'Created "$name"');
  }

  Future<void> upload() async {
    if (_browser.targetFolderId == null) return;
    final paths = await ref.read(filePickerProvider).pickFiles();
    if (paths.isNotEmpty) await uploadPaths(paths);
  }

  Future<void> uploadFolder() async {
    if (_browser.targetFolderId == null) return;
    final path = await ref.read(filePickerProvider).pickDirectory();
    if (path != null) await uploadPaths([path]);
  }

  /// Also the target of drag-and-drop from the desktop.
  Future<void> uploadPaths(List<String> paths) async {
    final parent = _browser.targetFolderId;
    if (parent == null) {
      _notice.show('Open a folder in My Drive to upload into', isError: true);
      return;
    }
    _notice.show(
      'Uploading ${paths.length == 1 ? '1 item' : '${paths.length} items'}…',
    );
    await _run(() async {
      final failed = await _repo.uploadPaths(paths, parent);
      _notice.show(
        failed == 0 ? 'Upload complete' : '$failed uploads failed',
        isError: failed > 0,
      );
    }, refresh: true);
  }

  Future<void> download(List<DriveItem> items) async {
    final dir = await ref.read(filePickerProvider).pickDirectory();
    if (dir == null) return;
    _notice.show('Downloading ${_count(items)}…');
    await _run(() async {
      var failed = 0;
      for (final item in items) {
        failed += await _repo.downloadTo(item, dir);
      }
      _notice.show(
        failed == 0 ? 'Download complete' : '$failed downloads failed',
        isError: failed > 0,
      );
    });
  }

  Future<void> rename(DriveItem item) async {
    final name = await showPrompt(
      context,
      title: 'Rename',
      initial: item.name,
      confirmLabel: 'Rename',
    );
    if (name == null || name == item.name) return;
    await _run(() => _repo.rename(item, name));
  }

  Future<void> move(List<DriveItem> items) async {
    final target = await pickFolder(
      context,
      ref,
      title: 'Move ${_count(items)} to…',
      exclude: items.map((e) => e.id).toSet(),
    );
    if (target == null) return;
    await _each(items, (item) => _repo.move(item, target), done: 'Moved');
  }

  Future<void> copy(List<DriveItem> items) => _each(
    items.where((e) => !e.isFolder).toList(),
    _repo.copy,
    done: 'Copy created',
  );

  Future<void> setStarred(List<DriveItem> items, bool starred) => _each(
    items,
    (item) => _repo.setStarred(item, starred),
    done: starred ? 'Added to Starred' : 'Removed from Starred',
  );

  Future<void> trash(List<DriveItem> items) =>
      _each(items, _repo.trash, done: 'Moved ${_count(items)} to Trash');

  Future<void> restore(List<DriveItem> items) =>
      _each(items, _repo.restore, done: 'Restored ${_count(items)}');

  Future<void> deleteForever(List<DriveItem> items) async {
    final confirmed = await showConfirm(
      context,
      title: 'Delete forever?',
      message:
          '${_count(items)} will be permanently deleted from Google Drive. '
          'This cannot be undone.',
      confirmLabel: 'Delete forever',
    );
    if (!confirmed) return;
    await _each(items, _repo.deleteForever, done: 'Deleted ${_count(items)}');
  }

  Future<void> emptyTrash() async {
    final confirmed = await showConfirm(
      context,
      title: 'Empty Trash?',
      message:
          'Everything in Trash will be permanently deleted from Google '
          'Drive. This cannot be undone.',
      confirmLabel: 'Empty Trash',
    );
    if (confirmed) await _run(_repo.emptyTrash, done: 'Trash emptied');
  }

  Future<void> setSynced(List<DriveItem> items, bool synced) async {
    final sync = ref.read(syncProvider.notifier);
    for (final item in items) {
      await sync.setSynced(item.id, synced);
    }
    _notice.show(
      synced
          ? 'Syncing ${_count(items)} to this computer'
          : 'Stopped syncing ${_count(items)}; local files were kept',
    );
  }

  Future<void> setSyncAll(bool synced) async {
    await ref
        .read(syncProvider.notifier)
        .setSynced(ref.read(accountProvider).rootId, synced);
    _notice.show(
      synced
          ? 'Syncing all of My Drive to this computer'
          : 'Stopped syncing all of My Drive; local files were kept',
    );
  }

  Future<void> openInBrowser(DriveItem item) async {
    final link = item.webViewLink;
    if (link == null) {
      _notice.show('No web link for this item', isError: true);
      return;
    }
    await _run(() => ref.read(launcherProvider)(Uri.parse(link)));
  }

  Future<void> details(DriveItem item) {
    final style = AppStyle.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: style.caption)),
          Expanded(child: Text(value, style: style.body)),
        ],
      ),
    );
    return showAppDialog(
      context,
      title: item.name,
      cancelLabel: null,
      confirmLabel: 'Close',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('Type', item.isFolder ? 'Folder' : item.mimeType),
          row('Size', formatBytes(item.size)),
          row('Modified', item.modifiedTime?.toLocal().toString() ?? '—'),
          row('Starred', item.starred ? 'Yes' : 'No'),
          row('Shared', item.sharedWithMe ? 'Shared with me' : 'Owned by me'),
        ],
      ),
    );
  }
}

/// Lets the user walk My Drive and choose a destination folder. Returns the
/// folder id, or null when cancelled.
Future<String?> pickFolder(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  Set<String> exclude = const {},
}) async {
  final rootId = ref.read(accountProvider).rootId;
  final current = ValueNotifier<String>(rootId);
  final confirmed = await showAppDialog(
    context,
    title: title,
    confirmLabel: 'Move here',
    content: SizedBox(
      width: 380,
      height: 300,
      child: _FolderPicker(rootId: rootId, exclude: exclude, current: current),
    ),
  );
  final chosen = current.value;
  current.dispose();
  return confirmed ? chosen : null;
}

final _foldersProvider = StreamProvider.autoDispose
    .family<List<DriveItem>, String>((ref, parentId) {
      final repo = ref.watch(driveRepositoryProvider);
      repo.refresh(FolderListing(parentId)).catchError((_) {});
      return repo
          .watch(FolderListing(parentId))
          .map(
            (items) => sortItems(
              items.where((e) => e.isFolder).toList(),
              SortField.name,
              true,
            ),
          );
    });

class _FolderPicker extends ConsumerStatefulWidget {
  const _FolderPicker({
    required this.rootId,
    required this.exclude,
    required this.current,
  });

  final String rootId;
  final Set<String> exclude;
  final ValueNotifier<String> current;

  @override
  ConsumerState<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<_FolderPicker> {
  final List<DriveItem> _path = [];

  String get _currentId => _path.isEmpty ? widget.rootId : _path.last.id;

  void _go(void Function() change) {
    setState(change);
    widget.current.value = _currentId;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final folders = ref.watch(_foldersProvider(_currentId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconButton(
              icon: icons.up,
              tooltip: 'Up one level',
              onPressed: _path.isEmpty ? null : () => _go(_path.removeLast),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _path.isEmpty ? 'My Drive' : _path.last.name,
                style: style.strong,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: style.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: folders.when(
              loading: () => const Center(child: AppSpinner()),
              error: (e, _) => Center(child: Text('$e', style: style.caption)),
              data: (items) {
                final visible = items
                    .where((e) => !widget.exclude.contains(e.id))
                    .toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text('No folders here', style: style.caption),
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) => Hoverable(
                    builder: (context, hovered) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(() => _path.add(visible[i])),
                      child: Container(
                        color: hovered ? style.hover : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(icons.folder, size: 16, color: style.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                visible[i].name,
                                style: style.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(icons.chevron, size: 12, color: style.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
