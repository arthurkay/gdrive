// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DriveItemsTable extends DriveItems
    with TableInfo<$DriveItemsTable, DriveItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriveItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _md5Meta = const VerificationMeta('md5');
  @override
  late final GeneratedColumn<String> md5 = GeneratedColumn<String>(
    'md5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedTimeMeta = const VerificationMeta(
    'modifiedTime',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedTime = GeneratedColumn<DateTime>(
    'modified_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewedTimeMeta = const VerificationMeta(
    'viewedTime',
  );
  @override
  late final GeneratedColumn<DateTime> viewedTime = GeneratedColumn<DateTime>(
    'viewed_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trashedMeta = const VerificationMeta(
    'trashed',
  );
  @override
  late final GeneratedColumn<bool> trashed = GeneratedColumn<bool>(
    'trashed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("trashed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sharedWithMeMeta = const VerificationMeta(
    'sharedWithMe',
  );
  @override
  late final GeneratedColumn<bool> sharedWithMe = GeneratedColumn<bool>(
    'shared_with_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shared_with_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _thumbnailLinkMeta = const VerificationMeta(
    'thumbnailLink',
  );
  @override
  late final GeneratedColumn<String> thumbnailLink = GeneratedColumn<String>(
    'thumbnail_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _webViewLinkMeta = const VerificationMeta(
    'webViewLink',
  );
  @override
  late final GeneratedColumn<String> webViewLink = GeneratedColumn<String>(
    'web_view_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    name,
    mimeType,
    size,
    md5,
    modifiedTime,
    viewedTime,
    trashed,
    starred,
    sharedWithMe,
    thumbnailLink,
    webViewLink,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drive_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriveItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('md5')) {
      context.handle(
        _md5Meta,
        md5.isAcceptableOrUnknown(data['md5']!, _md5Meta),
      );
    }
    if (data.containsKey('modified_time')) {
      context.handle(
        _modifiedTimeMeta,
        modifiedTime.isAcceptableOrUnknown(
          data['modified_time']!,
          _modifiedTimeMeta,
        ),
      );
    }
    if (data.containsKey('viewed_time')) {
      context.handle(
        _viewedTimeMeta,
        viewedTime.isAcceptableOrUnknown(data['viewed_time']!, _viewedTimeMeta),
      );
    }
    if (data.containsKey('trashed')) {
      context.handle(
        _trashedMeta,
        trashed.isAcceptableOrUnknown(data['trashed']!, _trashedMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('shared_with_me')) {
      context.handle(
        _sharedWithMeMeta,
        sharedWithMe.isAcceptableOrUnknown(
          data['shared_with_me']!,
          _sharedWithMeMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_link')) {
      context.handle(
        _thumbnailLinkMeta,
        thumbnailLink.isAcceptableOrUnknown(
          data['thumbnail_link']!,
          _thumbnailLinkMeta,
        ),
      );
    }
    if (data.containsKey('web_view_link')) {
      context.handle(
        _webViewLinkMeta,
        webViewLink.isAcceptableOrUnknown(
          data['web_view_link']!,
          _webViewLinkMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriveItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriveItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      md5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}md5'],
      ),
      modifiedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_time'],
      ),
      viewedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}viewed_time'],
      ),
      trashed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}trashed'],
      )!,
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      sharedWithMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shared_with_me'],
      )!,
      thumbnailLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_link'],
      ),
      webViewLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}web_view_link'],
      ),
    );
  }

  @override
  $DriveItemsTable createAlias(String alias) {
    return $DriveItemsTable(attachedDatabase, alias);
  }
}

class DriveItem extends DataClass implements Insertable<DriveItem> {
  final String id;
  final String? parentId;
  final String name;
  final String mimeType;
  final int? size;
  final String? md5;
  final DateTime? modifiedTime;
  final DateTime? viewedTime;
  final bool trashed;
  final bool starred;
  final bool sharedWithMe;
  final String? thumbnailLink;
  final String? webViewLink;
  const DriveItem({
    required this.id,
    this.parentId,
    required this.name,
    required this.mimeType,
    this.size,
    this.md5,
    this.modifiedTime,
    this.viewedTime,
    required this.trashed,
    required this.starred,
    required this.sharedWithMe,
    this.thumbnailLink,
    this.webViewLink,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || md5 != null) {
      map['md5'] = Variable<String>(md5);
    }
    if (!nullToAbsent || modifiedTime != null) {
      map['modified_time'] = Variable<DateTime>(modifiedTime);
    }
    if (!nullToAbsent || viewedTime != null) {
      map['viewed_time'] = Variable<DateTime>(viewedTime);
    }
    map['trashed'] = Variable<bool>(trashed);
    map['starred'] = Variable<bool>(starred);
    map['shared_with_me'] = Variable<bool>(sharedWithMe);
    if (!nullToAbsent || thumbnailLink != null) {
      map['thumbnail_link'] = Variable<String>(thumbnailLink);
    }
    if (!nullToAbsent || webViewLink != null) {
      map['web_view_link'] = Variable<String>(webViewLink);
    }
    return map;
  }

  DriveItemsCompanion toCompanion(bool nullToAbsent) {
    return DriveItemsCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      mimeType: Value(mimeType),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      md5: md5 == null && nullToAbsent ? const Value.absent() : Value(md5),
      modifiedTime: modifiedTime == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedTime),
      viewedTime: viewedTime == null && nullToAbsent
          ? const Value.absent()
          : Value(viewedTime),
      trashed: Value(trashed),
      starred: Value(starred),
      sharedWithMe: Value(sharedWithMe),
      thumbnailLink: thumbnailLink == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailLink),
      webViewLink: webViewLink == null && nullToAbsent
          ? const Value.absent()
          : Value(webViewLink),
    );
  }

  factory DriveItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriveItem(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int?>(json['size']),
      md5: serializer.fromJson<String?>(json['md5']),
      modifiedTime: serializer.fromJson<DateTime?>(json['modifiedTime']),
      viewedTime: serializer.fromJson<DateTime?>(json['viewedTime']),
      trashed: serializer.fromJson<bool>(json['trashed']),
      starred: serializer.fromJson<bool>(json['starred']),
      sharedWithMe: serializer.fromJson<bool>(json['sharedWithMe']),
      thumbnailLink: serializer.fromJson<String?>(json['thumbnailLink']),
      webViewLink: serializer.fromJson<String?>(json['webViewLink']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int?>(size),
      'md5': serializer.toJson<String?>(md5),
      'modifiedTime': serializer.toJson<DateTime?>(modifiedTime),
      'viewedTime': serializer.toJson<DateTime?>(viewedTime),
      'trashed': serializer.toJson<bool>(trashed),
      'starred': serializer.toJson<bool>(starred),
      'sharedWithMe': serializer.toJson<bool>(sharedWithMe),
      'thumbnailLink': serializer.toJson<String?>(thumbnailLink),
      'webViewLink': serializer.toJson<String?>(webViewLink),
    };
  }

  DriveItem copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    String? mimeType,
    Value<int?> size = const Value.absent(),
    Value<String?> md5 = const Value.absent(),
    Value<DateTime?> modifiedTime = const Value.absent(),
    Value<DateTime?> viewedTime = const Value.absent(),
    bool? trashed,
    bool? starred,
    bool? sharedWithMe,
    Value<String?> thumbnailLink = const Value.absent(),
    Value<String?> webViewLink = const Value.absent(),
  }) => DriveItem(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    mimeType: mimeType ?? this.mimeType,
    size: size.present ? size.value : this.size,
    md5: md5.present ? md5.value : this.md5,
    modifiedTime: modifiedTime.present ? modifiedTime.value : this.modifiedTime,
    viewedTime: viewedTime.present ? viewedTime.value : this.viewedTime,
    trashed: trashed ?? this.trashed,
    starred: starred ?? this.starred,
    sharedWithMe: sharedWithMe ?? this.sharedWithMe,
    thumbnailLink: thumbnailLink.present
        ? thumbnailLink.value
        : this.thumbnailLink,
    webViewLink: webViewLink.present ? webViewLink.value : this.webViewLink,
  );
  DriveItem copyWithCompanion(DriveItemsCompanion data) {
    return DriveItem(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      md5: data.md5.present ? data.md5.value : this.md5,
      modifiedTime: data.modifiedTime.present
          ? data.modifiedTime.value
          : this.modifiedTime,
      viewedTime: data.viewedTime.present
          ? data.viewedTime.value
          : this.viewedTime,
      trashed: data.trashed.present ? data.trashed.value : this.trashed,
      starred: data.starred.present ? data.starred.value : this.starred,
      sharedWithMe: data.sharedWithMe.present
          ? data.sharedWithMe.value
          : this.sharedWithMe,
      thumbnailLink: data.thumbnailLink.present
          ? data.thumbnailLink.value
          : this.thumbnailLink,
      webViewLink: data.webViewLink.present
          ? data.webViewLink.value
          : this.webViewLink,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriveItem(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('md5: $md5, ')
          ..write('modifiedTime: $modifiedTime, ')
          ..write('viewedTime: $viewedTime, ')
          ..write('trashed: $trashed, ')
          ..write('starred: $starred, ')
          ..write('sharedWithMe: $sharedWithMe, ')
          ..write('thumbnailLink: $thumbnailLink, ')
          ..write('webViewLink: $webViewLink')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    parentId,
    name,
    mimeType,
    size,
    md5,
    modifiedTime,
    viewedTime,
    trashed,
    starred,
    sharedWithMe,
    thumbnailLink,
    webViewLink,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriveItem &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.md5 == this.md5 &&
          other.modifiedTime == this.modifiedTime &&
          other.viewedTime == this.viewedTime &&
          other.trashed == this.trashed &&
          other.starred == this.starred &&
          other.sharedWithMe == this.sharedWithMe &&
          other.thumbnailLink == this.thumbnailLink &&
          other.webViewLink == this.webViewLink);
}

class DriveItemsCompanion extends UpdateCompanion<DriveItem> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String> mimeType;
  final Value<int?> size;
  final Value<String?> md5;
  final Value<DateTime?> modifiedTime;
  final Value<DateTime?> viewedTime;
  final Value<bool> trashed;
  final Value<bool> starred;
  final Value<bool> sharedWithMe;
  final Value<String?> thumbnailLink;
  final Value<String?> webViewLink;
  final Value<int> rowid;
  const DriveItemsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.md5 = const Value.absent(),
    this.modifiedTime = const Value.absent(),
    this.viewedTime = const Value.absent(),
    this.trashed = const Value.absent(),
    this.starred = const Value.absent(),
    this.sharedWithMe = const Value.absent(),
    this.thumbnailLink = const Value.absent(),
    this.webViewLink = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriveItemsCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    required String mimeType,
    this.size = const Value.absent(),
    this.md5 = const Value.absent(),
    this.modifiedTime = const Value.absent(),
    this.viewedTime = const Value.absent(),
    this.trashed = const Value.absent(),
    this.starred = const Value.absent(),
    this.sharedWithMe = const Value.absent(),
    this.thumbnailLink = const Value.absent(),
    this.webViewLink = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       mimeType = Value(mimeType);
  static Insertable<DriveItem> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<String>? md5,
    Expression<DateTime>? modifiedTime,
    Expression<DateTime>? viewedTime,
    Expression<bool>? trashed,
    Expression<bool>? starred,
    Expression<bool>? sharedWithMe,
    Expression<String>? thumbnailLink,
    Expression<String>? webViewLink,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (md5 != null) 'md5': md5,
      if (modifiedTime != null) 'modified_time': modifiedTime,
      if (viewedTime != null) 'viewed_time': viewedTime,
      if (trashed != null) 'trashed': trashed,
      if (starred != null) 'starred': starred,
      if (sharedWithMe != null) 'shared_with_me': sharedWithMe,
      if (thumbnailLink != null) 'thumbnail_link': thumbnailLink,
      if (webViewLink != null) 'web_view_link': webViewLink,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriveItemsCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String>? mimeType,
    Value<int?>? size,
    Value<String?>? md5,
    Value<DateTime?>? modifiedTime,
    Value<DateTime?>? viewedTime,
    Value<bool>? trashed,
    Value<bool>? starred,
    Value<bool>? sharedWithMe,
    Value<String?>? thumbnailLink,
    Value<String?>? webViewLink,
    Value<int>? rowid,
  }) {
    return DriveItemsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      md5: md5 ?? this.md5,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      viewedTime: viewedTime ?? this.viewedTime,
      trashed: trashed ?? this.trashed,
      starred: starred ?? this.starred,
      sharedWithMe: sharedWithMe ?? this.sharedWithMe,
      thumbnailLink: thumbnailLink ?? this.thumbnailLink,
      webViewLink: webViewLink ?? this.webViewLink,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (md5.present) {
      map['md5'] = Variable<String>(md5.value);
    }
    if (modifiedTime.present) {
      map['modified_time'] = Variable<DateTime>(modifiedTime.value);
    }
    if (viewedTime.present) {
      map['viewed_time'] = Variable<DateTime>(viewedTime.value);
    }
    if (trashed.present) {
      map['trashed'] = Variable<bool>(trashed.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (sharedWithMe.present) {
      map['shared_with_me'] = Variable<bool>(sharedWithMe.value);
    }
    if (thumbnailLink.present) {
      map['thumbnail_link'] = Variable<String>(thumbnailLink.value);
    }
    if (webViewLink.present) {
      map['web_view_link'] = Variable<String>(webViewLink.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriveItemsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('md5: $md5, ')
          ..write('modifiedTime: $modifiedTime, ')
          ..write('viewedTime: $viewedTime, ')
          ..write('trashed: $trashed, ')
          ..write('starred: $starred, ')
          ..write('sharedWithMe: $sharedWithMe, ')
          ..write('thumbnailLink: $thumbnailLink, ')
          ..write('webViewLink: $webViewLink, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncSelectionsTable extends SyncSelections
    with TableInfo<$SyncSelectionsTable, SyncSelection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSelectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_selections';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncSelection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  SyncSelection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSelection(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncSelectionsTable createAlias(String alias) {
    return $SyncSelectionsTable(attachedDatabase, alias);
  }
}

class SyncSelection extends DataClass implements Insertable<SyncSelection> {
  final String itemId;
  final DateTime createdAt;
  const SyncSelection({required this.itemId, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncSelectionsCompanion toCompanion(bool nullToAbsent) {
    return SyncSelectionsCompanion(
      itemId: Value(itemId),
      createdAt: Value(createdAt),
    );
  }

  factory SyncSelection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSelection(
      itemId: serializer.fromJson<String>(json['itemId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncSelection copyWith({String? itemId, DateTime? createdAt}) =>
      SyncSelection(
        itemId: itemId ?? this.itemId,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncSelection copyWithCompanion(SyncSelectionsCompanion data) {
    return SyncSelection(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncSelection(')
          ..write('itemId: $itemId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSelection &&
          other.itemId == this.itemId &&
          other.createdAt == this.createdAt);
}

class SyncSelectionsCompanion extends UpdateCompanion<SyncSelection> {
  final Value<String> itemId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SyncSelectionsCompanion({
    this.itemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncSelectionsCompanion.insert({
    required String itemId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       createdAt = Value(createdAt);
  static Insertable<SyncSelection> custom({
    Expression<String>? itemId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncSelectionsCompanion copyWith({
    Value<String>? itemId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncSelectionsCompanion(
      itemId: itemId ?? this.itemId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncSelectionsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncEntriesTable extends SyncEntries
    with TableInfo<$SyncEntriesTable, SyncEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isFolderMeta = const VerificationMeta(
    'isFolder',
  );
  @override
  late final GeneratedColumn<bool> isFolder = GeneratedColumn<bool>(
    'is_folder',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_folder" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isNativeMeta = const VerificationMeta(
    'isNative',
  );
  @override
  late final GeneratedColumn<bool> isNative = GeneratedColumn<bool>(
    'is_native',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_native" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localSizeMeta = const VerificationMeta(
    'localSize',
  );
  @override
  late final GeneratedColumn<int> localSize = GeneratedColumn<int>(
    'local_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localMtimeMsMeta = const VerificationMeta(
    'localMtimeMs',
  );
  @override
  late final GeneratedColumn<int> localMtimeMs = GeneratedColumn<int>(
    'local_mtime_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localMd5Meta = const VerificationMeta(
    'localMd5',
  );
  @override
  late final GeneratedColumn<String> localMd5 = GeneratedColumn<String>(
    'local_md5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteMd5Meta = const VerificationMeta(
    'remoteMd5',
  );
  @override
  late final GeneratedColumn<String> remoteMd5 = GeneratedColumn<String>(
    'remote_md5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteModifiedMsMeta = const VerificationMeta(
    'remoteModifiedMs',
  );
  @override
  late final GeneratedColumn<int> remoteModifiedMs = GeneratedColumn<int>(
    'remote_modified_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localEditedMeta = const VerificationMeta(
    'localEdited',
  );
  @override
  late final GeneratedColumn<bool> localEdited = GeneratedColumn<bool>(
    'local_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    relPath,
    isFolder,
    isNative,
    localSize,
    localMtimeMs,
    localMd5,
    remoteMd5,
    remoteModifiedMs,
    localEdited,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('is_folder')) {
      context.handle(
        _isFolderMeta,
        isFolder.isAcceptableOrUnknown(data['is_folder']!, _isFolderMeta),
      );
    }
    if (data.containsKey('is_native')) {
      context.handle(
        _isNativeMeta,
        isNative.isAcceptableOrUnknown(data['is_native']!, _isNativeMeta),
      );
    }
    if (data.containsKey('local_size')) {
      context.handle(
        _localSizeMeta,
        localSize.isAcceptableOrUnknown(data['local_size']!, _localSizeMeta),
      );
    }
    if (data.containsKey('local_mtime_ms')) {
      context.handle(
        _localMtimeMsMeta,
        localMtimeMs.isAcceptableOrUnknown(
          data['local_mtime_ms']!,
          _localMtimeMsMeta,
        ),
      );
    }
    if (data.containsKey('local_md5')) {
      context.handle(
        _localMd5Meta,
        localMd5.isAcceptableOrUnknown(data['local_md5']!, _localMd5Meta),
      );
    }
    if (data.containsKey('remote_md5')) {
      context.handle(
        _remoteMd5Meta,
        remoteMd5.isAcceptableOrUnknown(data['remote_md5']!, _remoteMd5Meta),
      );
    }
    if (data.containsKey('remote_modified_ms')) {
      context.handle(
        _remoteModifiedMsMeta,
        remoteModifiedMs.isAcceptableOrUnknown(
          data['remote_modified_ms']!,
          _remoteModifiedMsMeta,
        ),
      );
    }
    if (data.containsKey('local_edited')) {
      context.handle(
        _localEditedMeta,
        localEdited.isAcceptableOrUnknown(
          data['local_edited']!,
          _localEditedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId};
  @override
  SyncEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncEntry(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      isFolder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_folder'],
      )!,
      isNative: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_native'],
      )!,
      localSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_size'],
      ),
      localMtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_mtime_ms'],
      ),
      localMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_md5'],
      ),
      remoteMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_md5'],
      ),
      remoteModifiedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_modified_ms'],
      ),
      localEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_edited'],
      )!,
    );
  }

  @override
  $SyncEntriesTable createAlias(String alias) {
    return $SyncEntriesTable(attachedDatabase, alias);
  }
}

class SyncEntry extends DataClass implements Insertable<SyncEntry> {
  final String fileId;

  /// Path below the sync root, always with forward slashes.
  final String relPath;
  final bool isFolder;

  /// Google Docs/Sheets/Slides export: download-only.
  final bool isNative;
  final int? localSize;
  final int? localMtimeMs;
  final String? localMd5;
  final String? remoteMd5;
  final int? remoteModifiedMs;

  /// True when a native export was edited locally; those edits stay local.
  final bool localEdited;
  const SyncEntry({
    required this.fileId,
    required this.relPath,
    required this.isFolder,
    required this.isNative,
    this.localSize,
    this.localMtimeMs,
    this.localMd5,
    this.remoteMd5,
    this.remoteModifiedMs,
    required this.localEdited,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<String>(fileId);
    map['rel_path'] = Variable<String>(relPath);
    map['is_folder'] = Variable<bool>(isFolder);
    map['is_native'] = Variable<bool>(isNative);
    if (!nullToAbsent || localSize != null) {
      map['local_size'] = Variable<int>(localSize);
    }
    if (!nullToAbsent || localMtimeMs != null) {
      map['local_mtime_ms'] = Variable<int>(localMtimeMs);
    }
    if (!nullToAbsent || localMd5 != null) {
      map['local_md5'] = Variable<String>(localMd5);
    }
    if (!nullToAbsent || remoteMd5 != null) {
      map['remote_md5'] = Variable<String>(remoteMd5);
    }
    if (!nullToAbsent || remoteModifiedMs != null) {
      map['remote_modified_ms'] = Variable<int>(remoteModifiedMs);
    }
    map['local_edited'] = Variable<bool>(localEdited);
    return map;
  }

  SyncEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncEntriesCompanion(
      fileId: Value(fileId),
      relPath: Value(relPath),
      isFolder: Value(isFolder),
      isNative: Value(isNative),
      localSize: localSize == null && nullToAbsent
          ? const Value.absent()
          : Value(localSize),
      localMtimeMs: localMtimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(localMtimeMs),
      localMd5: localMd5 == null && nullToAbsent
          ? const Value.absent()
          : Value(localMd5),
      remoteMd5: remoteMd5 == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteMd5),
      remoteModifiedMs: remoteModifiedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteModifiedMs),
      localEdited: Value(localEdited),
    );
  }

  factory SyncEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncEntry(
      fileId: serializer.fromJson<String>(json['fileId']),
      relPath: serializer.fromJson<String>(json['relPath']),
      isFolder: serializer.fromJson<bool>(json['isFolder']),
      isNative: serializer.fromJson<bool>(json['isNative']),
      localSize: serializer.fromJson<int?>(json['localSize']),
      localMtimeMs: serializer.fromJson<int?>(json['localMtimeMs']),
      localMd5: serializer.fromJson<String?>(json['localMd5']),
      remoteMd5: serializer.fromJson<String?>(json['remoteMd5']),
      remoteModifiedMs: serializer.fromJson<int?>(json['remoteModifiedMs']),
      localEdited: serializer.fromJson<bool>(json['localEdited']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<String>(fileId),
      'relPath': serializer.toJson<String>(relPath),
      'isFolder': serializer.toJson<bool>(isFolder),
      'isNative': serializer.toJson<bool>(isNative),
      'localSize': serializer.toJson<int?>(localSize),
      'localMtimeMs': serializer.toJson<int?>(localMtimeMs),
      'localMd5': serializer.toJson<String?>(localMd5),
      'remoteMd5': serializer.toJson<String?>(remoteMd5),
      'remoteModifiedMs': serializer.toJson<int?>(remoteModifiedMs),
      'localEdited': serializer.toJson<bool>(localEdited),
    };
  }

  SyncEntry copyWith({
    String? fileId,
    String? relPath,
    bool? isFolder,
    bool? isNative,
    Value<int?> localSize = const Value.absent(),
    Value<int?> localMtimeMs = const Value.absent(),
    Value<String?> localMd5 = const Value.absent(),
    Value<String?> remoteMd5 = const Value.absent(),
    Value<int?> remoteModifiedMs = const Value.absent(),
    bool? localEdited,
  }) => SyncEntry(
    fileId: fileId ?? this.fileId,
    relPath: relPath ?? this.relPath,
    isFolder: isFolder ?? this.isFolder,
    isNative: isNative ?? this.isNative,
    localSize: localSize.present ? localSize.value : this.localSize,
    localMtimeMs: localMtimeMs.present ? localMtimeMs.value : this.localMtimeMs,
    localMd5: localMd5.present ? localMd5.value : this.localMd5,
    remoteMd5: remoteMd5.present ? remoteMd5.value : this.remoteMd5,
    remoteModifiedMs: remoteModifiedMs.present
        ? remoteModifiedMs.value
        : this.remoteModifiedMs,
    localEdited: localEdited ?? this.localEdited,
  );
  SyncEntry copyWithCompanion(SyncEntriesCompanion data) {
    return SyncEntry(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      isFolder: data.isFolder.present ? data.isFolder.value : this.isFolder,
      isNative: data.isNative.present ? data.isNative.value : this.isNative,
      localSize: data.localSize.present ? data.localSize.value : this.localSize,
      localMtimeMs: data.localMtimeMs.present
          ? data.localMtimeMs.value
          : this.localMtimeMs,
      localMd5: data.localMd5.present ? data.localMd5.value : this.localMd5,
      remoteMd5: data.remoteMd5.present ? data.remoteMd5.value : this.remoteMd5,
      remoteModifiedMs: data.remoteModifiedMs.present
          ? data.remoteModifiedMs.value
          : this.remoteModifiedMs,
      localEdited: data.localEdited.present
          ? data.localEdited.value
          : this.localEdited,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncEntry(')
          ..write('fileId: $fileId, ')
          ..write('relPath: $relPath, ')
          ..write('isFolder: $isFolder, ')
          ..write('isNative: $isNative, ')
          ..write('localSize: $localSize, ')
          ..write('localMtimeMs: $localMtimeMs, ')
          ..write('localMd5: $localMd5, ')
          ..write('remoteMd5: $remoteMd5, ')
          ..write('remoteModifiedMs: $remoteModifiedMs, ')
          ..write('localEdited: $localEdited')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileId,
    relPath,
    isFolder,
    isNative,
    localSize,
    localMtimeMs,
    localMd5,
    remoteMd5,
    remoteModifiedMs,
    localEdited,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEntry &&
          other.fileId == this.fileId &&
          other.relPath == this.relPath &&
          other.isFolder == this.isFolder &&
          other.isNative == this.isNative &&
          other.localSize == this.localSize &&
          other.localMtimeMs == this.localMtimeMs &&
          other.localMd5 == this.localMd5 &&
          other.remoteMd5 == this.remoteMd5 &&
          other.remoteModifiedMs == this.remoteModifiedMs &&
          other.localEdited == this.localEdited);
}

class SyncEntriesCompanion extends UpdateCompanion<SyncEntry> {
  final Value<String> fileId;
  final Value<String> relPath;
  final Value<bool> isFolder;
  final Value<bool> isNative;
  final Value<int?> localSize;
  final Value<int?> localMtimeMs;
  final Value<String?> localMd5;
  final Value<String?> remoteMd5;
  final Value<int?> remoteModifiedMs;
  final Value<bool> localEdited;
  final Value<int> rowid;
  const SyncEntriesCompanion({
    this.fileId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.isFolder = const Value.absent(),
    this.isNative = const Value.absent(),
    this.localSize = const Value.absent(),
    this.localMtimeMs = const Value.absent(),
    this.localMd5 = const Value.absent(),
    this.remoteMd5 = const Value.absent(),
    this.remoteModifiedMs = const Value.absent(),
    this.localEdited = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncEntriesCompanion.insert({
    required String fileId,
    required String relPath,
    this.isFolder = const Value.absent(),
    this.isNative = const Value.absent(),
    this.localSize = const Value.absent(),
    this.localMtimeMs = const Value.absent(),
    this.localMd5 = const Value.absent(),
    this.remoteMd5 = const Value.absent(),
    this.remoteModifiedMs = const Value.absent(),
    this.localEdited = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fileId = Value(fileId),
       relPath = Value(relPath);
  static Insertable<SyncEntry> custom({
    Expression<String>? fileId,
    Expression<String>? relPath,
    Expression<bool>? isFolder,
    Expression<bool>? isNative,
    Expression<int>? localSize,
    Expression<int>? localMtimeMs,
    Expression<String>? localMd5,
    Expression<String>? remoteMd5,
    Expression<int>? remoteModifiedMs,
    Expression<bool>? localEdited,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (relPath != null) 'rel_path': relPath,
      if (isFolder != null) 'is_folder': isFolder,
      if (isNative != null) 'is_native': isNative,
      if (localSize != null) 'local_size': localSize,
      if (localMtimeMs != null) 'local_mtime_ms': localMtimeMs,
      if (localMd5 != null) 'local_md5': localMd5,
      if (remoteMd5 != null) 'remote_md5': remoteMd5,
      if (remoteModifiedMs != null) 'remote_modified_ms': remoteModifiedMs,
      if (localEdited != null) 'local_edited': localEdited,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncEntriesCompanion copyWith({
    Value<String>? fileId,
    Value<String>? relPath,
    Value<bool>? isFolder,
    Value<bool>? isNative,
    Value<int?>? localSize,
    Value<int?>? localMtimeMs,
    Value<String?>? localMd5,
    Value<String?>? remoteMd5,
    Value<int?>? remoteModifiedMs,
    Value<bool>? localEdited,
    Value<int>? rowid,
  }) {
    return SyncEntriesCompanion(
      fileId: fileId ?? this.fileId,
      relPath: relPath ?? this.relPath,
      isFolder: isFolder ?? this.isFolder,
      isNative: isNative ?? this.isNative,
      localSize: localSize ?? this.localSize,
      localMtimeMs: localMtimeMs ?? this.localMtimeMs,
      localMd5: localMd5 ?? this.localMd5,
      remoteMd5: remoteMd5 ?? this.remoteMd5,
      remoteModifiedMs: remoteModifiedMs ?? this.remoteModifiedMs,
      localEdited: localEdited ?? this.localEdited,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (isFolder.present) {
      map['is_folder'] = Variable<bool>(isFolder.value);
    }
    if (isNative.present) {
      map['is_native'] = Variable<bool>(isNative.value);
    }
    if (localSize.present) {
      map['local_size'] = Variable<int>(localSize.value);
    }
    if (localMtimeMs.present) {
      map['local_mtime_ms'] = Variable<int>(localMtimeMs.value);
    }
    if (localMd5.present) {
      map['local_md5'] = Variable<String>(localMd5.value);
    }
    if (remoteMd5.present) {
      map['remote_md5'] = Variable<String>(remoteMd5.value);
    }
    if (remoteModifiedMs.present) {
      map['remote_modified_ms'] = Variable<int>(remoteModifiedMs.value);
    }
    if (localEdited.present) {
      map['local_edited'] = Variable<bool>(localEdited.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncEntriesCompanion(')
          ..write('fileId: $fileId, ')
          ..write('relPath: $relPath, ')
          ..write('isFolder: $isFolder, ')
          ..write('isNative: $isNative, ')
          ..write('localSize: $localSize, ')
          ..write('localMtimeMs: $localMtimeMs, ')
          ..write('localMd5: $localMd5, ')
          ..write('remoteMd5: $remoteMd5, ')
          ..write('remoteModifiedMs: $remoteModifiedMs, ')
          ..write('localEdited: $localEdited, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransfersTable extends Transfers
    with TableInfo<$TransfersTable, Transfer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneBytesMeta = const VerificationMeta(
    'doneBytes',
  );
  @override
  late final GeneratedColumn<int> doneBytes = GeneratedColumn<int>(
    'done_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromSyncMeta = const VerificationMeta(
    'fromSync',
  );
  @override
  late final GeneratedColumn<bool> fromSync = GeneratedColumn<bool>(
    'from_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    direction,
    name,
    localPath,
    fileId,
    totalBytes,
    doneBytes,
    state,
    error,
    fromSync,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transfer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('done_bytes')) {
      context.handle(
        _doneBytesMeta,
        doneBytes.isAcceptableOrUnknown(data['done_bytes']!, _doneBytesMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('from_sync')) {
      context.handle(
        _fromSyncMeta,
        fromSync.isAcceptableOrUnknown(data['from_sync']!, _fromSyncMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transfer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transfer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      ),
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      doneBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_bytes'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      fromSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_sync'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TransfersTable createAlias(String alias) {
    return $TransfersTable(attachedDatabase, alias);
  }
}

class Transfer extends DataClass implements Insertable<Transfer> {
  final int id;

  /// `upload` or `download`.
  final String direction;
  final String name;
  final String localPath;
  final String? fileId;
  final int totalBytes;
  final int doneBytes;

  /// `queued`, `running`, `done`, `failed` or `cancelled`.
  final String state;
  final String? error;
  final bool fromSync;
  final DateTime createdAt;
  const Transfer({
    required this.id,
    required this.direction,
    required this.name,
    required this.localPath,
    this.fileId,
    required this.totalBytes,
    required this.doneBytes,
    required this.state,
    this.error,
    required this.fromSync,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['direction'] = Variable<String>(direction);
    map['name'] = Variable<String>(name);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || fileId != null) {
      map['file_id'] = Variable<String>(fileId);
    }
    map['total_bytes'] = Variable<int>(totalBytes);
    map['done_bytes'] = Variable<int>(doneBytes);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['from_sync'] = Variable<bool>(fromSync);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransfersCompanion toCompanion(bool nullToAbsent) {
    return TransfersCompanion(
      id: Value(id),
      direction: Value(direction),
      name: Value(name),
      localPath: Value(localPath),
      fileId: fileId == null && nullToAbsent
          ? const Value.absent()
          : Value(fileId),
      totalBytes: Value(totalBytes),
      doneBytes: Value(doneBytes),
      state: Value(state),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      fromSync: Value(fromSync),
      createdAt: Value(createdAt),
    );
  }

  factory Transfer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transfer(
      id: serializer.fromJson<int>(json['id']),
      direction: serializer.fromJson<String>(json['direction']),
      name: serializer.fromJson<String>(json['name']),
      localPath: serializer.fromJson<String>(json['localPath']),
      fileId: serializer.fromJson<String?>(json['fileId']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      doneBytes: serializer.fromJson<int>(json['doneBytes']),
      state: serializer.fromJson<String>(json['state']),
      error: serializer.fromJson<String?>(json['error']),
      fromSync: serializer.fromJson<bool>(json['fromSync']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'direction': serializer.toJson<String>(direction),
      'name': serializer.toJson<String>(name),
      'localPath': serializer.toJson<String>(localPath),
      'fileId': serializer.toJson<String?>(fileId),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'doneBytes': serializer.toJson<int>(doneBytes),
      'state': serializer.toJson<String>(state),
      'error': serializer.toJson<String?>(error),
      'fromSync': serializer.toJson<bool>(fromSync),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Transfer copyWith({
    int? id,
    String? direction,
    String? name,
    String? localPath,
    Value<String?> fileId = const Value.absent(),
    int? totalBytes,
    int? doneBytes,
    String? state,
    Value<String?> error = const Value.absent(),
    bool? fromSync,
    DateTime? createdAt,
  }) => Transfer(
    id: id ?? this.id,
    direction: direction ?? this.direction,
    name: name ?? this.name,
    localPath: localPath ?? this.localPath,
    fileId: fileId.present ? fileId.value : this.fileId,
    totalBytes: totalBytes ?? this.totalBytes,
    doneBytes: doneBytes ?? this.doneBytes,
    state: state ?? this.state,
    error: error.present ? error.value : this.error,
    fromSync: fromSync ?? this.fromSync,
    createdAt: createdAt ?? this.createdAt,
  );
  Transfer copyWithCompanion(TransfersCompanion data) {
    return Transfer(
      id: data.id.present ? data.id.value : this.id,
      direction: data.direction.present ? data.direction.value : this.direction,
      name: data.name.present ? data.name.value : this.name,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      doneBytes: data.doneBytes.present ? data.doneBytes.value : this.doneBytes,
      state: data.state.present ? data.state.value : this.state,
      error: data.error.present ? data.error.value : this.error,
      fromSync: data.fromSync.present ? data.fromSync.value : this.fromSync,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transfer(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('name: $name, ')
          ..write('localPath: $localPath, ')
          ..write('fileId: $fileId, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('doneBytes: $doneBytes, ')
          ..write('state: $state, ')
          ..write('error: $error, ')
          ..write('fromSync: $fromSync, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    direction,
    name,
    localPath,
    fileId,
    totalBytes,
    doneBytes,
    state,
    error,
    fromSync,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transfer &&
          other.id == this.id &&
          other.direction == this.direction &&
          other.name == this.name &&
          other.localPath == this.localPath &&
          other.fileId == this.fileId &&
          other.totalBytes == this.totalBytes &&
          other.doneBytes == this.doneBytes &&
          other.state == this.state &&
          other.error == this.error &&
          other.fromSync == this.fromSync &&
          other.createdAt == this.createdAt);
}

class TransfersCompanion extends UpdateCompanion<Transfer> {
  final Value<int> id;
  final Value<String> direction;
  final Value<String> name;
  final Value<String> localPath;
  final Value<String?> fileId;
  final Value<int> totalBytes;
  final Value<int> doneBytes;
  final Value<String> state;
  final Value<String?> error;
  final Value<bool> fromSync;
  final Value<DateTime> createdAt;
  const TransfersCompanion({
    this.id = const Value.absent(),
    this.direction = const Value.absent(),
    this.name = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileId = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.doneBytes = const Value.absent(),
    this.state = const Value.absent(),
    this.error = const Value.absent(),
    this.fromSync = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransfersCompanion.insert({
    this.id = const Value.absent(),
    required String direction,
    required String name,
    required String localPath,
    this.fileId = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.doneBytes = const Value.absent(),
    this.state = const Value.absent(),
    this.error = const Value.absent(),
    this.fromSync = const Value.absent(),
    required DateTime createdAt,
  }) : direction = Value(direction),
       name = Value(name),
       localPath = Value(localPath),
       createdAt = Value(createdAt);
  static Insertable<Transfer> custom({
    Expression<int>? id,
    Expression<String>? direction,
    Expression<String>? name,
    Expression<String>? localPath,
    Expression<String>? fileId,
    Expression<int>? totalBytes,
    Expression<int>? doneBytes,
    Expression<String>? state,
    Expression<String>? error,
    Expression<bool>? fromSync,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (direction != null) 'direction': direction,
      if (name != null) 'name': name,
      if (localPath != null) 'local_path': localPath,
      if (fileId != null) 'file_id': fileId,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (doneBytes != null) 'done_bytes': doneBytes,
      if (state != null) 'state': state,
      if (error != null) 'error': error,
      if (fromSync != null) 'from_sync': fromSync,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransfersCompanion copyWith({
    Value<int>? id,
    Value<String>? direction,
    Value<String>? name,
    Value<String>? localPath,
    Value<String?>? fileId,
    Value<int>? totalBytes,
    Value<int>? doneBytes,
    Value<String>? state,
    Value<String?>? error,
    Value<bool>? fromSync,
    Value<DateTime>? createdAt,
  }) {
    return TransfersCompanion(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      fileId: fileId ?? this.fileId,
      totalBytes: totalBytes ?? this.totalBytes,
      doneBytes: doneBytes ?? this.doneBytes,
      state: state ?? this.state,
      error: error ?? this.error,
      fromSync: fromSync ?? this.fromSync,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (doneBytes.present) {
      map['done_bytes'] = Variable<int>(doneBytes.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (fromSync.present) {
      map['from_sync'] = Variable<bool>(fromSync.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransfersCompanion(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('name: $name, ')
          ..write('localPath: $localPath, ')
          ..write('fileId: $fileId, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('doneBytes: $doneBytes, ')
          ..write('state: $state, ')
          ..write('error: $error, ')
          ..write('fromSync: $fromSync, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $KvTable extends Kv with TableInfo<$KvTable, KvEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KvTable createAlias(String alias) {
    return $KvTable(attachedDatabase, alias);
  }
}

class KvEntry extends DataClass implements Insertable<KvEntry> {
  final String key;
  final String value;
  const KvEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KvCompanion toCompanion(bool nullToAbsent) {
    return KvCompanion(key: Value(key), value: Value(value));
  }

  factory KvEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KvEntry copyWith({String? key, String? value}) =>
      KvEntry(key: key ?? this.key, value: value ?? this.value);
  KvEntry copyWithCompanion(KvCompanion data) {
    return KvEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvEntry && other.key == this.key && other.value == this.value);
}

class KvCompanion extends UpdateCompanion<KvEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KvEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityTable extends Activity
    with TableInfo<$ActivityTable, ActivityEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, at, kind, message];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
    );
  }

  @override
  $ActivityTable createAlias(String alias) {
    return $ActivityTable(attachedDatabase, alias);
  }
}

class ActivityEvent extends DataClass implements Insertable<ActivityEvent> {
  final int id;
  final DateTime at;

  /// `info`, `download`, `upload`, `delete`, `conflict` or `error`.
  final String kind;
  final String message;
  const ActivityEvent({
    required this.id,
    required this.at,
    required this.kind,
    required this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<DateTime>(at);
    map['kind'] = Variable<String>(kind);
    map['message'] = Variable<String>(message);
    return map;
  }

  ActivityCompanion toCompanion(bool nullToAbsent) {
    return ActivityCompanion(
      id: Value(id),
      at: Value(at),
      kind: Value(kind),
      message: Value(message),
    );
  }

  factory ActivityEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEvent(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      kind: serializer.fromJson<String>(json['kind']),
      message: serializer.fromJson<String>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'kind': serializer.toJson<String>(kind),
      'message': serializer.toJson<String>(message),
    };
  }

  ActivityEvent copyWith({
    int? id,
    DateTime? at,
    String? kind,
    String? message,
  }) => ActivityEvent(
    id: id ?? this.id,
    at: at ?? this.at,
    kind: kind ?? this.kind,
    message: message ?? this.message,
  );
  ActivityEvent copyWithCompanion(ActivityCompanion data) {
    return ActivityEvent(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      kind: data.kind.present ? data.kind.value : this.kind,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEvent(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, at, kind, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEvent &&
          other.id == this.id &&
          other.at == this.at &&
          other.kind == this.kind &&
          other.message == this.message);
}

class ActivityCompanion extends UpdateCompanion<ActivityEvent> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<String> kind;
  final Value<String> message;
  const ActivityCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.kind = const Value.absent(),
    this.message = const Value.absent(),
  });
  ActivityCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    required String kind,
    required String message,
  }) : at = Value(at),
       kind = Value(kind),
       message = Value(message);
  static Insertable<ActivityEvent> custom({
    Expression<int>? id,
    Expression<DateTime>? at,
    Expression<String>? kind,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (kind != null) 'kind': kind,
      if (message != null) 'message': message,
    });
  }

  ActivityCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<String>? kind,
    Value<String>? message,
  }) {
    return ActivityCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      kind: kind ?? this.kind,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DriveItemsTable driveItems = $DriveItemsTable(this);
  late final $SyncSelectionsTable syncSelections = $SyncSelectionsTable(this);
  late final $SyncEntriesTable syncEntries = $SyncEntriesTable(this);
  late final $TransfersTable transfers = $TransfersTable(this);
  late final $KvTable kv = $KvTable(this);
  late final $ActivityTable activity = $ActivityTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    driveItems,
    syncSelections,
    syncEntries,
    transfers,
    kv,
    activity,
  ];
}

typedef $$DriveItemsTableCreateCompanionBuilder =
    DriveItemsCompanion Function({
      required String id,
      Value<String?> parentId,
      required String name,
      required String mimeType,
      Value<int?> size,
      Value<String?> md5,
      Value<DateTime?> modifiedTime,
      Value<DateTime?> viewedTime,
      Value<bool> trashed,
      Value<bool> starred,
      Value<bool> sharedWithMe,
      Value<String?> thumbnailLink,
      Value<String?> webViewLink,
      Value<int> rowid,
    });
typedef $$DriveItemsTableUpdateCompanionBuilder =
    DriveItemsCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<String> mimeType,
      Value<int?> size,
      Value<String?> md5,
      Value<DateTime?> modifiedTime,
      Value<DateTime?> viewedTime,
      Value<bool> trashed,
      Value<bool> starred,
      Value<bool> sharedWithMe,
      Value<String?> thumbnailLink,
      Value<String?> webViewLink,
      Value<int> rowid,
    });

class $$DriveItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DriveItemsTable> {
  $$DriveItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get md5 => $composableBuilder(
    column: $table.md5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedTime => $composableBuilder(
    column: $table.modifiedTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get viewedTime => $composableBuilder(
    column: $table.viewedTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trashed => $composableBuilder(
    column: $table.trashed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sharedWithMe => $composableBuilder(
    column: $table.sharedWithMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailLink => $composableBuilder(
    column: $table.thumbnailLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get webViewLink => $composableBuilder(
    column: $table.webViewLink,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriveItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DriveItemsTable> {
  $$DriveItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get md5 => $composableBuilder(
    column: $table.md5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedTime => $composableBuilder(
    column: $table.modifiedTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get viewedTime => $composableBuilder(
    column: $table.viewedTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trashed => $composableBuilder(
    column: $table.trashed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sharedWithMe => $composableBuilder(
    column: $table.sharedWithMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailLink => $composableBuilder(
    column: $table.thumbnailLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get webViewLink => $composableBuilder(
    column: $table.webViewLink,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriveItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriveItemsTable> {
  $$DriveItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get md5 =>
      $composableBuilder(column: $table.md5, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedTime => $composableBuilder(
    column: $table.modifiedTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get viewedTime => $composableBuilder(
    column: $table.viewedTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trashed =>
      $composableBuilder(column: $table.trashed, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<bool> get sharedWithMe => $composableBuilder(
    column: $table.sharedWithMe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailLink => $composableBuilder(
    column: $table.thumbnailLink,
    builder: (column) => column,
  );

  GeneratedColumn<String> get webViewLink => $composableBuilder(
    column: $table.webViewLink,
    builder: (column) => column,
  );
}

class $$DriveItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriveItemsTable,
          DriveItem,
          $$DriveItemsTableFilterComposer,
          $$DriveItemsTableOrderingComposer,
          $$DriveItemsTableAnnotationComposer,
          $$DriveItemsTableCreateCompanionBuilder,
          $$DriveItemsTableUpdateCompanionBuilder,
          (
            DriveItem,
            BaseReferences<_$AppDatabase, $DriveItemsTable, DriveItem>,
          ),
          DriveItem,
          PrefetchHooks Function()
        > {
  $$DriveItemsTableTableManager(_$AppDatabase db, $DriveItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DriveItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DriveItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DriveItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<String?> md5 = const Value.absent(),
                Value<DateTime?> modifiedTime = const Value.absent(),
                Value<DateTime?> viewedTime = const Value.absent(),
                Value<bool> trashed = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> sharedWithMe = const Value.absent(),
                Value<String?> thumbnailLink = const Value.absent(),
                Value<String?> webViewLink = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriveItemsCompanion(
                id: id,
                parentId: parentId,
                name: name,
                mimeType: mimeType,
                size: size,
                md5: md5,
                modifiedTime: modifiedTime,
                viewedTime: viewedTime,
                trashed: trashed,
                starred: starred,
                sharedWithMe: sharedWithMe,
                thumbnailLink: thumbnailLink,
                webViewLink: webViewLink,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                required String mimeType,
                Value<int?> size = const Value.absent(),
                Value<String?> md5 = const Value.absent(),
                Value<DateTime?> modifiedTime = const Value.absent(),
                Value<DateTime?> viewedTime = const Value.absent(),
                Value<bool> trashed = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> sharedWithMe = const Value.absent(),
                Value<String?> thumbnailLink = const Value.absent(),
                Value<String?> webViewLink = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriveItemsCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                mimeType: mimeType,
                size: size,
                md5: md5,
                modifiedTime: modifiedTime,
                viewedTime: viewedTime,
                trashed: trashed,
                starred: starred,
                sharedWithMe: sharedWithMe,
                thumbnailLink: thumbnailLink,
                webViewLink: webViewLink,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriveItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriveItemsTable,
      DriveItem,
      $$DriveItemsTableFilterComposer,
      $$DriveItemsTableOrderingComposer,
      $$DriveItemsTableAnnotationComposer,
      $$DriveItemsTableCreateCompanionBuilder,
      $$DriveItemsTableUpdateCompanionBuilder,
      (DriveItem, BaseReferences<_$AppDatabase, $DriveItemsTable, DriveItem>),
      DriveItem,
      PrefetchHooks Function()
    >;
typedef $$SyncSelectionsTableCreateCompanionBuilder =
    SyncSelectionsCompanion Function({
      required String itemId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SyncSelectionsTableUpdateCompanionBuilder =
    SyncSelectionsCompanion Function({
      Value<String> itemId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SyncSelectionsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncSelectionsTable> {
  $$SyncSelectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncSelectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncSelectionsTable> {
  $$SyncSelectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncSelectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncSelectionsTable> {
  $$SyncSelectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncSelectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncSelectionsTable,
          SyncSelection,
          $$SyncSelectionsTableFilterComposer,
          $$SyncSelectionsTableOrderingComposer,
          $$SyncSelectionsTableAnnotationComposer,
          $$SyncSelectionsTableCreateCompanionBuilder,
          $$SyncSelectionsTableUpdateCompanionBuilder,
          (
            SyncSelection,
            BaseReferences<_$AppDatabase, $SyncSelectionsTable, SyncSelection>,
          ),
          SyncSelection,
          PrefetchHooks Function()
        > {
  $$SyncSelectionsTableTableManager(
    _$AppDatabase db,
    $SyncSelectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSelectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSelectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSelectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncSelectionsCompanion(
                itemId: itemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncSelectionsCompanion.insert(
                itemId: itemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncSelectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncSelectionsTable,
      SyncSelection,
      $$SyncSelectionsTableFilterComposer,
      $$SyncSelectionsTableOrderingComposer,
      $$SyncSelectionsTableAnnotationComposer,
      $$SyncSelectionsTableCreateCompanionBuilder,
      $$SyncSelectionsTableUpdateCompanionBuilder,
      (
        SyncSelection,
        BaseReferences<_$AppDatabase, $SyncSelectionsTable, SyncSelection>,
      ),
      SyncSelection,
      PrefetchHooks Function()
    >;
typedef $$SyncEntriesTableCreateCompanionBuilder =
    SyncEntriesCompanion Function({
      required String fileId,
      required String relPath,
      Value<bool> isFolder,
      Value<bool> isNative,
      Value<int?> localSize,
      Value<int?> localMtimeMs,
      Value<String?> localMd5,
      Value<String?> remoteMd5,
      Value<int?> remoteModifiedMs,
      Value<bool> localEdited,
      Value<int> rowid,
    });
typedef $$SyncEntriesTableUpdateCompanionBuilder =
    SyncEntriesCompanion Function({
      Value<String> fileId,
      Value<String> relPath,
      Value<bool> isFolder,
      Value<bool> isNative,
      Value<int?> localSize,
      Value<int?> localMtimeMs,
      Value<String?> localMd5,
      Value<String?> remoteMd5,
      Value<int?> remoteModifiedMs,
      Value<bool> localEdited,
      Value<int> rowid,
    });

class $$SyncEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncEntriesTable> {
  $$SyncEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFolder => $composableBuilder(
    column: $table.isFolder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNative => $composableBuilder(
    column: $table.isNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localSize => $composableBuilder(
    column: $table.localSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localMtimeMs => $composableBuilder(
    column: $table.localMtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localMd5 => $composableBuilder(
    column: $table.localMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteMd5 => $composableBuilder(
    column: $table.remoteMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteModifiedMs => $composableBuilder(
    column: $table.remoteModifiedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localEdited => $composableBuilder(
    column: $table.localEdited,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncEntriesTable> {
  $$SyncEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFolder => $composableBuilder(
    column: $table.isFolder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNative => $composableBuilder(
    column: $table.isNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localSize => $composableBuilder(
    column: $table.localSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localMtimeMs => $composableBuilder(
    column: $table.localMtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localMd5 => $composableBuilder(
    column: $table.localMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteMd5 => $composableBuilder(
    column: $table.remoteMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteModifiedMs => $composableBuilder(
    column: $table.remoteModifiedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localEdited => $composableBuilder(
    column: $table.localEdited,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncEntriesTable> {
  $$SyncEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<bool> get isFolder =>
      $composableBuilder(column: $table.isFolder, builder: (column) => column);

  GeneratedColumn<bool> get isNative =>
      $composableBuilder(column: $table.isNative, builder: (column) => column);

  GeneratedColumn<int> get localSize =>
      $composableBuilder(column: $table.localSize, builder: (column) => column);

  GeneratedColumn<int> get localMtimeMs => $composableBuilder(
    column: $table.localMtimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localMd5 =>
      $composableBuilder(column: $table.localMd5, builder: (column) => column);

  GeneratedColumn<String> get remoteMd5 =>
      $composableBuilder(column: $table.remoteMd5, builder: (column) => column);

  GeneratedColumn<int> get remoteModifiedMs => $composableBuilder(
    column: $table.remoteModifiedMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localEdited => $composableBuilder(
    column: $table.localEdited,
    builder: (column) => column,
  );
}

class $$SyncEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncEntriesTable,
          SyncEntry,
          $$SyncEntriesTableFilterComposer,
          $$SyncEntriesTableOrderingComposer,
          $$SyncEntriesTableAnnotationComposer,
          $$SyncEntriesTableCreateCompanionBuilder,
          $$SyncEntriesTableUpdateCompanionBuilder,
          (
            SyncEntry,
            BaseReferences<_$AppDatabase, $SyncEntriesTable, SyncEntry>,
          ),
          SyncEntry,
          PrefetchHooks Function()
        > {
  $$SyncEntriesTableTableManager(_$AppDatabase db, $SyncEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fileId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<bool> isFolder = const Value.absent(),
                Value<bool> isNative = const Value.absent(),
                Value<int?> localSize = const Value.absent(),
                Value<int?> localMtimeMs = const Value.absent(),
                Value<String?> localMd5 = const Value.absent(),
                Value<String?> remoteMd5 = const Value.absent(),
                Value<int?> remoteModifiedMs = const Value.absent(),
                Value<bool> localEdited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncEntriesCompanion(
                fileId: fileId,
                relPath: relPath,
                isFolder: isFolder,
                isNative: isNative,
                localSize: localSize,
                localMtimeMs: localMtimeMs,
                localMd5: localMd5,
                remoteMd5: remoteMd5,
                remoteModifiedMs: remoteModifiedMs,
                localEdited: localEdited,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileId,
                required String relPath,
                Value<bool> isFolder = const Value.absent(),
                Value<bool> isNative = const Value.absent(),
                Value<int?> localSize = const Value.absent(),
                Value<int?> localMtimeMs = const Value.absent(),
                Value<String?> localMd5 = const Value.absent(),
                Value<String?> remoteMd5 = const Value.absent(),
                Value<int?> remoteModifiedMs = const Value.absent(),
                Value<bool> localEdited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncEntriesCompanion.insert(
                fileId: fileId,
                relPath: relPath,
                isFolder: isFolder,
                isNative: isNative,
                localSize: localSize,
                localMtimeMs: localMtimeMs,
                localMd5: localMd5,
                remoteMd5: remoteMd5,
                remoteModifiedMs: remoteModifiedMs,
                localEdited: localEdited,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncEntriesTable,
      SyncEntry,
      $$SyncEntriesTableFilterComposer,
      $$SyncEntriesTableOrderingComposer,
      $$SyncEntriesTableAnnotationComposer,
      $$SyncEntriesTableCreateCompanionBuilder,
      $$SyncEntriesTableUpdateCompanionBuilder,
      (SyncEntry, BaseReferences<_$AppDatabase, $SyncEntriesTable, SyncEntry>),
      SyncEntry,
      PrefetchHooks Function()
    >;
typedef $$TransfersTableCreateCompanionBuilder =
    TransfersCompanion Function({
      Value<int> id,
      required String direction,
      required String name,
      required String localPath,
      Value<String?> fileId,
      Value<int> totalBytes,
      Value<int> doneBytes,
      Value<String> state,
      Value<String?> error,
      Value<bool> fromSync,
      required DateTime createdAt,
    });
typedef $$TransfersTableUpdateCompanionBuilder =
    TransfersCompanion Function({
      Value<int> id,
      Value<String> direction,
      Value<String> name,
      Value<String> localPath,
      Value<String?> fileId,
      Value<int> totalBytes,
      Value<int> doneBytes,
      Value<String> state,
      Value<String?> error,
      Value<bool> fromSync,
      Value<DateTime> createdAt,
    });

class $$TransfersTableFilterComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneBytes => $composableBuilder(
    column: $table.doneBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromSync => $composableBuilder(
    column: $table.fromSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransfersTableOrderingComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneBytes => $composableBuilder(
    column: $table.doneBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromSync => $composableBuilder(
    column: $table.fromSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransfersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doneBytes =>
      $composableBuilder(column: $table.doneBytes, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<bool> get fromSync =>
      $composableBuilder(column: $table.fromSync, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TransfersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransfersTable,
          Transfer,
          $$TransfersTableFilterComposer,
          $$TransfersTableOrderingComposer,
          $$TransfersTableAnnotationComposer,
          $$TransfersTableCreateCompanionBuilder,
          $$TransfersTableUpdateCompanionBuilder,
          (Transfer, BaseReferences<_$AppDatabase, $TransfersTable, Transfer>),
          Transfer,
          PrefetchHooks Function()
        > {
  $$TransfersTableTableManager(_$AppDatabase db, $TransfersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String?> fileId = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> doneBytes = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> fromSync = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TransfersCompanion(
                id: id,
                direction: direction,
                name: name,
                localPath: localPath,
                fileId: fileId,
                totalBytes: totalBytes,
                doneBytes: doneBytes,
                state: state,
                error: error,
                fromSync: fromSync,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String direction,
                required String name,
                required String localPath,
                Value<String?> fileId = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> doneBytes = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> fromSync = const Value.absent(),
                required DateTime createdAt,
              }) => TransfersCompanion.insert(
                id: id,
                direction: direction,
                name: name,
                localPath: localPath,
                fileId: fileId,
                totalBytes: totalBytes,
                doneBytes: doneBytes,
                state: state,
                error: error,
                fromSync: fromSync,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransfersTable,
      Transfer,
      $$TransfersTableFilterComposer,
      $$TransfersTableOrderingComposer,
      $$TransfersTableAnnotationComposer,
      $$TransfersTableCreateCompanionBuilder,
      $$TransfersTableUpdateCompanionBuilder,
      (Transfer, BaseReferences<_$AppDatabase, $TransfersTable, Transfer>),
      Transfer,
      PrefetchHooks Function()
    >;
typedef $$KvTableCreateCompanionBuilder =
    KvCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KvTableUpdateCompanionBuilder =
    KvCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KvTableFilterComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvTableOrderingComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvTableAnnotationComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KvTable,
          KvEntry,
          $$KvTableFilterComposer,
          $$KvTableOrderingComposer,
          $$KvTableAnnotationComposer,
          $$KvTableCreateCompanionBuilder,
          $$KvTableUpdateCompanionBuilder,
          (KvEntry, BaseReferences<_$AppDatabase, $KvTable, KvEntry>),
          KvEntry,
          PrefetchHooks Function()
        > {
  $$KvTableTableManager(_$AppDatabase db, $KvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KvTable,
      KvEntry,
      $$KvTableFilterComposer,
      $$KvTableOrderingComposer,
      $$KvTableAnnotationComposer,
      $$KvTableCreateCompanionBuilder,
      $$KvTableUpdateCompanionBuilder,
      (KvEntry, BaseReferences<_$AppDatabase, $KvTable, KvEntry>),
      KvEntry,
      PrefetchHooks Function()
    >;
typedef $$ActivityTableCreateCompanionBuilder =
    ActivityCompanion Function({
      Value<int> id,
      required DateTime at,
      required String kind,
      required String message,
    });
typedef $$ActivityTableUpdateCompanionBuilder =
    ActivityCompanion Function({
      Value<int> id,
      Value<DateTime> at,
      Value<String> kind,
      Value<String> message,
    });

class $$ActivityTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityTable> {
  $$ActivityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityTable> {
  $$ActivityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityTable> {
  $$ActivityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$ActivityTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityTable,
          ActivityEvent,
          $$ActivityTableFilterComposer,
          $$ActivityTableOrderingComposer,
          $$ActivityTableAnnotationComposer,
          $$ActivityTableCreateCompanionBuilder,
          $$ActivityTableUpdateCompanionBuilder,
          (
            ActivityEvent,
            BaseReferences<_$AppDatabase, $ActivityTable, ActivityEvent>,
          ),
          ActivityEvent,
          PrefetchHooks Function()
        > {
  $$ActivityTableTableManager(_$AppDatabase db, $ActivityTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> message = const Value.absent(),
              }) => ActivityCompanion(
                id: id,
                at: at,
                kind: kind,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime at,
                required String kind,
                required String message,
              }) => ActivityCompanion.insert(
                id: id,
                at: at,
                kind: kind,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityTable,
      ActivityEvent,
      $$ActivityTableFilterComposer,
      $$ActivityTableOrderingComposer,
      $$ActivityTableAnnotationComposer,
      $$ActivityTableCreateCompanionBuilder,
      $$ActivityTableUpdateCompanionBuilder,
      (
        ActivityEvent,
        BaseReferences<_$AppDatabase, $ActivityTable, ActivityEvent>,
      ),
      ActivityEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DriveItemsTableTableManager get driveItems =>
      $$DriveItemsTableTableManager(_db, _db.driveItems);
  $$SyncSelectionsTableTableManager get syncSelections =>
      $$SyncSelectionsTableTableManager(_db, _db.syncSelections);
  $$SyncEntriesTableTableManager get syncEntries =>
      $$SyncEntriesTableTableManager(_db, _db.syncEntries);
  $$TransfersTableTableManager get transfers =>
      $$TransfersTableTableManager(_db, _db.transfers);
  $$KvTableTableManager get kv => $$KvTableTableManager(_db, _db.kv);
  $$ActivityTableTableManager get activity =>
      $$ActivityTableTableManager(_db, _db.activity);
}
