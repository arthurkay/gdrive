import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/ui/adaptive/menu.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/format.dart';
import '../auth/auth_controller.dart';
import '../settings/settings.dart';
import '../sync/sync_banner.dart';
import '../sync/sync_controller.dart';
import 'browser_controller.dart';
import 'drive_actions.dart';
import 'item_visuals.dart';

/// How an item relates to the local sync folder.
enum SyncBadge { none, waiting, synced, localEdits }

SyncBadge badgeFor(
  DriveItem item, {
  required Set<String> selections,
  required Map<String, SyncEntry> entries,
  required bool parentInScope,
}) {
  final entry = entries[item.id];
  if (entry != null) {
    return entry.localEdited ? SyncBadge.localEdits : SyncBadge.synced;
  }
  if (item.isUnsyncable) return SyncBadge.none;
  return parentInScope || selections.contains(item.id)
      ? SyncBadge.waiting
      : SyncBadge.none;
}

/// The Drive file browser: breadcrumbs, search, toolbar, and the item list
/// or grid with selection, context menu, shortcuts and drop-to-upload.
class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  final _focus = FocusNode(debugLabel: 'browser');
  final _searchFocus = FocusNode(debugLabel: 'search');
  final _search = TextEditingController();
  bool _dropping = false;

  @override
  void dispose() {
    _focus.dispose();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browserProvider);
    final items = ref.watch(browserItemsProvider).value ?? const <DriveItem>[];
    final selections = ref.watch(selectionsProvider).value ?? const <String>{};
    final entries =
        ref.watch(syncEntriesProvider).value ?? const <String, SyncEntry>{};
    final rootId = ref.watch(accountProvider).rootId;
    final grid = ref.watch(settingsProvider.select((s) => s.gridView));
    final details = ref.watch(settingsProvider.select((s) => s.detailsPane));
    final style = AppStyle.of(context);
    final actions = DriveActions(context, ref);
    final browser = ref.read(browserProvider.notifier);

    if (_search.text != state.search && !_searchFocus.hasFocus) {
      _search.text = state.search;
    }

    final chosen = items.where((e) => state.selected.contains(e.id)).toList();
    final inTrash = state.section == DriveSection.trash;
    final parentInScope =
        !state.searching &&
        (state.section == DriveSection.myDrive || state.path.isNotEmpty) &&
        (selections.contains(rootId) ||
            state.path.any((f) => selections.contains(f.id)));
    SyncBadge badge(DriveItem item) => badgeFor(
      item,
      selections: selections,
      entries: entries,
      parentInScope: parentInScope,
    );

    List<AppMenuItem> menuFor(List<DriveItem> targets) {
      final icons = AppIcons.of(context);
      final single = targets.length == 1 ? targets.single : null;
      if (inTrash) {
        return [
          AppMenuItem(
            label: 'Restore',
            icon: icons.restore,
            onSelected: () => actions.restore(targets),
          ),
          AppMenuItem(
            label: 'Delete forever',
            icon: icons.trash,
            destructive: true,
            onSelected: () => actions.deleteForever(targets),
          ),
        ];
      }
      final allSelected = targets.every((e) => selections.contains(e.id));
      final allStarred = targets.every((e) => e.starred);
      return [
        if (single != null)
          AppMenuItem(
            label: single.isFolder ? 'Open' : 'Preview',
            icon: single.isFolder ? icons.folder : icons.file,
            onSelected: () => actions.open(single, items),
          ),
        AppMenuItem(
          label: 'Download…',
          icon: icons.download,
          onSelected: () => actions.download(targets),
        ),
        if (parentInScope)
          AppMenuItem(
            label: 'Synced with its folder',
            icon: icons.sync,
            enabled: false,
            onSelected: null,
          )
        else
          AppMenuItem(
            label: allSelected ? 'Stop syncing' : 'Sync to this computer',
            icon: icons.sync,
            onSelected: () => actions.setSynced(targets, !allSelected),
          ),
        const AppMenuItem.divider(),
        if (single != null)
          AppMenuItem(
            label: 'Rename…',
            icon: icons.rename,
            onSelected: () => actions.rename(single),
          ),
        AppMenuItem(
          label: 'Move…',
          icon: icons.move,
          onSelected: () => actions.move(targets),
        ),
        AppMenuItem(
          label: 'Make a copy',
          icon: icons.copy,
          enabled: targets.any((e) => !e.isFolder),
          onSelected: () => actions.copy(targets),
        ),
        AppMenuItem(
          label: allStarred ? 'Remove star' : 'Add star',
          icon: allStarred ? icons.star : icons.starred,
          onSelected: () => actions.setStarred(targets, !allStarred),
        ),
        const AppMenuItem.divider(),
        if (single != null) ...[
          AppMenuItem(
            label: 'Open in browser',
            icon: icons.openExternal,
            onSelected: () => actions.openInBrowser(single),
          ),
          AppMenuItem(
            label: 'Details',
            icon: icons.info,
            onSelected: () => actions.details(single),
          ),
        ],
        AppMenuItem(
          label: 'Move to Trash',
          icon: icons.trash,
          destructive: true,
          onSelected: () => actions.trash(targets),
        ),
      ];
    }

    void onTap(DriveItem item) {
      _focus.requestFocus();
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        browser.toggleSelected(item.id);
      } else if (keys.isShiftPressed && state.selected.isNotEmpty) {
        final from = items.indexWhere((e) => state.selected.contains(e.id));
        final to = items.indexOf(item);
        final range = from <= to
            ? items.sublist(from, to + 1)
            : items.sublist(to, from + 1);
        browser.selectAll(range.map((e) => e.id));
      } else {
        browser.selectOnly(item.id);
      }
    }

    void onContext(DriveItem item, Offset position) {
      _focus.requestFocus();
      final targets = state.selected.contains(item.id) ? chosen : [item];
      if (!state.selected.contains(item.id)) browser.selectOnly(item.id);
      showAppMenu(context, position: position, items: menuFor(targets));
    }

    final content = items.isEmpty
        ? _EmptyState(state: state)
        : grid
        ? _Grid(
            items: items,
            selected: state.selected,
            badge: badge,
            onTap: onTap,
            onOpen: (item) => actions.open(item, items),
            onContext: onContext,
          )
        : _ListView(
            items: items,
            state: state,
            badge: badge,
            onTap: onTap,
            onOpen: (item) => actions.open(item, items),
            onContext: onContext,
            onSort: browser.setSort,
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            browser.selectAll(items.map((e) => e.id)),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
            browser.selectAll(items.map((e) => e.id)),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            actions.upload,
        const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
            actions.upload,
        const SingleActivator(LogicalKeyboardKey.f5): browser.refresh,
        const SingleActivator(LogicalKeyboardKey.escape):
            browser.clearSelection,
        const SingleActivator(LogicalKeyboardKey.backspace): browser.goUp,
        if (chosen.length == 1) ...{
          const SingleActivator(LogicalKeyboardKey.f2): () =>
              inTrash ? null : actions.rename(chosen.single),
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              actions.open(chosen.single, items),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              actions.open(chosen.single, items),
        },
        if (chosen.isNotEmpty)
          const SingleActivator(LogicalKeyboardKey.delete): () =>
              inTrash ? actions.deleteForever(chosen) : actions.trash(chosen),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(child: _Breadcrumbs(state: state)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 240,
                      child: AppTextField(
                        controller: _search,
                        focusNode: _searchFocus,
                        placeholder: 'Search Drive',
                        prefixIcon: AppIcons.of(context).search,
                        onSubmitted: browser.setSearch,
                        onChanged: (text) {
                          if (text.isEmpty) browser.setSearch('');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _Toolbar(
                state: state,
                chosen: chosen,
                items: items,
                grid: grid,
                details: details,
                syncingAll: selections.contains(rootId),
                canAdd: browser.targetFolderId != null,
                menuFor: menuFor,
              ),
              SizedBox(
                height: 3,
                child: state.loading ? const AppProgressBar() : null,
              ),
              const SyncBanner(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: AppBanner(
                    kind: BannerKind.error,
                    message: 'Could not refresh: ${state.error}',
                    action: AppButton(
                      label: 'Retry',
                      onPressed: browser.refresh,
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DropTarget(
                          onDragEntered: (_) =>
                              setState(() => _dropping = true),
                          onDragExited: (_) =>
                              setState(() => _dropping = false),
                          onDragDone: (details) {
                            setState(() => _dropping = false);
                            actions.uploadPaths(
                              details.files.map((f) => f.path).toList(),
                            );
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              _focus.requestFocus();
                              browser.clearSelection();
                            },
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: _dropping
                                    ? Border.all(color: style.accent, width: 2)
                                    : null,
                              ),
                              child: content,
                            ),
                          ),
                        ),
                      ),
                      // Hidden in narrow windows so the files keep their room.
                      if (details && box.maxWidth >= 720)
                        DetailsPane(
                          title: state.searching
                              ? 'Search results'
                              : state.path.isEmpty
                              ? state.section.label
                              : state.path.last.name,
                          items: items,
                          chosen: chosen,
                          syncLabel: (item) => switch (badge(item)) {
                            SyncBadge.none => null,
                            SyncBadge.waiting => 'Waiting to sync',
                            SyncBadge.synced => 'Synced to this computer',
                            SyncBadge.localEdits =>
                              'Local edits are not uploaded',
                          },
                          onOpen: (item) => actions.open(item, items),
                          onDownload: actions.download,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Breadcrumbs extends ConsumerWidget {
  const _Breadcrumbs({required this.state});

  final BrowserState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final browser = ref.read(browserProvider.notifier);
    final crumbs = [state.section.label, ...state.path.map((f) => f.name)];
    final last = state.searching ? -1 : crumbs.length - 1;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(icons.chevron, size: 11, color: style.muted),
              ),
            Hoverable(
              builder: (context, hovered) => GestureDetector(
                onTap: i == last ? null : () => browser.goToDepth(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hovered && i != last ? style.hover : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    crumbs[i],
                    style: i == last
                        ? style.title.copyWith(fontSize: 17)
                        : style.body.copyWith(fontSize: 17, color: style.muted),
                  ),
                ),
              ),
            ),
          ],
          if (state.searching) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(icons.chevron, size: 11, color: style.muted),
            ),
            Text(
              'Results for "${state.search.trim()}"',
              style: style.title.copyWith(fontSize: 17),
            ),
          ],
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.state,
    required this.chosen,
    required this.items,
    required this.grid,
    required this.details,
    required this.syncingAll,
    required this.canAdd,
    required this.menuFor,
  });

  final BrowserState state;
  final List<DriveItem> chosen;
  final List<DriveItem> items;
  final bool grid;
  final bool details;
  final bool syncingAll;
  final bool canAdd;
  final List<AppMenuItem> Function(List<DriveItem>) menuFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icons = AppIcons.of(context);
    final style = AppStyle.of(context);
    final actions = DriveActions(context, ref);
    final browser = ref.read(browserProvider.notifier);
    final inTrash = state.section == DriveSection.trash;
    final atRoot =
        state.section == DriveSection.myDrive &&
        state.path.isEmpty &&
        !state.searching;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
      child: Row(
        children: [
          // The left group scrolls rather than overflowing in a narrow
          // window; the selection and view controls stay put on the right.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppIconButton(
                    icon: icons.up,
                    tooltip: 'Up one level',
                    onPressed: state.path.isEmpty ? null : browser.goUp,
                  ),
                  const SizedBox(width: 4),
                  if (inTrash)
                    AppButton(
                      label: 'Empty Trash',
                      icon: icons.trash,
                      onPressed: items.isEmpty ? null : actions.emptyTrash,
                    )
                  else ...[
                    AppButton(
                      label: 'Upload',
                      icon: icons.upload,
                      primary: true,
                      onPressed: canAdd ? actions.upload : null,
                    ),
                    const SizedBox(width: 6),
                    AppIconButton(
                      icon: icons.move,
                      tooltip: 'Upload a folder',
                      onPressed: canAdd ? actions.uploadFolder : null,
                    ),
                    AppIconButton(
                      icon: icons.newFolder,
                      tooltip: 'New folder',
                      onPressed: canAdd ? actions.newFolder : null,
                    ),
                  ],
                  if (atRoot) ...[
                    const SizedBox(width: 8),
                    AppButton(
                      label: syncingAll
                          ? 'Stop syncing all'
                          : 'Sync all of My Drive',
                      icon: icons.sync,
                      onPressed: () => actions.setSyncAll(!syncingAll),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (chosen.isNotEmpty) ...[
            Text('${chosen.length} selected', style: style.caption),
            const SizedBox(width: 8),
            if (chosen.length == 1 && !inTrash)
              AppIconButton(
                icon: icons.rename,
                tooltip: 'Rename',
                onPressed: () => actions.rename(chosen.single),
              ),
            if (!inTrash)
              AppIconButton(
                icon: icons.download,
                tooltip: 'Download',
                onPressed: () => actions.download(chosen),
              ),
            if (inTrash)
              AppIconButton(
                icon: icons.restore,
                tooltip: 'Restore',
                onPressed: () => actions.restore(chosen),
              ),
            AppIconButton(
              icon: icons.trash,
              tooltip: inTrash ? 'Delete forever' : 'Move to Trash',
              color: style.danger,
              onPressed: () => inTrash
                  ? actions.deleteForever(chosen)
                  : actions.trash(chosen),
            ),
            Builder(
              builder: (button) => AppIconButton(
                icon: icons.more,
                tooltip: 'More actions',
                onPressed: () {
                  final box = button.findRenderObject()! as RenderBox;
                  showAppMenu(
                    context,
                    position: box.localToGlobal(Offset(0, box.size.height)),
                    items: menuFor(chosen),
                  );
                },
              ),
            ),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: style.border,
            ),
          ],
          AppIconButton(
            icon: icons.refresh,
            tooltip: 'Refresh',
            onPressed: browser.refresh,
          ),
          AppIconButton(
            icon: grid ? icons.list : icons.grid,
            tooltip: grid ? 'List view' : 'Thumbnail view',
            onPressed: () =>
                ref.read(settingsProvider.notifier).setGridView(!grid),
          ),
          AppIconButton(
            icon: icons.info,
            tooltip: details ? 'Hide details' : 'Show details',
            color: details ? style.accent : null,
            onPressed: () =>
                ref.read(settingsProvider.notifier).setDetailsPane(!details),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  final BrowserState state;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final (title, hint) = state.loading
        ? ('Loading…', '')
        : state.searching
        ? ('No results', 'Nothing in your Drive matches that name.')
        : switch (state.section) {
            DriveSection.trash => ('Trash is empty', ''),
            DriveSection.starred => (
              'No starred items',
              'Star files to find them here.',
            ),
            DriveSection.shared => ('Nothing shared with you yet', ''),
            DriveSection.recent => ('No recent files', ''),
            DriveSection.myDrive => (
              'This folder is empty',
              'Drop files here or use Upload.',
            ),
          };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.of(context).folder,
            size: 44,
            color: style.muted.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(title, style: style.strong),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(hint, style: style.caption),
          ],
        ],
      ),
    );
  }
}

typedef _ItemCallback = void Function(DriveItem item);
typedef _ContextCallback = void Function(DriveItem item, Offset position);

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon(this.badge);

  final SyncBadge badge;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final (icon, color, label) = switch (badge) {
      SyncBadge.none => (null, null, ''),
      SyncBadge.waiting => (icons.sync, style.muted, 'Waiting to sync'),
      SyncBadge.synced => (icons.synced, style.success, 'Synced'),
      SyncBadge.localEdits => (
        icons.warning,
        style.warning,
        'Local edits not uploaded',
      ),
    };
    if (icon == null) return const SizedBox(width: 14);
    return Icon(icon, size: 14, color: color, semanticLabel: label);
  }
}

class _ItemGestures extends StatelessWidget {
  const _ItemGestures({
    required this.item,
    required this.onTap,
    required this.onOpen,
    required this.onContext,
    required this.child,
  });

  final DriveItem item;
  final _ItemCallback onTap;
  final _ItemCallback onOpen;
  final _ContextCallback onContext;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onTap(item),
    onDoubleTap: () => onOpen(item),
    onSecondaryTapUp: (d) => onContext(item, d.globalPosition),
    child: child,
  );
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.items,
    required this.state,
    required this.badge,
    required this.onTap,
    required this.onOpen,
    required this.onContext,
    required this.onSort,
  });

  final List<DriveItem> items;
  final BrowserState state;
  final SyncBadge Function(DriveItem) badge;
  final _ItemCallback onTap;
  final _ItemCallback onOpen;
  final _ContextCallback onContext;
  final void Function(SortField) onSort;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);

    Widget header(String label, SortField field) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSort(field),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: style.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.sort == field)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(state.ascending ? '↑' : '↓', style: style.caption),
            ),
        ],
      ),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: style.border)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 28),
              Expanded(child: header('Name', SortField.name)),
              SizedBox(
                width: 110,
                child: header('Modified', SortField.modified),
              ),
              SizedBox(width: 80, child: header('Size', SortField.size)),
              const SizedBox(width: 20),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: items.length,
            itemExtent: 36,
            itemBuilder: (context, i) {
              final item = items[i];
              final selected = state.selected.contains(item.id);
              return _ItemGestures(
                item: item,
                onTap: onTap,
                onOpen: onOpen,
                onContext: onContext,
                child: Hoverable(
                  builder: (context, hovered) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? style.selected
                          : hovered
                          ? style.hover
                          : null,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icons.forKind(item.kind),
                          size: 17,
                          color: kindColor(style, item.kind),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: style.body,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.starred)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    icons.starred,
                                    size: 11,
                                    color: style.warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            formatDate(item.modifiedTime),
                            style: style.caption,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            item.isFolder ? '—' : formatBytes(item.size),
                            style: style.caption,
                          ),
                        ),
                        SizedBox(width: 20, child: _BadgeIcon(badge(item))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.items,
    required this.selected,
    required this.badge,
    required this.onTap,
    required this.onOpen,
    required this.onContext,
  });

  final List<DriveItem> items;
  final Set<String> selected;
  final SyncBadge Function(DriveItem) badge;
  final _ItemCallback onTap;
  final _ItemCallback onOpen;
  final _ContextCallback onContext;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final folders = items.where((e) => e.isFolder).toList();
    final files = items.where((e) => !e.isFolder).toList();

    Widget heading(String text) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      sliver: SliverToBoxAdapter(child: Text(text, style: style.caption)),
    );

    Widget section(
      List<DriveItem> of, {
      required double maxWidth,
      required double height,
      required Widget Function(DriveItem item, bool selected, bool hovered)
      tile,
    }) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxWidth,
          mainAxisExtent: height,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: of.length,
        itemBuilder: (context, i) => _ItemGestures(
          item: of[i],
          onTap: onTap,
          onOpen: onOpen,
          onContext: onContext,
          child: Hoverable(
            builder: (context, hovered) =>
                tile(of[i], selected.contains(of[i].id), hovered),
          ),
        ),
      ),
    );

    BoxDecoration card(bool isSelected, bool hovered) => BoxDecoration(
      color: isSelected
          ? style.selected
          : hovered
          ? style.hover
          : style.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isSelected ? style.accent : style.border,
        width: isSelected ? 1.5 : 1,
      ),
    );

    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty) ...[
          heading('Folders'),
          section(
            folders,
            maxWidth: 250,
            height: 52,
            tile: (item, isSelected, hovered) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: card(isSelected, hovered),
              child: Row(
                children: [
                  Icon(
                    AppIcons.of(context).folder,
                    size: 20,
                    color: style.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: style.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _BadgeIcon(badge(item)),
                ],
              ),
            ),
          ),
        ],
        if (files.isNotEmpty) ...[
          heading('Files'),
          section(
            files,
            maxWidth: 220,
            height: 196,
            tile: (item, isSelected, hovered) => Container(
              clipBehavior: Clip.antiAlias,
              decoration: card(isSelected, hovered),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ItemThumbnail(item: item)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppIcons.of(context).forKind(item.kind),
                              size: 14,
                              color: kindColor(style, item.kind),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                item.name,
                                style: style.body.copyWith(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _BadgeIcon(badge(item)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          // Google Docs have no size; say what they are.
                          '${item.size == null ? kindLabel(item) : formatBytes(item.size)}'
                          ' · ${formatDate(item.modifiedTime)}',
                          style: style.caption.copyWith(fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}
