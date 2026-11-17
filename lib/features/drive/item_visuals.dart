import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/format.dart';
import '../../core/util/names.dart';
import '../auth/auth_controller.dart';
import '../settings/settings.dart';
import '../sync/sync_controller.dart';

/// Signature colour for each kind of file, so types can be told apart at a
/// glance in lists, grids and the details pane.
Color kindColor(AppStyle style, FileKind kind) => switch (kind) {
  FileKind.folder => style.accent,
  FileKind.image => const Color(0xFF8E44AD),
  FileKind.video => const Color(0xFFD64541),
  FileKind.audio => const Color(0xFFE67E22),
  FileKind.pdf => const Color(0xFFC0392B),
  FileKind.text => const Color(0xFF5D6D7E),
  FileKind.googleDoc => const Color(0xFF2E86DE),
  FileKind.other => style.muted,
};

/// Plain-language type, e.g. "PNG image" or "Google Sheets".
String kindLabel(DriveItem item) {
  final ext = p.extension(item.name).replaceFirst('.', '').toUpperCase();
  String withExt(String noun) =>
      ext.isEmpty ? noun : '$ext ${noun.toLowerCase()}';
  return switch (item.kind) {
    FileKind.folder => 'Folder',
    FileKind.image => withExt('Image'),
    FileKind.video => withExt('Video'),
    FileKind.audio => withExt('Audio'),
    FileKind.pdf => 'PDF document',
    FileKind.text => withExt('Text file'),
    FileKind.googleDoc => switch (item.mimeType.split('.').last) {
      'document' => 'Google Docs',
      'spreadsheet' => 'Google Sheets',
      'presentation' => 'Google Slides',
      _ => 'Google Drawings',
    },
    FileKind.other => withExt('File'),
  };
}

/// Asks Drive for a larger rendition than the default 220px thumbnail.
String largerThumbnail(String link, {int size = 480}) =>
    link.replaceFirst(RegExp(r'=s\d+$'), '=s$size');

/// Bearer header for Drive thumbnail images.
final thumbnailHeadersProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final session = ref.watch(sessionProvider);
      if (session == null) return const {};
      return {'Authorization': 'Bearer ${await session.accessToken()}'};
    });

/// The synced local copy of a file, if it has one.
final localCopyProvider = Provider.autoDispose.family<File?, String>((
  ref,
  fileId,
) {
  final entry = ref.watch(syncEntriesProvider).value?[fileId];
  if (entry == null || entry.isFolder) return null;
  final root = ref.watch(settingsProvider.select((s) => s.syncRoot));
  return File(toAbsPath(root, entry.relPath));
});

/// A picture of the item: the synced image itself, Drive's thumbnail, or a
/// tinted tile with the file-type icon when neither is available.
class ItemThumbnail extends ConsumerWidget {
  const ItemThumbnail({super.key, required this.item, this.iconSize = 44});

  final DriveItem item;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final color = kindColor(style, item.kind);
    final fallback = Container(
      color: color.withValues(alpha: style.isDark ? 0.18 : 0.10),
      alignment: Alignment.center,
      child: Icon(
        AppIcons.of(context).forKind(item.kind),
        size: iconSize,
        color: color,
      ),
    );
    if (item.isFolder) return fallback;

    final local = item.kind == FileKind.image
        ? ref.watch(localCopyProvider(item.id))
        : null;
    if (local != null) {
      return Image.file(
        local,
        fit: BoxFit.cover,
        cacheWidth: 480,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final link = item.thumbnailLink;
    final headers = ref.watch(thumbnailHeadersProvider).value;
    if (link == null || headers == null || headers.isEmpty) return fallback;
    return Image.network(
      largerThumbnail(link),
      headers: headers,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Side panel describing the selection: one item in full, several items in
/// total, or the current folder when nothing is selected.
class DetailsPane extends StatelessWidget {
  const DetailsPane({
    super.key,
    required this.title,
    required this.items,
    required this.chosen,
    required this.syncLabel,
    required this.onOpen,
    required this.onDownload,
  });

  /// Name of the folder or section being browsed.
  final String title;
  final List<DriveItem> items;
  final List<DriveItem> chosen;

  /// Sync state of an item in words, or null when it is not synced.
  final String? Function(DriveItem item) syncLabel;
  final void Function(DriveItem item) onOpen;
  final void Function(List<DriveItem> items) onDownload;

  static const width = 288.0;

  static int totalBytes(Iterable<DriveItem> items) =>
      items.fold(0, (sum, item) => sum + (item.size ?? 0));

  static String describe(Iterable<DriveItem> items) {
    final folders = items.where((e) => e.isFolder).length;
    final files = items.length - folders;
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    return [
      if (folders > 0) count(folders, 'folder', 'folders'),
      if (files > 0 || folders == 0) count(files, 'file', 'files'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 76, child: Text(label, style: style.caption)),
          Expanded(child: Text(value, style: style.body)),
        ],
      ),
    );

    Widget hero(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(aspectRatio: 16 / 10, child: child),
    );

    Widget summary(IconData icon, String heading, Iterable<DriveItem> of) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero(
              Container(
                color: style.accent.withValues(
                  alpha: style.isDark ? 0.18 : 0.10,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 56, color: style.accent),
              ),
            ),
            const SizedBox(height: 14),
            Text(heading, style: style.strong.copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            row('Contains', describe(of)),
            row('Total size', formatBytes(totalBytes(of))),
          ],
        );

    final List<Widget> children;
    if (chosen.isEmpty) {
      children = [summary(icons.folder, title, items)];
    } else if (chosen.length > 1) {
      children = [
        summary(icons.copy, '${chosen.length} items selected', chosen),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Download',
            icon: icons.download,
            onPressed: () => onDownload(chosen),
          ),
        ),
      ];
    } else {
      final item = chosen.single;
      final sync = syncLabel(item);
      children = [
        hero(ItemThumbnail(item: item, iconSize: 56)),
        const SizedBox(height: 14),
        Text(item.name, style: style.strong.copyWith(fontSize: 15)),
        const SizedBox(height: 2),
        Text(kindLabel(item), style: style.caption),
        const SizedBox(height: 10),
        if (!item.isFolder) row('Size', formatBytes(item.size)),
        row('Modified', formatDate(item.modifiedTime)),
        row('Owner', item.sharedWithMe ? 'Shared with me' : 'Me'),
        if (item.starred) row('Starred', 'Yes'),
        row('Sync', sync ?? 'Not synced to this computer'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!item.trashed)
              AppButton(
                label: item.isFolder ? 'Open' : 'Preview',
                primary: true,
                onPressed: () => onOpen(item),
              ),
            if (!item.trashed)
              AppButton(
                label: 'Download',
                icon: icons.download,
                onPressed: () => onDownload(chosen),
              ),
          ],
        ),
      ];
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(left: BorderSide(color: style.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
