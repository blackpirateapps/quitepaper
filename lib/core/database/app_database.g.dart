// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NotesTableTable extends NotesTable
    with TableInfo<$NotesTableTable, NoteEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isTrashedMeta = const VerificationMeta(
    'isTrashed',
  );
  @override
  late final GeneratedColumn<bool> isTrashed = GeneratedColumn<bool>(
    'is_trashed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_trashed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    createdAt,
    updatedAt,
    isPinned,
    isArchived,
    isTrashed,
    deletedAt,
    serverRevision,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('is_trashed')) {
      context.handle(
        _isTrashedMeta,
        isTrashed.isAcceptableOrUnknown(data['is_trashed']!, _isTrashedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isTrashed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_trashed'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $NotesTableTable createAlias(String alias) {
    return $NotesTableTable(attachedDatabase, alias);
  }
}

class NoteEntity extends DataClass implements Insertable<NoteEntity> {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final bool isTrashed;
  final DateTime? deletedAt;
  final int serverRevision;
  final bool isDirty;
  final DateTime? syncedAt;
  const NoteEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.isArchived,
    required this.isTrashed,
    this.deletedAt,
    required this.serverRevision,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_trashed'] = Variable<bool>(isTrashed);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['server_revision'] = Variable<int>(serverRevision);
    map['is_dirty'] = Variable<bool>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  NotesTableCompanion toCompanion(bool nullToAbsent) {
    return NotesTableCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
      isTrashed: Value(isTrashed),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverRevision: Value(serverRevision),
      isDirty: Value(isDirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory NoteEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteEntity(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isTrashed: serializer.fromJson<bool>(json['isTrashed']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isTrashed': serializer.toJson<bool>(isTrashed),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
      'isDirty': serializer.toJson<bool>(isDirty),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  NoteEntity copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isArchived,
    bool? isTrashed,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? serverRevision,
    bool? isDirty,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => NoteEntity(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    isTrashed: isTrashed ?? this.isTrashed,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverRevision: serverRevision ?? this.serverRevision,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  NoteEntity copyWithCompanion(NotesTableCompanion data) {
    return NoteEntity(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isTrashed: data.isTrashed.present ? data.isTrashed.value : this.isTrashed,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteEntity(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('isTrashed: $isTrashed, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    createdAt,
    updatedAt,
    isPinned,
    isArchived,
    isTrashed,
    deletedAt,
    serverRevision,
    isDirty,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteEntity &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived &&
          other.isTrashed == this.isTrashed &&
          other.deletedAt == this.deletedAt &&
          other.serverRevision == this.serverRevision &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class NotesTableCompanion extends UpdateCompanion<NoteEntity> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<bool> isTrashed;
  final Value<DateTime?> deletedAt;
  final Value<int> serverRevision;
  final Value<bool> isDirty;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const NotesTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isTrashed = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesTableCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isTrashed = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteEntity> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<bool>? isTrashed,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverRevision,
    Expression<bool>? isDirty,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (isTrashed != null) 'is_trashed': isTrashed,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isPinned,
    Value<bool>? isArchived,
    Value<bool>? isTrashed,
    Value<DateTime?>? deletedAt,
    Value<int>? serverRevision,
    Value<bool>? isDirty,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return NotesTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      deletedAt: deletedAt ?? this.deletedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isTrashed.present) {
      map['is_trashed'] = Variable<bool>(isTrashed.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('isTrashed: $isTrashed, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTableTable extends TagsTable
    with TableInfo<$TagsTableTable, TagEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTableTable createAlias(String alias) {
    return $TagsTableTable(attachedDatabase, alias);
  }
}

class TagEntity extends DataClass implements Insertable<TagEntity> {
  final String id;
  final String name;
  const TagEntity({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsTableCompanion toCompanion(bool nullToAbsent) {
    return TagsTableCompanion(id: Value(id), name: Value(name));
  }

  factory TagEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  TagEntity copyWith({String? id, String? name}) =>
      TagEntity(id: id ?? this.id, name: name ?? this.name);
  TagEntity copyWithCompanion(TagsTableCompanion data) {
    return TagEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagEntity(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagEntity && other.id == this.id && other.name == this.name);
}

class TagsTableCompanion extends UpdateCompanion<TagEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const TagsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsTableCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<TagEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TagsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTagsTableTable extends NoteTagsTable
    with TableInfo<$NoteTagsTableTable, NoteTagEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTagEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tagId};
  @override
  NoteTagEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTagEntity(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $NoteTagsTableTable createAlias(String alias) {
    return $NoteTagsTableTable(attachedDatabase, alias);
  }
}

class NoteTagEntity extends DataClass implements Insertable<NoteTagEntity> {
  final String noteId;
  final String tagId;
  const NoteTagEntity({required this.noteId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  NoteTagsTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTagsTableCompanion(noteId: Value(noteId), tagId: Value(tagId));
  }

  factory NoteTagEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTagEntity(
      noteId: serializer.fromJson<String>(json['noteId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  NoteTagEntity copyWith({String? noteId, String? tagId}) =>
      NoteTagEntity(noteId: noteId ?? this.noteId, tagId: tagId ?? this.tagId);
  NoteTagEntity copyWithCompanion(NoteTagsTableCompanion data) {
    return NoteTagEntity(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagEntity(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTagEntity &&
          other.noteId == this.noteId &&
          other.tagId == this.tagId);
}

class NoteTagsTableCompanion extends UpdateCompanion<NoteTagEntity> {
  final Value<String> noteId;
  final Value<String> tagId;
  final Value<int> rowid;
  const NoteTagsTableCompanion({
    this.noteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagsTableCompanion.insert({
    required String noteId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tagId = Value(tagId);
  static Insertable<NoteTagEntity> custom({
    Expression<String>? noteId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagsTableCompanion copyWith({
    Value<String>? noteId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return NoteTagsTableCompanion(
      noteId: noteId ?? this.noteId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagsTableCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTableTable extends SyncMetadataTable
    with TableInfo<$SyncMetadataTableTable, SyncMetadataEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataEntity> instance, {
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataEntity(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncMetadataTableTable createAlias(String alias) {
    return $SyncMetadataTableTable(attachedDatabase, alias);
  }
}

class SyncMetadataEntity extends DataClass
    implements Insertable<SyncMetadataEntity> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const SyncMetadataEntity({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncMetadataTableCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncMetadataEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataEntity(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncMetadataEntity copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => SyncMetadataEntity(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncMetadataEntity copyWithCompanion(SyncMetadataTableCompanion data) {
    return SyncMetadataEntity(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataEntity(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataEntity &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncMetadataTableCompanion extends UpdateCompanion<SyncMetadataEntity> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncMetadataTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataTableCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SyncMetadataEntity> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncMetadataTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
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
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    operation,
    createdAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueEntity extends DataClass implements Insertable<SyncQueueEntity> {
  final String id;
  final String noteId;
  final String operation;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const SyncQueueEntity({
    required this.id,
    required this.noteId,
    required this.operation,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['operation'] = Variable<String>(operation);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      operation: Value(operation),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncQueueEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntity(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      operation: serializer.fromJson<String>(json['operation']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'operation': serializer.toJson<String>(operation),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncQueueEntity copyWith({
    String? id,
    String? noteId,
    String? operation,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => SyncQueueEntity(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    operation: operation ?? this.operation,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncQueueEntity copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueEntity(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      operation: data.operation.present ? data.operation.value : this.operation,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntity(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('operation: $operation, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, noteId, operation, createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntity &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.operation == this.operation &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueEntity> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> operation;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.operation = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    required String id,
    required String noteId,
    required String operation,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       operation = Value(operation),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueEntity> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? operation,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (operation != null) 'operation': operation,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueTableCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? operation,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      operation: operation ?? this.operation,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('operation: $operation, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTableTable extends AttachmentsTable
    with TableInfo<$AttachmentsTableTable, AttachmentEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    defaultValue: const Constant('image/png'),
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _encryptionKeyVersionMeta =
      const VerificationMeta('encryptionKeyVersion');
  @override
  late final GeneratedColumn<int> encryptionKeyVersion = GeneratedColumn<int>(
    'encryption_key_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _cloudPublicIdMeta = const VerificationMeta(
    'cloudPublicId',
  );
  @override
  late final GeneratedColumn<String> cloudPublicId = GeneratedColumn<String>(
    'cloud_public_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudUrlMeta = const VerificationMeta(
    'cloudUrl',
  );
  @override
  late final GeneratedColumn<String> cloudUrl = GeneratedColumn<String>(
    'cloud_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    createdAt,
    updatedAt,
    mimeType,
    byteSize,
    width,
    height,
    sha256,
    encryptionKeyVersion,
    isDirty,
    isDeleted,
    deletedAt,
    serverRevision,
    syncedAt,
    uploadState,
    cloudPublicId,
    cloudUrl,
    localPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('encryption_key_version')) {
      context.handle(
        _encryptionKeyVersionMeta,
        encryptionKeyVersion.isAcceptableOrUnknown(
          data['encryption_key_version']!,
          _encryptionKeyVersionMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('cloud_public_id')) {
      context.handle(
        _cloudPublicIdMeta,
        cloudPublicId.isAcceptableOrUnknown(
          data['cloud_public_id']!,
          _cloudPublicIdMeta,
        ),
      );
    }
    if (data.containsKey('cloud_url')) {
      context.handle(
        _cloudUrlMeta,
        cloudUrl.isAcceptableOrUnknown(data['cloud_url']!, _cloudUrlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      encryptionKeyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_key_version'],
      )!,
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      cloudPublicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_public_id'],
      ),
      cloudUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_url'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
    );
  }

  @override
  $AttachmentsTableTable createAlias(String alias) {
    return $AttachmentsTableTable(attachedDatabase, alias);
  }
}

class AttachmentEntity extends DataClass
    implements Insertable<AttachmentEntity> {
  /// Canonical UUID primary key
  final String id;

  /// Associated note ID (can be null for detached/unassigned attachments)
  final String? noteId;

  /// Creation timestamp
  final DateTime createdAt;

  /// Update timestamp
  final DateTime updatedAt;

  /// MIME type (e.g. 'image/png', 'image/jpeg', 'image/webp')
  final String mimeType;

  /// Plaintext byte size in bytes
  final int byteSize;

  /// Image pixel width
  final int? width;

  /// Image pixel height
  final int? height;

  /// Plaintext SHA-256 hash
  final String sha256;

  /// Key version used to encrypt this attachment
  final int encryptionKeyVersion;

  /// Whether local changes need synchronization
  final bool isDirty;

  /// Whether attachment is tombstoned/deleted
  final bool isDeleted;

  /// Timestamp when deletion occurred
  final DateTime? deletedAt;

  /// Cloud revision assigned by control plane
  final int serverRevision;

  /// Timestamp of last successful metadata sync
  final DateTime? syncedAt;

  /// Lifecycle state: 'local_only', 'upload_pending', 'uploading', 'uploaded', 'failed', 'synced'
  final String uploadState;

  /// Cloudinary public ID
  final String? cloudPublicId;

  /// Cloudinary delivery URL
  final String? cloudUrl;

  /// Local app-private encrypted file path
  final String? localPath;
  const AttachmentEntity({
    required this.id,
    this.noteId,
    required this.createdAt,
    required this.updatedAt,
    required this.mimeType,
    required this.byteSize,
    this.width,
    this.height,
    required this.sha256,
    required this.encryptionKeyVersion,
    required this.isDirty,
    required this.isDeleted,
    this.deletedAt,
    required this.serverRevision,
    this.syncedAt,
    required this.uploadState,
    this.cloudPublicId,
    this.cloudUrl,
    this.localPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['mime_type'] = Variable<String>(mimeType);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['sha256'] = Variable<String>(sha256);
    map['encryption_key_version'] = Variable<int>(encryptionKeyVersion);
    map['is_dirty'] = Variable<bool>(isDirty);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['server_revision'] = Variable<int>(serverRevision);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['upload_state'] = Variable<String>(uploadState);
    if (!nullToAbsent || cloudPublicId != null) {
      map['cloud_public_id'] = Variable<String>(cloudPublicId);
    }
    if (!nullToAbsent || cloudUrl != null) {
      map['cloud_url'] = Variable<String>(cloudUrl);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    return map;
  }

  AttachmentsTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsTableCompanion(
      id: Value(id),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      mimeType: Value(mimeType),
      byteSize: Value(byteSize),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      sha256: Value(sha256),
      encryptionKeyVersion: Value(encryptionKeyVersion),
      isDirty: Value(isDirty),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverRevision: Value(serverRevision),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      uploadState: Value(uploadState),
      cloudPublicId: cloudPublicId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudPublicId),
      cloudUrl: cloudUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
    );
  }

  factory AttachmentEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentEntity(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      sha256: serializer.fromJson<String>(json['sha256']),
      encryptionKeyVersion: serializer.fromJson<int>(
        json['encryptionKeyVersion'],
      ),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      cloudPublicId: serializer.fromJson<String?>(json['cloudPublicId']),
      cloudUrl: serializer.fromJson<String?>(json['cloudUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String?>(noteId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'mimeType': serializer.toJson<String>(mimeType),
      'byteSize': serializer.toJson<int>(byteSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'sha256': serializer.toJson<String>(sha256),
      'encryptionKeyVersion': serializer.toJson<int>(encryptionKeyVersion),
      'isDirty': serializer.toJson<bool>(isDirty),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'uploadState': serializer.toJson<String>(uploadState),
      'cloudPublicId': serializer.toJson<String?>(cloudPublicId),
      'cloudUrl': serializer.toJson<String?>(cloudUrl),
      'localPath': serializer.toJson<String?>(localPath),
    };
  }

  AttachmentEntity copyWith({
    String? id,
    Value<String?> noteId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mimeType,
    int? byteSize,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    String? sha256,
    int? encryptionKeyVersion,
    bool? isDirty,
    bool? isDeleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? serverRevision,
    Value<DateTime?> syncedAt = const Value.absent(),
    String? uploadState,
    Value<String?> cloudPublicId = const Value.absent(),
    Value<String?> cloudUrl = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
  }) => AttachmentEntity(
    id: id ?? this.id,
    noteId: noteId.present ? noteId.value : this.noteId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mimeType: mimeType ?? this.mimeType,
    byteSize: byteSize ?? this.byteSize,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    sha256: sha256 ?? this.sha256,
    encryptionKeyVersion: encryptionKeyVersion ?? this.encryptionKeyVersion,
    isDirty: isDirty ?? this.isDirty,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverRevision: serverRevision ?? this.serverRevision,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    uploadState: uploadState ?? this.uploadState,
    cloudPublicId: cloudPublicId.present
        ? cloudPublicId.value
        : this.cloudPublicId,
    cloudUrl: cloudUrl.present ? cloudUrl.value : this.cloudUrl,
    localPath: localPath.present ? localPath.value : this.localPath,
  );
  AttachmentEntity copyWithCompanion(AttachmentsTableCompanion data) {
    return AttachmentEntity(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      encryptionKeyVersion: data.encryptionKeyVersion.present
          ? data.encryptionKeyVersion.value
          : this.encryptionKeyVersion,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      cloudPublicId: data.cloudPublicId.present
          ? data.cloudPublicId.value
          : this.cloudPublicId,
      cloudUrl: data.cloudUrl.present ? data.cloudUrl.value : this.cloudUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentEntity(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sha256: $sha256, ')
          ..write('encryptionKeyVersion: $encryptionKeyVersion, ')
          ..write('isDirty: $isDirty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('cloudPublicId: $cloudPublicId, ')
          ..write('cloudUrl: $cloudUrl, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    createdAt,
    updatedAt,
    mimeType,
    byteSize,
    width,
    height,
    sha256,
    encryptionKeyVersion,
    isDirty,
    isDeleted,
    deletedAt,
    serverRevision,
    syncedAt,
    uploadState,
    cloudPublicId,
    cloudUrl,
    localPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentEntity &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.mimeType == this.mimeType &&
          other.byteSize == this.byteSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.sha256 == this.sha256 &&
          other.encryptionKeyVersion == this.encryptionKeyVersion &&
          other.isDirty == this.isDirty &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.serverRevision == this.serverRevision &&
          other.syncedAt == this.syncedAt &&
          other.uploadState == this.uploadState &&
          other.cloudPublicId == this.cloudPublicId &&
          other.cloudUrl == this.cloudUrl &&
          other.localPath == this.localPath);
}

class AttachmentsTableCompanion extends UpdateCompanion<AttachmentEntity> {
  final Value<String> id;
  final Value<String?> noteId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> mimeType;
  final Value<int> byteSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String> sha256;
  final Value<int> encryptionKeyVersion;
  final Value<bool> isDirty;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  final Value<int> serverRevision;
  final Value<DateTime?> syncedAt;
  final Value<String> uploadState;
  final Value<String?> cloudPublicId;
  final Value<String?> cloudUrl;
  final Value<String?> localPath;
  final Value<int> rowid;
  const AttachmentsTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.encryptionKeyVersion = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.cloudPublicId = const Value.absent(),
    this.cloudUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsTableCompanion.insert({
    required String id,
    this.noteId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.mimeType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.encryptionKeyVersion = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.cloudPublicId = const Value.absent(),
    this.cloudUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AttachmentEntity> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? mimeType,
    Expression<int>? byteSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? sha256,
    Expression<int>? encryptionKeyVersion,
    Expression<bool>? isDirty,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverRevision,
    Expression<DateTime>? syncedAt,
    Expression<String>? uploadState,
    Expression<String>? cloudPublicId,
    Expression<String>? cloudUrl,
    Expression<String>? localPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (mimeType != null) 'mime_type': mimeType,
      if (byteSize != null) 'byte_size': byteSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sha256 != null) 'sha256': sha256,
      if (encryptionKeyVersion != null)
        'encryption_key_version': encryptionKeyVersion,
      if (isDirty != null) 'is_dirty': isDirty,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (uploadState != null) 'upload_state': uploadState,
      if (cloudPublicId != null) 'cloud_public_id': cloudPublicId,
      if (cloudUrl != null) 'cloud_url': cloudUrl,
      if (localPath != null) 'local_path': localPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? noteId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? mimeType,
    Value<int>? byteSize,
    Value<int?>? width,
    Value<int?>? height,
    Value<String>? sha256,
    Value<int>? encryptionKeyVersion,
    Value<bool>? isDirty,
    Value<bool>? isDeleted,
    Value<DateTime?>? deletedAt,
    Value<int>? serverRevision,
    Value<DateTime?>? syncedAt,
    Value<String>? uploadState,
    Value<String?>? cloudPublicId,
    Value<String?>? cloudUrl,
    Value<String?>? localPath,
    Value<int>? rowid,
  }) {
    return AttachmentsTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      width: width ?? this.width,
      height: height ?? this.height,
      sha256: sha256 ?? this.sha256,
      encryptionKeyVersion: encryptionKeyVersion ?? this.encryptionKeyVersion,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      syncedAt: syncedAt ?? this.syncedAt,
      uploadState: uploadState ?? this.uploadState,
      cloudPublicId: cloudPublicId ?? this.cloudPublicId,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      localPath: localPath ?? this.localPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (encryptionKeyVersion.present) {
      map['encryption_key_version'] = Variable<int>(encryptionKeyVersion.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (cloudPublicId.present) {
      map['cloud_public_id'] = Variable<String>(cloudPublicId.value);
    }
    if (cloudUrl.present) {
      map['cloud_url'] = Variable<String>(cloudUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sha256: $sha256, ')
          ..write('encryptionKeyVersion: $encryptionKeyVersion, ')
          ..write('isDirty: $isDirty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('cloudPublicId: $cloudPublicId, ')
          ..write('cloudUrl: $cloudUrl, ')
          ..write('localPath: $localPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentVariantsTableTable extends AttachmentVariantsTable
    with TableInfo<$AttachmentVariantsTableTable, AttachmentVariantEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentVariantsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  @override
  late final GeneratedColumn<String> attachmentId = GeneratedColumn<String>(
    'attachment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variantTypeMeta = const VerificationMeta(
    'variantType',
  );
  @override
  late final GeneratedColumn<String> variantType = GeneratedColumn<String>(
    'variant_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudPublicIdMeta = const VerificationMeta(
    'cloudPublicId',
  );
  @override
  late final GeneratedColumn<String> cloudPublicId = GeneratedColumn<String>(
    'cloud_public_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudUrlMeta = const VerificationMeta(
    'cloudUrl',
  );
  @override
  late final GeneratedColumn<String> cloudUrl = GeneratedColumn<String>(
    'cloud_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    attachmentId,
    variantType,
    byteSize,
    width,
    height,
    localPath,
    cloudPublicId,
    cloudUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachment_variants';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentVariantEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('attachment_id')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachment_id']!,
          _attachmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentIdMeta);
    }
    if (data.containsKey('variant_type')) {
      context.handle(
        _variantTypeMeta,
        variantType.isAcceptableOrUnknown(
          data['variant_type']!,
          _variantTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_variantTypeMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('cloud_public_id')) {
      context.handle(
        _cloudPublicIdMeta,
        cloudPublicId.isAcceptableOrUnknown(
          data['cloud_public_id']!,
          _cloudPublicIdMeta,
        ),
      );
    }
    if (data.containsKey('cloud_url')) {
      context.handle(
        _cloudUrlMeta,
        cloudUrl.isAcceptableOrUnknown(data['cloud_url']!, _cloudUrlMeta),
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
  AttachmentVariantEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentVariantEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_id'],
      )!,
      variantType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_type'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      cloudPublicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_public_id'],
      ),
      cloudUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentVariantsTableTable createAlias(String alias) {
    return $AttachmentVariantsTableTable(attachedDatabase, alias);
  }
}

class AttachmentVariantEntity extends DataClass
    implements Insertable<AttachmentVariantEntity> {
  /// UUID primary key for the variant
  final String id;

  /// Foreign key referencing parent attachment
  final String attachmentId;

  /// Variant type: 'original', 'preview', 'thumbnail'
  final String variantType;

  /// Plaintext byte size
  final int byteSize;

  /// Pixel width
  final int? width;

  /// Pixel height
  final int? height;

  /// Local encrypted file path
  final String? localPath;

  /// Cloudinary public ID for variant
  final String? cloudPublicId;

  /// Cloudinary URL for variant
  final String? cloudUrl;

  /// Creation timestamp
  final DateTime createdAt;
  const AttachmentVariantEntity({
    required this.id,
    required this.attachmentId,
    required this.variantType,
    required this.byteSize,
    this.width,
    this.height,
    this.localPath,
    this.cloudPublicId,
    this.cloudUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['attachment_id'] = Variable<String>(attachmentId);
    map['variant_type'] = Variable<String>(variantType);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || cloudPublicId != null) {
      map['cloud_public_id'] = Variable<String>(cloudPublicId);
    }
    if (!nullToAbsent || cloudUrl != null) {
      map['cloud_url'] = Variable<String>(cloudUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentVariantsTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentVariantsTableCompanion(
      id: Value(id),
      attachmentId: Value(attachmentId),
      variantType: Value(variantType),
      byteSize: Value(byteSize),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      cloudPublicId: cloudPublicId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudPublicId),
      cloudUrl: cloudUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudUrl),
      createdAt: Value(createdAt),
    );
  }

  factory AttachmentVariantEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentVariantEntity(
      id: serializer.fromJson<String>(json['id']),
      attachmentId: serializer.fromJson<String>(json['attachmentId']),
      variantType: serializer.fromJson<String>(json['variantType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      cloudPublicId: serializer.fromJson<String?>(json['cloudPublicId']),
      cloudUrl: serializer.fromJson<String?>(json['cloudUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'attachmentId': serializer.toJson<String>(attachmentId),
      'variantType': serializer.toJson<String>(variantType),
      'byteSize': serializer.toJson<int>(byteSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'localPath': serializer.toJson<String?>(localPath),
      'cloudPublicId': serializer.toJson<String?>(cloudPublicId),
      'cloudUrl': serializer.toJson<String?>(cloudUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AttachmentVariantEntity copyWith({
    String? id,
    String? attachmentId,
    String? variantType,
    int? byteSize,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> cloudPublicId = const Value.absent(),
    Value<String?> cloudUrl = const Value.absent(),
    DateTime? createdAt,
  }) => AttachmentVariantEntity(
    id: id ?? this.id,
    attachmentId: attachmentId ?? this.attachmentId,
    variantType: variantType ?? this.variantType,
    byteSize: byteSize ?? this.byteSize,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    localPath: localPath.present ? localPath.value : this.localPath,
    cloudPublicId: cloudPublicId.present
        ? cloudPublicId.value
        : this.cloudPublicId,
    cloudUrl: cloudUrl.present ? cloudUrl.value : this.cloudUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  AttachmentVariantEntity copyWithCompanion(
    AttachmentVariantsTableCompanion data,
  ) {
    return AttachmentVariantEntity(
      id: data.id.present ? data.id.value : this.id,
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      variantType: data.variantType.present
          ? data.variantType.value
          : this.variantType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      cloudPublicId: data.cloudPublicId.present
          ? data.cloudPublicId.value
          : this.cloudPublicId,
      cloudUrl: data.cloudUrl.present ? data.cloudUrl.value : this.cloudUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentVariantEntity(')
          ..write('id: $id, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('variantType: $variantType, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('localPath: $localPath, ')
          ..write('cloudPublicId: $cloudPublicId, ')
          ..write('cloudUrl: $cloudUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    attachmentId,
    variantType,
    byteSize,
    width,
    height,
    localPath,
    cloudPublicId,
    cloudUrl,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentVariantEntity &&
          other.id == this.id &&
          other.attachmentId == this.attachmentId &&
          other.variantType == this.variantType &&
          other.byteSize == this.byteSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.localPath == this.localPath &&
          other.cloudPublicId == this.cloudPublicId &&
          other.cloudUrl == this.cloudUrl &&
          other.createdAt == this.createdAt);
}

class AttachmentVariantsTableCompanion
    extends UpdateCompanion<AttachmentVariantEntity> {
  final Value<String> id;
  final Value<String> attachmentId;
  final Value<String> variantType;
  final Value<int> byteSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> localPath;
  final Value<String?> cloudPublicId;
  final Value<String?> cloudUrl;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttachmentVariantsTableCompanion({
    this.id = const Value.absent(),
    this.attachmentId = const Value.absent(),
    this.variantType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.localPath = const Value.absent(),
    this.cloudPublicId = const Value.absent(),
    this.cloudUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentVariantsTableCompanion.insert({
    required String id,
    required String attachmentId,
    required String variantType,
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.localPath = const Value.absent(),
    this.cloudPublicId = const Value.absent(),
    this.cloudUrl = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       attachmentId = Value(attachmentId),
       variantType = Value(variantType),
       createdAt = Value(createdAt);
  static Insertable<AttachmentVariantEntity> custom({
    Expression<String>? id,
    Expression<String>? attachmentId,
    Expression<String>? variantType,
    Expression<int>? byteSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? localPath,
    Expression<String>? cloudPublicId,
    Expression<String>? cloudUrl,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (variantType != null) 'variant_type': variantType,
      if (byteSize != null) 'byte_size': byteSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (localPath != null) 'local_path': localPath,
      if (cloudPublicId != null) 'cloud_public_id': cloudPublicId,
      if (cloudUrl != null) 'cloud_url': cloudUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentVariantsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? attachmentId,
    Value<String>? variantType,
    Value<int>? byteSize,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? localPath,
    Value<String?>? cloudPublicId,
    Value<String?>? cloudUrl,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentVariantsTableCompanion(
      id: id ?? this.id,
      attachmentId: attachmentId ?? this.attachmentId,
      variantType: variantType ?? this.variantType,
      byteSize: byteSize ?? this.byteSize,
      width: width ?? this.width,
      height: height ?? this.height,
      localPath: localPath ?? this.localPath,
      cloudPublicId: cloudPublicId ?? this.cloudPublicId,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (attachmentId.present) {
      map['attachment_id'] = Variable<String>(attachmentId.value);
    }
    if (variantType.present) {
      map['variant_type'] = Variable<String>(variantType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (cloudPublicId.present) {
      map['cloud_public_id'] = Variable<String>(cloudPublicId.value);
    }
    if (cloudUrl.present) {
      map['cloud_url'] = Variable<String>(cloudUrl.value);
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
    return (StringBuffer('AttachmentVariantsTableCompanion(')
          ..write('id: $id, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('variantType: $variantType, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('localPath: $localPath, ')
          ..write('cloudPublicId: $cloudPublicId, ')
          ..write('cloudUrl: $cloudUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteVersionsTableTable extends NoteVersionsTable
    with TableInfo<$NoteVersionsTableTable, NoteVersionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteVersionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _versionNumberMeta = const VerificationMeta(
    'versionNumber',
  );
  @override
  late final GeneratedColumn<int> versionNumber = GeneratedColumn<int>(
    'version_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
  static const VerificationMeta _charCountMeta = const VerificationMeta(
    'charCount',
  );
  @override
  late final GeneratedColumn<int> charCount = GeneratedColumn<int>(
    'char_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deltaSummaryMeta = const VerificationMeta(
    'deltaSummary',
  );
  @override
  late final GeneratedColumn<String> deltaSummary = GeneratedColumn<String>(
    'delta_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    versionNumber,
    title,
    content,
    tagsJson,
    createdAt,
    charCount,
    wordCount,
    deltaSummary,
    serverRevision,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteVersionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('version_number')) {
      context.handle(
        _versionNumberMeta,
        versionNumber.isAcceptableOrUnknown(
          data['version_number']!,
          _versionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionNumberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
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
    if (data.containsKey('char_count')) {
      context.handle(
        _charCountMeta,
        charCount.isAcceptableOrUnknown(data['char_count']!, _charCountMeta),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('delta_summary')) {
      context.handle(
        _deltaSummaryMeta,
        deltaSummary.isAcceptableOrUnknown(
          data['delta_summary']!,
          _deltaSummaryMeta,
        ),
      );
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteVersionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteVersionEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      versionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      charCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_count'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      deltaSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delta_summary'],
      ),
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $NoteVersionsTableTable createAlias(String alias) {
    return $NoteVersionsTableTable(attachedDatabase, alias);
  }
}

class NoteVersionEntity extends DataClass
    implements Insertable<NoteVersionEntity> {
  final String id;
  final String noteId;
  final int versionNumber;
  final String title;
  final String content;
  final String tagsJson;
  final DateTime createdAt;
  final int charCount;
  final int wordCount;
  final String? deltaSummary;
  final int serverRevision;
  final bool isDirty;
  final DateTime? syncedAt;
  const NoteVersionEntity({
    required this.id,
    required this.noteId,
    required this.versionNumber,
    required this.title,
    required this.content,
    required this.tagsJson,
    required this.createdAt,
    required this.charCount,
    required this.wordCount,
    this.deltaSummary,
    required this.serverRevision,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['version_number'] = Variable<int>(versionNumber);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['tags_json'] = Variable<String>(tagsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['char_count'] = Variable<int>(charCount);
    map['word_count'] = Variable<int>(wordCount);
    if (!nullToAbsent || deltaSummary != null) {
      map['delta_summary'] = Variable<String>(deltaSummary);
    }
    map['server_revision'] = Variable<int>(serverRevision);
    map['is_dirty'] = Variable<bool>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  NoteVersionsTableCompanion toCompanion(bool nullToAbsent) {
    return NoteVersionsTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      versionNumber: Value(versionNumber),
      title: Value(title),
      content: Value(content),
      tagsJson: Value(tagsJson),
      createdAt: Value(createdAt),
      charCount: Value(charCount),
      wordCount: Value(wordCount),
      deltaSummary: deltaSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(deltaSummary),
      serverRevision: Value(serverRevision),
      isDirty: Value(isDirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory NoteVersionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteVersionEntity(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      versionNumber: serializer.fromJson<int>(json['versionNumber']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      charCount: serializer.fromJson<int>(json['charCount']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      deltaSummary: serializer.fromJson<String?>(json['deltaSummary']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'versionNumber': serializer.toJson<int>(versionNumber),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'charCount': serializer.toJson<int>(charCount),
      'wordCount': serializer.toJson<int>(wordCount),
      'deltaSummary': serializer.toJson<String?>(deltaSummary),
      'serverRevision': serializer.toJson<int>(serverRevision),
      'isDirty': serializer.toJson<bool>(isDirty),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  NoteVersionEntity copyWith({
    String? id,
    String? noteId,
    int? versionNumber,
    String? title,
    String? content,
    String? tagsJson,
    DateTime? createdAt,
    int? charCount,
    int? wordCount,
    Value<String?> deltaSummary = const Value.absent(),
    int? serverRevision,
    bool? isDirty,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => NoteVersionEntity(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    versionNumber: versionNumber ?? this.versionNumber,
    title: title ?? this.title,
    content: content ?? this.content,
    tagsJson: tagsJson ?? this.tagsJson,
    createdAt: createdAt ?? this.createdAt,
    charCount: charCount ?? this.charCount,
    wordCount: wordCount ?? this.wordCount,
    deltaSummary: deltaSummary.present ? deltaSummary.value : this.deltaSummary,
    serverRevision: serverRevision ?? this.serverRevision,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  NoteVersionEntity copyWithCompanion(NoteVersionsTableCompanion data) {
    return NoteVersionEntity(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      versionNumber: data.versionNumber.present
          ? data.versionNumber.value
          : this.versionNumber,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      charCount: data.charCount.present ? data.charCount.value : this.charCount,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      deltaSummary: data.deltaSummary.present
          ? data.deltaSummary.value
          : this.deltaSummary,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteVersionEntity(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('charCount: $charCount, ')
          ..write('wordCount: $wordCount, ')
          ..write('deltaSummary: $deltaSummary, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    versionNumber,
    title,
    content,
    tagsJson,
    createdAt,
    charCount,
    wordCount,
    deltaSummary,
    serverRevision,
    isDirty,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteVersionEntity &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.versionNumber == this.versionNumber &&
          other.title == this.title &&
          other.content == this.content &&
          other.tagsJson == this.tagsJson &&
          other.createdAt == this.createdAt &&
          other.charCount == this.charCount &&
          other.wordCount == this.wordCount &&
          other.deltaSummary == this.deltaSummary &&
          other.serverRevision == this.serverRevision &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class NoteVersionsTableCompanion extends UpdateCompanion<NoteVersionEntity> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<int> versionNumber;
  final Value<String> title;
  final Value<String> content;
  final Value<String> tagsJson;
  final Value<DateTime> createdAt;
  final Value<int> charCount;
  final Value<int> wordCount;
  final Value<String?> deltaSummary;
  final Value<int> serverRevision;
  final Value<bool> isDirty;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const NoteVersionsTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.versionNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.charCount = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.deltaSummary = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteVersionsTableCompanion.insert({
    required String id,
    required String noteId,
    required int versionNumber,
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.tagsJson = const Value.absent(),
    required DateTime createdAt,
    this.charCount = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.deltaSummary = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       versionNumber = Value(versionNumber),
       createdAt = Value(createdAt);
  static Insertable<NoteVersionEntity> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<int>? versionNumber,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? tagsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? charCount,
    Expression<int>? wordCount,
    Expression<String>? deltaSummary,
    Expression<int>? serverRevision,
    Expression<bool>? isDirty,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (versionNumber != null) 'version_number': versionNumber,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (charCount != null) 'char_count': charCount,
      if (wordCount != null) 'word_count': wordCount,
      if (deltaSummary != null) 'delta_summary': deltaSummary,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteVersionsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<int>? versionNumber,
    Value<String>? title,
    Value<String>? content,
    Value<String>? tagsJson,
    Value<DateTime>? createdAt,
    Value<int>? charCount,
    Value<int>? wordCount,
    Value<String?>? deltaSummary,
    Value<int>? serverRevision,
    Value<bool>? isDirty,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return NoteVersionsTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      versionNumber: versionNumber ?? this.versionNumber,
      title: title ?? this.title,
      content: content ?? this.content,
      tagsJson: tagsJson ?? this.tagsJson,
      createdAt: createdAt ?? this.createdAt,
      charCount: charCount ?? this.charCount,
      wordCount: wordCount ?? this.wordCount,
      deltaSummary: deltaSummary ?? this.deltaSummary,
      serverRevision: serverRevision ?? this.serverRevision,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (versionNumber.present) {
      map['version_number'] = Variable<int>(versionNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (charCount.present) {
      map['char_count'] = Variable<int>(charCount.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (deltaSummary.present) {
      map['delta_summary'] = Variable<String>(deltaSummary.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteVersionsTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('charCount: $charCount, ')
          ..write('wordCount: $wordCount, ')
          ..write('deltaSummary: $deltaSummary, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTableTable extends DocumentsTable
    with TableInfo<$DocumentsTableTable, DocumentEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Scanned Document'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scanner'),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    defaultValue: const Constant('application/pdf'),
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _encryptionKeyVersionMeta =
      const VerificationMeta('encryptionKeyVersion');
  @override
  late final GeneratedColumn<int> encryptionKeyVersion = GeneratedColumn<int>(
    'encryption_key_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _cloudPublicIdMeta = const VerificationMeta(
    'cloudPublicId',
  );
  @override
  late final GeneratedColumn<String> cloudPublicId = GeneratedColumn<String>(
    'cloud_public_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudUrlMeta = const VerificationMeta(
    'cloudUrl',
  );
  @override
  late final GeneratedColumn<String> cloudUrl = GeneratedColumn<String>(
    'cloud_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrStateMeta = const VerificationMeta(
    'ocrState',
  );
  @override
  late final GeneratedColumn<String> ocrState = GeneratedColumn<String>(
    'ocr_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_requested'),
  );
  static const VerificationMeta _ocrLanguageMeta = const VerificationMeta(
    'ocrLanguage',
  );
  @override
  late final GeneratedColumn<String> ocrLanguage = GeneratedColumn<String>(
    'ocr_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    title,
    source,
    createdAt,
    updatedAt,
    mimeType,
    byteSize,
    pageCount,
    sha256,
    encryptionKeyVersion,
    isDirty,
    isDeleted,
    deletedAt,
    serverRevision,
    syncedAt,
    uploadState,
    cloudPublicId,
    cloudUrl,
    localPath,
    thumbnailPath,
    ocrState,
    ocrLanguage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('encryption_key_version')) {
      context.handle(
        _encryptionKeyVersionMeta,
        encryptionKeyVersion.isAcceptableOrUnknown(
          data['encryption_key_version']!,
          _encryptionKeyVersionMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('cloud_public_id')) {
      context.handle(
        _cloudPublicIdMeta,
        cloudPublicId.isAcceptableOrUnknown(
          data['cloud_public_id']!,
          _cloudPublicIdMeta,
        ),
      );
    }
    if (data.containsKey('cloud_url')) {
      context.handle(
        _cloudUrlMeta,
        cloudUrl.isAcceptableOrUnknown(data['cloud_url']!, _cloudUrlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('ocr_state')) {
      context.handle(
        _ocrStateMeta,
        ocrState.isAcceptableOrUnknown(data['ocr_state']!, _ocrStateMeta),
      );
    }
    if (data.containsKey('ocr_language')) {
      context.handle(
        _ocrLanguageMeta,
        ocrLanguage.isAcceptableOrUnknown(
          data['ocr_language']!,
          _ocrLanguageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      encryptionKeyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_key_version'],
      )!,
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      cloudPublicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_public_id'],
      ),
      cloudUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_url'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      ocrState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_state'],
      )!,
      ocrLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_language'],
      )!,
    );
  }

  @override
  $DocumentsTableTable createAlias(String alias) {
    return $DocumentsTableTable(attachedDatabase, alias);
  }
}

class DocumentEntity extends DataClass implements Insertable<DocumentEntity> {
  /// Canonical UUID primary key
  final String id;

  /// Associated note ID (can be null for unassigned documents)
  final String? noteId;

  /// Document title (display name, e.g. 'Scanned Document')
  final String title;

  /// Document source: 'scanner' or 'imported_pdf'
  final String source;

  /// Creation timestamp
  final DateTime createdAt;

  /// Update timestamp
  final DateTime updatedAt;

  /// Canonical MIME type (strictly 'application/pdf')
  final String mimeType;

  /// Plaintext PDF byte size in bytes
  final int byteSize;

  /// Total page count in PDF
  final int pageCount;

  /// Plaintext SHA-256 hash of canonical PDF bytes
  final String sha256;

  /// Key version used to encrypt this document
  final int encryptionKeyVersion;

  /// Whether local changes need synchronization
  final bool isDirty;

  /// Whether document is tombstoned/deleted
  final bool isDeleted;

  /// Timestamp when deletion occurred
  final DateTime? deletedAt;

  /// Cloud revision assigned by control plane
  final int serverRevision;

  /// Timestamp of last successful metadata sync
  final DateTime? syncedAt;

  /// Lifecycle state: 'local_only', 'upload_pending', 'uploading', 'uploaded', 'failed', 'synced'
  final String uploadState;

  /// Cloudinary public ID
  final String? cloudPublicId;

  /// Cloudinary delivery URL
  final String? cloudUrl;

  /// Local app-private encrypted file path (.qpd)
  final String? localPath;

  /// Optional local path to cached first-page thumbnail
  final String? thumbnailPath;

  /// OCR processing state: 'not_requested', 'queued', 'processing', 'available', 'failed'
  final String ocrState;

  /// OCR language code: e.g. 'en'
  final String ocrLanguage;
  const DocumentEntity({
    required this.id,
    this.noteId,
    required this.title,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.mimeType,
    required this.byteSize,
    required this.pageCount,
    required this.sha256,
    required this.encryptionKeyVersion,
    required this.isDirty,
    required this.isDeleted,
    this.deletedAt,
    required this.serverRevision,
    this.syncedAt,
    required this.uploadState,
    this.cloudPublicId,
    this.cloudUrl,
    this.localPath,
    this.thumbnailPath,
    required this.ocrState,
    required this.ocrLanguage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    map['title'] = Variable<String>(title);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['mime_type'] = Variable<String>(mimeType);
    map['byte_size'] = Variable<int>(byteSize);
    map['page_count'] = Variable<int>(pageCount);
    map['sha256'] = Variable<String>(sha256);
    map['encryption_key_version'] = Variable<int>(encryptionKeyVersion);
    map['is_dirty'] = Variable<bool>(isDirty);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['server_revision'] = Variable<int>(serverRevision);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['upload_state'] = Variable<String>(uploadState);
    if (!nullToAbsent || cloudPublicId != null) {
      map['cloud_public_id'] = Variable<String>(cloudPublicId);
    }
    if (!nullToAbsent || cloudUrl != null) {
      map['cloud_url'] = Variable<String>(cloudUrl);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    map['ocr_state'] = Variable<String>(ocrState);
    map['ocr_language'] = Variable<String>(ocrLanguage);
    return map;
  }

  DocumentsTableCompanion toCompanion(bool nullToAbsent) {
    return DocumentsTableCompanion(
      id: Value(id),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      title: Value(title),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      mimeType: Value(mimeType),
      byteSize: Value(byteSize),
      pageCount: Value(pageCount),
      sha256: Value(sha256),
      encryptionKeyVersion: Value(encryptionKeyVersion),
      isDirty: Value(isDirty),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverRevision: Value(serverRevision),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      uploadState: Value(uploadState),
      cloudPublicId: cloudPublicId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudPublicId),
      cloudUrl: cloudUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      ocrState: Value(ocrState),
      ocrLanguage: Value(ocrLanguage),
    );
  }

  factory DocumentEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentEntity(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      title: serializer.fromJson<String>(json['title']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      sha256: serializer.fromJson<String>(json['sha256']),
      encryptionKeyVersion: serializer.fromJson<int>(
        json['encryptionKeyVersion'],
      ),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      cloudPublicId: serializer.fromJson<String?>(json['cloudPublicId']),
      cloudUrl: serializer.fromJson<String?>(json['cloudUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      ocrState: serializer.fromJson<String>(json['ocrState']),
      ocrLanguage: serializer.fromJson<String>(json['ocrLanguage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String?>(noteId),
      'title': serializer.toJson<String>(title),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'mimeType': serializer.toJson<String>(mimeType),
      'byteSize': serializer.toJson<int>(byteSize),
      'pageCount': serializer.toJson<int>(pageCount),
      'sha256': serializer.toJson<String>(sha256),
      'encryptionKeyVersion': serializer.toJson<int>(encryptionKeyVersion),
      'isDirty': serializer.toJson<bool>(isDirty),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'uploadState': serializer.toJson<String>(uploadState),
      'cloudPublicId': serializer.toJson<String?>(cloudPublicId),
      'cloudUrl': serializer.toJson<String?>(cloudUrl),
      'localPath': serializer.toJson<String?>(localPath),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'ocrState': serializer.toJson<String>(ocrState),
      'ocrLanguage': serializer.toJson<String>(ocrLanguage),
    };
  }

  DocumentEntity copyWith({
    String? id,
    Value<String?> noteId = const Value.absent(),
    String? title,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mimeType,
    int? byteSize,
    int? pageCount,
    String? sha256,
    int? encryptionKeyVersion,
    bool? isDirty,
    bool? isDeleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? serverRevision,
    Value<DateTime?> syncedAt = const Value.absent(),
    String? uploadState,
    Value<String?> cloudPublicId = const Value.absent(),
    Value<String?> cloudUrl = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    String? ocrState,
    String? ocrLanguage,
  }) => DocumentEntity(
    id: id ?? this.id,
    noteId: noteId.present ? noteId.value : this.noteId,
    title: title ?? this.title,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mimeType: mimeType ?? this.mimeType,
    byteSize: byteSize ?? this.byteSize,
    pageCount: pageCount ?? this.pageCount,
    sha256: sha256 ?? this.sha256,
    encryptionKeyVersion: encryptionKeyVersion ?? this.encryptionKeyVersion,
    isDirty: isDirty ?? this.isDirty,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverRevision: serverRevision ?? this.serverRevision,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    uploadState: uploadState ?? this.uploadState,
    cloudPublicId: cloudPublicId.present
        ? cloudPublicId.value
        : this.cloudPublicId,
    cloudUrl: cloudUrl.present ? cloudUrl.value : this.cloudUrl,
    localPath: localPath.present ? localPath.value : this.localPath,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    ocrState: ocrState ?? this.ocrState,
    ocrLanguage: ocrLanguage ?? this.ocrLanguage,
  );
  DocumentEntity copyWithCompanion(DocumentsTableCompanion data) {
    return DocumentEntity(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      title: data.title.present ? data.title.value : this.title,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      encryptionKeyVersion: data.encryptionKeyVersion.present
          ? data.encryptionKeyVersion.value
          : this.encryptionKeyVersion,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      cloudPublicId: data.cloudPublicId.present
          ? data.cloudPublicId.value
          : this.cloudPublicId,
      cloudUrl: data.cloudUrl.present ? data.cloudUrl.value : this.cloudUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      ocrState: data.ocrState.present ? data.ocrState.value : this.ocrState,
      ocrLanguage: data.ocrLanguage.present
          ? data.ocrLanguage.value
          : this.ocrLanguage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentEntity(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('pageCount: $pageCount, ')
          ..write('sha256: $sha256, ')
          ..write('encryptionKeyVersion: $encryptionKeyVersion, ')
          ..write('isDirty: $isDirty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('cloudPublicId: $cloudPublicId, ')
          ..write('cloudUrl: $cloudUrl, ')
          ..write('localPath: $localPath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('ocrState: $ocrState, ')
          ..write('ocrLanguage: $ocrLanguage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    noteId,
    title,
    source,
    createdAt,
    updatedAt,
    mimeType,
    byteSize,
    pageCount,
    sha256,
    encryptionKeyVersion,
    isDirty,
    isDeleted,
    deletedAt,
    serverRevision,
    syncedAt,
    uploadState,
    cloudPublicId,
    cloudUrl,
    localPath,
    thumbnailPath,
    ocrState,
    ocrLanguage,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentEntity &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.title == this.title &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.mimeType == this.mimeType &&
          other.byteSize == this.byteSize &&
          other.pageCount == this.pageCount &&
          other.sha256 == this.sha256 &&
          other.encryptionKeyVersion == this.encryptionKeyVersion &&
          other.isDirty == this.isDirty &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.serverRevision == this.serverRevision &&
          other.syncedAt == this.syncedAt &&
          other.uploadState == this.uploadState &&
          other.cloudPublicId == this.cloudPublicId &&
          other.cloudUrl == this.cloudUrl &&
          other.localPath == this.localPath &&
          other.thumbnailPath == this.thumbnailPath &&
          other.ocrState == this.ocrState &&
          other.ocrLanguage == this.ocrLanguage);
}

class DocumentsTableCompanion extends UpdateCompanion<DocumentEntity> {
  final Value<String> id;
  final Value<String?> noteId;
  final Value<String> title;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> mimeType;
  final Value<int> byteSize;
  final Value<int> pageCount;
  final Value<String> sha256;
  final Value<int> encryptionKeyVersion;
  final Value<bool> isDirty;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  final Value<int> serverRevision;
  final Value<DateTime?> syncedAt;
  final Value<String> uploadState;
  final Value<String?> cloudPublicId;
  final Value<String?> cloudUrl;
  final Value<String?> localPath;
  final Value<String?> thumbnailPath;
  final Value<String> ocrState;
  final Value<String> ocrLanguage;
  final Value<int> rowid;
  const DocumentsTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.title = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.encryptionKeyVersion = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.cloudPublicId = const Value.absent(),
    this.cloudUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.ocrState = const Value.absent(),
    this.ocrLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsTableCompanion.insert({
    required String id,
    this.noteId = const Value.absent(),
    this.title = const Value.absent(),
    this.source = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.mimeType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.encryptionKeyVersion = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.cloudPublicId = const Value.absent(),
    this.cloudUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.ocrState = const Value.absent(),
    this.ocrLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DocumentEntity> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? title,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? mimeType,
    Expression<int>? byteSize,
    Expression<int>? pageCount,
    Expression<String>? sha256,
    Expression<int>? encryptionKeyVersion,
    Expression<bool>? isDirty,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverRevision,
    Expression<DateTime>? syncedAt,
    Expression<String>? uploadState,
    Expression<String>? cloudPublicId,
    Expression<String>? cloudUrl,
    Expression<String>? localPath,
    Expression<String>? thumbnailPath,
    Expression<String>? ocrState,
    Expression<String>? ocrLanguage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (title != null) 'title': title,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (mimeType != null) 'mime_type': mimeType,
      if (byteSize != null) 'byte_size': byteSize,
      if (pageCount != null) 'page_count': pageCount,
      if (sha256 != null) 'sha256': sha256,
      if (encryptionKeyVersion != null)
        'encryption_key_version': encryptionKeyVersion,
      if (isDirty != null) 'is_dirty': isDirty,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (uploadState != null) 'upload_state': uploadState,
      if (cloudPublicId != null) 'cloud_public_id': cloudPublicId,
      if (cloudUrl != null) 'cloud_url': cloudUrl,
      if (localPath != null) 'local_path': localPath,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (ocrState != null) 'ocr_state': ocrState,
      if (ocrLanguage != null) 'ocr_language': ocrLanguage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? noteId,
    Value<String>? title,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? mimeType,
    Value<int>? byteSize,
    Value<int>? pageCount,
    Value<String>? sha256,
    Value<int>? encryptionKeyVersion,
    Value<bool>? isDirty,
    Value<bool>? isDeleted,
    Value<DateTime?>? deletedAt,
    Value<int>? serverRevision,
    Value<DateTime?>? syncedAt,
    Value<String>? uploadState,
    Value<String?>? cloudPublicId,
    Value<String?>? cloudUrl,
    Value<String?>? localPath,
    Value<String?>? thumbnailPath,
    Value<String>? ocrState,
    Value<String>? ocrLanguage,
    Value<int>? rowid,
  }) {
    return DocumentsTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      pageCount: pageCount ?? this.pageCount,
      sha256: sha256 ?? this.sha256,
      encryptionKeyVersion: encryptionKeyVersion ?? this.encryptionKeyVersion,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      syncedAt: syncedAt ?? this.syncedAt,
      uploadState: uploadState ?? this.uploadState,
      cloudPublicId: cloudPublicId ?? this.cloudPublicId,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      localPath: localPath ?? this.localPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ocrState: ocrState ?? this.ocrState,
      ocrLanguage: ocrLanguage ?? this.ocrLanguage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (encryptionKeyVersion.present) {
      map['encryption_key_version'] = Variable<int>(encryptionKeyVersion.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (cloudPublicId.present) {
      map['cloud_public_id'] = Variable<String>(cloudPublicId.value);
    }
    if (cloudUrl.present) {
      map['cloud_url'] = Variable<String>(cloudUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (ocrState.present) {
      map['ocr_state'] = Variable<String>(ocrState.value);
    }
    if (ocrLanguage.present) {
      map['ocr_language'] = Variable<String>(ocrLanguage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('pageCount: $pageCount, ')
          ..write('sha256: $sha256, ')
          ..write('encryptionKeyVersion: $encryptionKeyVersion, ')
          ..write('isDirty: $isDirty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('cloudPublicId: $cloudPublicId, ')
          ..write('cloudUrl: $cloudUrl, ')
          ..write('localPath: $localPath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('ocrState: $ocrState, ')
          ..write('ocrLanguage: $ocrLanguage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentOcrPagesTableTable extends DocumentOcrPagesTable
    with TableInfo<$DocumentOcrPagesTableTable, DocumentOcrPageEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentOcrPagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ocrSchemaVersionMeta = const VerificationMeta(
    'ocrSchemaVersion',
  );
  @override
  late final GeneratedColumn<int> ocrSchemaVersion = GeneratedColumn<int>(
    'ocr_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _ocrEngineMeta = const VerificationMeta(
    'ocrEngine',
  );
  @override
  late final GeneratedColumn<String> ocrEngine = GeneratedColumn<String>(
    'ocr_engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('quietpaper_ocr_v1'),
  );
  static const VerificationMeta _ocrEngineVersionMeta = const VerificationMeta(
    'ocrEngineVersion',
  );
  @override
  late final GeneratedColumn<String> ocrEngineVersion = GeneratedColumn<String>(
    'ocr_engine_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1.0.0'),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    pageNumber,
    encryptedPayload,
    ocrSchemaVersion,
    ocrEngine,
    ocrEngineVersion,
    language,
    processedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_ocr_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentOcrPageEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('ocr_schema_version')) {
      context.handle(
        _ocrSchemaVersionMeta,
        ocrSchemaVersion.isAcceptableOrUnknown(
          data['ocr_schema_version']!,
          _ocrSchemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('ocr_engine')) {
      context.handle(
        _ocrEngineMeta,
        ocrEngine.isAcceptableOrUnknown(data['ocr_engine']!, _ocrEngineMeta),
      );
    }
    if (data.containsKey('ocr_engine_version')) {
      context.handle(
        _ocrEngineVersionMeta,
        ocrEngineVersion.isAcceptableOrUnknown(
          data['ocr_engine_version']!,
          _ocrEngineVersionMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, pageNumber};
  @override
  DocumentOcrPageEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentOcrPageEntity(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      ocrSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ocr_schema_version'],
      )!,
      ocrEngine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_engine'],
      )!,
      ocrEngineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_engine_version'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processed_at'],
      )!,
    );
  }

  @override
  $DocumentOcrPagesTableTable createAlias(String alias) {
    return $DocumentOcrPagesTableTable(attachedDatabase, alias);
  }
}

class DocumentOcrPageEntity extends DataClass
    implements Insertable<DocumentOcrPageEntity> {
  /// Document canonical UUID reference
  final String documentId;

  /// 1-based page number
  final int pageNumber;

  /// Base64-encoded encrypted binary OCR envelope (QPOC)
  final String encryptedPayload;

  /// OCR schema version (e.g. 1)
  final int ocrSchemaVersion;

  /// Engine name used for recognition
  final String ocrEngine;

  /// Engine version used for recognition
  final String ocrEngineVersion;

  /// Language code used during recognition (e.g. 'en')
  final String language;

  /// Processing completion timestamp
  final DateTime processedAt;
  const DocumentOcrPageEntity({
    required this.documentId,
    required this.pageNumber,
    required this.encryptedPayload,
    required this.ocrSchemaVersion,
    required this.ocrEngine,
    required this.ocrEngineVersion,
    required this.language,
    required this.processedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['page_number'] = Variable<int>(pageNumber);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    map['ocr_schema_version'] = Variable<int>(ocrSchemaVersion);
    map['ocr_engine'] = Variable<String>(ocrEngine);
    map['ocr_engine_version'] = Variable<String>(ocrEngineVersion);
    map['language'] = Variable<String>(language);
    map['processed_at'] = Variable<DateTime>(processedAt);
    return map;
  }

  DocumentOcrPagesTableCompanion toCompanion(bool nullToAbsent) {
    return DocumentOcrPagesTableCompanion(
      documentId: Value(documentId),
      pageNumber: Value(pageNumber),
      encryptedPayload: Value(encryptedPayload),
      ocrSchemaVersion: Value(ocrSchemaVersion),
      ocrEngine: Value(ocrEngine),
      ocrEngineVersion: Value(ocrEngineVersion),
      language: Value(language),
      processedAt: Value(processedAt),
    );
  }

  factory DocumentOcrPageEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentOcrPageEntity(
      documentId: serializer.fromJson<String>(json['documentId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      encryptedPayload: serializer.fromJson<String>(json['encryptedPayload']),
      ocrSchemaVersion: serializer.fromJson<int>(json['ocrSchemaVersion']),
      ocrEngine: serializer.fromJson<String>(json['ocrEngine']),
      ocrEngineVersion: serializer.fromJson<String>(json['ocrEngineVersion']),
      language: serializer.fromJson<String>(json['language']),
      processedAt: serializer.fromJson<DateTime>(json['processedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
      'ocrSchemaVersion': serializer.toJson<int>(ocrSchemaVersion),
      'ocrEngine': serializer.toJson<String>(ocrEngine),
      'ocrEngineVersion': serializer.toJson<String>(ocrEngineVersion),
      'language': serializer.toJson<String>(language),
      'processedAt': serializer.toJson<DateTime>(processedAt),
    };
  }

  DocumentOcrPageEntity copyWith({
    String? documentId,
    int? pageNumber,
    String? encryptedPayload,
    int? ocrSchemaVersion,
    String? ocrEngine,
    String? ocrEngineVersion,
    String? language,
    DateTime? processedAt,
  }) => DocumentOcrPageEntity(
    documentId: documentId ?? this.documentId,
    pageNumber: pageNumber ?? this.pageNumber,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    ocrSchemaVersion: ocrSchemaVersion ?? this.ocrSchemaVersion,
    ocrEngine: ocrEngine ?? this.ocrEngine,
    ocrEngineVersion: ocrEngineVersion ?? this.ocrEngineVersion,
    language: language ?? this.language,
    processedAt: processedAt ?? this.processedAt,
  );
  DocumentOcrPageEntity copyWithCompanion(DocumentOcrPagesTableCompanion data) {
    return DocumentOcrPageEntity(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      ocrSchemaVersion: data.ocrSchemaVersion.present
          ? data.ocrSchemaVersion.value
          : this.ocrSchemaVersion,
      ocrEngine: data.ocrEngine.present ? data.ocrEngine.value : this.ocrEngine,
      ocrEngineVersion: data.ocrEngineVersion.present
          ? data.ocrEngineVersion.value
          : this.ocrEngineVersion,
      language: data.language.present ? data.language.value : this.language,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentOcrPageEntity(')
          ..write('documentId: $documentId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('ocrSchemaVersion: $ocrSchemaVersion, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('ocrEngineVersion: $ocrEngineVersion, ')
          ..write('language: $language, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentId,
    pageNumber,
    encryptedPayload,
    ocrSchemaVersion,
    ocrEngine,
    ocrEngineVersion,
    language,
    processedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentOcrPageEntity &&
          other.documentId == this.documentId &&
          other.pageNumber == this.pageNumber &&
          other.encryptedPayload == this.encryptedPayload &&
          other.ocrSchemaVersion == this.ocrSchemaVersion &&
          other.ocrEngine == this.ocrEngine &&
          other.ocrEngineVersion == this.ocrEngineVersion &&
          other.language == this.language &&
          other.processedAt == this.processedAt);
}

class DocumentOcrPagesTableCompanion
    extends UpdateCompanion<DocumentOcrPageEntity> {
  final Value<String> documentId;
  final Value<int> pageNumber;
  final Value<String> encryptedPayload;
  final Value<int> ocrSchemaVersion;
  final Value<String> ocrEngine;
  final Value<String> ocrEngineVersion;
  final Value<String> language;
  final Value<DateTime> processedAt;
  final Value<int> rowid;
  const DocumentOcrPagesTableCompanion({
    this.documentId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.ocrSchemaVersion = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrEngineVersion = const Value.absent(),
    this.language = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentOcrPagesTableCompanion.insert({
    required String documentId,
    required int pageNumber,
    required String encryptedPayload,
    this.ocrSchemaVersion = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrEngineVersion = const Value.absent(),
    this.language = const Value.absent(),
    required DateTime processedAt,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       pageNumber = Value(pageNumber),
       encryptedPayload = Value(encryptedPayload),
       processedAt = Value(processedAt);
  static Insertable<DocumentOcrPageEntity> custom({
    Expression<String>? documentId,
    Expression<int>? pageNumber,
    Expression<String>? encryptedPayload,
    Expression<int>? ocrSchemaVersion,
    Expression<String>? ocrEngine,
    Expression<String>? ocrEngineVersion,
    Expression<String>? language,
    Expression<DateTime>? processedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (ocrSchemaVersion != null) 'ocr_schema_version': ocrSchemaVersion,
      if (ocrEngine != null) 'ocr_engine': ocrEngine,
      if (ocrEngineVersion != null) 'ocr_engine_version': ocrEngineVersion,
      if (language != null) 'language': language,
      if (processedAt != null) 'processed_at': processedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentOcrPagesTableCompanion copyWith({
    Value<String>? documentId,
    Value<int>? pageNumber,
    Value<String>? encryptedPayload,
    Value<int>? ocrSchemaVersion,
    Value<String>? ocrEngine,
    Value<String>? ocrEngineVersion,
    Value<String>? language,
    Value<DateTime>? processedAt,
    Value<int>? rowid,
  }) {
    return DocumentOcrPagesTableCompanion(
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      ocrSchemaVersion: ocrSchemaVersion ?? this.ocrSchemaVersion,
      ocrEngine: ocrEngine ?? this.ocrEngine,
      ocrEngineVersion: ocrEngineVersion ?? this.ocrEngineVersion,
      language: language ?? this.language,
      processedAt: processedAt ?? this.processedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (ocrSchemaVersion.present) {
      map['ocr_schema_version'] = Variable<int>(ocrSchemaVersion.value);
    }
    if (ocrEngine.present) {
      map['ocr_engine'] = Variable<String>(ocrEngine.value);
    }
    if (ocrEngineVersion.present) {
      map['ocr_engine_version'] = Variable<String>(ocrEngineVersion.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentOcrPagesTableCompanion(')
          ..write('documentId: $documentId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('ocrSchemaVersion: $ocrSchemaVersion, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('ocrEngineVersion: $ocrEngineVersion, ')
          ..write('language: $language, ')
          ..write('processedAt: $processedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTableTable notesTable = $NotesTableTable(this);
  late final $TagsTableTable tagsTable = $TagsTableTable(this);
  late final $NoteTagsTableTable noteTagsTable = $NoteTagsTableTable(this);
  late final $SyncMetadataTableTable syncMetadataTable =
      $SyncMetadataTableTable(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  late final $AttachmentsTableTable attachmentsTable = $AttachmentsTableTable(
    this,
  );
  late final $AttachmentVariantsTableTable attachmentVariantsTable =
      $AttachmentVariantsTableTable(this);
  late final $NoteVersionsTableTable noteVersionsTable =
      $NoteVersionsTableTable(this);
  late final $DocumentsTableTable documentsTable = $DocumentsTableTable(this);
  late final $DocumentOcrPagesTableTable documentOcrPagesTable =
      $DocumentOcrPagesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notesTable,
    tagsTable,
    noteTagsTable,
    syncMetadataTable,
    syncQueueTable,
    attachmentsTable,
    attachmentVariantsTable,
    noteVersionsTable,
    documentsTable,
    documentOcrPagesTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_versions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$NotesTableTableCreateCompanionBuilder =
    NotesTableCompanion Function({
      required String id,
      Value<String> title,
      Value<String> content,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<bool> isTrashed,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<bool> isDirty,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$NotesTableTableUpdateCompanionBuilder =
    NotesTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<bool> isTrashed,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<bool> isDirty,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

final class $$NotesTableTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTableTable, NoteEntity> {
  $$NotesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteTagsTableTable, List<NoteTagEntity>>
  _noteTagsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagsTable,
    aliasName: 'notes__id__note_tags__note_id',
  );

  $$NoteTagsTableTableProcessedTableManager get noteTagsTableRefs {
    final manager = $$NoteTagsTableTableTableManager(
      $_db,
      $_db.noteTagsTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagsTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteVersionsTableTable, List<NoteVersionEntity>>
  _noteVersionsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.noteVersionsTable,
        aliasName: 'notes__id__note_versions__note_id',
      );

  $$NoteVersionsTableTableProcessedTableManager get noteVersionsTableRefs {
    final manager = $$NoteVersionsTableTableTableManager(
      $_db,
      $_db.noteVersionsTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _noteVersionsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableTableFilterComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTrashed => $composableBuilder(
    column: $table.isTrashed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteTagsTableRefs(
    Expression<bool> Function($$NoteTagsTableTableFilterComposer f) f,
  ) {
    final $$NoteTagsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagsTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagsTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteVersionsTableRefs(
    Expression<bool> Function($$NoteVersionsTableTableFilterComposer f) f,
  ) {
    final $$NoteVersionsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteVersionsTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteVersionsTableTableFilterComposer(
            $db: $db,
            $table: $db.noteVersionsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTrashed => $composableBuilder(
    column: $table.isTrashed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isTrashed =>
      $composableBuilder(column: $table.isTrashed, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  Expression<T> noteTagsTableRefs<T extends Object>(
    Expression<T> Function($$NoteTagsTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTagsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagsTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> noteVersionsTableRefs<T extends Object>(
    Expression<T> Function($$NoteVersionsTableTableAnnotationComposer a) f,
  ) {
    final $$NoteVersionsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.noteVersionsTable,
          getReferencedColumn: (t) => t.noteId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NoteVersionsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.noteVersionsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$NotesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTableTable,
          NoteEntity,
          $$NotesTableTableFilterComposer,
          $$NotesTableTableOrderingComposer,
          $$NotesTableTableAnnotationComposer,
          $$NotesTableTableCreateCompanionBuilder,
          $$NotesTableTableUpdateCompanionBuilder,
          (NoteEntity, $$NotesTableTableReferences),
          NoteEntity,
          PrefetchHooks Function({
            bool noteTagsTableRefs,
            bool noteVersionsTableRefs,
          })
        > {
  $$NotesTableTableTableManager(_$AppDatabase db, $NotesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isTrashed = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesTableCompanion(
                id: id,
                title: title,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                isArchived: isArchived,
                isTrashed: isTrashed,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isTrashed = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesTableCompanion.insert(
                id: id,
                title: title,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                isArchived: isArchived,
                isTrashed: isTrashed,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NotesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({noteTagsTableRefs = false, noteVersionsTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (noteTagsTableRefs) db.noteTagsTable,
                    if (noteVersionsTableRefs) db.noteVersionsTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (noteTagsTableRefs)
                        await $_getPrefetchedData<
                          NoteEntity,
                          $NotesTableTable,
                          NoteTagEntity
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._noteTagsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTagsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (noteVersionsTableRefs)
                        await $_getPrefetchedData<
                          NoteEntity,
                          $NotesTableTable,
                          NoteVersionEntity
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._noteVersionsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteVersionsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTableTable,
      NoteEntity,
      $$NotesTableTableFilterComposer,
      $$NotesTableTableOrderingComposer,
      $$NotesTableTableAnnotationComposer,
      $$NotesTableTableCreateCompanionBuilder,
      $$NotesTableTableUpdateCompanionBuilder,
      (NoteEntity, $$NotesTableTableReferences),
      NoteEntity,
      PrefetchHooks Function({
        bool noteTagsTableRefs,
        bool noteVersionsTableRefs,
      })
    >;
typedef $$TagsTableTableCreateCompanionBuilder =
    TagsTableCompanion Function({
      required String id,
      required String name,
      Value<int> rowid,
    });
typedef $$TagsTableTableUpdateCompanionBuilder =
    TagsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> rowid,
    });

final class $$TagsTableTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTableTable, TagEntity> {
  $$TagsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteTagsTableTable, List<NoteTagEntity>>
  _noteTagsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagsTable,
    aliasName: 'tags__id__note_tags__tag_id',
  );

  $$NoteTagsTableTableProcessedTableManager get noteTagsTableRefs {
    final manager = $$NoteTagsTableTableTableManager(
      $_db,
      $_db.noteTagsTable,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagsTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableTableFilterComposer
    extends Composer<_$AppDatabase, $TagsTableTable> {
  $$TagsTableTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteTagsTableRefs(
    Expression<bool> Function($$NoteTagsTableTableFilterComposer f) f,
  ) {
    final $$NoteTagsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagsTable,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagsTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TagsTableTable> {
  $$TagsTableTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTableTable> {
  $$TagsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> noteTagsTableRefs<T extends Object>(
    Expression<T> Function($$NoteTagsTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTagsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagsTable,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTableTable,
          TagEntity,
          $$TagsTableTableFilterComposer,
          $$TagsTableTableOrderingComposer,
          $$TagsTableTableAnnotationComposer,
          $$TagsTableTableCreateCompanionBuilder,
          $$TagsTableTableUpdateCompanionBuilder,
          (TagEntity, $$TagsTableTableReferences),
          TagEntity,
          PrefetchHooks Function({bool noteTagsTableRefs})
        > {
  $$TagsTableTableTableManager(_$AppDatabase db, $TagsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsTableCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => TagsTableCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TagsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteTagsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (noteTagsTableRefs) db.noteTagsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTagsTableRefs)
                    await $_getPrefetchedData<
                      TagEntity,
                      $TagsTableTable,
                      NoteTagEntity
                    >(
                      currentTable: table,
                      referencedTable: $$TagsTableTableReferences
                          ._noteTagsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).noteTagsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTableTable,
      TagEntity,
      $$TagsTableTableFilterComposer,
      $$TagsTableTableOrderingComposer,
      $$TagsTableTableAnnotationComposer,
      $$TagsTableTableCreateCompanionBuilder,
      $$TagsTableTableUpdateCompanionBuilder,
      (TagEntity, $$TagsTableTableReferences),
      TagEntity,
      PrefetchHooks Function({bool noteTagsTableRefs})
    >;
typedef $$NoteTagsTableTableCreateCompanionBuilder =
    NoteTagsTableCompanion Function({
      required String noteId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$NoteTagsTableTableUpdateCompanionBuilder =
    NoteTagsTableCompanion Function({
      Value<String> noteId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$NoteTagsTableTableReferences
    extends BaseReferences<_$AppDatabase, $NoteTagsTableTable, NoteTagEntity> {
  $$NoteTagsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _noteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('note_tags__note_id__notes__id');

  $$NotesTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableTableManager(
      $_db,
      $_db.notesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTableTable _tagIdTable(_$AppDatabase db) =>
      db.tagsTable.createAlias('note_tags__tag_id__tags__id');

  $$TagsTableTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableTableManager(
      $_db,
      $_db.tagsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteTagsTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagsTableTable> {
  $$NoteTagsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableTableFilterComposer get noteId {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableFilterComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableTableFilterComposer get tagId {
    final $$TagsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableTableFilterComposer(
            $db: $db,
            $table: $db.tagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagsTableTable> {
  $$NoteTagsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableTableOrderingComposer get noteId {
    final $$NotesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableOrderingComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableTableOrderingComposer get tagId {
    final $$TagsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableTableOrderingComposer(
            $db: $db,
            $table: $db.tagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagsTableTable> {
  $$NoteTagsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableTableAnnotationComposer get noteId {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableTableAnnotationComposer get tagId {
    final $$TagsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.tagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTagsTableTable,
          NoteTagEntity,
          $$NoteTagsTableTableFilterComposer,
          $$NoteTagsTableTableOrderingComposer,
          $$NoteTagsTableTableAnnotationComposer,
          $$NoteTagsTableTableCreateCompanionBuilder,
          $$NoteTagsTableTableUpdateCompanionBuilder,
          (NoteTagEntity, $$NoteTagsTableTableReferences),
          NoteTagEntity,
          PrefetchHooks Function({bool noteId, bool tagId})
        > {
  $$NoteTagsTableTableTableManager(_$AppDatabase db, $NoteTagsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsTableCompanion(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsTableCompanion.insert(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteTagsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$NoteTagsTableTableReferences
                                    ._noteIdTable(db),
                                referencedColumn: $$NoteTagsTableTableReferences
                                    ._noteIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$NoteTagsTableTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$NoteTagsTableTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteTagsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTagsTableTable,
      NoteTagEntity,
      $$NoteTagsTableTableFilterComposer,
      $$NoteTagsTableTableOrderingComposer,
      $$NoteTagsTableTableAnnotationComposer,
      $$NoteTagsTableTableCreateCompanionBuilder,
      $$NoteTagsTableTableUpdateCompanionBuilder,
      (NoteTagEntity, $$NoteTagsTableTableReferences),
      NoteTagEntity,
      PrefetchHooks Function({bool noteId, bool tagId})
    >;
typedef $$SyncMetadataTableTableCreateCompanionBuilder =
    SyncMetadataTableCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableTableUpdateCompanionBuilder =
    SyncMetadataTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncMetadataTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTableTable> {
  $$SyncMetadataTableTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTableTable> {
  $$SyncMetadataTableTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTableTable> {
  $$SyncMetadataTableTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncMetadataTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTableTable,
          SyncMetadataEntity,
          $$SyncMetadataTableTableFilterComposer,
          $$SyncMetadataTableTableOrderingComposer,
          $$SyncMetadataTableTableAnnotationComposer,
          $$SyncMetadataTableTableCreateCompanionBuilder,
          $$SyncMetadataTableTableUpdateCompanionBuilder,
          (
            SyncMetadataEntity,
            BaseReferences<
              _$AppDatabase,
              $SyncMetadataTableTable,
              SyncMetadataEntity
            >,
          ),
          SyncMetadataEntity,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableTableManager(
    _$AppDatabase db,
    $SyncMetadataTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataTableCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataTableCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTableTable,
      SyncMetadataEntity,
      $$SyncMetadataTableTableFilterComposer,
      $$SyncMetadataTableTableOrderingComposer,
      $$SyncMetadataTableTableAnnotationComposer,
      $$SyncMetadataTableTableCreateCompanionBuilder,
      $$SyncMetadataTableTableUpdateCompanionBuilder,
      (
        SyncMetadataEntity,
        BaseReferences<
          _$AppDatabase,
          $SyncMetadataTableTable,
          SyncMetadataEntity
        >,
      ),
      SyncMetadataEntity,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableTableCreateCompanionBuilder =
    SyncQueueTableCompanion Function({
      required String id,
      required String noteId,
      required String operation,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncQueueTableTableUpdateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<String> operation,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncQueueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTableTable,
          SyncQueueEntity,
          $$SyncQueueTableTableFilterComposer,
          $$SyncQueueTableTableOrderingComposer,
          $$SyncQueueTableTableAnnotationComposer,
          $$SyncQueueTableTableCreateCompanionBuilder,
          $$SyncQueueTableTableUpdateCompanionBuilder,
          (
            SyncQueueEntity,
            BaseReferences<
              _$AppDatabase,
              $SyncQueueTableTable,
              SyncQueueEntity
            >,
          ),
          SyncQueueEntity,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableTableManager(
    _$AppDatabase db,
    $SyncQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueTableCompanion(
                id: id,
                noteId: noteId,
                operation: operation,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String operation,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueTableCompanion.insert(
                id: id,
                noteId: noteId,
                operation: operation,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTableTable,
      SyncQueueEntity,
      $$SyncQueueTableTableFilterComposer,
      $$SyncQueueTableTableOrderingComposer,
      $$SyncQueueTableTableAnnotationComposer,
      $$SyncQueueTableTableCreateCompanionBuilder,
      $$SyncQueueTableTableUpdateCompanionBuilder,
      (
        SyncQueueEntity,
        BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueEntity>,
      ),
      SyncQueueEntity,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableTableCreateCompanionBuilder =
    AttachmentsTableCompanion Function({
      required String id,
      Value<String?> noteId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String> mimeType,
      Value<int> byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<String> sha256,
      Value<int> encryptionKeyVersion,
      Value<bool> isDirty,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<DateTime?> syncedAt,
      Value<String> uploadState,
      Value<String?> cloudPublicId,
      Value<String?> cloudUrl,
      Value<String?> localPath,
      Value<int> rowid,
    });
typedef $$AttachmentsTableTableUpdateCompanionBuilder =
    AttachmentsTableCompanion Function({
      Value<String> id,
      Value<String?> noteId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> mimeType,
      Value<int> byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<String> sha256,
      Value<int> encryptionKeyVersion,
      Value<bool> isDirty,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<DateTime?> syncedAt,
      Value<String> uploadState,
      Value<String?> cloudPublicId,
      Value<String?> cloudUrl,
      Value<String?> localPath,
      Value<int> rowid,
    });

class $$AttachmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudUrl => $composableBuilder(
    column: $table.cloudUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudUrl => $composableBuilder(
    column: $table.cloudUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudUrl =>
      $composableBuilder(column: $table.cloudUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);
}

class $$AttachmentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTableTable,
          AttachmentEntity,
          $$AttachmentsTableTableFilterComposer,
          $$AttachmentsTableTableOrderingComposer,
          $$AttachmentsTableTableAnnotationComposer,
          $$AttachmentsTableTableCreateCompanionBuilder,
          $$AttachmentsTableTableUpdateCompanionBuilder,
          (
            AttachmentEntity,
            BaseReferences<
              _$AppDatabase,
              $AttachmentsTableTable,
              AttachmentEntity
            >,
          ),
          AttachmentEntity,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableTableManager(
    _$AppDatabase db,
    $AttachmentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> encryptionKeyVersion = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<String?> cloudPublicId = const Value.absent(),
                Value<String?> cloudUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsTableCompanion(
                id: id,
                noteId: noteId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                mimeType: mimeType,
                byteSize: byteSize,
                width: width,
                height: height,
                sha256: sha256,
                encryptionKeyVersion: encryptionKeyVersion,
                isDirty: isDirty,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                syncedAt: syncedAt,
                uploadState: uploadState,
                cloudPublicId: cloudPublicId,
                cloudUrl: cloudUrl,
                localPath: localPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> noteId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> mimeType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> encryptionKeyVersion = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<String?> cloudPublicId = const Value.absent(),
                Value<String?> cloudUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsTableCompanion.insert(
                id: id,
                noteId: noteId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                mimeType: mimeType,
                byteSize: byteSize,
                width: width,
                height: height,
                sha256: sha256,
                encryptionKeyVersion: encryptionKeyVersion,
                isDirty: isDirty,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                syncedAt: syncedAt,
                uploadState: uploadState,
                cloudPublicId: cloudPublicId,
                cloudUrl: cloudUrl,
                localPath: localPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTableTable,
      AttachmentEntity,
      $$AttachmentsTableTableFilterComposer,
      $$AttachmentsTableTableOrderingComposer,
      $$AttachmentsTableTableAnnotationComposer,
      $$AttachmentsTableTableCreateCompanionBuilder,
      $$AttachmentsTableTableUpdateCompanionBuilder,
      (
        AttachmentEntity,
        BaseReferences<_$AppDatabase, $AttachmentsTableTable, AttachmentEntity>,
      ),
      AttachmentEntity,
      PrefetchHooks Function()
    >;
typedef $$AttachmentVariantsTableTableCreateCompanionBuilder =
    AttachmentVariantsTableCompanion Function({
      required String id,
      required String attachmentId,
      required String variantType,
      Value<int> byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<String?> localPath,
      Value<String?> cloudPublicId,
      Value<String?> cloudUrl,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentVariantsTableTableUpdateCompanionBuilder =
    AttachmentVariantsTableCompanion Function({
      Value<String> id,
      Value<String> attachmentId,
      Value<String> variantType,
      Value<int> byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<String?> localPath,
      Value<String?> cloudPublicId,
      Value<String?> cloudUrl,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AttachmentVariantsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentVariantsTableTable> {
  $$AttachmentVariantsTableTableFilterComposer({
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

  ColumnFilters<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantType => $composableBuilder(
    column: $table.variantType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudUrl => $composableBuilder(
    column: $table.cloudUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentVariantsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentVariantsTableTable> {
  $$AttachmentVariantsTableTableOrderingComposer({
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

  ColumnOrderings<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantType => $composableBuilder(
    column: $table.variantType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudUrl => $composableBuilder(
    column: $table.cloudUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentVariantsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentVariantsTableTable> {
  $$AttachmentVariantsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variantType => $composableBuilder(
    column: $table.variantType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudUrl =>
      $composableBuilder(column: $table.cloudUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttachmentVariantsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentVariantsTableTable,
          AttachmentVariantEntity,
          $$AttachmentVariantsTableTableFilterComposer,
          $$AttachmentVariantsTableTableOrderingComposer,
          $$AttachmentVariantsTableTableAnnotationComposer,
          $$AttachmentVariantsTableTableCreateCompanionBuilder,
          $$AttachmentVariantsTableTableUpdateCompanionBuilder,
          (
            AttachmentVariantEntity,
            BaseReferences<
              _$AppDatabase,
              $AttachmentVariantsTableTable,
              AttachmentVariantEntity
            >,
          ),
          AttachmentVariantEntity,
          PrefetchHooks Function()
        > {
  $$AttachmentVariantsTableTableTableManager(
    _$AppDatabase db,
    $AttachmentVariantsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentVariantsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AttachmentVariantsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AttachmentVariantsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> attachmentId = const Value.absent(),
                Value<String> variantType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> cloudPublicId = const Value.absent(),
                Value<String?> cloudUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentVariantsTableCompanion(
                id: id,
                attachmentId: attachmentId,
                variantType: variantType,
                byteSize: byteSize,
                width: width,
                height: height,
                localPath: localPath,
                cloudPublicId: cloudPublicId,
                cloudUrl: cloudUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String attachmentId,
                required String variantType,
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> cloudPublicId = const Value.absent(),
                Value<String?> cloudUrl = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentVariantsTableCompanion.insert(
                id: id,
                attachmentId: attachmentId,
                variantType: variantType,
                byteSize: byteSize,
                width: width,
                height: height,
                localPath: localPath,
                cloudPublicId: cloudPublicId,
                cloudUrl: cloudUrl,
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

typedef $$AttachmentVariantsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentVariantsTableTable,
      AttachmentVariantEntity,
      $$AttachmentVariantsTableTableFilterComposer,
      $$AttachmentVariantsTableTableOrderingComposer,
      $$AttachmentVariantsTableTableAnnotationComposer,
      $$AttachmentVariantsTableTableCreateCompanionBuilder,
      $$AttachmentVariantsTableTableUpdateCompanionBuilder,
      (
        AttachmentVariantEntity,
        BaseReferences<
          _$AppDatabase,
          $AttachmentVariantsTableTable,
          AttachmentVariantEntity
        >,
      ),
      AttachmentVariantEntity,
      PrefetchHooks Function()
    >;
typedef $$NoteVersionsTableTableCreateCompanionBuilder =
    NoteVersionsTableCompanion Function({
      required String id,
      required String noteId,
      required int versionNumber,
      Value<String> title,
      Value<String> content,
      Value<String> tagsJson,
      required DateTime createdAt,
      Value<int> charCount,
      Value<int> wordCount,
      Value<String?> deltaSummary,
      Value<int> serverRevision,
      Value<bool> isDirty,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$NoteVersionsTableTableUpdateCompanionBuilder =
    NoteVersionsTableCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<int> versionNumber,
      Value<String> title,
      Value<String> content,
      Value<String> tagsJson,
      Value<DateTime> createdAt,
      Value<int> charCount,
      Value<int> wordCount,
      Value<String?> deltaSummary,
      Value<int> serverRevision,
      Value<bool> isDirty,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

final class $$NoteVersionsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NoteVersionsTableTable,
          NoteVersionEntity
        > {
  $$NoteVersionsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _noteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('note_versions__note_id__notes__id');

  $$NotesTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableTableManager(
      $_db,
      $_db.notesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteVersionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteVersionsTableTable> {
  $$NoteVersionsTableTableFilterComposer({
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

  ColumnFilters<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charCount => $composableBuilder(
    column: $table.charCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deltaSummary => $composableBuilder(
    column: $table.deltaSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableTableFilterComposer get noteId {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableFilterComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteVersionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteVersionsTableTable> {
  $$NoteVersionsTableTableOrderingComposer({
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

  ColumnOrderings<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charCount => $composableBuilder(
    column: $table.charCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deltaSummary => $composableBuilder(
    column: $table.deltaSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableTableOrderingComposer get noteId {
    final $$NotesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableOrderingComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteVersionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteVersionsTableTable> {
  $$NoteVersionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get charCount =>
      $composableBuilder(column: $table.charCount, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get deltaSummary => $composableBuilder(
    column: $table.deltaSummary,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$NotesTableTableAnnotationComposer get noteId {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteVersionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteVersionsTableTable,
          NoteVersionEntity,
          $$NoteVersionsTableTableFilterComposer,
          $$NoteVersionsTableTableOrderingComposer,
          $$NoteVersionsTableTableAnnotationComposer,
          $$NoteVersionsTableTableCreateCompanionBuilder,
          $$NoteVersionsTableTableUpdateCompanionBuilder,
          (NoteVersionEntity, $$NoteVersionsTableTableReferences),
          NoteVersionEntity,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteVersionsTableTableTableManager(
    _$AppDatabase db,
    $NoteVersionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteVersionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteVersionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteVersionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<int> versionNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> charCount = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<String?> deltaSummary = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteVersionsTableCompanion(
                id: id,
                noteId: noteId,
                versionNumber: versionNumber,
                title: title,
                content: content,
                tagsJson: tagsJson,
                createdAt: createdAt,
                charCount: charCount,
                wordCount: wordCount,
                deltaSummary: deltaSummary,
                serverRevision: serverRevision,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required int versionNumber,
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> charCount = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<String?> deltaSummary = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteVersionsTableCompanion.insert(
                id: id,
                noteId: noteId,
                versionNumber: versionNumber,
                title: title,
                content: content,
                tagsJson: tagsJson,
                createdAt: createdAt,
                charCount: charCount,
                wordCount: wordCount,
                deltaSummary: deltaSummary,
                serverRevision: serverRevision,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteVersionsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable:
                                    $$NoteVersionsTableTableReferences
                                        ._noteIdTable(db),
                                referencedColumn:
                                    $$NoteVersionsTableTableReferences
                                        ._noteIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteVersionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteVersionsTableTable,
      NoteVersionEntity,
      $$NoteVersionsTableTableFilterComposer,
      $$NoteVersionsTableTableOrderingComposer,
      $$NoteVersionsTableTableAnnotationComposer,
      $$NoteVersionsTableTableCreateCompanionBuilder,
      $$NoteVersionsTableTableUpdateCompanionBuilder,
      (NoteVersionEntity, $$NoteVersionsTableTableReferences),
      NoteVersionEntity,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$DocumentsTableTableCreateCompanionBuilder =
    DocumentsTableCompanion Function({
      required String id,
      Value<String?> noteId,
      Value<String> title,
      Value<String> source,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String> mimeType,
      Value<int> byteSize,
      Value<int> pageCount,
      Value<String> sha256,
      Value<int> encryptionKeyVersion,
      Value<bool> isDirty,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<DateTime?> syncedAt,
      Value<String> uploadState,
      Value<String?> cloudPublicId,
      Value<String?> cloudUrl,
      Value<String?> localPath,
      Value<String?> thumbnailPath,
      Value<String> ocrState,
      Value<String> ocrLanguage,
      Value<int> rowid,
    });
typedef $$DocumentsTableTableUpdateCompanionBuilder =
    DocumentsTableCompanion Function({
      Value<String> id,
      Value<String?> noteId,
      Value<String> title,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> mimeType,
      Value<int> byteSize,
      Value<int> pageCount,
      Value<String> sha256,
      Value<int> encryptionKeyVersion,
      Value<bool> isDirty,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<DateTime?> syncedAt,
      Value<String> uploadState,
      Value<String?> cloudPublicId,
      Value<String?> cloudUrl,
      Value<String?> localPath,
      Value<String?> thumbnailPath,
      Value<String> ocrState,
      Value<String> ocrLanguage,
      Value<int> rowid,
    });

class $$DocumentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTableTable> {
  $$DocumentsTableTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudUrl => $composableBuilder(
    column: $table.cloudUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrState => $composableBuilder(
    column: $table.ocrState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrLanguage => $composableBuilder(
    column: $table.ocrLanguage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTableTable> {
  $$DocumentsTableTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudUrl => $composableBuilder(
    column: $table.cloudUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrState => $composableBuilder(
    column: $table.ocrState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrLanguage => $composableBuilder(
    column: $table.ocrLanguage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTableTable> {
  $$DocumentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudPublicId => $composableBuilder(
    column: $table.cloudPublicId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudUrl =>
      $composableBuilder(column: $table.cloudUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrState =>
      $composableBuilder(column: $table.ocrState, builder: (column) => column);

  GeneratedColumn<String> get ocrLanguage => $composableBuilder(
    column: $table.ocrLanguage,
    builder: (column) => column,
  );
}

class $$DocumentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTableTable,
          DocumentEntity,
          $$DocumentsTableTableFilterComposer,
          $$DocumentsTableTableOrderingComposer,
          $$DocumentsTableTableAnnotationComposer,
          $$DocumentsTableTableCreateCompanionBuilder,
          $$DocumentsTableTableUpdateCompanionBuilder,
          (
            DocumentEntity,
            BaseReferences<_$AppDatabase, $DocumentsTableTable, DocumentEntity>,
          ),
          DocumentEntity,
          PrefetchHooks Function()
        > {
  $$DocumentsTableTableTableManager(
    _$AppDatabase db,
    $DocumentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> encryptionKeyVersion = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<String?> cloudPublicId = const Value.absent(),
                Value<String?> cloudUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String> ocrState = const Value.absent(),
                Value<String> ocrLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsTableCompanion(
                id: id,
                noteId: noteId,
                title: title,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                mimeType: mimeType,
                byteSize: byteSize,
                pageCount: pageCount,
                sha256: sha256,
                encryptionKeyVersion: encryptionKeyVersion,
                isDirty: isDirty,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                syncedAt: syncedAt,
                uploadState: uploadState,
                cloudPublicId: cloudPublicId,
                cloudUrl: cloudUrl,
                localPath: localPath,
                thumbnailPath: thumbnailPath,
                ocrState: ocrState,
                ocrLanguage: ocrLanguage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> noteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> source = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> mimeType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> encryptionKeyVersion = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<String?> cloudPublicId = const Value.absent(),
                Value<String?> cloudUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String> ocrState = const Value.absent(),
                Value<String> ocrLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsTableCompanion.insert(
                id: id,
                noteId: noteId,
                title: title,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                mimeType: mimeType,
                byteSize: byteSize,
                pageCount: pageCount,
                sha256: sha256,
                encryptionKeyVersion: encryptionKeyVersion,
                isDirty: isDirty,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                syncedAt: syncedAt,
                uploadState: uploadState,
                cloudPublicId: cloudPublicId,
                cloudUrl: cloudUrl,
                localPath: localPath,
                thumbnailPath: thumbnailPath,
                ocrState: ocrState,
                ocrLanguage: ocrLanguage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTableTable,
      DocumentEntity,
      $$DocumentsTableTableFilterComposer,
      $$DocumentsTableTableOrderingComposer,
      $$DocumentsTableTableAnnotationComposer,
      $$DocumentsTableTableCreateCompanionBuilder,
      $$DocumentsTableTableUpdateCompanionBuilder,
      (
        DocumentEntity,
        BaseReferences<_$AppDatabase, $DocumentsTableTable, DocumentEntity>,
      ),
      DocumentEntity,
      PrefetchHooks Function()
    >;
typedef $$DocumentOcrPagesTableTableCreateCompanionBuilder =
    DocumentOcrPagesTableCompanion Function({
      required String documentId,
      required int pageNumber,
      required String encryptedPayload,
      Value<int> ocrSchemaVersion,
      Value<String> ocrEngine,
      Value<String> ocrEngineVersion,
      Value<String> language,
      required DateTime processedAt,
      Value<int> rowid,
    });
typedef $$DocumentOcrPagesTableTableUpdateCompanionBuilder =
    DocumentOcrPagesTableCompanion Function({
      Value<String> documentId,
      Value<int> pageNumber,
      Value<String> encryptedPayload,
      Value<int> ocrSchemaVersion,
      Value<String> ocrEngine,
      Value<String> ocrEngineVersion,
      Value<String> language,
      Value<DateTime> processedAt,
      Value<int> rowid,
    });

class $$DocumentOcrPagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentOcrPagesTableTable> {
  $$DocumentOcrPagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ocrSchemaVersion => $composableBuilder(
    column: $table.ocrSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrEngine => $composableBuilder(
    column: $table.ocrEngine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrEngineVersion => $composableBuilder(
    column: $table.ocrEngineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentOcrPagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentOcrPagesTableTable> {
  $$DocumentOcrPagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ocrSchemaVersion => $composableBuilder(
    column: $table.ocrSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrEngine => $composableBuilder(
    column: $table.ocrEngine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrEngineVersion => $composableBuilder(
    column: $table.ocrEngineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentOcrPagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentOcrPagesTableTable> {
  $$DocumentOcrPagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ocrSchemaVersion => $composableBuilder(
    column: $table.ocrSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrEngine =>
      $composableBuilder(column: $table.ocrEngine, builder: (column) => column);

  GeneratedColumn<String> get ocrEngineVersion => $composableBuilder(
    column: $table.ocrEngineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );
}

class $$DocumentOcrPagesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentOcrPagesTableTable,
          DocumentOcrPageEntity,
          $$DocumentOcrPagesTableTableFilterComposer,
          $$DocumentOcrPagesTableTableOrderingComposer,
          $$DocumentOcrPagesTableTableAnnotationComposer,
          $$DocumentOcrPagesTableTableCreateCompanionBuilder,
          $$DocumentOcrPagesTableTableUpdateCompanionBuilder,
          (
            DocumentOcrPageEntity,
            BaseReferences<
              _$AppDatabase,
              $DocumentOcrPagesTableTable,
              DocumentOcrPageEntity
            >,
          ),
          DocumentOcrPageEntity,
          PrefetchHooks Function()
        > {
  $$DocumentOcrPagesTableTableTableManager(
    _$AppDatabase db,
    $DocumentOcrPagesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentOcrPagesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DocumentOcrPagesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DocumentOcrPagesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<int> pageNumber = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<int> ocrSchemaVersion = const Value.absent(),
                Value<String> ocrEngine = const Value.absent(),
                Value<String> ocrEngineVersion = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<DateTime> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentOcrPagesTableCompanion(
                documentId: documentId,
                pageNumber: pageNumber,
                encryptedPayload: encryptedPayload,
                ocrSchemaVersion: ocrSchemaVersion,
                ocrEngine: ocrEngine,
                ocrEngineVersion: ocrEngineVersion,
                language: language,
                processedAt: processedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required int pageNumber,
                required String encryptedPayload,
                Value<int> ocrSchemaVersion = const Value.absent(),
                Value<String> ocrEngine = const Value.absent(),
                Value<String> ocrEngineVersion = const Value.absent(),
                Value<String> language = const Value.absent(),
                required DateTime processedAt,
                Value<int> rowid = const Value.absent(),
              }) => DocumentOcrPagesTableCompanion.insert(
                documentId: documentId,
                pageNumber: pageNumber,
                encryptedPayload: encryptedPayload,
                ocrSchemaVersion: ocrSchemaVersion,
                ocrEngine: ocrEngine,
                ocrEngineVersion: ocrEngineVersion,
                language: language,
                processedAt: processedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentOcrPagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentOcrPagesTableTable,
      DocumentOcrPageEntity,
      $$DocumentOcrPagesTableTableFilterComposer,
      $$DocumentOcrPagesTableTableOrderingComposer,
      $$DocumentOcrPagesTableTableAnnotationComposer,
      $$DocumentOcrPagesTableTableCreateCompanionBuilder,
      $$DocumentOcrPagesTableTableUpdateCompanionBuilder,
      (
        DocumentOcrPageEntity,
        BaseReferences<
          _$AppDatabase,
          $DocumentOcrPagesTableTable,
          DocumentOcrPageEntity
        >,
      ),
      DocumentOcrPageEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableTableManager get notesTable =>
      $$NotesTableTableTableManager(_db, _db.notesTable);
  $$TagsTableTableTableManager get tagsTable =>
      $$TagsTableTableTableManager(_db, _db.tagsTable);
  $$NoteTagsTableTableTableManager get noteTagsTable =>
      $$NoteTagsTableTableTableManager(_db, _db.noteTagsTable);
  $$SyncMetadataTableTableTableManager get syncMetadataTable =>
      $$SyncMetadataTableTableTableManager(_db, _db.syncMetadataTable);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
  $$AttachmentsTableTableTableManager get attachmentsTable =>
      $$AttachmentsTableTableTableManager(_db, _db.attachmentsTable);
  $$AttachmentVariantsTableTableTableManager get attachmentVariantsTable =>
      $$AttachmentVariantsTableTableTableManager(
        _db,
        _db.attachmentVariantsTable,
      );
  $$NoteVersionsTableTableTableManager get noteVersionsTable =>
      $$NoteVersionsTableTableTableManager(_db, _db.noteVersionsTable);
  $$DocumentsTableTableTableManager get documentsTable =>
      $$DocumentsTableTableTableManager(_db, _db.documentsTable);
  $$DocumentOcrPagesTableTableTableManager get documentOcrPagesTable =>
      $$DocumentOcrPagesTableTableTableManager(_db, _db.documentOcrPagesTable);
}
