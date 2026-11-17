import '../../core/db/database.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/names.dart';

/// Folder that holds selected items living outside "My Drive".
const sharedFolderName = 'Shared with me';

/// Where every in-scope Drive item belongs below the sync root.
class RemoteTree {
  final Map<String, DriveItem> byPath = {};
  final Map<String, String> pathById = {};

  /// Folders whose whole subtree is synced; new local files inside them are
  /// uploaded. The empty string is the sync root itself.
  final Set<String> scopeDirs = {};

  /// Paths of individually selected files.
  final Set<String> scopeFiles = {};

  /// Selections that no longer exist on Drive.
  final List<String> staleSelections = [];

  void add(String path, DriveItem item) {
    byPath[path] = item;
    pathById[item.id] = path;
  }

  void move(String from, String to, DriveItem item) {
    byPath.remove(from);
    add(to, item);
  }

  bool inScope(String path) {
    if (scopeFiles.contains(path)) return true;
    for (final dir in scopeDirs) {
      if (dir.isEmpty || path == dir || path.startsWith('$dir/')) return true;
    }
    return false;
  }

  /// In-scope items strictly below [path].
  Iterable<DriveItem> descendants(String path) => byPath.entries
      .where((e) => e.key.startsWith('$path/'))
      .map((e) => e.value);
}

/// Name an item takes on disk: sanitised, with the export extension for
/// Google-native files.
String localNameOf(DriveItem item) {
  final name = sanitizeName(item.name);
  final ext = nativeExports[item.mimeType]?.extension;
  return ext == null || name.toLowerCase().endsWith(ext) ? name : '$name$ext';
}

/// Maps the cached Drive [items] selected by [selections] onto local paths.
RemoteTree buildRemoteTree({
  required Iterable<DriveItem> items,
  required Iterable<String> selections,
  required String rootId,
}) {
  final byId = <String, DriveItem>{};
  final childrenOf = <String, List<DriveItem>>{};
  for (final item in items) {
    if (item.trashed) continue;
    byId[item.id] = item;
    if (item.parentId != null) {
      childrenOf.putIfAbsent(item.parentId!, () => []).add(item);
    }
  }

  // Drive allows siblings with the same name; disk does not. The lowest id
  // keeps the name and the rest are numbered, which is stable across runs.
  final names = <String, String>{};
  for (final siblings in childrenOf.values) {
    siblings.sort((a, b) => a.id.compareTo(b.id));
    final used = <String>{};
    for (final item in siblings) {
      final base = localNameOf(item);
      var name = base;
      for (var n = 2; !used.add(name.toLowerCase()); n++) {
        name = numberedName(base, n);
      }
      names[item.id] = name;
    }
  }
  String nameOf(DriveItem item) => names[item.id] ?? localNameOf(item);

  String? pathOf(DriveItem item) {
    final segments = <String>[];
    DriveItem? current = item;
    for (var depth = 0; current != null && depth < 512; depth++) {
      if (current.id == rootId) return segments.reversed.join('/');
      segments.add(nameOf(current));
      final parent = current.parentId;
      if (parent == rootId) return segments.reversed.join('/');
      current = parent == null ? null : byId[parent];
    }
    return null;
  }

  final tree = RemoteTree();

  // Drive metadata can contain parent cycles; visit each folder once.
  final visited = <String>{};
  void addSubtree(DriveItem folder, String path) {
    if (!visited.add(folder.id)) return;
    for (final child in childrenOf[folder.id] ?? const <DriveItem>[]) {
      if (child.isUnsyncable) continue;
      final childPath = relJoin(path, nameOf(child));
      tree.add(childPath, child);
      if (child.isFolder) addSubtree(child, childPath);
    }
  }

  // Broad selections first, so a file inside a selected folder is not also
  // treated as a separate selection.
  int rank(String id) => id == rootId
      ? 0
      : (byId[id]?.isFolder ?? false)
      ? 1
      : 2;
  final ordered = selections.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  for (final id in ordered) {
    if (id == rootId) {
      tree.scopeDirs.add('');
      for (final child in childrenOf[rootId] ?? const <DriveItem>[]) {
        if (child.isUnsyncable) continue;
        final path = nameOf(child);
        tree.add(path, child);
        if (child.isFolder) addSubtree(child, path);
      }
      continue;
    }
    final item = byId[id];
    if (item == null || item.isUnsyncable) {
      tree.staleSelections.add(id);
      continue;
    }
    if (tree.pathById.containsKey(id)) {
      if (item.isFolder) tree.scopeDirs.add(tree.pathById[id]!);
      continue;
    }
    final path = pathOf(item) ?? '$sharedFolderName/${nameOf(item)}';
    tree.add(path, item);
    if (item.isFolder) {
      tree.scopeDirs.add(path);
      visited.remove(item.id);
      addSubtree(item, path);
    } else {
      tree.scopeFiles.add(path);
    }
  }
  return tree;
}
