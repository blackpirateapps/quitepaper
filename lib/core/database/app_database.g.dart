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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _pinnedOrderMeta = const VerificationMeta(
    'pinnedOrder',
  );
  @override
  late final GeneratedColumn<int> pinnedOrder = GeneratedColumn<int>(
    'pinned_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    color,
    isPinned,
    pinnedOrder,
    createdAt,
    updatedAt,
    isDirty,
    serverRevision,
    syncedAt,
    isDeleted,
    deletedAt,
  ];
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
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('pinned_order')) {
      context.handle(
        _pinnedOrderMeta,
        pinnedOrder.isAcceptableOrUnknown(
          data['pinned_order']!,
          _pinnedOrderMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
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
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      pinnedOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
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
  final String? icon;
  final String? color;
  final bool isPinned;
  final int pinnedOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDirty;
  final int serverRevision;
  final DateTime? syncedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  const TagEntity({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.isPinned,
    required this.pinnedOrder,
    this.createdAt,
    this.updatedAt,
    required this.isDirty,
    required this.serverRevision,
    this.syncedAt,
    required this.isDeleted,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['pinned_order'] = Variable<int>(pinnedOrder);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_dirty'] = Variable<bool>(isDirty);
    map['server_revision'] = Variable<int>(serverRevision);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TagsTableCompanion toCompanion(bool nullToAbsent) {
    return TagsTableCompanion(
      id: Value(id),
      name: Value(name),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      isPinned: Value(isPinned),
      pinnedOrder: Value(pinnedOrder),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDirty: Value(isDirty),
      serverRevision: Value(serverRevision),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TagEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      pinnedOrder: serializer.fromJson<int>(json['pinnedOrder']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'isPinned': serializer.toJson<bool>(isPinned),
      'pinnedOrder': serializer.toJson<int>(pinnedOrder),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isDirty': serializer.toJson<bool>(isDirty),
      'serverRevision': serializer.toJson<int>(serverRevision),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TagEntity copyWith({
    String? id,
    String? name,
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    bool? isPinned,
    int? pinnedOrder,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isDirty,
    int? serverRevision,
    Value<DateTime?> syncedAt = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TagEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    isPinned: isPinned ?? this.isPinned,
    pinnedOrder: pinnedOrder ?? this.pinnedOrder,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDirty: isDirty ?? this.isDirty,
    serverRevision: serverRevision ?? this.serverRevision,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TagEntity copyWithCompanion(TagsTableCompanion data) {
    return TagEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      pinnedOrder: data.pinnedOrder.present
          ? data.pinnedOrder.value
          : this.pinnedOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedOrder: $pinnedOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    color,
    isPinned,
    pinnedOrder,
    createdAt,
    updatedAt,
    isDirty,
    serverRevision,
    syncedAt,
    isDeleted,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.isPinned == this.isPinned &&
          other.pinnedOrder == this.pinnedOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDirty == this.isDirty &&
          other.serverRevision == this.serverRevision &&
          other.syncedAt == this.syncedAt &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class TagsTableCompanion extends UpdateCompanion<TagEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<bool> isPinned;
  final Value<int> pinnedOrder;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isDirty;
  final Value<int> serverRevision;
  final Value<DateTime?> syncedAt;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TagsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsTableCompanion.insert({
    required String id,
    required String name,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<TagEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<bool>? isPinned,
    Expression<int>? pinnedOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDirty,
    Expression<int>? serverRevision,
    Expression<DateTime>? syncedAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (isPinned != null) 'is_pinned': isPinned,
      if (pinnedOrder != null) 'pinned_order': pinnedOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDirty != null) 'is_dirty': isDirty,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? icon,
    Value<String?>? color,
    Value<bool>? isPinned,
    Value<int>? pinnedOrder,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? isDirty,
    Value<int>? serverRevision,
    Value<DateTime?>? syncedAt,
    Value<bool>? isDeleted,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TagsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      pinnedOrder: pinnedOrder ?? this.pinnedOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDirty: isDirty ?? this.isDirty,
      serverRevision: serverRevision ?? this.serverRevision,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (pinnedOrder.present) {
      map['pinned_order'] = Variable<int>(pinnedOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
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
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedOrder: $pinnedOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
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
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('attachment'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('image'),
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
    createdAt,
    updatedAt,
    fileName,
    kind,
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
    ocrState,
    ocrLanguage,
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
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
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
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
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

  /// Original user-visible file name (e.g. 'report.docx', 'image.png')
  final String fileName;

  /// Attachment classification kind ('image', 'document', 'file')
  final String kind;

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

  /// OCR processing state: 'not_requested', 'queued', 'processing', 'available', 'failed'
  final String ocrState;

  /// OCR language code: e.g. 'en'
  final String ocrLanguage;
  const AttachmentEntity({
    required this.id,
    this.noteId,
    required this.createdAt,
    required this.updatedAt,
    required this.fileName,
    required this.kind,
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
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['file_name'] = Variable<String>(fileName);
    map['kind'] = Variable<String>(kind);
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
    map['ocr_state'] = Variable<String>(ocrState);
    map['ocr_language'] = Variable<String>(ocrLanguage);
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
      fileName: Value(fileName),
      kind: Value(kind),
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
      ocrState: Value(ocrState),
      ocrLanguage: Value(ocrLanguage),
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
      fileName: serializer.fromJson<String>(json['fileName']),
      kind: serializer.fromJson<String>(json['kind']),
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'fileName': serializer.toJson<String>(fileName),
      'kind': serializer.toJson<String>(kind),
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
      'ocrState': serializer.toJson<String>(ocrState),
      'ocrLanguage': serializer.toJson<String>(ocrLanguage),
    };
  }

  AttachmentEntity copyWith({
    String? id,
    Value<String?> noteId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fileName,
    String? kind,
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
    String? ocrState,
    String? ocrLanguage,
  }) => AttachmentEntity(
    id: id ?? this.id,
    noteId: noteId.present ? noteId.value : this.noteId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    fileName: fileName ?? this.fileName,
    kind: kind ?? this.kind,
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
    ocrState: ocrState ?? this.ocrState,
    ocrLanguage: ocrLanguage ?? this.ocrLanguage,
  );
  AttachmentEntity copyWithCompanion(AttachmentsTableCompanion data) {
    return AttachmentEntity(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      kind: data.kind.present ? data.kind.value : this.kind,
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
      ocrState: data.ocrState.present ? data.ocrState.value : this.ocrState,
      ocrLanguage: data.ocrLanguage.present
          ? data.ocrLanguage.value
          : this.ocrLanguage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentEntity(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('fileName: $fileName, ')
          ..write('kind: $kind, ')
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
          ..write('ocrState: $ocrState, ')
          ..write('ocrLanguage: $ocrLanguage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    noteId,
    createdAt,
    updatedAt,
    fileName,
    kind,
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
    ocrState,
    ocrLanguage,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentEntity &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.fileName == this.fileName &&
          other.kind == this.kind &&
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
          other.localPath == this.localPath &&
          other.ocrState == this.ocrState &&
          other.ocrLanguage == this.ocrLanguage);
}

class AttachmentsTableCompanion extends UpdateCompanion<AttachmentEntity> {
  final Value<String> id;
  final Value<String?> noteId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> fileName;
  final Value<String> kind;
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
  final Value<String> ocrState;
  final Value<String> ocrLanguage;
  final Value<int> rowid;
  const AttachmentsTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.fileName = const Value.absent(),
    this.kind = const Value.absent(),
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
    this.ocrState = const Value.absent(),
    this.ocrLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsTableCompanion.insert({
    required String id,
    this.noteId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.fileName = const Value.absent(),
    this.kind = const Value.absent(),
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
    this.ocrState = const Value.absent(),
    this.ocrLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AttachmentEntity> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? fileName,
    Expression<String>? kind,
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
    Expression<String>? ocrState,
    Expression<String>? ocrLanguage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (fileName != null) 'file_name': fileName,
      if (kind != null) 'kind': kind,
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
      if (ocrState != null) 'ocr_state': ocrState,
      if (ocrLanguage != null) 'ocr_language': ocrLanguage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? noteId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? fileName,
    Value<String>? kind,
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
    Value<String>? ocrState,
    Value<String>? ocrLanguage,
    Value<int>? rowid,
  }) {
    return AttachmentsTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileName: fileName ?? this.fileName,
      kind: kind ?? this.kind,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
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
    return (StringBuffer('AttachmentsTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('fileName: $fileName, ')
          ..write('kind: $kind, ')
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
          ..write('ocrState: $ocrState, ')
          ..write('ocrLanguage: $ocrLanguage, ')
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

class $AttachmentOcrPagesTableTable extends AttachmentOcrPagesTable
    with TableInfo<$AttachmentOcrPagesTableTable, AttachmentOcrPageEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentOcrPagesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    attachmentId,
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
  static const String $name = 'attachment_ocr_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentOcrPageEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {attachmentId, pageNumber};
  @override
  AttachmentOcrPageEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentOcrPageEntity(
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_id'],
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
  $AttachmentOcrPagesTableTable createAlias(String alias) {
    return $AttachmentOcrPagesTableTable(attachedDatabase, alias);
  }
}

class AttachmentOcrPageEntity extends DataClass
    implements Insertable<AttachmentOcrPageEntity> {
  /// Attachment canonical UUID reference
  final String attachmentId;

  /// 1-based page number (defaults to 1 for images)
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
  const AttachmentOcrPageEntity({
    required this.attachmentId,
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
    map['attachment_id'] = Variable<String>(attachmentId);
    map['page_number'] = Variable<int>(pageNumber);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    map['ocr_schema_version'] = Variable<int>(ocrSchemaVersion);
    map['ocr_engine'] = Variable<String>(ocrEngine);
    map['ocr_engine_version'] = Variable<String>(ocrEngineVersion);
    map['language'] = Variable<String>(language);
    map['processed_at'] = Variable<DateTime>(processedAt);
    return map;
  }

  AttachmentOcrPagesTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentOcrPagesTableCompanion(
      attachmentId: Value(attachmentId),
      pageNumber: Value(pageNumber),
      encryptedPayload: Value(encryptedPayload),
      ocrSchemaVersion: Value(ocrSchemaVersion),
      ocrEngine: Value(ocrEngine),
      ocrEngineVersion: Value(ocrEngineVersion),
      language: Value(language),
      processedAt: Value(processedAt),
    );
  }

  factory AttachmentOcrPageEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentOcrPageEntity(
      attachmentId: serializer.fromJson<String>(json['attachmentId']),
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
      'attachmentId': serializer.toJson<String>(attachmentId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
      'ocrSchemaVersion': serializer.toJson<int>(ocrSchemaVersion),
      'ocrEngine': serializer.toJson<String>(ocrEngine),
      'ocrEngineVersion': serializer.toJson<String>(ocrEngineVersion),
      'language': serializer.toJson<String>(language),
      'processedAt': serializer.toJson<DateTime>(processedAt),
    };
  }

  AttachmentOcrPageEntity copyWith({
    String? attachmentId,
    int? pageNumber,
    String? encryptedPayload,
    int? ocrSchemaVersion,
    String? ocrEngine,
    String? ocrEngineVersion,
    String? language,
    DateTime? processedAt,
  }) => AttachmentOcrPageEntity(
    attachmentId: attachmentId ?? this.attachmentId,
    pageNumber: pageNumber ?? this.pageNumber,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    ocrSchemaVersion: ocrSchemaVersion ?? this.ocrSchemaVersion,
    ocrEngine: ocrEngine ?? this.ocrEngine,
    ocrEngineVersion: ocrEngineVersion ?? this.ocrEngineVersion,
    language: language ?? this.language,
    processedAt: processedAt ?? this.processedAt,
  );
  AttachmentOcrPageEntity copyWithCompanion(
    AttachmentOcrPagesTableCompanion data,
  ) {
    return AttachmentOcrPageEntity(
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
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
    return (StringBuffer('AttachmentOcrPageEntity(')
          ..write('attachmentId: $attachmentId, ')
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
    attachmentId,
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
      (other is AttachmentOcrPageEntity &&
          other.attachmentId == this.attachmentId &&
          other.pageNumber == this.pageNumber &&
          other.encryptedPayload == this.encryptedPayload &&
          other.ocrSchemaVersion == this.ocrSchemaVersion &&
          other.ocrEngine == this.ocrEngine &&
          other.ocrEngineVersion == this.ocrEngineVersion &&
          other.language == this.language &&
          other.processedAt == this.processedAt);
}

class AttachmentOcrPagesTableCompanion
    extends UpdateCompanion<AttachmentOcrPageEntity> {
  final Value<String> attachmentId;
  final Value<int> pageNumber;
  final Value<String> encryptedPayload;
  final Value<int> ocrSchemaVersion;
  final Value<String> ocrEngine;
  final Value<String> ocrEngineVersion;
  final Value<String> language;
  final Value<DateTime> processedAt;
  final Value<int> rowid;
  const AttachmentOcrPagesTableCompanion({
    this.attachmentId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.ocrSchemaVersion = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrEngineVersion = const Value.absent(),
    this.language = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentOcrPagesTableCompanion.insert({
    required String attachmentId,
    this.pageNumber = const Value.absent(),
    required String encryptedPayload,
    this.ocrSchemaVersion = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrEngineVersion = const Value.absent(),
    this.language = const Value.absent(),
    required DateTime processedAt,
    this.rowid = const Value.absent(),
  }) : attachmentId = Value(attachmentId),
       encryptedPayload = Value(encryptedPayload),
       processedAt = Value(processedAt);
  static Insertable<AttachmentOcrPageEntity> custom({
    Expression<String>? attachmentId,
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
      if (attachmentId != null) 'attachment_id': attachmentId,
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

  AttachmentOcrPagesTableCompanion copyWith({
    Value<String>? attachmentId,
    Value<int>? pageNumber,
    Value<String>? encryptedPayload,
    Value<int>? ocrSchemaVersion,
    Value<String>? ocrEngine,
    Value<String>? ocrEngineVersion,
    Value<String>? language,
    Value<DateTime>? processedAt,
    Value<int>? rowid,
  }) {
    return AttachmentOcrPagesTableCompanion(
      attachmentId: attachmentId ?? this.attachmentId,
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
    if (attachmentId.present) {
      map['attachment_id'] = Variable<String>(attachmentId.value);
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
    return (StringBuffer('AttachmentOcrPagesTableCompanion(')
          ..write('attachmentId: $attachmentId, ')
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
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localParentRevisionMeta =
      const VerificationMeta('localParentRevision');
  @override
  late final GeneratedColumn<int> localParentRevision = GeneratedColumn<int>(
    'local_parent_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteParentRevisionMeta =
      const VerificationMeta('remoteParentRevision');
  @override
  late final GeneratedColumn<int> remoteParentRevision = GeneratedColumn<int>(
    'remote_parent_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mergeTypeMeta = const VerificationMeta(
    'mergeType',
  );
  @override
  late final GeneratedColumn<String> mergeType = GeneratedColumn<String>(
    'merge_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionSummaryMeta = const VerificationMeta(
    'resolutionSummary',
  );
  @override
  late final GeneratedColumn<String> resolutionSummary =
      GeneratedColumn<String>(
        'resolution_summary',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
    baseRevision,
    localParentRevision,
    remoteParentRevision,
    mergeType,
    resolutionSummary,
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
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('local_parent_revision')) {
      context.handle(
        _localParentRevisionMeta,
        localParentRevision.isAcceptableOrUnknown(
          data['local_parent_revision']!,
          _localParentRevisionMeta,
        ),
      );
    }
    if (data.containsKey('remote_parent_revision')) {
      context.handle(
        _remoteParentRevisionMeta,
        remoteParentRevision.isAcceptableOrUnknown(
          data['remote_parent_revision']!,
          _remoteParentRevisionMeta,
        ),
      );
    }
    if (data.containsKey('merge_type')) {
      context.handle(
        _mergeTypeMeta,
        mergeType.isAcceptableOrUnknown(data['merge_type']!, _mergeTypeMeta),
      );
    }
    if (data.containsKey('resolution_summary')) {
      context.handle(
        _resolutionSummaryMeta,
        resolutionSummary.isAcceptableOrUnknown(
          data['resolution_summary']!,
          _resolutionSummaryMeta,
        ),
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
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      ),
      localParentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_parent_revision'],
      ),
      remoteParentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_parent_revision'],
      ),
      mergeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merge_type'],
      ),
      resolutionSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_summary'],
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
  final int? baseRevision;
  final int? localParentRevision;
  final int? remoteParentRevision;
  final String? mergeType;
  final String? resolutionSummary;
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
    this.baseRevision,
    this.localParentRevision,
    this.remoteParentRevision,
    this.mergeType,
    this.resolutionSummary,
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
    if (!nullToAbsent || baseRevision != null) {
      map['base_revision'] = Variable<int>(baseRevision);
    }
    if (!nullToAbsent || localParentRevision != null) {
      map['local_parent_revision'] = Variable<int>(localParentRevision);
    }
    if (!nullToAbsent || remoteParentRevision != null) {
      map['remote_parent_revision'] = Variable<int>(remoteParentRevision);
    }
    if (!nullToAbsent || mergeType != null) {
      map['merge_type'] = Variable<String>(mergeType);
    }
    if (!nullToAbsent || resolutionSummary != null) {
      map['resolution_summary'] = Variable<String>(resolutionSummary);
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
      baseRevision: baseRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRevision),
      localParentRevision: localParentRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(localParentRevision),
      remoteParentRevision: remoteParentRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteParentRevision),
      mergeType: mergeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mergeType),
      resolutionSummary: resolutionSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionSummary),
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
      baseRevision: serializer.fromJson<int?>(json['baseRevision']),
      localParentRevision: serializer.fromJson<int?>(
        json['localParentRevision'],
      ),
      remoteParentRevision: serializer.fromJson<int?>(
        json['remoteParentRevision'],
      ),
      mergeType: serializer.fromJson<String?>(json['mergeType']),
      resolutionSummary: serializer.fromJson<String?>(
        json['resolutionSummary'],
      ),
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
      'baseRevision': serializer.toJson<int?>(baseRevision),
      'localParentRevision': serializer.toJson<int?>(localParentRevision),
      'remoteParentRevision': serializer.toJson<int?>(remoteParentRevision),
      'mergeType': serializer.toJson<String?>(mergeType),
      'resolutionSummary': serializer.toJson<String?>(resolutionSummary),
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
    Value<int?> baseRevision = const Value.absent(),
    Value<int?> localParentRevision = const Value.absent(),
    Value<int?> remoteParentRevision = const Value.absent(),
    Value<String?> mergeType = const Value.absent(),
    Value<String?> resolutionSummary = const Value.absent(),
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
    baseRevision: baseRevision.present ? baseRevision.value : this.baseRevision,
    localParentRevision: localParentRevision.present
        ? localParentRevision.value
        : this.localParentRevision,
    remoteParentRevision: remoteParentRevision.present
        ? remoteParentRevision.value
        : this.remoteParentRevision,
    mergeType: mergeType.present ? mergeType.value : this.mergeType,
    resolutionSummary: resolutionSummary.present
        ? resolutionSummary.value
        : this.resolutionSummary,
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
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      localParentRevision: data.localParentRevision.present
          ? data.localParentRevision.value
          : this.localParentRevision,
      remoteParentRevision: data.remoteParentRevision.present
          ? data.remoteParentRevision.value
          : this.remoteParentRevision,
      mergeType: data.mergeType.present ? data.mergeType.value : this.mergeType,
      resolutionSummary: data.resolutionSummary.present
          ? data.resolutionSummary.value
          : this.resolutionSummary,
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
          ..write('syncedAt: $syncedAt, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('localParentRevision: $localParentRevision, ')
          ..write('remoteParentRevision: $remoteParentRevision, ')
          ..write('mergeType: $mergeType, ')
          ..write('resolutionSummary: $resolutionSummary')
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
    baseRevision,
    localParentRevision,
    remoteParentRevision,
    mergeType,
    resolutionSummary,
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
          other.syncedAt == this.syncedAt &&
          other.baseRevision == this.baseRevision &&
          other.localParentRevision == this.localParentRevision &&
          other.remoteParentRevision == this.remoteParentRevision &&
          other.mergeType == this.mergeType &&
          other.resolutionSummary == this.resolutionSummary);
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
  final Value<int?> baseRevision;
  final Value<int?> localParentRevision;
  final Value<int?> remoteParentRevision;
  final Value<String?> mergeType;
  final Value<String?> resolutionSummary;
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
    this.baseRevision = const Value.absent(),
    this.localParentRevision = const Value.absent(),
    this.remoteParentRevision = const Value.absent(),
    this.mergeType = const Value.absent(),
    this.resolutionSummary = const Value.absent(),
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
    this.baseRevision = const Value.absent(),
    this.localParentRevision = const Value.absent(),
    this.remoteParentRevision = const Value.absent(),
    this.mergeType = const Value.absent(),
    this.resolutionSummary = const Value.absent(),
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
    Expression<int>? baseRevision,
    Expression<int>? localParentRevision,
    Expression<int>? remoteParentRevision,
    Expression<String>? mergeType,
    Expression<String>? resolutionSummary,
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
      if (baseRevision != null) 'base_revision': baseRevision,
      if (localParentRevision != null)
        'local_parent_revision': localParentRevision,
      if (remoteParentRevision != null)
        'remote_parent_revision': remoteParentRevision,
      if (mergeType != null) 'merge_type': mergeType,
      if (resolutionSummary != null) 'resolution_summary': resolutionSummary,
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
    Value<int?>? baseRevision,
    Value<int?>? localParentRevision,
    Value<int?>? remoteParentRevision,
    Value<String?>? mergeType,
    Value<String?>? resolutionSummary,
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
      baseRevision: baseRevision ?? this.baseRevision,
      localParentRevision: localParentRevision ?? this.localParentRevision,
      remoteParentRevision: remoteParentRevision ?? this.remoteParentRevision,
      mergeType: mergeType ?? this.mergeType,
      resolutionSummary: resolutionSummary ?? this.resolutionSummary,
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
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (localParentRevision.present) {
      map['local_parent_revision'] = Variable<int>(localParentRevision.value);
    }
    if (remoteParentRevision.present) {
      map['remote_parent_revision'] = Variable<int>(remoteParentRevision.value);
    }
    if (mergeType.present) {
      map['merge_type'] = Variable<String>(mergeType.value);
    }
    if (resolutionSummary.present) {
      map['resolution_summary'] = Variable<String>(resolutionSummary.value);
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
          ..write('baseRevision: $baseRevision, ')
          ..write('localParentRevision: $localParentRevision, ')
          ..write('remoteParentRevision: $remoteParentRevision, ')
          ..write('mergeType: $mergeType, ')
          ..write('resolutionSummary: $resolutionSummary, ')
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

class $SyncConflictsTableTable extends SyncConflictsTable
    with TableInfo<$SyncConflictsTableTable, SyncConflictEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localRevisionMeta = const VerificationMeta(
    'localRevision',
  );
  @override
  late final GeneratedColumn<int> localRevision = GeneratedColumn<int>(
    'local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta(
    'remoteRevision',
  );
  @override
  late final GeneratedColumn<int> remoteRevision = GeneratedColumn<int>(
    'remote_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _conflictTypeMeta = const VerificationMeta(
    'conflictType',
  );
  @override
  late final GeneratedColumn<String> conflictType = GeneratedColumn<String>(
    'conflict_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('content'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('detected'),
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
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionRevisionMeta =
      const VerificationMeta('resolutionRevision');
  @override
  late final GeneratedColumn<int> resolutionRevision = GeneratedColumn<int>(
    'resolution_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionTypeMeta = const VerificationMeta(
    'resolutionType',
  );
  @override
  late final GeneratedColumn<String> resolutionType = GeneratedColumn<String>(
    'resolution_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    baseRevision,
    localRevision,
    remoteRevision,
    conflictType,
    state,
    createdAt,
    resolvedAt,
    resolutionRevision,
    resolutionType,
    dataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictEntity> instance, {
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
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('local_revision')) {
      context.handle(
        _localRevisionMeta,
        localRevision.isAcceptableOrUnknown(
          data['local_revision']!,
          _localRevisionMeta,
        ),
      );
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(
          data['remote_revision']!,
          _remoteRevisionMeta,
        ),
      );
    }
    if (data.containsKey('conflict_type')) {
      context.handle(
        _conflictTypeMeta,
        conflictType.isAcceptableOrUnknown(
          data['conflict_type']!,
          _conflictTypeMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
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
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('resolution_revision')) {
      context.handle(
        _resolutionRevisionMeta,
        resolutionRevision.isAcceptableOrUnknown(
          data['resolution_revision']!,
          _resolutionRevisionMeta,
        ),
      );
    }
    if (data.containsKey('resolution_type')) {
      context.handle(
        _resolutionTypeMeta,
        resolutionType.isAcceptableOrUnknown(
          data['resolution_type']!,
          _resolutionTypeMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflictEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      )!,
      localRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision'],
      )!,
      remoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_revision'],
      )!,
      conflictType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_type'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      resolutionRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolution_revision'],
      ),
      resolutionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_type'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $SyncConflictsTableTable createAlias(String alias) {
    return $SyncConflictsTableTable(attachedDatabase, alias);
  }
}

class SyncConflictEntity extends DataClass
    implements Insertable<SyncConflictEntity> {
  final String id;
  final String noteId;
  final int baseRevision;
  final int localRevision;
  final int remoteRevision;
  final String conflictType;
  final String state;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final int? resolutionRevision;
  final String? resolutionType;
  final String dataJson;
  const SyncConflictEntity({
    required this.id,
    required this.noteId,
    required this.baseRevision,
    required this.localRevision,
    required this.remoteRevision,
    required this.conflictType,
    required this.state,
    required this.createdAt,
    this.resolvedAt,
    this.resolutionRevision,
    this.resolutionType,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['base_revision'] = Variable<int>(baseRevision);
    map['local_revision'] = Variable<int>(localRevision);
    map['remote_revision'] = Variable<int>(remoteRevision);
    map['conflict_type'] = Variable<String>(conflictType);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || resolutionRevision != null) {
      map['resolution_revision'] = Variable<int>(resolutionRevision);
    }
    if (!nullToAbsent || resolutionType != null) {
      map['resolution_type'] = Variable<String>(resolutionType);
    }
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  SyncConflictsTableCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      baseRevision: Value(baseRevision),
      localRevision: Value(localRevision),
      remoteRevision: Value(remoteRevision),
      conflictType: Value(conflictType),
      state: Value(state),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      resolutionRevision: resolutionRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionRevision),
      resolutionType: resolutionType == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionType),
      dataJson: Value(dataJson),
    );
  }

  factory SyncConflictEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictEntity(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      baseRevision: serializer.fromJson<int>(json['baseRevision']),
      localRevision: serializer.fromJson<int>(json['localRevision']),
      remoteRevision: serializer.fromJson<int>(json['remoteRevision']),
      conflictType: serializer.fromJson<String>(json['conflictType']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      resolutionRevision: serializer.fromJson<int?>(json['resolutionRevision']),
      resolutionType: serializer.fromJson<String?>(json['resolutionType']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'localRevision': serializer.toJson<int>(localRevision),
      'remoteRevision': serializer.toJson<int>(remoteRevision),
      'conflictType': serializer.toJson<String>(conflictType),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'resolutionRevision': serializer.toJson<int?>(resolutionRevision),
      'resolutionType': serializer.toJson<String?>(resolutionType),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  SyncConflictEntity copyWith({
    String? id,
    String? noteId,
    int? baseRevision,
    int? localRevision,
    int? remoteRevision,
    String? conflictType,
    String? state,
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<int?> resolutionRevision = const Value.absent(),
    Value<String?> resolutionType = const Value.absent(),
    String? dataJson,
  }) => SyncConflictEntity(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    baseRevision: baseRevision ?? this.baseRevision,
    localRevision: localRevision ?? this.localRevision,
    remoteRevision: remoteRevision ?? this.remoteRevision,
    conflictType: conflictType ?? this.conflictType,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    resolutionRevision: resolutionRevision.present
        ? resolutionRevision.value
        : this.resolutionRevision,
    resolutionType: resolutionType.present
        ? resolutionType.value
        : this.resolutionType,
    dataJson: dataJson ?? this.dataJson,
  );
  SyncConflictEntity copyWithCompanion(SyncConflictsTableCompanion data) {
    return SyncConflictEntity(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      localRevision: data.localRevision.present
          ? data.localRevision.value
          : this.localRevision,
      remoteRevision: data.remoteRevision.present
          ? data.remoteRevision.value
          : this.remoteRevision,
      conflictType: data.conflictType.present
          ? data.conflictType.value
          : this.conflictType,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      resolutionRevision: data.resolutionRevision.present
          ? data.resolutionRevision.value
          : this.resolutionRevision,
      resolutionType: data.resolutionType.present
          ? data.resolutionType.value
          : this.resolutionType,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictEntity(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('localRevision: $localRevision, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('conflictType: $conflictType, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolutionRevision: $resolutionRevision, ')
          ..write('resolutionType: $resolutionType, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    baseRevision,
    localRevision,
    remoteRevision,
    conflictType,
    state,
    createdAt,
    resolvedAt,
    resolutionRevision,
    resolutionType,
    dataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictEntity &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.baseRevision == this.baseRevision &&
          other.localRevision == this.localRevision &&
          other.remoteRevision == this.remoteRevision &&
          other.conflictType == this.conflictType &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt &&
          other.resolutionRevision == this.resolutionRevision &&
          other.resolutionType == this.resolutionType &&
          other.dataJson == this.dataJson);
}

class SyncConflictsTableCompanion extends UpdateCompanion<SyncConflictEntity> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<int> baseRevision;
  final Value<int> localRevision;
  final Value<int> remoteRevision;
  final Value<String> conflictType;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int?> resolutionRevision;
  final Value<String?> resolutionType;
  final Value<String> dataJson;
  final Value<int> rowid;
  const SyncConflictsTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.conflictType = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.resolutionRevision = const Value.absent(),
    this.resolutionType = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsTableCompanion.insert({
    required String id,
    required String noteId,
    this.baseRevision = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.conflictType = const Value.absent(),
    this.state = const Value.absent(),
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.resolutionRevision = const Value.absent(),
    this.resolutionType = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       createdAt = Value(createdAt);
  static Insertable<SyncConflictEntity> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<int>? baseRevision,
    Expression<int>? localRevision,
    Expression<int>? remoteRevision,
    Expression<String>? conflictType,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? resolutionRevision,
    Expression<String>? resolutionType,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (localRevision != null) 'local_revision': localRevision,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (conflictType != null) 'conflict_type': conflictType,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (resolutionRevision != null) 'resolution_revision': resolutionRevision,
      if (resolutionType != null) 'resolution_type': resolutionType,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<int>? baseRevision,
    Value<int>? localRevision,
    Value<int>? remoteRevision,
    Value<String>? conflictType,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int?>? resolutionRevision,
    Value<String?>? resolutionType,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return SyncConflictsTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      baseRevision: baseRevision ?? this.baseRevision,
      localRevision: localRevision ?? this.localRevision,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      conflictType: conflictType ?? this.conflictType,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionRevision: resolutionRevision ?? this.resolutionRevision,
      resolutionType: resolutionType ?? this.resolutionType,
      dataJson: dataJson ?? this.dataJson,
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
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (localRevision.present) {
      map['local_revision'] = Variable<int>(localRevision.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<int>(remoteRevision.value);
    }
    if (conflictType.present) {
      map['conflict_type'] = Variable<String>(conflictType.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (resolutionRevision.present) {
      map['resolution_revision'] = Variable<int>(resolutionRevision.value);
    }
    if (resolutionType.present) {
      map['resolution_type'] = Variable<String>(resolutionType.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('localRevision: $localRevision, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('conflictType: $conflictType, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolutionRevision: $resolutionRevision, ')
          ..write('resolutionType: $resolutionType, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteLinksTableTable extends NoteLinksTable
    with TableInfo<$NoteLinksTableTable, NoteLinkEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteLinksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNoteIdMeta = const VerificationMeta(
    'sourceNoteId',
  );
  @override
  late final GeneratedColumn<String> sourceNoteId = GeneratedColumn<String>(
    'source_note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetNoteIdMeta = const VerificationMeta(
    'targetNoteId',
  );
  @override
  late final GeneratedColumn<String> targetNoteId = GeneratedColumn<String>(
    'target_note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayTextMeta = const VerificationMeta(
    'displayText',
  );
  @override
  late final GeneratedColumn<String> displayText = GeneratedColumn<String>(
    'display_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceOffsetMeta = const VerificationMeta(
    'sourceOffset',
  );
  @override
  late final GeneratedColumn<int> sourceOffset = GeneratedColumn<int>(
    'source_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceNoteId,
    targetNoteId,
    displayText,
    sourceOffset,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteLinkEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_note_id')) {
      context.handle(
        _sourceNoteIdMeta,
        sourceNoteId.isAcceptableOrUnknown(
          data['source_note_id']!,
          _sourceNoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceNoteIdMeta);
    }
    if (data.containsKey('target_note_id')) {
      context.handle(
        _targetNoteIdMeta,
        targetNoteId.isAcceptableOrUnknown(
          data['target_note_id']!,
          _targetNoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetNoteIdMeta);
    }
    if (data.containsKey('display_text')) {
      context.handle(
        _displayTextMeta,
        displayText.isAcceptableOrUnknown(
          data['display_text']!,
          _displayTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayTextMeta);
    }
    if (data.containsKey('source_offset')) {
      context.handle(
        _sourceOffsetMeta,
        sourceOffset.isAcceptableOrUnknown(
          data['source_offset']!,
          _sourceOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceOffsetMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteLinkEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteLinkEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceNoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_note_id'],
      )!,
      targetNoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_note_id'],
      )!,
      displayText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_text'],
      )!,
      sourceOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_offset'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NoteLinksTableTable createAlias(String alias) {
    return $NoteLinksTableTable(attachedDatabase, alias);
  }
}

class NoteLinkEntity extends DataClass implements Insertable<NoteLinkEntity> {
  /// Unique UUID for the link relationship record.
  final String id;

  /// Source note containing the link. Cascades deletion when source note is removed.
  final String sourceNoteId;

  /// Target note ID being referenced (UUID).
  final String targetNoteId;

  /// Display text rendered inside the link `[displayText](qp://note/<UUID>)`.
  final String displayText;

  /// UTF-16 character offset of the link in the source Markdown text.
  final int sourceOffset;

  /// Timestamp when the link record was first derived.
  final DateTime createdAt;

  /// Timestamp when the link record was last updated.
  final DateTime updatedAt;
  const NoteLinkEntity({
    required this.id,
    required this.sourceNoteId,
    required this.targetNoteId,
    required this.displayText,
    required this.sourceOffset,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_note_id'] = Variable<String>(sourceNoteId);
    map['target_note_id'] = Variable<String>(targetNoteId);
    map['display_text'] = Variable<String>(displayText);
    map['source_offset'] = Variable<int>(sourceOffset);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NoteLinksTableCompanion toCompanion(bool nullToAbsent) {
    return NoteLinksTableCompanion(
      id: Value(id),
      sourceNoteId: Value(sourceNoteId),
      targetNoteId: Value(targetNoteId),
      displayText: Value(displayText),
      sourceOffset: Value(sourceOffset),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NoteLinkEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteLinkEntity(
      id: serializer.fromJson<String>(json['id']),
      sourceNoteId: serializer.fromJson<String>(json['sourceNoteId']),
      targetNoteId: serializer.fromJson<String>(json['targetNoteId']),
      displayText: serializer.fromJson<String>(json['displayText']),
      sourceOffset: serializer.fromJson<int>(json['sourceOffset']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceNoteId': serializer.toJson<String>(sourceNoteId),
      'targetNoteId': serializer.toJson<String>(targetNoteId),
      'displayText': serializer.toJson<String>(displayText),
      'sourceOffset': serializer.toJson<int>(sourceOffset),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NoteLinkEntity copyWith({
    String? id,
    String? sourceNoteId,
    String? targetNoteId,
    String? displayText,
    int? sourceOffset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteLinkEntity(
    id: id ?? this.id,
    sourceNoteId: sourceNoteId ?? this.sourceNoteId,
    targetNoteId: targetNoteId ?? this.targetNoteId,
    displayText: displayText ?? this.displayText,
    sourceOffset: sourceOffset ?? this.sourceOffset,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NoteLinkEntity copyWithCompanion(NoteLinksTableCompanion data) {
    return NoteLinkEntity(
      id: data.id.present ? data.id.value : this.id,
      sourceNoteId: data.sourceNoteId.present
          ? data.sourceNoteId.value
          : this.sourceNoteId,
      targetNoteId: data.targetNoteId.present
          ? data.targetNoteId.value
          : this.targetNoteId,
      displayText: data.displayText.present
          ? data.displayText.value
          : this.displayText,
      sourceOffset: data.sourceOffset.present
          ? data.sourceOffset.value
          : this.sourceOffset,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteLinkEntity(')
          ..write('id: $id, ')
          ..write('sourceNoteId: $sourceNoteId, ')
          ..write('targetNoteId: $targetNoteId, ')
          ..write('displayText: $displayText, ')
          ..write('sourceOffset: $sourceOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceNoteId,
    targetNoteId,
    displayText,
    sourceOffset,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteLinkEntity &&
          other.id == this.id &&
          other.sourceNoteId == this.sourceNoteId &&
          other.targetNoteId == this.targetNoteId &&
          other.displayText == this.displayText &&
          other.sourceOffset == this.sourceOffset &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NoteLinksTableCompanion extends UpdateCompanion<NoteLinkEntity> {
  final Value<String> id;
  final Value<String> sourceNoteId;
  final Value<String> targetNoteId;
  final Value<String> displayText;
  final Value<int> sourceOffset;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NoteLinksTableCompanion({
    this.id = const Value.absent(),
    this.sourceNoteId = const Value.absent(),
    this.targetNoteId = const Value.absent(),
    this.displayText = const Value.absent(),
    this.sourceOffset = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteLinksTableCompanion.insert({
    required String id,
    required String sourceNoteId,
    required String targetNoteId,
    required String displayText,
    required int sourceOffset,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceNoteId = Value(sourceNoteId),
       targetNoteId = Value(targetNoteId),
       displayText = Value(displayText),
       sourceOffset = Value(sourceOffset);
  static Insertable<NoteLinkEntity> custom({
    Expression<String>? id,
    Expression<String>? sourceNoteId,
    Expression<String>? targetNoteId,
    Expression<String>? displayText,
    Expression<int>? sourceOffset,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceNoteId != null) 'source_note_id': sourceNoteId,
      if (targetNoteId != null) 'target_note_id': targetNoteId,
      if (displayText != null) 'display_text': displayText,
      if (sourceOffset != null) 'source_offset': sourceOffset,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteLinksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceNoteId,
    Value<String>? targetNoteId,
    Value<String>? displayText,
    Value<int>? sourceOffset,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NoteLinksTableCompanion(
      id: id ?? this.id,
      sourceNoteId: sourceNoteId ?? this.sourceNoteId,
      targetNoteId: targetNoteId ?? this.targetNoteId,
      displayText: displayText ?? this.displayText,
      sourceOffset: sourceOffset ?? this.sourceOffset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceNoteId.present) {
      map['source_note_id'] = Variable<String>(sourceNoteId.value);
    }
    if (targetNoteId.present) {
      map['target_note_id'] = Variable<String>(targetNoteId.value);
    }
    if (displayText.present) {
      map['display_text'] = Variable<String>(displayText.value);
    }
    if (sourceOffset.present) {
      map['source_offset'] = Variable<int>(sourceOffset.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('NoteLinksTableCompanion(')
          ..write('id: $id, ')
          ..write('sourceNoteId: $sourceNoteId, ')
          ..write('targetNoteId: $targetNoteId, ')
          ..write('displayText: $displayText, ')
          ..write('sourceOffset: $sourceOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $AttachmentOcrPagesTableTable attachmentOcrPagesTable =
      $AttachmentOcrPagesTableTable(this);
  late final $NoteVersionsTableTable noteVersionsTable =
      $NoteVersionsTableTable(this);
  late final $DocumentsTableTable documentsTable = $DocumentsTableTable(this);
  late final $DocumentOcrPagesTableTable documentOcrPagesTable =
      $DocumentOcrPagesTableTable(this);
  late final $SyncConflictsTableTable syncConflictsTable =
      $SyncConflictsTableTable(this);
  late final $NoteLinksTableTable noteLinksTable = $NoteLinksTableTable(this);
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
    attachmentOcrPagesTable,
    noteVersionsTable,
    documentsTable,
    documentOcrPagesTable,
    syncConflictsTable,
    noteLinksTable,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_conflicts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_links', kind: UpdateKind.delete)],
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

  static MultiTypedResultKey<$SyncConflictsTableTable, List<SyncConflictEntity>>
  _syncConflictsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.syncConflictsTable,
        aliasName: 'notes__id__sync_conflicts__note_id',
      );

  $$SyncConflictsTableTableProcessedTableManager get syncConflictsTableRefs {
    final manager = $$SyncConflictsTableTableTableManager(
      $_db,
      $_db.syncConflictsTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _syncConflictsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteLinksTableTable, List<NoteLinkEntity>>
  _noteLinksTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteLinksTable,
    aliasName: 'notes__id__note_links__source_note_id',
  );

  $$NoteLinksTableTableProcessedTableManager get noteLinksTableRefs {
    final manager = $$NoteLinksTableTableTableManager(
      $_db,
      $_db.noteLinksTable,
    ).filter((f) => f.sourceNoteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteLinksTableRefsTable($_db));
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

  Expression<bool> syncConflictsTableRefs(
    Expression<bool> Function($$SyncConflictsTableTableFilterComposer f) f,
  ) {
    final $$SyncConflictsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncConflictsTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncConflictsTableTableFilterComposer(
            $db: $db,
            $table: $db.syncConflictsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteLinksTableRefs(
    Expression<bool> Function($$NoteLinksTableTableFilterComposer f) f,
  ) {
    final $$NoteLinksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteLinksTable,
      getReferencedColumn: (t) => t.sourceNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinksTableTableFilterComposer(
            $db: $db,
            $table: $db.noteLinksTable,
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

  Expression<T> syncConflictsTableRefs<T extends Object>(
    Expression<T> Function($$SyncConflictsTableTableAnnotationComposer a) f,
  ) {
    final $$SyncConflictsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.syncConflictsTable,
          getReferencedColumn: (t) => t.noteId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SyncConflictsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.syncConflictsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> noteLinksTableRefs<T extends Object>(
    Expression<T> Function($$NoteLinksTableTableAnnotationComposer a) f,
  ) {
    final $$NoteLinksTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteLinksTable,
      getReferencedColumn: (t) => t.sourceNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinksTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteLinksTable,
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
            bool syncConflictsTableRefs,
            bool noteLinksTableRefs,
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
              ({
                noteTagsTableRefs = false,
                noteVersionsTableRefs = false,
                syncConflictsTableRefs = false,
                noteLinksTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (noteTagsTableRefs) db.noteTagsTable,
                    if (noteVersionsTableRefs) db.noteVersionsTable,
                    if (syncConflictsTableRefs) db.syncConflictsTable,
                    if (noteLinksTableRefs) db.noteLinksTable,
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
                      if (syncConflictsTableRefs)
                        await $_getPrefetchedData<
                          NoteEntity,
                          $NotesTableTable,
                          SyncConflictEntity
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._syncConflictsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).syncConflictsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (noteLinksTableRefs)
                        await $_getPrefetchedData<
                          NoteEntity,
                          $NotesTableTable,
                          NoteLinkEntity
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._noteLinksTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteLinksTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceNoteId == item.id,
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
        bool syncConflictsTableRefs,
        bool noteLinksTableRefs,
      })
    >;
typedef $$TagsTableTableCreateCompanionBuilder =
    TagsTableCompanion Function({
      required String id,
      required String name,
      Value<String?> icon,
      Value<String?> color,
      Value<bool> isPinned,
      Value<int> pinnedOrder,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isDirty,
      Value<int> serverRevision,
      Value<DateTime?> syncedAt,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TagsTableTableUpdateCompanionBuilder =
    TagsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> icon,
      Value<String?> color,
      Value<bool> isPinned,
      Value<int> pinnedOrder,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isDirty,
      Value<int> serverRevision,
      Value<DateTime?> syncedAt,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
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

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedOrder => $composableBuilder(
    column: $table.pinnedOrder,
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

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
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

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedOrder => $composableBuilder(
    column: $table.pinnedOrder,
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

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
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

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get pinnedOrder => $composableBuilder(
    column: $table.pinnedOrder,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

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
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> pinnedOrder = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsTableCompanion(
                id: id,
                name: name,
                icon: icon,
                color: color,
                isPinned: isPinned,
                pinnedOrder: pinnedOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDirty: isDirty,
                serverRevision: serverRevision,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> pinnedOrder = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsTableCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                color: color,
                isPinned: isPinned,
                pinnedOrder: pinnedOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDirty: isDirty,
                serverRevision: serverRevision,
                syncedAt: syncedAt,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
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
      Value<String> fileName,
      Value<String> kind,
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
      Value<String> ocrState,
      Value<String> ocrLanguage,
      Value<int> rowid,
    });
typedef $$AttachmentsTableTableUpdateCompanionBuilder =
    AttachmentsTableCompanion Function({
      Value<String> id,
      Value<String?> noteId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> fileName,
      Value<String> kind,
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
      Value<String> ocrState,
      Value<String> ocrLanguage,
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

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
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

  ColumnFilters<String> get ocrState => $composableBuilder(
    column: $table.ocrState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrLanguage => $composableBuilder(
    column: $table.ocrLanguage,
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

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
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

  ColumnOrderings<String> get ocrState => $composableBuilder(
    column: $table.ocrState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrLanguage => $composableBuilder(
    column: $table.ocrLanguage,
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

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

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

  GeneratedColumn<String> get ocrState =>
      $composableBuilder(column: $table.ocrState, builder: (column) => column);

  GeneratedColumn<String> get ocrLanguage => $composableBuilder(
    column: $table.ocrLanguage,
    builder: (column) => column,
  );
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
                Value<String> fileName = const Value.absent(),
                Value<String> kind = const Value.absent(),
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
                Value<String> ocrState = const Value.absent(),
                Value<String> ocrLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsTableCompanion(
                id: id,
                noteId: noteId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                fileName: fileName,
                kind: kind,
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
                ocrState: ocrState,
                ocrLanguage: ocrLanguage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> noteId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> fileName = const Value.absent(),
                Value<String> kind = const Value.absent(),
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
                Value<String> ocrState = const Value.absent(),
                Value<String> ocrLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsTableCompanion.insert(
                id: id,
                noteId: noteId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                fileName: fileName,
                kind: kind,
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
typedef $$AttachmentOcrPagesTableTableCreateCompanionBuilder =
    AttachmentOcrPagesTableCompanion Function({
      required String attachmentId,
      Value<int> pageNumber,
      required String encryptedPayload,
      Value<int> ocrSchemaVersion,
      Value<String> ocrEngine,
      Value<String> ocrEngineVersion,
      Value<String> language,
      required DateTime processedAt,
      Value<int> rowid,
    });
typedef $$AttachmentOcrPagesTableTableUpdateCompanionBuilder =
    AttachmentOcrPagesTableCompanion Function({
      Value<String> attachmentId,
      Value<int> pageNumber,
      Value<String> encryptedPayload,
      Value<int> ocrSchemaVersion,
      Value<String> ocrEngine,
      Value<String> ocrEngineVersion,
      Value<String> language,
      Value<DateTime> processedAt,
      Value<int> rowid,
    });

class $$AttachmentOcrPagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentOcrPagesTableTable> {
  $$AttachmentOcrPagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
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

class $$AttachmentOcrPagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentOcrPagesTableTable> {
  $$AttachmentOcrPagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
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

class $$AttachmentOcrPagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentOcrPagesTableTable> {
  $$AttachmentOcrPagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
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

class $$AttachmentOcrPagesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentOcrPagesTableTable,
          AttachmentOcrPageEntity,
          $$AttachmentOcrPagesTableTableFilterComposer,
          $$AttachmentOcrPagesTableTableOrderingComposer,
          $$AttachmentOcrPagesTableTableAnnotationComposer,
          $$AttachmentOcrPagesTableTableCreateCompanionBuilder,
          $$AttachmentOcrPagesTableTableUpdateCompanionBuilder,
          (
            AttachmentOcrPageEntity,
            BaseReferences<
              _$AppDatabase,
              $AttachmentOcrPagesTableTable,
              AttachmentOcrPageEntity
            >,
          ),
          AttachmentOcrPageEntity,
          PrefetchHooks Function()
        > {
  $$AttachmentOcrPagesTableTableTableManager(
    _$AppDatabase db,
    $AttachmentOcrPagesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentOcrPagesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AttachmentOcrPagesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AttachmentOcrPagesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> attachmentId = const Value.absent(),
                Value<int> pageNumber = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<int> ocrSchemaVersion = const Value.absent(),
                Value<String> ocrEngine = const Value.absent(),
                Value<String> ocrEngineVersion = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<DateTime> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentOcrPagesTableCompanion(
                attachmentId: attachmentId,
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
                required String attachmentId,
                Value<int> pageNumber = const Value.absent(),
                required String encryptedPayload,
                Value<int> ocrSchemaVersion = const Value.absent(),
                Value<String> ocrEngine = const Value.absent(),
                Value<String> ocrEngineVersion = const Value.absent(),
                Value<String> language = const Value.absent(),
                required DateTime processedAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentOcrPagesTableCompanion.insert(
                attachmentId: attachmentId,
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

typedef $$AttachmentOcrPagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentOcrPagesTableTable,
      AttachmentOcrPageEntity,
      $$AttachmentOcrPagesTableTableFilterComposer,
      $$AttachmentOcrPagesTableTableOrderingComposer,
      $$AttachmentOcrPagesTableTableAnnotationComposer,
      $$AttachmentOcrPagesTableTableCreateCompanionBuilder,
      $$AttachmentOcrPagesTableTableUpdateCompanionBuilder,
      (
        AttachmentOcrPageEntity,
        BaseReferences<
          _$AppDatabase,
          $AttachmentOcrPagesTableTable,
          AttachmentOcrPageEntity
        >,
      ),
      AttachmentOcrPageEntity,
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
      Value<int?> baseRevision,
      Value<int?> localParentRevision,
      Value<int?> remoteParentRevision,
      Value<String?> mergeType,
      Value<String?> resolutionSummary,
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
      Value<int?> baseRevision,
      Value<int?> localParentRevision,
      Value<int?> remoteParentRevision,
      Value<String?> mergeType,
      Value<String?> resolutionSummary,
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

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localParentRevision => $composableBuilder(
    column: $table.localParentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteParentRevision => $composableBuilder(
    column: $table.remoteParentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mergeType => $composableBuilder(
    column: $table.mergeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionSummary => $composableBuilder(
    column: $table.resolutionSummary,
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

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localParentRevision => $composableBuilder(
    column: $table.localParentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteParentRevision => $composableBuilder(
    column: $table.remoteParentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mergeType => $composableBuilder(
    column: $table.mergeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionSummary => $composableBuilder(
    column: $table.resolutionSummary,
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

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localParentRevision => $composableBuilder(
    column: $table.localParentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteParentRevision => $composableBuilder(
    column: $table.remoteParentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mergeType =>
      $composableBuilder(column: $table.mergeType, builder: (column) => column);

  GeneratedColumn<String> get resolutionSummary => $composableBuilder(
    column: $table.resolutionSummary,
    builder: (column) => column,
  );

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
                Value<int?> baseRevision = const Value.absent(),
                Value<int?> localParentRevision = const Value.absent(),
                Value<int?> remoteParentRevision = const Value.absent(),
                Value<String?> mergeType = const Value.absent(),
                Value<String?> resolutionSummary = const Value.absent(),
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
                baseRevision: baseRevision,
                localParentRevision: localParentRevision,
                remoteParentRevision: remoteParentRevision,
                mergeType: mergeType,
                resolutionSummary: resolutionSummary,
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
                Value<int?> baseRevision = const Value.absent(),
                Value<int?> localParentRevision = const Value.absent(),
                Value<int?> remoteParentRevision = const Value.absent(),
                Value<String?> mergeType = const Value.absent(),
                Value<String?> resolutionSummary = const Value.absent(),
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
                baseRevision: baseRevision,
                localParentRevision: localParentRevision,
                remoteParentRevision: remoteParentRevision,
                mergeType: mergeType,
                resolutionSummary: resolutionSummary,
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
typedef $$SyncConflictsTableTableCreateCompanionBuilder =
    SyncConflictsTableCompanion Function({
      required String id,
      required String noteId,
      Value<int> baseRevision,
      Value<int> localRevision,
      Value<int> remoteRevision,
      Value<String> conflictType,
      Value<String> state,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
      Value<int?> resolutionRevision,
      Value<String?> resolutionType,
      Value<String> dataJson,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableTableUpdateCompanionBuilder =
    SyncConflictsTableCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<int> baseRevision,
      Value<int> localRevision,
      Value<int> remoteRevision,
      Value<String> conflictType,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int?> resolutionRevision,
      Value<String?> resolutionType,
      Value<String> dataJson,
      Value<int> rowid,
    });

final class $$SyncConflictsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SyncConflictsTableTable,
          SyncConflictEntity
        > {
  $$SyncConflictsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _noteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('sync_conflicts__note_id__notes__id');

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

class $$SyncConflictsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTableTable> {
  $$SyncConflictsTableTableFilterComposer({
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

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictType => $composableBuilder(
    column: $table.conflictType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolutionRevision => $composableBuilder(
    column: $table.resolutionRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionType => $composableBuilder(
    column: $table.resolutionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
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

class $$SyncConflictsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTableTable> {
  $$SyncConflictsTableTableOrderingComposer({
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

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictType => $composableBuilder(
    column: $table.conflictType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolutionRevision => $composableBuilder(
    column: $table.resolutionRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionType => $composableBuilder(
    column: $table.resolutionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
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

class $$SyncConflictsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTableTable> {
  $$SyncConflictsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictType => $composableBuilder(
    column: $table.conflictType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolutionRevision => $composableBuilder(
    column: $table.resolutionRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionType => $composableBuilder(
    column: $table.resolutionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

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

class $$SyncConflictsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTableTable,
          SyncConflictEntity,
          $$SyncConflictsTableTableFilterComposer,
          $$SyncConflictsTableTableOrderingComposer,
          $$SyncConflictsTableTableAnnotationComposer,
          $$SyncConflictsTableTableCreateCompanionBuilder,
          $$SyncConflictsTableTableUpdateCompanionBuilder,
          (SyncConflictEntity, $$SyncConflictsTableTableReferences),
          SyncConflictEntity,
          PrefetchHooks Function({bool noteId})
        > {
  $$SyncConflictsTableTableTableManager(
    _$AppDatabase db,
    $SyncConflictsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> remoteRevision = const Value.absent(),
                Value<String> conflictType = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int?> resolutionRevision = const Value.absent(),
                Value<String?> resolutionType = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsTableCompanion(
                id: id,
                noteId: noteId,
                baseRevision: baseRevision,
                localRevision: localRevision,
                remoteRevision: remoteRevision,
                conflictType: conflictType,
                state: state,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                resolutionRevision: resolutionRevision,
                resolutionType: resolutionType,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                Value<int> baseRevision = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int> remoteRevision = const Value.absent(),
                Value<String> conflictType = const Value.absent(),
                Value<String> state = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int?> resolutionRevision = const Value.absent(),
                Value<String?> resolutionType = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsTableCompanion.insert(
                id: id,
                noteId: noteId,
                baseRevision: baseRevision,
                localRevision: localRevision,
                remoteRevision: remoteRevision,
                conflictType: conflictType,
                state: state,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                resolutionRevision: resolutionRevision,
                resolutionType: resolutionType,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SyncConflictsTableTableReferences(db, table, e),
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
                                    $$SyncConflictsTableTableReferences
                                        ._noteIdTable(db),
                                referencedColumn:
                                    $$SyncConflictsTableTableReferences
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

typedef $$SyncConflictsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTableTable,
      SyncConflictEntity,
      $$SyncConflictsTableTableFilterComposer,
      $$SyncConflictsTableTableOrderingComposer,
      $$SyncConflictsTableTableAnnotationComposer,
      $$SyncConflictsTableTableCreateCompanionBuilder,
      $$SyncConflictsTableTableUpdateCompanionBuilder,
      (SyncConflictEntity, $$SyncConflictsTableTableReferences),
      SyncConflictEntity,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$NoteLinksTableTableCreateCompanionBuilder =
    NoteLinksTableCompanion Function({
      required String id,
      required String sourceNoteId,
      required String targetNoteId,
      required String displayText,
      required int sourceOffset,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$NoteLinksTableTableUpdateCompanionBuilder =
    NoteLinksTableCompanion Function({
      Value<String> id,
      Value<String> sourceNoteId,
      Value<String> targetNoteId,
      Value<String> displayText,
      Value<int> sourceOffset,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NoteLinksTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $NoteLinksTableTable, NoteLinkEntity> {
  $$NoteLinksTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _sourceNoteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('note_links__source_note_id__notes__id');

  $$NotesTableTableProcessedTableManager get sourceNoteId {
    final $_column = $_itemColumn<String>('source_note_id')!;

    final manager = $$NotesTableTableTableManager(
      $_db,
      $_db.notesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceNoteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteLinksTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteLinksTableTable> {
  $$NoteLinksTableTableFilterComposer({
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

  ColumnFilters<String> get targetNoteId => $composableBuilder(
    column: $table.targetNoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayText => $composableBuilder(
    column: $table.displayText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceOffset => $composableBuilder(
    column: $table.sourceOffset,
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

  $$NotesTableTableFilterComposer get sourceNoteId {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceNoteId,
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

class $$NoteLinksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteLinksTableTable> {
  $$NoteLinksTableTableOrderingComposer({
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

  ColumnOrderings<String> get targetNoteId => $composableBuilder(
    column: $table.targetNoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayText => $composableBuilder(
    column: $table.displayText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceOffset => $composableBuilder(
    column: $table.sourceOffset,
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

  $$NotesTableTableOrderingComposer get sourceNoteId {
    final $$NotesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceNoteId,
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

class $$NoteLinksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteLinksTableTable> {
  $$NoteLinksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetNoteId => $composableBuilder(
    column: $table.targetNoteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayText => $composableBuilder(
    column: $table.displayText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceOffset => $composableBuilder(
    column: $table.sourceOffset,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NotesTableTableAnnotationComposer get sourceNoteId {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceNoteId,
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

class $$NoteLinksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteLinksTableTable,
          NoteLinkEntity,
          $$NoteLinksTableTableFilterComposer,
          $$NoteLinksTableTableOrderingComposer,
          $$NoteLinksTableTableAnnotationComposer,
          $$NoteLinksTableTableCreateCompanionBuilder,
          $$NoteLinksTableTableUpdateCompanionBuilder,
          (NoteLinkEntity, $$NoteLinksTableTableReferences),
          NoteLinkEntity,
          PrefetchHooks Function({bool sourceNoteId})
        > {
  $$NoteLinksTableTableTableManager(
    _$AppDatabase db,
    $NoteLinksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteLinksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteLinksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteLinksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceNoteId = const Value.absent(),
                Value<String> targetNoteId = const Value.absent(),
                Value<String> displayText = const Value.absent(),
                Value<int> sourceOffset = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksTableCompanion(
                id: id,
                sourceNoteId: sourceNoteId,
                targetNoteId: targetNoteId,
                displayText: displayText,
                sourceOffset: sourceOffset,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceNoteId,
                required String targetNoteId,
                required String displayText,
                required int sourceOffset,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksTableCompanion.insert(
                id: id,
                sourceNoteId: sourceNoteId,
                targetNoteId: targetNoteId,
                displayText: displayText,
                sourceOffset: sourceOffset,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteLinksTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceNoteId = false}) {
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
                    if (sourceNoteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceNoteId,
                                referencedTable: $$NoteLinksTableTableReferences
                                    ._sourceNoteIdTable(db),
                                referencedColumn:
                                    $$NoteLinksTableTableReferences
                                        ._sourceNoteIdTable(db)
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

typedef $$NoteLinksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteLinksTableTable,
      NoteLinkEntity,
      $$NoteLinksTableTableFilterComposer,
      $$NoteLinksTableTableOrderingComposer,
      $$NoteLinksTableTableAnnotationComposer,
      $$NoteLinksTableTableCreateCompanionBuilder,
      $$NoteLinksTableTableUpdateCompanionBuilder,
      (NoteLinkEntity, $$NoteLinksTableTableReferences),
      NoteLinkEntity,
      PrefetchHooks Function({bool sourceNoteId})
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
  $$AttachmentOcrPagesTableTableTableManager get attachmentOcrPagesTable =>
      $$AttachmentOcrPagesTableTableTableManager(
        _db,
        _db.attachmentOcrPagesTable,
      );
  $$NoteVersionsTableTableTableManager get noteVersionsTable =>
      $$NoteVersionsTableTableTableManager(_db, _db.noteVersionsTable);
  $$DocumentsTableTableTableManager get documentsTable =>
      $$DocumentsTableTableTableManager(_db, _db.documentsTable);
  $$DocumentOcrPagesTableTableTableManager get documentOcrPagesTable =>
      $$DocumentOcrPagesTableTableTableManager(_db, _db.documentOcrPagesTable);
  $$SyncConflictsTableTableTableManager get syncConflictsTable =>
      $$SyncConflictsTableTableTableManager(_db, _db.syncConflictsTable);
  $$NoteLinksTableTableTableManager get noteLinksTable =>
      $$NoteLinksTableTableTableManager(_db, _db.noteLinksTable);
}
