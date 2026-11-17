import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/util/file_kind.dart';
import '../auth/auth_controller.dart';
import 'drive_api.dart';
import 'drive_repository.dart';

enum DriveSection {
  myDrive('My Drive'),
  shared('Shared with me'),
  recent('Recent'),
  starred('Starred'),
  trash('Trash');

  const DriveSection(this.label);
  final String label;
}

enum SortField { name, modified, size }

class BrowserState {
  const BrowserState({
    this.section = DriveSection.myDrive,
    this.path = const [],
    this.search = '',
    this.selected = const {},
    this.sort = SortField.name,
    this.ascending = true,
    this.loading = false,
    this.error,
  });

  final DriveSection section;

  /// Folders opened below the section root, outermost first.
  final List<DriveItem> path;
  final String search;
  final Set<String> selected;
  final SortField sort;
  final bool ascending;
  final bool loading;
  final String? error;

  bool get searching => search.trim().isNotEmpty;

  BrowserState copyWith({
    DriveSection? section,
    List<DriveItem>? path,
    String? search,
    Set<String>? selected,
    SortField? sort,
    bool? ascending,
    bool? loading,
    String? Function()? error,
  }) => BrowserState(
    section: section ?? this.section,
    path: path ?? this.path,
    search: search ?? this.search,
    selected: selected ?? this.selected,
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
  );
}

class BrowserController extends Notifier<BrowserState> {
  int _request = 0;

  @override
  BrowserState build() {
    // Start over for each session; nothing to load while signed out.
    if (ref.watch(sessionProvider) != null) Future.microtask(refresh);
    return const BrowserState();
  }

  String get _rootId => ref.read(accountProvider).rootId;

  /// What the current view shows.
  DriveListing get listing => listingFor(state, _rootId);

  /// Folder that uploads and new folders go into, or null where the view has
  /// no single folder (search results, Starred, Trash...).
  String? get targetFolderId {
    if (state.searching) return null;
    if (state.path.isNotEmpty) return state.path.last.id;
    return state.section == DriveSection.myDrive ? _rootId : null;
  }

  void openSection(DriveSection section) {
    state = BrowserState(
      section: section,
      sort: state.sort,
      ascending: state.ascending,
    );
    refresh();
  }

  void openFolder(DriveItem folder) {
    state = state.copyWith(
      path: [...state.path, folder],
      search: '',
      selected: const {},
    );
    refresh();
  }

  /// Jumps to a breadcrumb: 0 is the section root.
  void goToDepth(int depth) {
    if (depth >= state.path.length && !state.searching) return;
    state = state.copyWith(
      path: state.path.take(depth).toList(),
      search: '',
      selected: const {},
    );
    refresh();
  }

  void goUp() {
    if (state.path.isNotEmpty) goToDepth(state.path.length - 1);
  }

  void setSearch(String text) {
    if (text == state.search) return;
    state = state.copyWith(search: text, selected: const {});
    refresh();
  }

  void setSort(SortField field) => state = state.copyWith(
    sort: field,
    ascending: state.sort == field ? !state.ascending : true,
  );

  void selectOnly(String id) => state = state.copyWith(selected: {id});

  void toggleSelected(String id) {
    final next = {...state.selected};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selected: next);
  }

  void selectAll(Iterable<String> ids) =>
      state = state.copyWith(selected: ids.toSet());

  void clearSelection() {
    if (state.selected.isNotEmpty) state = state.copyWith(selected: const {});
  }

  /// Reloads the current view from Drive.
  Future<void> refresh() async {
    if (ref.read(sessionProvider) == null) return;
    final request = ++_request;
    state = state.copyWith(loading: true, error: () => null);
    String? error;
    try {
      await ref.read(driveRepositoryProvider).refresh(listing);
    } catch (e) {
      error = '$e';
    }
    if (request != _request || !ref.mounted) return;
    state = state.copyWith(loading: false, error: () => error);
  }
}

DriveListing listingFor(BrowserState state, String rootId) {
  if (state.searching) return SearchListing(state.search.trim());
  if (state.path.isNotEmpty) return FolderListing(state.path.last.id);
  return switch (state.section) {
    DriveSection.myDrive => FolderListing(rootId),
    DriveSection.shared => const SharedListing(),
    DriveSection.recent => const RecentListing(),
    DriveSection.starred => const StarredListing(),
    DriveSection.trash => const TrashListing(),
  };
}

/// Folders first, then by the chosen column.
List<DriveItem> sortItems(
  List<DriveItem> items,
  SortField field,
  bool ascending,
) {
  int compare(DriveItem a, DriveItem b) {
    final result = switch (field) {
      SortField.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      SortField.modified => (a.modifiedTime ?? DateTime(0)).compareTo(
        b.modifiedTime ?? DateTime(0),
      ),
      SortField.size => (a.size ?? 0).compareTo(b.size ?? 0),
    };
    return ascending ? result : -result;
  }

  return [...items]..sort((a, b) {
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
    final result = compare(a, b);
    return result != 0 ? result : a.id.compareTo(b.id);
  });
}

final browserProvider = NotifierProvider<BrowserController, BrowserState>(
  BrowserController.new,
);

/// Items in the current view, sorted. Recent keeps Drive's own order.
final browserItemsProvider = StreamProvider<List<DriveItem>>((ref) {
  final rootId = ref.watch(accountProvider).rootId;
  final listing = ref.watch(
    browserProvider.select((s) => listingFor(s, rootId)),
  );
  final sort = ref.watch(browserProvider.select((s) => s.sort));
  final ascending = ref.watch(browserProvider.select((s) => s.ascending));
  final items = ref.watch(driveRepositoryProvider).watch(listing);
  return listing is RecentListing
      ? items
      : items.map((list) => sortItems(list, sort, ascending));
});
