import 'dart:convert';

import '../../core/db/database.dart';

/// The signed-in user plus the facts the app needs about their Drive.
class DriveAccount {
  const DriveAccount({
    required this.email,
    required this.displayName,
    required this.rootId,
    this.usageBytes,
    this.limitBytes,
  });

  final String email;
  final String displayName;

  /// Real id of "My Drive"; children carry it as their parent.
  final String rootId;
  final int? usageBytes;
  final int? limitBytes;

  String encode() => jsonEncode({
    'email': email,
    'displayName': displayName,
    'rootId': rootId,
    'usageBytes': usageBytes,
    'limitBytes': limitBytes,
  });

  factory DriveAccount.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return DriveAccount(
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      rootId: json['rootId'] as String,
      usageBytes: json['usageBytes'] as int?,
      limitBytes: json['limitBytes'] as int?,
    );
  }
}

/// What a listing call asks Drive for.
sealed class DriveListing {
  const DriveListing();

  /// Identifies the listing; two listings with the same key are equal.
  String get key;

  @override
  bool operator ==(Object other) => other is DriveListing && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class FolderListing extends DriveListing {
  const FolderListing(this.folderId);
  final String folderId;

  @override
  String get key => 'folder:$folderId';
}

class SharedListing extends DriveListing {
  const SharedListing();

  @override
  String get key => 'shared';
}

class StarredListing extends DriveListing {
  const StarredListing();

  @override
  String get key => 'starred';
}

class TrashListing extends DriveListing {
  const TrashListing();

  @override
  String get key => 'trash';
}

class RecentListing extends DriveListing {
  const RecentListing();

  @override
  String get key => 'recent';
}

/// Every live item in the account, used to index a whole-Drive sync.
class AllListing extends DriveListing {
  const AllListing();

  @override
  String get key => 'all';
}

class SearchListing extends DriveListing {
  const SearchListing(this.text);
  final String text;

  @override
  String get key => 'search:$text';
}

class DriveChange {
  const DriveChange({required this.fileId, this.item, this.removed = false});

  final String fileId;

  /// Null when [removed].
  final DriveItem? item;
  final bool removed;
}

class DriveChanges {
  const DriveChanges({required this.changes, required this.nextToken});

  final List<DriveChange> changes;

  /// Token to store and pass to the next [DriveApi.changes] call.
  final String nextToken;
}

/// Everything the app asks of Google Drive. The only network boundary for
/// file data, so the rest of the app is tested against an in-memory fake.
abstract interface class DriveApi {
  Future<DriveAccount> about();

  /// All pages of [listing].
  Future<List<DriveItem>> list(DriveListing listing);

  Future<DriveItem> get(String id);

  /// File bytes. Not valid for Google-native files; use [export].
  Stream<List<int>> download(String id);

  Stream<List<int>> export(String id, String mimeType);

  Future<DriveItem> createFolder(String name, String parentId);

  Future<DriveItem> upload({
    required String name,
    required String parentId,
    required Stream<List<int>> data,
    required int length,
    DateTime? modifiedTime,
  });

  /// Replaces the bytes of an existing file (a new revision).
  Future<DriveItem> updateContent(
    String id, {
    required Stream<List<int>> data,
    required int length,
    DateTime? modifiedTime,
  });

  Future<DriveItem> updateMetadata(
    String id, {
    String? name,
    bool? starred,
    bool? trashed,
    String? addParent,
    String? removeParent,
  });

  Future<DriveItem> copy(String id, {String? name, String? parentId});

  /// Permanent. The sync engine never calls this; it trashes instead.
  Future<void> delete(String id);

  Future<void> emptyTrash();

  Future<String> startPageToken();

  /// All changes since [pageToken].
  Future<DriveChanges> changes(String pageToken);
}
