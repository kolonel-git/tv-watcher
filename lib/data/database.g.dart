// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, path];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolder extends DataClass implements Insertable<LibraryFolder> {
  final int id;
  final String path;
  const LibraryFolder({required this.id, required this.path});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(id: Value(id), path: Value(path));
  }

  factory LibraryFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolder(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
    };
  }

  LibraryFolder copyWith({int? id, String? path}) =>
      LibraryFolder(id: id ?? this.id, path: path ?? this.path);
  LibraryFolder copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolder(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFolder(')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFolder &&
          other.id == this.id &&
          other.path == this.path);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolder> {
  final Value<int> id;
  final Value<String> path;
  const LibraryFoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
  }) : path = Value(path);
  static Insertable<LibraryFolder> custom({
    Expression<int>? id,
    Expression<String>? path,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    });
  }

  LibraryFoldersCompanion copyWith({Value<int>? id, Value<String>? path}) {
    return LibraryFoldersCompanion(id: id ?? this.id, path: path ?? this.path);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }
}

class $ShowsTable extends Shows with TableInfo<$ShowsTable, Show> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbNameMeta = const VerificationMeta(
    'tmdbName',
  );
  @override
  late final GeneratedColumn<String> tmdbName = GeneratedColumn<String>(
    'tmdb_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overviewMeta = const VerificationMeta(
    'overview',
  );
  @override
  late final GeneratedColumn<String> overview = GeneratedColumn<String>(
    'overview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterFileMeta = const VerificationMeta(
    'posterFile',
  );
  @override
  late final GeneratedColumn<String> posterFile = GeneratedColumn<String>(
    'poster_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropFileMeta = const VerificationMeta(
    'backdropFile',
  );
  @override
  late final GeneratedColumn<String> backdropFile = GeneratedColumn<String>(
    'backdrop_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaStatusMeta = const VerificationMeta(
    'metaStatus',
  );
  @override
  late final GeneratedColumn<String> metaStatus = GeneratedColumn<String>(
    'meta_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _metaLockedMeta = const VerificationMeta(
    'metaLocked',
  );
  @override
  late final GeneratedColumn<bool> metaLocked = GeneratedColumn<bool>(
    'meta_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("meta_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    key,
    year,
    tmdbId,
    tmdbName,
    overview,
    posterFile,
    backdropFile,
    metaStatus,
    metaLocked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shows';
  @override
  VerificationContext validateIntegrity(
    Insertable<Show> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('tmdb_name')) {
      context.handle(
        _tmdbNameMeta,
        tmdbName.isAcceptableOrUnknown(data['tmdb_name']!, _tmdbNameMeta),
      );
    }
    if (data.containsKey('overview')) {
      context.handle(
        _overviewMeta,
        overview.isAcceptableOrUnknown(data['overview']!, _overviewMeta),
      );
    }
    if (data.containsKey('poster_file')) {
      context.handle(
        _posterFileMeta,
        posterFile.isAcceptableOrUnknown(data['poster_file']!, _posterFileMeta),
      );
    }
    if (data.containsKey('backdrop_file')) {
      context.handle(
        _backdropFileMeta,
        backdropFile.isAcceptableOrUnknown(
          data['backdrop_file']!,
          _backdropFileMeta,
        ),
      );
    }
    if (data.containsKey('meta_status')) {
      context.handle(
        _metaStatusMeta,
        metaStatus.isAcceptableOrUnknown(data['meta_status']!, _metaStatusMeta),
      );
    }
    if (data.containsKey('meta_locked')) {
      context.handle(
        _metaLockedMeta,
        metaLocked.isAcceptableOrUnknown(data['meta_locked']!, _metaLockedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Show map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Show(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
      tmdbName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tmdb_name'],
      ),
      overview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overview'],
      ),
      posterFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_file'],
      ),
      backdropFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_file'],
      ),
      metaStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_status'],
      )!,
      metaLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}meta_locked'],
      )!,
    );
  }

  @override
  $ShowsTable createAlias(String alias) {
    return $ShowsTable(attachedDatabase, alias);
  }
}

class Show extends DataClass implements Insertable<Show> {
  final int id;
  final String name;

  /// Normalised grouping key (lowercase alphanumerics).
  final String key;
  final int? year;
  final int? tmdbId;
  final String? tmdbName;
  final String? overview;

  /// Local cached artwork file paths.
  final String? posterFile;
  final String? backdropFile;

  /// none | matched | ambiguous | nomatch
  final String metaStatus;

  /// User picked the match by hand; never auto-rematched.
  final bool metaLocked;
  const Show({
    required this.id,
    required this.name,
    required this.key,
    this.year,
    this.tmdbId,
    this.tmdbName,
    this.overview,
    this.posterFile,
    this.backdropFile,
    required this.metaStatus,
    required this.metaLocked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    if (!nullToAbsent || tmdbName != null) {
      map['tmdb_name'] = Variable<String>(tmdbName);
    }
    if (!nullToAbsent || overview != null) {
      map['overview'] = Variable<String>(overview);
    }
    if (!nullToAbsent || posterFile != null) {
      map['poster_file'] = Variable<String>(posterFile);
    }
    if (!nullToAbsent || backdropFile != null) {
      map['backdrop_file'] = Variable<String>(backdropFile);
    }
    map['meta_status'] = Variable<String>(metaStatus);
    map['meta_locked'] = Variable<bool>(metaLocked);
    return map;
  }

  ShowsCompanion toCompanion(bool nullToAbsent) {
    return ShowsCompanion(
      id: Value(id),
      name: Value(name),
      key: Value(key),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      tmdbName: tmdbName == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbName),
      overview: overview == null && nullToAbsent
          ? const Value.absent()
          : Value(overview),
      posterFile: posterFile == null && nullToAbsent
          ? const Value.absent()
          : Value(posterFile),
      backdropFile: backdropFile == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropFile),
      metaStatus: Value(metaStatus),
      metaLocked: Value(metaLocked),
    );
  }

  factory Show.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Show(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      key: serializer.fromJson<String>(json['key']),
      year: serializer.fromJson<int?>(json['year']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
      tmdbName: serializer.fromJson<String?>(json['tmdbName']),
      overview: serializer.fromJson<String?>(json['overview']),
      posterFile: serializer.fromJson<String?>(json['posterFile']),
      backdropFile: serializer.fromJson<String?>(json['backdropFile']),
      metaStatus: serializer.fromJson<String>(json['metaStatus']),
      metaLocked: serializer.fromJson<bool>(json['metaLocked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'key': serializer.toJson<String>(key),
      'year': serializer.toJson<int?>(year),
      'tmdbId': serializer.toJson<int?>(tmdbId),
      'tmdbName': serializer.toJson<String?>(tmdbName),
      'overview': serializer.toJson<String?>(overview),
      'posterFile': serializer.toJson<String?>(posterFile),
      'backdropFile': serializer.toJson<String?>(backdropFile),
      'metaStatus': serializer.toJson<String>(metaStatus),
      'metaLocked': serializer.toJson<bool>(metaLocked),
    };
  }

  Show copyWith({
    int? id,
    String? name,
    String? key,
    Value<int?> year = const Value.absent(),
    Value<int?> tmdbId = const Value.absent(),
    Value<String?> tmdbName = const Value.absent(),
    Value<String?> overview = const Value.absent(),
    Value<String?> posterFile = const Value.absent(),
    Value<String?> backdropFile = const Value.absent(),
    String? metaStatus,
    bool? metaLocked,
  }) => Show(
    id: id ?? this.id,
    name: name ?? this.name,
    key: key ?? this.key,
    year: year.present ? year.value : this.year,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    tmdbName: tmdbName.present ? tmdbName.value : this.tmdbName,
    overview: overview.present ? overview.value : this.overview,
    posterFile: posterFile.present ? posterFile.value : this.posterFile,
    backdropFile: backdropFile.present ? backdropFile.value : this.backdropFile,
    metaStatus: metaStatus ?? this.metaStatus,
    metaLocked: metaLocked ?? this.metaLocked,
  );
  Show copyWithCompanion(ShowsCompanion data) {
    return Show(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      key: data.key.present ? data.key.value : this.key,
      year: data.year.present ? data.year.value : this.year,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      tmdbName: data.tmdbName.present ? data.tmdbName.value : this.tmdbName,
      overview: data.overview.present ? data.overview.value : this.overview,
      posterFile: data.posterFile.present
          ? data.posterFile.value
          : this.posterFile,
      backdropFile: data.backdropFile.present
          ? data.backdropFile.value
          : this.backdropFile,
      metaStatus: data.metaStatus.present
          ? data.metaStatus.value
          : this.metaStatus,
      metaLocked: data.metaLocked.present
          ? data.metaLocked.value
          : this.metaLocked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Show(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('key: $key, ')
          ..write('year: $year, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('tmdbName: $tmdbName, ')
          ..write('overview: $overview, ')
          ..write('posterFile: $posterFile, ')
          ..write('backdropFile: $backdropFile, ')
          ..write('metaStatus: $metaStatus, ')
          ..write('metaLocked: $metaLocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    key,
    year,
    tmdbId,
    tmdbName,
    overview,
    posterFile,
    backdropFile,
    metaStatus,
    metaLocked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Show &&
          other.id == this.id &&
          other.name == this.name &&
          other.key == this.key &&
          other.year == this.year &&
          other.tmdbId == this.tmdbId &&
          other.tmdbName == this.tmdbName &&
          other.overview == this.overview &&
          other.posterFile == this.posterFile &&
          other.backdropFile == this.backdropFile &&
          other.metaStatus == this.metaStatus &&
          other.metaLocked == this.metaLocked);
}

class ShowsCompanion extends UpdateCompanion<Show> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> key;
  final Value<int?> year;
  final Value<int?> tmdbId;
  final Value<String?> tmdbName;
  final Value<String?> overview;
  final Value<String?> posterFile;
  final Value<String?> backdropFile;
  final Value<String> metaStatus;
  final Value<bool> metaLocked;
  const ShowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.key = const Value.absent(),
    this.year = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.tmdbName = const Value.absent(),
    this.overview = const Value.absent(),
    this.posterFile = const Value.absent(),
    this.backdropFile = const Value.absent(),
    this.metaStatus = const Value.absent(),
    this.metaLocked = const Value.absent(),
  });
  ShowsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String key,
    this.year = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.tmdbName = const Value.absent(),
    this.overview = const Value.absent(),
    this.posterFile = const Value.absent(),
    this.backdropFile = const Value.absent(),
    this.metaStatus = const Value.absent(),
    this.metaLocked = const Value.absent(),
  }) : name = Value(name),
       key = Value(key);
  static Insertable<Show> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? key,
    Expression<int>? year,
    Expression<int>? tmdbId,
    Expression<String>? tmdbName,
    Expression<String>? overview,
    Expression<String>? posterFile,
    Expression<String>? backdropFile,
    Expression<String>? metaStatus,
    Expression<bool>? metaLocked,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (key != null) 'key': key,
      if (year != null) 'year': year,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (tmdbName != null) 'tmdb_name': tmdbName,
      if (overview != null) 'overview': overview,
      if (posterFile != null) 'poster_file': posterFile,
      if (backdropFile != null) 'backdrop_file': backdropFile,
      if (metaStatus != null) 'meta_status': metaStatus,
      if (metaLocked != null) 'meta_locked': metaLocked,
    });
  }

  ShowsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? key,
    Value<int?>? year,
    Value<int?>? tmdbId,
    Value<String?>? tmdbName,
    Value<String?>? overview,
    Value<String?>? posterFile,
    Value<String?>? backdropFile,
    Value<String>? metaStatus,
    Value<bool>? metaLocked,
  }) {
    return ShowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      year: year ?? this.year,
      tmdbId: tmdbId ?? this.tmdbId,
      tmdbName: tmdbName ?? this.tmdbName,
      overview: overview ?? this.overview,
      posterFile: posterFile ?? this.posterFile,
      backdropFile: backdropFile ?? this.backdropFile,
      metaStatus: metaStatus ?? this.metaStatus,
      metaLocked: metaLocked ?? this.metaLocked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (tmdbName.present) {
      map['tmdb_name'] = Variable<String>(tmdbName.value);
    }
    if (overview.present) {
      map['overview'] = Variable<String>(overview.value);
    }
    if (posterFile.present) {
      map['poster_file'] = Variable<String>(posterFile.value);
    }
    if (backdropFile.present) {
      map['backdrop_file'] = Variable<String>(backdropFile.value);
    }
    if (metaStatus.present) {
      map['meta_status'] = Variable<String>(metaStatus.value);
    }
    if (metaLocked.present) {
      map['meta_locked'] = Variable<bool>(metaLocked.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('key: $key, ')
          ..write('year: $year, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('tmdbName: $tmdbName, ')
          ..write('overview: $overview, ')
          ..write('posterFile: $posterFile, ')
          ..write('backdropFile: $backdropFile, ')
          ..write('metaStatus: $metaStatus, ')
          ..write('metaLocked: $metaLocked')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_folders (id)',
    ),
  );
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<int> showId = GeneratedColumn<int>(
    'show_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shows (id)',
    ),
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endEpisodeMeta = const VerificationMeta(
    'endEpisode',
  );
  @override
  late final GeneratedColumn<int> endEpisode = GeneratedColumn<int>(
    'end_episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbTitleMeta = const VerificationMeta(
    'tmdbTitle',
  );
  @override
  late final GeneratedColumn<String> tmdbTitle = GeneratedColumn<String>(
    'tmdb_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overviewMeta = const VerificationMeta(
    'overview',
  );
  @override
  late final GeneratedColumn<String> overview = GeneratedColumn<String>(
    'overview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<int> runtime = GeneratedColumn<int>(
    'runtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<String> airDate = GeneratedColumn<String>(
    'air_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stillFileMeta = const VerificationMeta(
    'stillFile',
  );
  @override
  late final GeneratedColumn<String> stillFile = GeneratedColumn<String>(
    'still_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _manualMeta = const VerificationMeta('manual');
  @override
  late final GeneratedColumn<bool> manual = GeneratedColumn<bool>(
    'manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filePath,
    folderId,
    showId,
    season,
    episode,
    endEpisode,
    title,
    tmdbTitle,
    overview,
    runtime,
    airDate,
    stillFile,
    missing,
    manual,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Episode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('show_id')) {
      context.handle(
        _showIdMeta,
        showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('end_episode')) {
      context.handle(
        _endEpisodeMeta,
        endEpisode.isAcceptableOrUnknown(data['end_episode']!, _endEpisodeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('tmdb_title')) {
      context.handle(
        _tmdbTitleMeta,
        tmdbTitle.isAcceptableOrUnknown(data['tmdb_title']!, _tmdbTitleMeta),
      );
    }
    if (data.containsKey('overview')) {
      context.handle(
        _overviewMeta,
        overview.isAcceptableOrUnknown(data['overview']!, _overviewMeta),
      );
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    }
    if (data.containsKey('air_date')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['air_date']!, _airDateMeta),
      );
    }
    if (data.containsKey('still_file')) {
      context.handle(
        _stillFileMeta,
        stillFile.isAcceptableOrUnknown(data['still_file']!, _stillFileMeta),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    if (data.containsKey('manual')) {
      context.handle(
        _manualMeta,
        manual.isAcceptableOrUnknown(data['manual']!, _manualMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      )!,
      showId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}show_id'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      ),
      endEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_episode'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      tmdbTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tmdb_title'],
      ),
      overview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overview'],
      ),
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}runtime'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}air_date'],
      ),
      stillFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}still_file'],
      ),
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
      manual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final int id;
  final String filePath;
  final int folderId;
  final int? showId;
  final int? season;
  final int? episode;
  final int? endEpisode;
  final String? title;
  final String? tmdbTitle;
  final String? overview;
  final int? runtime;
  final String? airDate;
  final String? stillFile;

  /// File no longer found on disk at last scan. Row kept to preserve data.
  final bool missing;

  /// User assigned show/season/episode by hand; rescans never overwrite it.
  final bool manual;
  final DateTime addedAt;
  const Episode({
    required this.id,
    required this.filePath,
    required this.folderId,
    this.showId,
    this.season,
    this.episode,
    this.endEpisode,
    this.title,
    this.tmdbTitle,
    this.overview,
    this.runtime,
    this.airDate,
    this.stillFile,
    required this.missing,
    required this.manual,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['folder_id'] = Variable<int>(folderId);
    if (!nullToAbsent || showId != null) {
      map['show_id'] = Variable<int>(showId);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<int>(episode);
    }
    if (!nullToAbsent || endEpisode != null) {
      map['end_episode'] = Variable<int>(endEpisode);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || tmdbTitle != null) {
      map['tmdb_title'] = Variable<String>(tmdbTitle);
    }
    if (!nullToAbsent || overview != null) {
      map['overview'] = Variable<String>(overview);
    }
    if (!nullToAbsent || runtime != null) {
      map['runtime'] = Variable<int>(runtime);
    }
    if (!nullToAbsent || airDate != null) {
      map['air_date'] = Variable<String>(airDate);
    }
    if (!nullToAbsent || stillFile != null) {
      map['still_file'] = Variable<String>(stillFile);
    }
    map['missing'] = Variable<bool>(missing);
    map['manual'] = Variable<bool>(manual);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      filePath: Value(filePath),
      folderId: Value(folderId),
      showId: showId == null && nullToAbsent
          ? const Value.absent()
          : Value(showId),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      endEpisode: endEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(endEpisode),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      tmdbTitle: tmdbTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbTitle),
      overview: overview == null && nullToAbsent
          ? const Value.absent()
          : Value(overview),
      runtime: runtime == null && nullToAbsent
          ? const Value.absent()
          : Value(runtime),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      stillFile: stillFile == null && nullToAbsent
          ? const Value.absent()
          : Value(stillFile),
      missing: Value(missing),
      manual: Value(manual),
      addedAt: Value(addedAt),
    );
  }

  factory Episode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      folderId: serializer.fromJson<int>(json['folderId']),
      showId: serializer.fromJson<int?>(json['showId']),
      season: serializer.fromJson<int?>(json['season']),
      episode: serializer.fromJson<int?>(json['episode']),
      endEpisode: serializer.fromJson<int?>(json['endEpisode']),
      title: serializer.fromJson<String?>(json['title']),
      tmdbTitle: serializer.fromJson<String?>(json['tmdbTitle']),
      overview: serializer.fromJson<String?>(json['overview']),
      runtime: serializer.fromJson<int?>(json['runtime']),
      airDate: serializer.fromJson<String?>(json['airDate']),
      stillFile: serializer.fromJson<String?>(json['stillFile']),
      missing: serializer.fromJson<bool>(json['missing']),
      manual: serializer.fromJson<bool>(json['manual']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'folderId': serializer.toJson<int>(folderId),
      'showId': serializer.toJson<int?>(showId),
      'season': serializer.toJson<int?>(season),
      'episode': serializer.toJson<int?>(episode),
      'endEpisode': serializer.toJson<int?>(endEpisode),
      'title': serializer.toJson<String?>(title),
      'tmdbTitle': serializer.toJson<String?>(tmdbTitle),
      'overview': serializer.toJson<String?>(overview),
      'runtime': serializer.toJson<int?>(runtime),
      'airDate': serializer.toJson<String?>(airDate),
      'stillFile': serializer.toJson<String?>(stillFile),
      'missing': serializer.toJson<bool>(missing),
      'manual': serializer.toJson<bool>(manual),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Episode copyWith({
    int? id,
    String? filePath,
    int? folderId,
    Value<int?> showId = const Value.absent(),
    Value<int?> season = const Value.absent(),
    Value<int?> episode = const Value.absent(),
    Value<int?> endEpisode = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> tmdbTitle = const Value.absent(),
    Value<String?> overview = const Value.absent(),
    Value<int?> runtime = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
    Value<String?> stillFile = const Value.absent(),
    bool? missing,
    bool? manual,
    DateTime? addedAt,
  }) => Episode(
    id: id ?? this.id,
    filePath: filePath ?? this.filePath,
    folderId: folderId ?? this.folderId,
    showId: showId.present ? showId.value : this.showId,
    season: season.present ? season.value : this.season,
    episode: episode.present ? episode.value : this.episode,
    endEpisode: endEpisode.present ? endEpisode.value : this.endEpisode,
    title: title.present ? title.value : this.title,
    tmdbTitle: tmdbTitle.present ? tmdbTitle.value : this.tmdbTitle,
    overview: overview.present ? overview.value : this.overview,
    runtime: runtime.present ? runtime.value : this.runtime,
    airDate: airDate.present ? airDate.value : this.airDate,
    stillFile: stillFile.present ? stillFile.value : this.stillFile,
    missing: missing ?? this.missing,
    manual: manual ?? this.manual,
    addedAt: addedAt ?? this.addedAt,
  );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      showId: data.showId.present ? data.showId.value : this.showId,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      endEpisode: data.endEpisode.present
          ? data.endEpisode.value
          : this.endEpisode,
      title: data.title.present ? data.title.value : this.title,
      tmdbTitle: data.tmdbTitle.present ? data.tmdbTitle.value : this.tmdbTitle,
      overview: data.overview.present ? data.overview.value : this.overview,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      stillFile: data.stillFile.present ? data.stillFile.value : this.stillFile,
      missing: data.missing.present ? data.missing.value : this.missing,
      manual: data.manual.present ? data.manual.value : this.manual,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('folderId: $folderId, ')
          ..write('showId: $showId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('endEpisode: $endEpisode, ')
          ..write('title: $title, ')
          ..write('tmdbTitle: $tmdbTitle, ')
          ..write('overview: $overview, ')
          ..write('runtime: $runtime, ')
          ..write('airDate: $airDate, ')
          ..write('stillFile: $stillFile, ')
          ..write('missing: $missing, ')
          ..write('manual: $manual, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filePath,
    folderId,
    showId,
    season,
    episode,
    endEpisode,
    title,
    tmdbTitle,
    overview,
    runtime,
    airDate,
    stillFile,
    missing,
    manual,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.folderId == this.folderId &&
          other.showId == this.showId &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.endEpisode == this.endEpisode &&
          other.title == this.title &&
          other.tmdbTitle == this.tmdbTitle &&
          other.overview == this.overview &&
          other.runtime == this.runtime &&
          other.airDate == this.airDate &&
          other.stillFile == this.stillFile &&
          other.missing == this.missing &&
          other.manual == this.manual &&
          other.addedAt == this.addedAt);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<int> folderId;
  final Value<int?> showId;
  final Value<int?> season;
  final Value<int?> episode;
  final Value<int?> endEpisode;
  final Value<String?> title;
  final Value<String?> tmdbTitle;
  final Value<String?> overview;
  final Value<int?> runtime;
  final Value<String?> airDate;
  final Value<String?> stillFile;
  final Value<bool> missing;
  final Value<bool> manual;
  final Value<DateTime> addedAt;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.folderId = const Value.absent(),
    this.showId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.endEpisode = const Value.absent(),
    this.title = const Value.absent(),
    this.tmdbTitle = const Value.absent(),
    this.overview = const Value.absent(),
    this.runtime = const Value.absent(),
    this.airDate = const Value.absent(),
    this.stillFile = const Value.absent(),
    this.missing = const Value.absent(),
    this.manual = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required int folderId,
    this.showId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.endEpisode = const Value.absent(),
    this.title = const Value.absent(),
    this.tmdbTitle = const Value.absent(),
    this.overview = const Value.absent(),
    this.runtime = const Value.absent(),
    this.airDate = const Value.absent(),
    this.stillFile = const Value.absent(),
    this.missing = const Value.absent(),
    this.manual = const Value.absent(),
    this.addedAt = const Value.absent(),
  }) : filePath = Value(filePath),
       folderId = Value(folderId);
  static Insertable<Episode> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<int>? folderId,
    Expression<int>? showId,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<int>? endEpisode,
    Expression<String>? title,
    Expression<String>? tmdbTitle,
    Expression<String>? overview,
    Expression<int>? runtime,
    Expression<String>? airDate,
    Expression<String>? stillFile,
    Expression<bool>? missing,
    Expression<bool>? manual,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (folderId != null) 'folder_id': folderId,
      if (showId != null) 'show_id': showId,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (endEpisode != null) 'end_episode': endEpisode,
      if (title != null) 'title': title,
      if (tmdbTitle != null) 'tmdb_title': tmdbTitle,
      if (overview != null) 'overview': overview,
      if (runtime != null) 'runtime': runtime,
      if (airDate != null) 'air_date': airDate,
      if (stillFile != null) 'still_file': stillFile,
      if (missing != null) 'missing': missing,
      if (manual != null) 'manual': manual,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<String>? filePath,
    Value<int>? folderId,
    Value<int?>? showId,
    Value<int?>? season,
    Value<int?>? episode,
    Value<int?>? endEpisode,
    Value<String?>? title,
    Value<String?>? tmdbTitle,
    Value<String?>? overview,
    Value<int?>? runtime,
    Value<String?>? airDate,
    Value<String?>? stillFile,
    Value<bool>? missing,
    Value<bool>? manual,
    Value<DateTime>? addedAt,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      showId: showId ?? this.showId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      endEpisode: endEpisode ?? this.endEpisode,
      title: title ?? this.title,
      tmdbTitle: tmdbTitle ?? this.tmdbTitle,
      overview: overview ?? this.overview,
      runtime: runtime ?? this.runtime,
      airDate: airDate ?? this.airDate,
      stillFile: stillFile ?? this.stillFile,
      missing: missing ?? this.missing,
      manual: manual ?? this.manual,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (showId.present) {
      map['show_id'] = Variable<int>(showId.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (endEpisode.present) {
      map['end_episode'] = Variable<int>(endEpisode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (tmdbTitle.present) {
      map['tmdb_title'] = Variable<String>(tmdbTitle.value);
    }
    if (overview.present) {
      map['overview'] = Variable<String>(overview.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<int>(runtime.value);
    }
    if (airDate.present) {
      map['air_date'] = Variable<String>(airDate.value);
    }
    if (stillFile.present) {
      map['still_file'] = Variable<String>(stillFile.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (manual.present) {
      map['manual'] = Variable<bool>(manual.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('folderId: $folderId, ')
          ..write('showId: $showId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('endEpisode: $endEpisode, ')
          ..write('title: $title, ')
          ..write('tmdbTitle: $tmdbTitle, ')
          ..write('overview: $overview, ')
          ..write('runtime: $runtime, ')
          ..write('airDate: $airDate, ')
          ..write('stillFile: $stillFile, ')
          ..write('missing: $missing, ')
          ..write('manual: $manual, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $ShowsTable shows = $ShowsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryFolders,
    shows,
    episodes,
  ];
}

typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({Value<int> id, required String path});
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({Value<int> id, Value<String> path});

final class $$LibraryFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $LibraryFoldersTable, LibraryFolder> {
  $$LibraryFoldersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$EpisodesTable, List<Episode>> _episodesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: 'library_folders__id__episodes__folder_id',
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryFoldersTable,
          LibraryFolder,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (LibraryFolder, $$LibraryFoldersTableReferences),
          LibraryFolder,
          PrefetchHooks Function({bool episodesRefs})
        > {
  $$LibraryFoldersTableTableManager(
    _$AppDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> path = const Value.absent(),
          }) => LibraryFoldersCompanion(id: id, path: path),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String path,
          }) => LibraryFoldersCompanion.insert(id: id, path: path),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryFoldersTable, LibraryFolder>(table),
                  $$LibraryFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (episodesRefs) db.episodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (episodesRefs)
                    await $_getPrefetchedDataByColumns<
                      LibraryFolder,
                      $LibraryFoldersTable,
                      Episode,
                      $EpisodesTable
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryFoldersTableReferences
                          ._episodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).episodesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'folder_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryFoldersTable,
      LibraryFolder,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (LibraryFolder, $$LibraryFoldersTableReferences),
      LibraryFolder,
      PrefetchHooks Function({bool episodesRefs})
    >;
typedef $$ShowsTableCreateCompanionBuilder = ShowsCompanion Function({
  Value<int> id,
  required String name,
  required String key,
  Value<int?> year,
  Value<int?> tmdbId,
  Value<String?> tmdbName,
  Value<String?> overview,
  Value<String?> posterFile,
  Value<String?> backdropFile,
  Value<String> metaStatus,
  Value<bool> metaLocked,
});
typedef $$ShowsTableUpdateCompanionBuilder = ShowsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> key,
  Value<int?> year,
  Value<int?> tmdbId,
  Value<String?> tmdbName,
  Value<String?> overview,
  Value<String?> posterFile,
  Value<String?> backdropFile,
  Value<String> metaStatus,
  Value<bool> metaLocked,
});

final class $$ShowsTableReferences
    extends BaseReferences<_$AppDatabase, $ShowsTable, Show> {
  $$ShowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<Episode>> _episodesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: 'shows__id__episodes__show_id',
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.showId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShowsTableFilterComposer extends Composer<_$AppDatabase, $ShowsTable> {
  $$ShowsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tmdbName => $composableBuilder(
    column: $table.tmdbName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterFile => $composableBuilder(
    column: $table.posterFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropFile => $composableBuilder(
    column: $table.backdropFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaStatus => $composableBuilder(
    column: $table.metaStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get metaLocked => $composableBuilder(
    column: $table.metaLocked,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShowsTable> {
  $$ShowsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tmdbName => $composableBuilder(
    column: $table.tmdbName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterFile => $composableBuilder(
    column: $table.posterFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropFile => $composableBuilder(
    column: $table.backdropFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaStatus => $composableBuilder(
    column: $table.metaStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get metaLocked => $composableBuilder(
    column: $table.metaLocked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShowsTable> {
  $$ShowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<String> get tmdbName =>
      $composableBuilder(column: $table.tmdbName, builder: (column) => column);

  GeneratedColumn<String> get overview =>
      $composableBuilder(column: $table.overview, builder: (column) => column);

  GeneratedColumn<String> get posterFile => $composableBuilder(
    column: $table.posterFile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backdropFile => $composableBuilder(
    column: $table.backdropFile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metaStatus => $composableBuilder(
    column: $table.metaStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get metaLocked => $composableBuilder(
    column: $table.metaLocked,
    builder: (column) => column,
  );

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShowsTable,
          Show,
          $$ShowsTableFilterComposer,
          $$ShowsTableOrderingComposer,
          $$ShowsTableAnnotationComposer,
          $$ShowsTableCreateCompanionBuilder,
          $$ShowsTableUpdateCompanionBuilder,
          (Show, $$ShowsTableReferences),
          Show,
          PrefetchHooks Function({bool episodesRefs})
        > {
  $$ShowsTableTableManager(_$AppDatabase db, $ShowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<String?> tmdbName = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<String?> posterFile = const Value.absent(),
                Value<String?> backdropFile = const Value.absent(),
                Value<String> metaStatus = const Value.absent(),
                Value<bool> metaLocked = const Value.absent(),
              }) => ShowsCompanion(
                id: id,
                name: name,
                key: key,
                year: year,
                tmdbId: tmdbId,
                tmdbName: tmdbName,
                overview: overview,
                posterFile: posterFile,
                backdropFile: backdropFile,
                metaStatus: metaStatus,
                metaLocked: metaLocked,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String key,
                Value<int?> year = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<String?> tmdbName = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<String?> posterFile = const Value.absent(),
                Value<String?> backdropFile = const Value.absent(),
                Value<String> metaStatus = const Value.absent(),
                Value<bool> metaLocked = const Value.absent(),
              }) => ShowsCompanion.insert(
                id: id,
                name: name,
                key: key,
                year: year,
                tmdbId: tmdbId,
                tmdbName: tmdbName,
                overview: overview,
                posterFile: posterFile,
                backdropFile: backdropFile,
                metaStatus: metaStatus,
                metaLocked: metaLocked,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShowsTable, Show>(table),
                  $$ShowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (episodesRefs) db.episodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (episodesRefs)
                    await $_getPrefetchedDataByColumns<
                      Show,
                      $ShowsTable,
                      Episode,
                      $EpisodesTable
                    >(
                      currentTable: table,
                      referencedTable: $$ShowsTableReferences
                          ._episodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ShowsTableReferences(db, table, p0).episodesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'show_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ShowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShowsTable,
      Show,
      $$ShowsTableFilterComposer,
      $$ShowsTableOrderingComposer,
      $$ShowsTableAnnotationComposer,
      $$ShowsTableCreateCompanionBuilder,
      $$ShowsTableUpdateCompanionBuilder,
      (Show, $$ShowsTableReferences),
      Show,
      PrefetchHooks Function({bool episodesRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  required String filePath,
  required int folderId,
  Value<int?> showId,
  Value<int?> season,
  Value<int?> episode,
  Value<int?> endEpisode,
  Value<String?> title,
  Value<String?> tmdbTitle,
  Value<String?> overview,
  Value<int?> runtime,
  Value<String?> airDate,
  Value<String?> stillFile,
  Value<bool> missing,
  Value<bool> manual,
  Value<DateTime> addedAt,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  Value<String> filePath,
  Value<int> folderId,
  Value<int?> showId,
  Value<int?> season,
  Value<int?> episode,
  Value<int?> endEpisode,
  Value<String?> title,
  Value<String?> tmdbTitle,
  Value<String?> overview,
  Value<int?> runtime,
  Value<String?> airDate,
  Value<String?> stillFile,
  Value<bool> missing,
  Value<bool> manual,
  Value<DateTime> addedAt,
});

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, Episode> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryFoldersTable _folderIdTable(_$AppDatabase db) =>
      db.libraryFolders.createAlias('episodes__folder_id__library_folders__id');

  $$LibraryFoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<int>('folder_id')!;

    final manager = $$LibraryFoldersTableTableManager(
      $_db,
      $_db.libraryFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ShowsTable _showIdTable(_$AppDatabase db) =>
      db.shows.createAlias('episodes__show_id__shows__id');

  $$ShowsTableProcessedTableManager? get showId {
    final $_column = $_itemColumn<int>('show_id');
    if ($_column == null) return null;
    final manager = $$ShowsTableTableManager(
      $_db,
      $_db.shows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_showIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
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

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endEpisode => $composableBuilder(
    column: $table.endEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tmdbTitle => $composableBuilder(
    column: $table.tmdbTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stillFile => $composableBuilder(
    column: $table.stillFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryFoldersTableFilterComposer get folderId {
    final $$LibraryFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableFilterComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ShowsTableFilterComposer get showId {
    final $$ShowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableFilterComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
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

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endEpisode => $composableBuilder(
    column: $table.endEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tmdbTitle => $composableBuilder(
    column: $table.tmdbTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stillFile => $composableBuilder(
    column: $table.stillFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryFoldersTableOrderingComposer get folderId {
    final $$LibraryFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ShowsTableOrderingComposer get showId {
    final $$ShowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableOrderingComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<int> get endEpisode => $composableBuilder(
    column: $table.endEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get tmdbTitle =>
      $composableBuilder(column: $table.tmdbTitle, builder: (column) => column);

  GeneratedColumn<String> get overview =>
      $composableBuilder(column: $table.overview, builder: (column) => column);

  GeneratedColumn<int> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<String> get stillFile =>
      $composableBuilder(column: $table.stillFile, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  GeneratedColumn<bool> get manual =>
      $composableBuilder(column: $table.manual, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$LibraryFoldersTableAnnotationComposer get folderId {
    final $$LibraryFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ShowsTableAnnotationComposer get showId {
    final $$ShowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableAnnotationComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          Episode,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (Episode, $$EpisodesTableReferences),
          Episode,
          PrefetchHooks Function({bool folderId, bool showId})
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> folderId = const Value.absent(),
                Value<int?> showId = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int?> endEpisode = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> tmdbTitle = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<int?> runtime = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<String?> stillFile = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                filePath: filePath,
                folderId: folderId,
                showId: showId,
                season: season,
                episode: episode,
                endEpisode: endEpisode,
                title: title,
                tmdbTitle: tmdbTitle,
                overview: overview,
                runtime: runtime,
                airDate: airDate,
                stillFile: stillFile,
                missing: missing,
                manual: manual,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String filePath,
                required int folderId,
                Value<int?> showId = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int?> endEpisode = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> tmdbTitle = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<int?> runtime = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<String?> stillFile = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                filePath: filePath,
                folderId: folderId,
                showId: showId,
                season: season,
                episode: episode,
                endEpisode: endEpisode,
                title: title,
                tmdbTitle: tmdbTitle,
                overview: overview,
                runtime: runtime,
                airDate: airDate,
                stillFile: stillFile,
                missing: missing,
                manual: manual,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodesTable, Episode>(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, showId = false}) {
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
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$EpisodesTableReferences
                            ._folderIdTable(db),
                        referencedColumn: $$EpisodesTableReferences
                            ._folderIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (showId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.showId,
                        referencedTable: $$EpisodesTableReferences._showIdTable(
                          db,
                        ),
                        referencedColumn: $$EpisodesTableReferences
                            ._showIdTable(db)
                            .id,
                      ) as T;
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

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      Episode,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (Episode, $$EpisodesTableReferences),
      Episode,
      PrefetchHooks Function({bool folderId, bool showId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$ShowsTableTableManager get shows =>
      $$ShowsTableTableManager(_db, _db.shows);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
}
