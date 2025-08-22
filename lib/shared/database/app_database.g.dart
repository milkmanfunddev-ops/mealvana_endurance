// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserProfilesTableTable extends UserProfilesTable
    with TableInfo<$UserProfilesTableTable, UserProfileEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _birthdayMeta =
      const VerificationMeta('birthday');
  @override
  late final GeneratedColumn<DateTime> birthday = GeneratedColumn<DateTime>(
      'birthday', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _heightFeetMeta =
      const VerificationMeta('heightFeet');
  @override
  late final GeneratedColumn<int> heightFeet = GeneratedColumn<int>(
      'height_feet', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _heightInchesMeta =
      const VerificationMeta('heightInches');
  @override
  late final GeneratedColumn<int> heightInches = GeneratedColumn<int>(
      'height_inches', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _weightPoundsMeta =
      const VerificationMeta('weightPounds');
  @override
  late final GeneratedColumn<double> weightPounds = GeneratedColumn<double>(
      'weight_pounds', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _runsWithWaterBottleMeta =
      const VerificationMeta('runsWithWaterBottle');
  @override
  late final GeneratedColumn<bool> runsWithWaterBottle = GeneratedColumn<bool>(
      'runs_with_water_bottle', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("runs_with_water_bottle" IN (0, 1))'));
  static const VerificationMeta _gutTrainingMeta =
      const VerificationMeta('gutTraining');
  @override
  late final GeneratedColumn<String> gutTraining = GeneratedColumn<String>(
      'gut_training', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
      'onboarding_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("onboarding_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _appVersionMeta =
      const VerificationMeta('appVersion');
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
      'app_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        gender,
        birthday,
        heightFeet,
        heightInches,
        weightPounds,
        runsWithWaterBottle,
        gutTraining,
        onboardingCompleted,
        createdAt,
        updatedAt,
        appVersion
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles_table';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfileEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    } else if (isInserting) {
      context.missing(_genderMeta);
    }
    if (data.containsKey('birthday')) {
      context.handle(_birthdayMeta,
          birthday.isAcceptableOrUnknown(data['birthday']!, _birthdayMeta));
    } else if (isInserting) {
      context.missing(_birthdayMeta);
    }
    if (data.containsKey('height_feet')) {
      context.handle(
          _heightFeetMeta,
          heightFeet.isAcceptableOrUnknown(
              data['height_feet']!, _heightFeetMeta));
    } else if (isInserting) {
      context.missing(_heightFeetMeta);
    }
    if (data.containsKey('height_inches')) {
      context.handle(
          _heightInchesMeta,
          heightInches.isAcceptableOrUnknown(
              data['height_inches']!, _heightInchesMeta));
    } else if (isInserting) {
      context.missing(_heightInchesMeta);
    }
    if (data.containsKey('weight_pounds')) {
      context.handle(
          _weightPoundsMeta,
          weightPounds.isAcceptableOrUnknown(
              data['weight_pounds']!, _weightPoundsMeta));
    } else if (isInserting) {
      context.missing(_weightPoundsMeta);
    }
    if (data.containsKey('runs_with_water_bottle')) {
      context.handle(
          _runsWithWaterBottleMeta,
          runsWithWaterBottle.isAcceptableOrUnknown(
              data['runs_with_water_bottle']!, _runsWithWaterBottleMeta));
    } else if (isInserting) {
      context.missing(_runsWithWaterBottleMeta);
    }
    if (data.containsKey('gut_training')) {
      context.handle(
          _gutTrainingMeta,
          gutTraining.isAcceptableOrUnknown(
              data['gut_training']!, _gutTrainingMeta));
    } else if (isInserting) {
      context.missing(_gutTrainingMeta);
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
          _onboardingCompletedMeta,
          onboardingCompleted.isAcceptableOrUnknown(
              data['onboarding_completed']!, _onboardingCompletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('app_version')) {
      context.handle(
          _appVersionMeta,
          appVersion.isAcceptableOrUnknown(
              data['app_version']!, _appVersionMeta));
    } else if (isInserting) {
      context.missing(_appVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender'])!,
      birthday: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}birthday'])!,
      heightFeet: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height_feet'])!,
      heightInches: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height_inches'])!,
      weightPounds: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight_pounds'])!,
      runsWithWaterBottle: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}runs_with_water_bottle'])!,
      gutTraining: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gut_training'])!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}onboarding_completed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      appVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_version'])!,
    );
  }

  @override
  $UserProfilesTableTable createAlias(String alias) {
    return $UserProfilesTableTable(attachedDatabase, alias);
  }
}

class UserProfileEntry extends DataClass
    implements Insertable<UserProfileEntry> {
  /// Primary key - device ID used as user identifier
  final String id;

  /// User's gender (stored as string enum)
  final String gender;

  /// User's birthday
  final DateTime birthday;

  /// Height in feet (integer part)
  final int heightFeet;

  /// Height in inches (remaining part)
  final int heightInches;

  /// Weight in pounds
  final double weightPounds;

  /// Whether user runs with a water bottle
  final bool runsWithWaterBottle;

  /// Gut training level (stored as string enum)
  final String gutTraining;

  /// Whether user has completed onboarding
  final bool onboardingCompleted;

  /// When the profile was created
  final DateTime createdAt;

  /// When the profile was last updated
  final DateTime updatedAt;

  /// App version when profile was created/updated
  final String appVersion;
  const UserProfileEntry(
      {required this.id,
      required this.gender,
      required this.birthday,
      required this.heightFeet,
      required this.heightInches,
      required this.weightPounds,
      required this.runsWithWaterBottle,
      required this.gutTraining,
      required this.onboardingCompleted,
      required this.createdAt,
      required this.updatedAt,
      required this.appVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['gender'] = Variable<String>(gender);
    map['birthday'] = Variable<DateTime>(birthday);
    map['height_feet'] = Variable<int>(heightFeet);
    map['height_inches'] = Variable<int>(heightInches);
    map['weight_pounds'] = Variable<double>(weightPounds);
    map['runs_with_water_bottle'] = Variable<bool>(runsWithWaterBottle);
    map['gut_training'] = Variable<String>(gutTraining);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['app_version'] = Variable<String>(appVersion);
    return map;
  }

  UserProfilesTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesTableCompanion(
      id: Value(id),
      gender: Value(gender),
      birthday: Value(birthday),
      heightFeet: Value(heightFeet),
      heightInches: Value(heightInches),
      weightPounds: Value(weightPounds),
      runsWithWaterBottle: Value(runsWithWaterBottle),
      gutTraining: Value(gutTraining),
      onboardingCompleted: Value(onboardingCompleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      appVersion: Value(appVersion),
    );
  }

  factory UserProfileEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileEntry(
      id: serializer.fromJson<String>(json['id']),
      gender: serializer.fromJson<String>(json['gender']),
      birthday: serializer.fromJson<DateTime>(json['birthday']),
      heightFeet: serializer.fromJson<int>(json['heightFeet']),
      heightInches: serializer.fromJson<int>(json['heightInches']),
      weightPounds: serializer.fromJson<double>(json['weightPounds']),
      runsWithWaterBottle:
          serializer.fromJson<bool>(json['runsWithWaterBottle']),
      gutTraining: serializer.fromJson<String>(json['gutTraining']),
      onboardingCompleted:
          serializer.fromJson<bool>(json['onboardingCompleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'gender': serializer.toJson<String>(gender),
      'birthday': serializer.toJson<DateTime>(birthday),
      'heightFeet': serializer.toJson<int>(heightFeet),
      'heightInches': serializer.toJson<int>(heightInches),
      'weightPounds': serializer.toJson<double>(weightPounds),
      'runsWithWaterBottle': serializer.toJson<bool>(runsWithWaterBottle),
      'gutTraining': serializer.toJson<String>(gutTraining),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'appVersion': serializer.toJson<String>(appVersion),
    };
  }

  UserProfileEntry copyWith(
          {String? id,
          String? gender,
          DateTime? birthday,
          int? heightFeet,
          int? heightInches,
          double? weightPounds,
          bool? runsWithWaterBottle,
          String? gutTraining,
          bool? onboardingCompleted,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? appVersion}) =>
      UserProfileEntry(
        id: id ?? this.id,
        gender: gender ?? this.gender,
        birthday: birthday ?? this.birthday,
        heightFeet: heightFeet ?? this.heightFeet,
        heightInches: heightInches ?? this.heightInches,
        weightPounds: weightPounds ?? this.weightPounds,
        runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
        gutTraining: gutTraining ?? this.gutTraining,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        appVersion: appVersion ?? this.appVersion,
      );
  UserProfileEntry copyWithCompanion(UserProfilesTableCompanion data) {
    return UserProfileEntry(
      id: data.id.present ? data.id.value : this.id,
      gender: data.gender.present ? data.gender.value : this.gender,
      birthday: data.birthday.present ? data.birthday.value : this.birthday,
      heightFeet:
          data.heightFeet.present ? data.heightFeet.value : this.heightFeet,
      heightInches: data.heightInches.present
          ? data.heightInches.value
          : this.heightInches,
      weightPounds: data.weightPounds.present
          ? data.weightPounds.value
          : this.weightPounds,
      runsWithWaterBottle: data.runsWithWaterBottle.present
          ? data.runsWithWaterBottle.value
          : this.runsWithWaterBottle,
      gutTraining:
          data.gutTraining.present ? data.gutTraining.value : this.gutTraining,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      appVersion:
          data.appVersion.present ? data.appVersion.value : this.appVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileEntry(')
          ..write('id: $id, ')
          ..write('gender: $gender, ')
          ..write('birthday: $birthday, ')
          ..write('heightFeet: $heightFeet, ')
          ..write('heightInches: $heightInches, ')
          ..write('weightPounds: $weightPounds, ')
          ..write('runsWithWaterBottle: $runsWithWaterBottle, ')
          ..write('gutTraining: $gutTraining, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('appVersion: $appVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      gender,
      birthday,
      heightFeet,
      heightInches,
      weightPounds,
      runsWithWaterBottle,
      gutTraining,
      onboardingCompleted,
      createdAt,
      updatedAt,
      appVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileEntry &&
          other.id == this.id &&
          other.gender == this.gender &&
          other.birthday == this.birthday &&
          other.heightFeet == this.heightFeet &&
          other.heightInches == this.heightInches &&
          other.weightPounds == this.weightPounds &&
          other.runsWithWaterBottle == this.runsWithWaterBottle &&
          other.gutTraining == this.gutTraining &&
          other.onboardingCompleted == this.onboardingCompleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.appVersion == this.appVersion);
}

class UserProfilesTableCompanion extends UpdateCompanion<UserProfileEntry> {
  final Value<String> id;
  final Value<String> gender;
  final Value<DateTime> birthday;
  final Value<int> heightFeet;
  final Value<int> heightInches;
  final Value<double> weightPounds;
  final Value<bool> runsWithWaterBottle;
  final Value<String> gutTraining;
  final Value<bool> onboardingCompleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> appVersion;
  final Value<int> rowid;
  const UserProfilesTableCompanion({
    this.id = const Value.absent(),
    this.gender = const Value.absent(),
    this.birthday = const Value.absent(),
    this.heightFeet = const Value.absent(),
    this.heightInches = const Value.absent(),
    this.weightPounds = const Value.absent(),
    this.runsWithWaterBottle = const Value.absent(),
    this.gutTraining = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesTableCompanion.insert({
    required String id,
    required String gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
    required String gutTraining,
    this.onboardingCompleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required String appVersion,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        gender = Value(gender),
        birthday = Value(birthday),
        heightFeet = Value(heightFeet),
        heightInches = Value(heightInches),
        weightPounds = Value(weightPounds),
        runsWithWaterBottle = Value(runsWithWaterBottle),
        gutTraining = Value(gutTraining),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        appVersion = Value(appVersion);
  static Insertable<UserProfileEntry> custom({
    Expression<String>? id,
    Expression<String>? gender,
    Expression<DateTime>? birthday,
    Expression<int>? heightFeet,
    Expression<int>? heightInches,
    Expression<double>? weightPounds,
    Expression<bool>? runsWithWaterBottle,
    Expression<String>? gutTraining,
    Expression<bool>? onboardingCompleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? appVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gender != null) 'gender': gender,
      if (birthday != null) 'birthday': birthday,
      if (heightFeet != null) 'height_feet': heightFeet,
      if (heightInches != null) 'height_inches': heightInches,
      if (weightPounds != null) 'weight_pounds': weightPounds,
      if (runsWithWaterBottle != null)
        'runs_with_water_bottle': runsWithWaterBottle,
      if (gutTraining != null) 'gut_training': gutTraining,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (appVersion != null) 'app_version': appVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? gender,
      Value<DateTime>? birthday,
      Value<int>? heightFeet,
      Value<int>? heightInches,
      Value<double>? weightPounds,
      Value<bool>? runsWithWaterBottle,
      Value<String>? gutTraining,
      Value<bool>? onboardingCompleted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? appVersion,
      Value<int>? rowid}) {
    return UserProfilesTableCompanion(
      id: id ?? this.id,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      heightFeet: heightFeet ?? this.heightFeet,
      heightInches: heightInches ?? this.heightInches,
      weightPounds: weightPounds ?? this.weightPounds,
      runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
      gutTraining: gutTraining ?? this.gutTraining,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appVersion: appVersion ?? this.appVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (birthday.present) {
      map['birthday'] = Variable<DateTime>(birthday.value);
    }
    if (heightFeet.present) {
      map['height_feet'] = Variable<int>(heightFeet.value);
    }
    if (heightInches.present) {
      map['height_inches'] = Variable<int>(heightInches.value);
    }
    if (weightPounds.present) {
      map['weight_pounds'] = Variable<double>(weightPounds.value);
    }
    if (runsWithWaterBottle.present) {
      map['runs_with_water_bottle'] = Variable<bool>(runsWithWaterBottle.value);
    }
    if (gutTraining.present) {
      map['gut_training'] = Variable<String>(gutTraining.value);
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesTableCompanion(')
          ..write('id: $id, ')
          ..write('gender: $gender, ')
          ..write('birthday: $birthday, ')
          ..write('heightFeet: $heightFeet, ')
          ..write('heightInches: $heightInches, ')
          ..write('weightPounds: $weightPounds, ')
          ..write('runsWithWaterBottle: $runsWithWaterBottle, ')
          ..write('gutTraining: $gutTraining, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoodPreferencesTableTable extends FoodPreferencesTable
    with TableInfo<$FoodPreferencesTableTable, FoodPreferenceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<String> foodId = GeneratedColumn<String>(
      'food_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _preferenceMeta =
      const VerificationMeta('preference');
  @override
  late final GeneratedColumn<String> preference = GeneratedColumn<String>(
      'preference', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, foodId, preference, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_preferences_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<FoodPreferenceEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(_foodIdMeta,
          foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta));
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('preference')) {
      context.handle(
          _preferenceMeta,
          preference.isAcceptableOrUnknown(
              data['preference']!, _preferenceMeta));
    } else if (isInserting) {
      context.missing(_preferenceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, foodId};
  @override
  FoodPreferenceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodPreferenceEntry(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      foodId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}food_id'])!,
      preference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preference'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $FoodPreferencesTableTable createAlias(String alias) {
    return $FoodPreferencesTableTable(attachedDatabase, alias);
  }
}

class FoodPreferenceEntry extends DataClass
    implements Insertable<FoodPreferenceEntry> {
  /// User ID (foreign key reference)
  final String userId;

  /// Food ID or name
  final String foodId;

  /// Preference type (like, dislike, neutral, willingToTry)
  final String preference;

  /// When the preference was created
  final DateTime createdAt;

  /// When the preference was last updated
  final DateTime updatedAt;
  const FoodPreferenceEntry(
      {required this.userId,
      required this.foodId,
      required this.preference,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['food_id'] = Variable<String>(foodId);
    map['preference'] = Variable<String>(preference);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FoodPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return FoodPreferencesTableCompanion(
      userId: Value(userId),
      foodId: Value(foodId),
      preference: Value(preference),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FoodPreferenceEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodPreferenceEntry(
      userId: serializer.fromJson<String>(json['userId']),
      foodId: serializer.fromJson<String>(json['foodId']),
      preference: serializer.fromJson<String>(json['preference']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'foodId': serializer.toJson<String>(foodId),
      'preference': serializer.toJson<String>(preference),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FoodPreferenceEntry copyWith(
          {String? userId,
          String? foodId,
          String? preference,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      FoodPreferenceEntry(
        userId: userId ?? this.userId,
        foodId: foodId ?? this.foodId,
        preference: preference ?? this.preference,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FoodPreferenceEntry copyWithCompanion(FoodPreferencesTableCompanion data) {
    return FoodPreferenceEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      preference:
          data.preference.present ? data.preference.value : this.preference,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodPreferenceEntry(')
          ..write('userId: $userId, ')
          ..write('foodId: $foodId, ')
          ..write('preference: $preference, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, foodId, preference, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodPreferenceEntry &&
          other.userId == this.userId &&
          other.foodId == this.foodId &&
          other.preference == this.preference &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FoodPreferencesTableCompanion
    extends UpdateCompanion<FoodPreferenceEntry> {
  final Value<String> userId;
  final Value<String> foodId;
  final Value<String> preference;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FoodPreferencesTableCompanion({
    this.userId = const Value.absent(),
    this.foodId = const Value.absent(),
    this.preference = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodPreferencesTableCompanion.insert({
    required String userId,
    required String foodId,
    required String preference,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        foodId = Value(foodId),
        preference = Value(preference),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<FoodPreferenceEntry> custom({
    Expression<String>? userId,
    Expression<String>? foodId,
    Expression<String>? preference,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (foodId != null) 'food_id': foodId,
      if (preference != null) 'preference': preference,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodPreferencesTableCompanion copyWith(
      {Value<String>? userId,
      Value<String>? foodId,
      Value<String>? preference,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return FoodPreferencesTableCompanion(
      userId: userId ?? this.userId,
      foodId: foodId ?? this.foodId,
      preference: preference ?? this.preference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<String>(foodId.value);
    }
    if (preference.present) {
      map['preference'] = Variable<String>(preference.value);
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
    return (StringBuffer('FoodPreferencesTableCompanion(')
          ..write('userId: $userId, ')
          ..write('foodId: $foodId, ')
          ..write('preference: $preference, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NutritionPlansTable extends NutritionPlans
    with TableInfo<$NutritionPlansTable, NutritionPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NutritionPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planDataMeta =
      const VerificationMeta('planData');
  @override
  late final GeneratedColumn<String> planData = GeneratedColumn<String>(
      'plan_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, planData, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nutrition_plans';
  @override
  VerificationContext validateIntegrity(Insertable<NutritionPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('plan_data')) {
      context.handle(_planDataMeta,
          planData.isAcceptableOrUnknown(data['plan_data']!, _planDataMeta));
    } else if (isInserting) {
      context.missing(_planDataMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NutritionPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NutritionPlan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      planData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_data'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $NutritionPlansTable createAlias(String alias) {
    return $NutritionPlansTable(attachedDatabase, alias);
  }
}

class NutritionPlan extends DataClass implements Insertable<NutritionPlan> {
  /// Plan ID (primary key)
  final String id;

  /// User ID (foreign key reference)
  final String userId;

  /// Plan data stored as JSON string
  final String planData;

  /// When the plan was created
  final DateTime createdAt;

  /// When the plan was last updated
  final DateTime updatedAt;
  const NutritionPlan(
      {required this.id,
      required this.userId,
      required this.planData,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['plan_data'] = Variable<String>(planData);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NutritionPlansCompanion toCompanion(bool nullToAbsent) {
    return NutritionPlansCompanion(
      id: Value(id),
      userId: Value(userId),
      planData: Value(planData),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NutritionPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NutritionPlan(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      planData: serializer.fromJson<String>(json['planData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'planData': serializer.toJson<String>(planData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NutritionPlan copyWith(
          {String? id,
          String? userId,
          String? planData,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      NutritionPlan(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        planData: planData ?? this.planData,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  NutritionPlan copyWithCompanion(NutritionPlansCompanion data) {
    return NutritionPlan(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      planData: data.planData.present ? data.planData.value : this.planData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NutritionPlan(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('planData: $planData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, planData, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NutritionPlan &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.planData == this.planData &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NutritionPlansCompanion extends UpdateCompanion<NutritionPlan> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> planData;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NutritionPlansCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.planData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NutritionPlansCompanion.insert({
    required String id,
    required String userId,
    required String planData,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        planData = Value(planData),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<NutritionPlan> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? planData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (planData != null) 'plan_data': planData,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NutritionPlansCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? planData,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return NutritionPlansCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planData: planData ?? this.planData,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (planData.present) {
      map['plan_data'] = Variable<String>(planData.value);
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
    return (StringBuffer('NutritionPlansCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('planData: $planData, ')
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
  late final $UserProfilesTableTable userProfilesTable =
      $UserProfilesTableTable(this);
  late final $FoodPreferencesTableTable foodPreferencesTable =
      $FoodPreferencesTableTable(this);
  late final $NutritionPlansTable nutritionPlans = $NutritionPlansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [userProfilesTable, foodPreferencesTable, nutritionPlans];
}

typedef $$UserProfilesTableTableCreateCompanionBuilder
    = UserProfilesTableCompanion Function({
  required String id,
  required String gender,
  required DateTime birthday,
  required int heightFeet,
  required int heightInches,
  required double weightPounds,
  required bool runsWithWaterBottle,
  required String gutTraining,
  Value<bool> onboardingCompleted,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String appVersion,
  Value<int> rowid,
});
typedef $$UserProfilesTableTableUpdateCompanionBuilder
    = UserProfilesTableCompanion Function({
  Value<String> id,
  Value<String> gender,
  Value<DateTime> birthday,
  Value<int> heightFeet,
  Value<int> heightInches,
  Value<double> weightPounds,
  Value<bool> runsWithWaterBottle,
  Value<String> gutTraining,
  Value<bool> onboardingCompleted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> appVersion,
  Value<int> rowid,
});

class $$UserProfilesTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTableTable> {
  $$UserProfilesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get birthday => $composableBuilder(
      column: $table.birthday, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heightFeet => $composableBuilder(
      column: $table.heightFeet, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heightInches => $composableBuilder(
      column: $table.heightInches, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightPounds => $composableBuilder(
      column: $table.weightPounds, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get runsWithWaterBottle => $composableBuilder(
      column: $table.runsWithWaterBottle,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gutTraining => $composableBuilder(
      column: $table.gutTraining, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
      column: $table.onboardingCompleted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get appVersion => $composableBuilder(
      column: $table.appVersion, builder: (column) => ColumnFilters(column));
}

class $$UserProfilesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTableTable> {
  $$UserProfilesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get birthday => $composableBuilder(
      column: $table.birthday, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heightFeet => $composableBuilder(
      column: $table.heightFeet, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heightInches => $composableBuilder(
      column: $table.heightInches,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightPounds => $composableBuilder(
      column: $table.weightPounds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get runsWithWaterBottle => $composableBuilder(
      column: $table.runsWithWaterBottle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gutTraining => $composableBuilder(
      column: $table.gutTraining, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
      column: $table.onboardingCompleted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get appVersion => $composableBuilder(
      column: $table.appVersion, builder: (column) => ColumnOrderings(column));
}

class $$UserProfilesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTableTable> {
  $$UserProfilesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<DateTime> get birthday =>
      $composableBuilder(column: $table.birthday, builder: (column) => column);

  GeneratedColumn<int> get heightFeet => $composableBuilder(
      column: $table.heightFeet, builder: (column) => column);

  GeneratedColumn<int> get heightInches => $composableBuilder(
      column: $table.heightInches, builder: (column) => column);

  GeneratedColumn<double> get weightPounds => $composableBuilder(
      column: $table.weightPounds, builder: (column) => column);

  GeneratedColumn<bool> get runsWithWaterBottle => $composableBuilder(
      column: $table.runsWithWaterBottle, builder: (column) => column);

  GeneratedColumn<String> get gutTraining => $composableBuilder(
      column: $table.gutTraining, builder: (column) => column);

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
      column: $table.onboardingCompleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
      column: $table.appVersion, builder: (column) => column);
}

class $$UserProfilesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfilesTableTable,
    UserProfileEntry,
    $$UserProfilesTableTableFilterComposer,
    $$UserProfilesTableTableOrderingComposer,
    $$UserProfilesTableTableAnnotationComposer,
    $$UserProfilesTableTableCreateCompanionBuilder,
    $$UserProfilesTableTableUpdateCompanionBuilder,
    (
      UserProfileEntry,
      BaseReferences<_$AppDatabase, $UserProfilesTableTable, UserProfileEntry>
    ),
    UserProfileEntry,
    PrefetchHooks Function()> {
  $$UserProfilesTableTableTableManager(
      _$AppDatabase db, $UserProfilesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> gender = const Value.absent(),
            Value<DateTime> birthday = const Value.absent(),
            Value<int> heightFeet = const Value.absent(),
            Value<int> heightInches = const Value.absent(),
            Value<double> weightPounds = const Value.absent(),
            Value<bool> runsWithWaterBottle = const Value.absent(),
            Value<String> gutTraining = const Value.absent(),
            Value<bool> onboardingCompleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> appVersion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfilesTableCompanion(
            id: id,
            gender: gender,
            birthday: birthday,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightPounds: weightPounds,
            runsWithWaterBottle: runsWithWaterBottle,
            gutTraining: gutTraining,
            onboardingCompleted: onboardingCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            appVersion: appVersion,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String gender,
            required DateTime birthday,
            required int heightFeet,
            required int heightInches,
            required double weightPounds,
            required bool runsWithWaterBottle,
            required String gutTraining,
            Value<bool> onboardingCompleted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            required String appVersion,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfilesTableCompanion.insert(
            id: id,
            gender: gender,
            birthday: birthday,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightPounds: weightPounds,
            runsWithWaterBottle: runsWithWaterBottle,
            gutTraining: gutTraining,
            onboardingCompleted: onboardingCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            appVersion: appVersion,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserProfilesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserProfilesTableTable,
    UserProfileEntry,
    $$UserProfilesTableTableFilterComposer,
    $$UserProfilesTableTableOrderingComposer,
    $$UserProfilesTableTableAnnotationComposer,
    $$UserProfilesTableTableCreateCompanionBuilder,
    $$UserProfilesTableTableUpdateCompanionBuilder,
    (
      UserProfileEntry,
      BaseReferences<_$AppDatabase, $UserProfilesTableTable, UserProfileEntry>
    ),
    UserProfileEntry,
    PrefetchHooks Function()>;
typedef $$FoodPreferencesTableTableCreateCompanionBuilder
    = FoodPreferencesTableCompanion Function({
  required String userId,
  required String foodId,
  required String preference,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$FoodPreferencesTableTableUpdateCompanionBuilder
    = FoodPreferencesTableCompanion Function({
  Value<String> userId,
  Value<String> foodId,
  Value<String> preference,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$FoodPreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FoodPreferencesTableTable> {
  $$FoodPreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodId => $composableBuilder(
      column: $table.foodId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preference => $composableBuilder(
      column: $table.preference, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$FoodPreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodPreferencesTableTable> {
  $$FoodPreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodId => $composableBuilder(
      column: $table.foodId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preference => $composableBuilder(
      column: $table.preference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$FoodPreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodPreferencesTableTable> {
  $$FoodPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get foodId =>
      $composableBuilder(column: $table.foodId, builder: (column) => column);

  GeneratedColumn<String> get preference => $composableBuilder(
      column: $table.preference, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FoodPreferencesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoodPreferencesTableTable,
    FoodPreferenceEntry,
    $$FoodPreferencesTableTableFilterComposer,
    $$FoodPreferencesTableTableOrderingComposer,
    $$FoodPreferencesTableTableAnnotationComposer,
    $$FoodPreferencesTableTableCreateCompanionBuilder,
    $$FoodPreferencesTableTableUpdateCompanionBuilder,
    (
      FoodPreferenceEntry,
      BaseReferences<_$AppDatabase, $FoodPreferencesTableTable,
          FoodPreferenceEntry>
    ),
    FoodPreferenceEntry,
    PrefetchHooks Function()> {
  $$FoodPreferencesTableTableTableManager(
      _$AppDatabase db, $FoodPreferencesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodPreferencesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodPreferencesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> foodId = const Value.absent(),
            Value<String> preference = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodPreferencesTableCompanion(
            userId: userId,
            foodId: foodId,
            preference: preference,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String foodId,
            required String preference,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodPreferencesTableCompanion.insert(
            userId: userId,
            foodId: foodId,
            preference: preference,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FoodPreferencesTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $FoodPreferencesTableTable,
        FoodPreferenceEntry,
        $$FoodPreferencesTableTableFilterComposer,
        $$FoodPreferencesTableTableOrderingComposer,
        $$FoodPreferencesTableTableAnnotationComposer,
        $$FoodPreferencesTableTableCreateCompanionBuilder,
        $$FoodPreferencesTableTableUpdateCompanionBuilder,
        (
          FoodPreferenceEntry,
          BaseReferences<_$AppDatabase, $FoodPreferencesTableTable,
              FoodPreferenceEntry>
        ),
        FoodPreferenceEntry,
        PrefetchHooks Function()>;
typedef $$NutritionPlansTableCreateCompanionBuilder = NutritionPlansCompanion
    Function({
  required String id,
  required String userId,
  required String planData,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$NutritionPlansTableUpdateCompanionBuilder = NutritionPlansCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> planData,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$NutritionPlansTableFilterComposer
    extends Composer<_$AppDatabase, $NutritionPlansTable> {
  $$NutritionPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planData => $composableBuilder(
      column: $table.planData, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$NutritionPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $NutritionPlansTable> {
  $$NutritionPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planData => $composableBuilder(
      column: $table.planData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$NutritionPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $NutritionPlansTable> {
  $$NutritionPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get planData =>
      $composableBuilder(column: $table.planData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NutritionPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NutritionPlansTable,
    NutritionPlan,
    $$NutritionPlansTableFilterComposer,
    $$NutritionPlansTableOrderingComposer,
    $$NutritionPlansTableAnnotationComposer,
    $$NutritionPlansTableCreateCompanionBuilder,
    $$NutritionPlansTableUpdateCompanionBuilder,
    (
      NutritionPlan,
      BaseReferences<_$AppDatabase, $NutritionPlansTable, NutritionPlan>
    ),
    NutritionPlan,
    PrefetchHooks Function()> {
  $$NutritionPlansTableTableManager(
      _$AppDatabase db, $NutritionPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NutritionPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NutritionPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NutritionPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> planData = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NutritionPlansCompanion(
            id: id,
            userId: userId,
            planData: planData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String planData,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              NutritionPlansCompanion.insert(
            id: id,
            userId: userId,
            planData: planData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NutritionPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NutritionPlansTable,
    NutritionPlan,
    $$NutritionPlansTableFilterComposer,
    $$NutritionPlansTableOrderingComposer,
    $$NutritionPlansTableAnnotationComposer,
    $$NutritionPlansTableCreateCompanionBuilder,
    $$NutritionPlansTableUpdateCompanionBuilder,
    (
      NutritionPlan,
      BaseReferences<_$AppDatabase, $NutritionPlansTable, NutritionPlan>
    ),
    NutritionPlan,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableTableManager get userProfilesTable =>
      $$UserProfilesTableTableTableManager(_db, _db.userProfilesTable);
  $$FoodPreferencesTableTableTableManager get foodPreferencesTable =>
      $$FoodPreferencesTableTableTableManager(_db, _db.foodPreferencesTable);
  $$NutritionPlansTableTableManager get nutritionPlans =>
      $$NutritionPlansTableTableManager(_db, _db.nutritionPlans);
}
