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
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
      'notifications_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notifications_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _defaultReminderDayMeta =
      const VerificationMeta('defaultReminderDay');
  @override
  late final GeneratedColumn<int> defaultReminderDay = GeneratedColumn<int>(
      'default_reminder_day', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(4));
  static const VerificationMeta _defaultReminderHourMeta =
      const VerificationMeta('defaultReminderHour');
  @override
  late final GeneratedColumn<int> defaultReminderHour = GeneratedColumn<int>(
      'default_reminder_hour', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(17));
  static const VerificationMeta _defaultReminderMinuteMeta =
      const VerificationMeta('defaultReminderMinute');
  @override
  late final GeneratedColumn<int> defaultReminderMinute = GeneratedColumn<int>(
      'default_reminder_minute', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _defaultReminderRecurringMeta =
      const VerificationMeta('defaultReminderRecurring');
  @override
  late final GeneratedColumn<bool> defaultReminderRecurring =
      GeneratedColumn<bool>(
          'default_reminder_recurring', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("default_reminder_recurring" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _tempPlanDataMeta =
      const VerificationMeta('tempPlanData');
  @override
  late final GeneratedColumn<String> tempPlanData = GeneratedColumn<String>(
      'temp_plan_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        appVersion,
        notificationsEnabled,
        defaultReminderDay,
        defaultReminderHour,
        defaultReminderMinute,
        defaultReminderRecurring,
        tempPlanData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
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
    if (data.containsKey('notifications_enabled')) {
      context.handle(
          _notificationsEnabledMeta,
          notificationsEnabled.isAcceptableOrUnknown(
              data['notifications_enabled']!, _notificationsEnabledMeta));
    }
    if (data.containsKey('default_reminder_day')) {
      context.handle(
          _defaultReminderDayMeta,
          defaultReminderDay.isAcceptableOrUnknown(
              data['default_reminder_day']!, _defaultReminderDayMeta));
    }
    if (data.containsKey('default_reminder_hour')) {
      context.handle(
          _defaultReminderHourMeta,
          defaultReminderHour.isAcceptableOrUnknown(
              data['default_reminder_hour']!, _defaultReminderHourMeta));
    }
    if (data.containsKey('default_reminder_minute')) {
      context.handle(
          _defaultReminderMinuteMeta,
          defaultReminderMinute.isAcceptableOrUnknown(
              data['default_reminder_minute']!, _defaultReminderMinuteMeta));
    }
    if (data.containsKey('default_reminder_recurring')) {
      context.handle(
          _defaultReminderRecurringMeta,
          defaultReminderRecurring.isAcceptableOrUnknown(
              data['default_reminder_recurring']!,
              _defaultReminderRecurringMeta));
    }
    if (data.containsKey('temp_plan_data')) {
      context.handle(
          _tempPlanDataMeta,
          tempPlanData.isAcceptableOrUnknown(
              data['temp_plan_data']!, _tempPlanDataMeta));
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
      notificationsEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}notifications_enabled'])!,
      defaultReminderDay: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}default_reminder_day'])!,
      defaultReminderHour: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}default_reminder_hour'])!,
      defaultReminderMinute: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}default_reminder_minute'])!,
      defaultReminderRecurring: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}default_reminder_recurring'])!,
      tempPlanData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}temp_plan_data']),
    );
  }

  @override
  $UserProfilesTableTable createAlias(String alias) {
    return $UserProfilesTableTable(attachedDatabase, alias);
  }
}

class UserProfileEntry extends DataClass
    implements Insertable<UserProfileEntry> {
  /// Device ID used as user identifier (maps to device_id in Supabase users table)
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

  /// Notification preferences
  final bool notificationsEnabled;
  final int defaultReminderDay;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final bool defaultReminderRecurring;

  /// Temporary plan storage (unsaved plan that persists through app restart)
  final String? tempPlanData;
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
      required this.appVersion,
      required this.notificationsEnabled,
      required this.defaultReminderDay,
      required this.defaultReminderHour,
      required this.defaultReminderMinute,
      required this.defaultReminderRecurring,
      this.tempPlanData});
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
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['default_reminder_day'] = Variable<int>(defaultReminderDay);
    map['default_reminder_hour'] = Variable<int>(defaultReminderHour);
    map['default_reminder_minute'] = Variable<int>(defaultReminderMinute);
    map['default_reminder_recurring'] =
        Variable<bool>(defaultReminderRecurring);
    if (!nullToAbsent || tempPlanData != null) {
      map['temp_plan_data'] = Variable<String>(tempPlanData);
    }
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
      notificationsEnabled: Value(notificationsEnabled),
      defaultReminderDay: Value(defaultReminderDay),
      defaultReminderHour: Value(defaultReminderHour),
      defaultReminderMinute: Value(defaultReminderMinute),
      defaultReminderRecurring: Value(defaultReminderRecurring),
      tempPlanData: tempPlanData == null && nullToAbsent
          ? const Value.absent()
          : Value(tempPlanData),
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
      notificationsEnabled:
          serializer.fromJson<bool>(json['notificationsEnabled']),
      defaultReminderDay: serializer.fromJson<int>(json['defaultReminderDay']),
      defaultReminderHour:
          serializer.fromJson<int>(json['defaultReminderHour']),
      defaultReminderMinute:
          serializer.fromJson<int>(json['defaultReminderMinute']),
      defaultReminderRecurring:
          serializer.fromJson<bool>(json['defaultReminderRecurring']),
      tempPlanData: serializer.fromJson<String?>(json['tempPlanData']),
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
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'defaultReminderDay': serializer.toJson<int>(defaultReminderDay),
      'defaultReminderHour': serializer.toJson<int>(defaultReminderHour),
      'defaultReminderMinute': serializer.toJson<int>(defaultReminderMinute),
      'defaultReminderRecurring':
          serializer.toJson<bool>(defaultReminderRecurring),
      'tempPlanData': serializer.toJson<String?>(tempPlanData),
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
          String? appVersion,
          bool? notificationsEnabled,
          int? defaultReminderDay,
          int? defaultReminderHour,
          int? defaultReminderMinute,
          bool? defaultReminderRecurring,
          Value<String?> tempPlanData = const Value.absent()}) =>
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
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        defaultReminderDay: defaultReminderDay ?? this.defaultReminderDay,
        defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
        defaultReminderMinute:
            defaultReminderMinute ?? this.defaultReminderMinute,
        defaultReminderRecurring:
            defaultReminderRecurring ?? this.defaultReminderRecurring,
        tempPlanData:
            tempPlanData.present ? tempPlanData.value : this.tempPlanData,
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
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      defaultReminderDay: data.defaultReminderDay.present
          ? data.defaultReminderDay.value
          : this.defaultReminderDay,
      defaultReminderHour: data.defaultReminderHour.present
          ? data.defaultReminderHour.value
          : this.defaultReminderHour,
      defaultReminderMinute: data.defaultReminderMinute.present
          ? data.defaultReminderMinute.value
          : this.defaultReminderMinute,
      defaultReminderRecurring: data.defaultReminderRecurring.present
          ? data.defaultReminderRecurring.value
          : this.defaultReminderRecurring,
      tempPlanData: data.tempPlanData.present
          ? data.tempPlanData.value
          : this.tempPlanData,
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
          ..write('appVersion: $appVersion, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('defaultReminderDay: $defaultReminderDay, ')
          ..write('defaultReminderHour: $defaultReminderHour, ')
          ..write('defaultReminderMinute: $defaultReminderMinute, ')
          ..write('defaultReminderRecurring: $defaultReminderRecurring, ')
          ..write('tempPlanData: $tempPlanData')
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
      appVersion,
      notificationsEnabled,
      defaultReminderDay,
      defaultReminderHour,
      defaultReminderMinute,
      defaultReminderRecurring,
      tempPlanData);
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
          other.appVersion == this.appVersion &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.defaultReminderDay == this.defaultReminderDay &&
          other.defaultReminderHour == this.defaultReminderHour &&
          other.defaultReminderMinute == this.defaultReminderMinute &&
          other.defaultReminderRecurring == this.defaultReminderRecurring &&
          other.tempPlanData == this.tempPlanData);
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
  final Value<bool> notificationsEnabled;
  final Value<int> defaultReminderDay;
  final Value<int> defaultReminderHour;
  final Value<int> defaultReminderMinute;
  final Value<bool> defaultReminderRecurring;
  final Value<String?> tempPlanData;
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
    this.notificationsEnabled = const Value.absent(),
    this.defaultReminderDay = const Value.absent(),
    this.defaultReminderHour = const Value.absent(),
    this.defaultReminderMinute = const Value.absent(),
    this.defaultReminderRecurring = const Value.absent(),
    this.tempPlanData = const Value.absent(),
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
    this.notificationsEnabled = const Value.absent(),
    this.defaultReminderDay = const Value.absent(),
    this.defaultReminderHour = const Value.absent(),
    this.defaultReminderMinute = const Value.absent(),
    this.defaultReminderRecurring = const Value.absent(),
    this.tempPlanData = const Value.absent(),
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
    Expression<bool>? notificationsEnabled,
    Expression<int>? defaultReminderDay,
    Expression<int>? defaultReminderHour,
    Expression<int>? defaultReminderMinute,
    Expression<bool>? defaultReminderRecurring,
    Expression<String>? tempPlanData,
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
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (defaultReminderDay != null)
        'default_reminder_day': defaultReminderDay,
      if (defaultReminderHour != null)
        'default_reminder_hour': defaultReminderHour,
      if (defaultReminderMinute != null)
        'default_reminder_minute': defaultReminderMinute,
      if (defaultReminderRecurring != null)
        'default_reminder_recurring': defaultReminderRecurring,
      if (tempPlanData != null) 'temp_plan_data': tempPlanData,
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
      Value<bool>? notificationsEnabled,
      Value<int>? defaultReminderDay,
      Value<int>? defaultReminderHour,
      Value<int>? defaultReminderMinute,
      Value<bool>? defaultReminderRecurring,
      Value<String?>? tempPlanData,
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
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultReminderDay: defaultReminderDay ?? this.defaultReminderDay,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute:
          defaultReminderMinute ?? this.defaultReminderMinute,
      defaultReminderRecurring:
          defaultReminderRecurring ?? this.defaultReminderRecurring,
      tempPlanData: tempPlanData ?? this.tempPlanData,
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
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (defaultReminderDay.present) {
      map['default_reminder_day'] = Variable<int>(defaultReminderDay.value);
    }
    if (defaultReminderHour.present) {
      map['default_reminder_hour'] = Variable<int>(defaultReminderHour.value);
    }
    if (defaultReminderMinute.present) {
      map['default_reminder_minute'] =
          Variable<int>(defaultReminderMinute.value);
    }
    if (defaultReminderRecurring.present) {
      map['default_reminder_recurring'] =
          Variable<bool>(defaultReminderRecurring.value);
    }
    if (tempPlanData.present) {
      map['temp_plan_data'] = Variable<String>(tempPlanData.value);
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
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('defaultReminderDay: $defaultReminderDay, ')
          ..write('defaultReminderHour: $defaultReminderHour, ')
          ..write('defaultReminderMinute: $defaultReminderMinute, ')
          ..write('defaultReminderRecurring: $defaultReminderRecurring, ')
          ..write('tempPlanData: $tempPlanData, ')
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

class $MacroTargetsTableTable extends MacroTargetsTable
    with TableInfo<$MacroTargetsTableTable, MacroTargetsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MacroTargetsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _preRunCarbsGMeta =
      const VerificationMeta('preRunCarbsG');
  @override
  late final GeneratedColumn<double> preRunCarbsG = GeneratedColumn<double>(
      'pre_run_carbs_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _preRunProteinGMeta =
      const VerificationMeta('preRunProteinG');
  @override
  late final GeneratedColumn<double> preRunProteinG = GeneratedColumn<double>(
      'pre_run_protein_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _preRunFatCapGMeta =
      const VerificationMeta('preRunFatCapG');
  @override
  late final GeneratedColumn<double> preRunFatCapG = GeneratedColumn<double>(
      'pre_run_fat_cap_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _preRunFluidsMlMeta =
      const VerificationMeta('preRunFluidsMl');
  @override
  late final GeneratedColumn<double> preRunFluidsMl = GeneratedColumn<double>(
      'pre_run_fluids_ml', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _preRunSodiumMgMeta =
      const VerificationMeta('preRunSodiumMg');
  @override
  late final GeneratedColumn<double> preRunSodiumMg = GeneratedColumn<double>(
      'pre_run_sodium_mg', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringCarbRateGPerHMeta =
      const VerificationMeta('duringCarbRateGPerH');
  @override
  late final GeneratedColumn<double> duringCarbRateGPerH =
      GeneratedColumn<double>('during_carb_rate_g_per_h', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringCarbTotalGMeta =
      const VerificationMeta('duringCarbTotalG');
  @override
  late final GeneratedColumn<double> duringCarbTotalG = GeneratedColumn<double>(
      'during_carb_total_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringFluidRateMlPerHMeta =
      const VerificationMeta('duringFluidRateMlPerH');
  @override
  late final GeneratedColumn<double> duringFluidRateMlPerH =
      GeneratedColumn<double>('during_fluid_rate_ml_per_h', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringFluidTotalMlMeta =
      const VerificationMeta('duringFluidTotalMl');
  @override
  late final GeneratedColumn<double> duringFluidTotalMl =
      GeneratedColumn<double>('during_fluid_total_ml', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringSodiumRateMgPerHMeta =
      const VerificationMeta('duringSodiumRateMgPerH');
  @override
  late final GeneratedColumn<double> duringSodiumRateMgPerH =
      GeneratedColumn<double>('during_sodium_rate_mg_per_h', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringSodiumTotalMgMeta =
      const VerificationMeta('duringSodiumTotalMg');
  @override
  late final GeneratedColumn<double> duringSodiumTotalMg =
      GeneratedColumn<double>('during_sodium_total_mg', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _duringMassNormRateGPerHMeta =
      const VerificationMeta('duringMassNormRateGPerH');
  @override
  late final GeneratedColumn<double> duringMassNormRateGPerH =
      GeneratedColumn<double>(
          'during_mass_norm_rate_g_per_h', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _postRunCarbsGMeta =
      const VerificationMeta('postRunCarbsG');
  @override
  late final GeneratedColumn<double> postRunCarbsG = GeneratedColumn<double>(
      'post_run_carbs_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _postRunProteinGMeta =
      const VerificationMeta('postRunProteinG');
  @override
  late final GeneratedColumn<double> postRunProteinG = GeneratedColumn<double>(
      'post_run_protein_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _postRunFluidsMlMeta =
      const VerificationMeta('postRunFluidsMl');
  @override
  late final GeneratedColumn<double> postRunFluidsMl = GeneratedColumn<double>(
      'post_run_fluids_ml', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _postRunSodiumMgMeta =
      const VerificationMeta('postRunSodiumMg');
  @override
  late final GeneratedColumn<double> postRunSodiumMg = GeneratedColumn<double>(
      'post_run_sodium_mg', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _distanceMiMeta =
      const VerificationMeta('distanceMi');
  @override
  late final GeneratedColumn<double> distanceMi = GeneratedColumn<double>(
      'distance_mi', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _durationHMeta =
      const VerificationMeta('durationH');
  @override
  late final GeneratedColumn<double> durationH = GeneratedColumn<double>(
      'duration_h', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _paceMinPerMileMeta =
      const VerificationMeta('paceMinPerMile');
  @override
  late final GeneratedColumn<double> paceMinPerMile = GeneratedColumn<double>(
      'pace_min_per_mile', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _caloriesGrossKcalMeta =
      const VerificationMeta('caloriesGrossKcal');
  @override
  late final GeneratedColumn<double> caloriesGrossKcal =
      GeneratedColumn<double>('calories_gross_kcal', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _metMeta = const VerificationMeta('met');
  @override
  late final GeneratedColumn<double> met = GeneratedColumn<double>(
      'met', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _calculationRuleMeta =
      const VerificationMeta('calculationRule');
  @override
  late final GeneratedColumn<String> calculationRule = GeneratedColumn<String>(
      'calculation_rule', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isUserModifiedMeta =
      const VerificationMeta('isUserModified');
  @override
  late final GeneratedColumn<bool> isUserModified = GeneratedColumn<bool>(
      'is_user_modified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_user_modified" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _modifiedFieldsMeta =
      const VerificationMeta('modifiedFields');
  @override
  late final GeneratedColumn<String> modifiedFields = GeneratedColumn<String>(
      'modified_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        preRunCarbsG,
        preRunProteinG,
        preRunFatCapG,
        preRunFluidsMl,
        preRunSodiumMg,
        duringCarbRateGPerH,
        duringCarbTotalG,
        duringFluidRateMlPerH,
        duringFluidTotalMl,
        duringSodiumRateMgPerH,
        duringSodiumTotalMg,
        duringMassNormRateGPerH,
        postRunCarbsG,
        postRunProteinG,
        postRunFluidsMl,
        postRunSodiumMg,
        distanceMi,
        durationH,
        paceMinPerMile,
        caloriesGrossKcal,
        met,
        calculationRule,
        timestamp,
        isUserModified,
        modifiedFields
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'macro_targets_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<MacroTargetsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pre_run_carbs_g')) {
      context.handle(
          _preRunCarbsGMeta,
          preRunCarbsG.isAcceptableOrUnknown(
              data['pre_run_carbs_g']!, _preRunCarbsGMeta));
    } else if (isInserting) {
      context.missing(_preRunCarbsGMeta);
    }
    if (data.containsKey('pre_run_protein_g')) {
      context.handle(
          _preRunProteinGMeta,
          preRunProteinG.isAcceptableOrUnknown(
              data['pre_run_protein_g']!, _preRunProteinGMeta));
    } else if (isInserting) {
      context.missing(_preRunProteinGMeta);
    }
    if (data.containsKey('pre_run_fat_cap_g')) {
      context.handle(
          _preRunFatCapGMeta,
          preRunFatCapG.isAcceptableOrUnknown(
              data['pre_run_fat_cap_g']!, _preRunFatCapGMeta));
    } else if (isInserting) {
      context.missing(_preRunFatCapGMeta);
    }
    if (data.containsKey('pre_run_fluids_ml')) {
      context.handle(
          _preRunFluidsMlMeta,
          preRunFluidsMl.isAcceptableOrUnknown(
              data['pre_run_fluids_ml']!, _preRunFluidsMlMeta));
    } else if (isInserting) {
      context.missing(_preRunFluidsMlMeta);
    }
    if (data.containsKey('pre_run_sodium_mg')) {
      context.handle(
          _preRunSodiumMgMeta,
          preRunSodiumMg.isAcceptableOrUnknown(
              data['pre_run_sodium_mg']!, _preRunSodiumMgMeta));
    } else if (isInserting) {
      context.missing(_preRunSodiumMgMeta);
    }
    if (data.containsKey('during_carb_rate_g_per_h')) {
      context.handle(
          _duringCarbRateGPerHMeta,
          duringCarbRateGPerH.isAcceptableOrUnknown(
              data['during_carb_rate_g_per_h']!, _duringCarbRateGPerHMeta));
    } else if (isInserting) {
      context.missing(_duringCarbRateGPerHMeta);
    }
    if (data.containsKey('during_carb_total_g')) {
      context.handle(
          _duringCarbTotalGMeta,
          duringCarbTotalG.isAcceptableOrUnknown(
              data['during_carb_total_g']!, _duringCarbTotalGMeta));
    } else if (isInserting) {
      context.missing(_duringCarbTotalGMeta);
    }
    if (data.containsKey('during_fluid_rate_ml_per_h')) {
      context.handle(
          _duringFluidRateMlPerHMeta,
          duringFluidRateMlPerH.isAcceptableOrUnknown(
              data['during_fluid_rate_ml_per_h']!, _duringFluidRateMlPerHMeta));
    } else if (isInserting) {
      context.missing(_duringFluidRateMlPerHMeta);
    }
    if (data.containsKey('during_fluid_total_ml')) {
      context.handle(
          _duringFluidTotalMlMeta,
          duringFluidTotalMl.isAcceptableOrUnknown(
              data['during_fluid_total_ml']!, _duringFluidTotalMlMeta));
    } else if (isInserting) {
      context.missing(_duringFluidTotalMlMeta);
    }
    if (data.containsKey('during_sodium_rate_mg_per_h')) {
      context.handle(
          _duringSodiumRateMgPerHMeta,
          duringSodiumRateMgPerH.isAcceptableOrUnknown(
              data['during_sodium_rate_mg_per_h']!,
              _duringSodiumRateMgPerHMeta));
    } else if (isInserting) {
      context.missing(_duringSodiumRateMgPerHMeta);
    }
    if (data.containsKey('during_sodium_total_mg')) {
      context.handle(
          _duringSodiumTotalMgMeta,
          duringSodiumTotalMg.isAcceptableOrUnknown(
              data['during_sodium_total_mg']!, _duringSodiumTotalMgMeta));
    } else if (isInserting) {
      context.missing(_duringSodiumTotalMgMeta);
    }
    if (data.containsKey('during_mass_norm_rate_g_per_h')) {
      context.handle(
          _duringMassNormRateGPerHMeta,
          duringMassNormRateGPerH.isAcceptableOrUnknown(
              data['during_mass_norm_rate_g_per_h']!,
              _duringMassNormRateGPerHMeta));
    }
    if (data.containsKey('post_run_carbs_g')) {
      context.handle(
          _postRunCarbsGMeta,
          postRunCarbsG.isAcceptableOrUnknown(
              data['post_run_carbs_g']!, _postRunCarbsGMeta));
    } else if (isInserting) {
      context.missing(_postRunCarbsGMeta);
    }
    if (data.containsKey('post_run_protein_g')) {
      context.handle(
          _postRunProteinGMeta,
          postRunProteinG.isAcceptableOrUnknown(
              data['post_run_protein_g']!, _postRunProteinGMeta));
    } else if (isInserting) {
      context.missing(_postRunProteinGMeta);
    }
    if (data.containsKey('post_run_fluids_ml')) {
      context.handle(
          _postRunFluidsMlMeta,
          postRunFluidsMl.isAcceptableOrUnknown(
              data['post_run_fluids_ml']!, _postRunFluidsMlMeta));
    } else if (isInserting) {
      context.missing(_postRunFluidsMlMeta);
    }
    if (data.containsKey('post_run_sodium_mg')) {
      context.handle(
          _postRunSodiumMgMeta,
          postRunSodiumMg.isAcceptableOrUnknown(
              data['post_run_sodium_mg']!, _postRunSodiumMgMeta));
    } else if (isInserting) {
      context.missing(_postRunSodiumMgMeta);
    }
    if (data.containsKey('distance_mi')) {
      context.handle(
          _distanceMiMeta,
          distanceMi.isAcceptableOrUnknown(
              data['distance_mi']!, _distanceMiMeta));
    } else if (isInserting) {
      context.missing(_distanceMiMeta);
    }
    if (data.containsKey('duration_h')) {
      context.handle(_durationHMeta,
          durationH.isAcceptableOrUnknown(data['duration_h']!, _durationHMeta));
    } else if (isInserting) {
      context.missing(_durationHMeta);
    }
    if (data.containsKey('pace_min_per_mile')) {
      context.handle(
          _paceMinPerMileMeta,
          paceMinPerMile.isAcceptableOrUnknown(
              data['pace_min_per_mile']!, _paceMinPerMileMeta));
    } else if (isInserting) {
      context.missing(_paceMinPerMileMeta);
    }
    if (data.containsKey('calories_gross_kcal')) {
      context.handle(
          _caloriesGrossKcalMeta,
          caloriesGrossKcal.isAcceptableOrUnknown(
              data['calories_gross_kcal']!, _caloriesGrossKcalMeta));
    } else if (isInserting) {
      context.missing(_caloriesGrossKcalMeta);
    }
    if (data.containsKey('met')) {
      context.handle(
          _metMeta, met.isAcceptableOrUnknown(data['met']!, _metMeta));
    } else if (isInserting) {
      context.missing(_metMeta);
    }
    if (data.containsKey('calculation_rule')) {
      context.handle(
          _calculationRuleMeta,
          calculationRule.isAcceptableOrUnknown(
              data['calculation_rule']!, _calculationRuleMeta));
    } else if (isInserting) {
      context.missing(_calculationRuleMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_user_modified')) {
      context.handle(
          _isUserModifiedMeta,
          isUserModified.isAcceptableOrUnknown(
              data['is_user_modified']!, _isUserModifiedMeta));
    }
    if (data.containsKey('modified_fields')) {
      context.handle(
          _modifiedFieldsMeta,
          modifiedFields.isAcceptableOrUnknown(
              data['modified_fields']!, _modifiedFieldsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MacroTargetsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MacroTargetsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      preRunCarbsG: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pre_run_carbs_g'])!,
      preRunProteinG: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pre_run_protein_g'])!,
      preRunFatCapG: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pre_run_fat_cap_g'])!,
      preRunFluidsMl: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pre_run_fluids_ml'])!,
      preRunSodiumMg: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pre_run_sodium_mg'])!,
      duringCarbRateGPerH: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}during_carb_rate_g_per_h'])!,
      duringCarbTotalG: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}during_carb_total_g'])!,
      duringFluidRateMlPerH: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}during_fluid_rate_ml_per_h'])!,
      duringFluidTotalMl: attachedDatabase.typeMapping.read(DriftSqlType.double,
          data['${effectivePrefix}during_fluid_total_ml'])!,
      duringSodiumRateMgPerH: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}during_sodium_rate_mg_per_h'])!,
      duringSodiumTotalMg: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}during_sodium_total_mg'])!,
      duringMassNormRateGPerH: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}during_mass_norm_rate_g_per_h']),
      postRunCarbsG: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}post_run_carbs_g'])!,
      postRunProteinG: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}post_run_protein_g'])!,
      postRunFluidsMl: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}post_run_fluids_ml'])!,
      postRunSodiumMg: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}post_run_sodium_mg'])!,
      distanceMi: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_mi'])!,
      durationH: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration_h'])!,
      paceMinPerMile: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pace_min_per_mile'])!,
      caloriesGrossKcal: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}calories_gross_kcal'])!,
      met: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}met'])!,
      calculationRule: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}calculation_rule'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      isUserModified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_user_modified'])!,
      modifiedFields: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}modified_fields'])!,
    );
  }

  @override
  $MacroTargetsTableTable createAlias(String alias) {
    return $MacroTargetsTableTable(attachedDatabase, alias);
  }
}

class MacroTargetsTableData extends DataClass
    implements Insertable<MacroTargetsTableData> {
  /// Unique identifier for this macro target set
  final String id;
  final double preRunCarbsG;
  final double preRunProteinG;
  final double preRunFatCapG;
  final double preRunFluidsMl;
  final double preRunSodiumMg;
  final double duringCarbRateGPerH;
  final double duringCarbTotalG;
  final double duringFluidRateMlPerH;
  final double duringFluidTotalMl;
  final double duringSodiumRateMgPerH;
  final double duringSodiumTotalMg;
  final double? duringMassNormRateGPerH;
  final double postRunCarbsG;
  final double postRunProteinG;
  final double postRunFluidsMl;
  final double postRunSodiumMg;
  final double distanceMi;
  final double durationH;
  final double paceMinPerMile;
  final double caloriesGrossKcal;
  final double met;
  final String calculationRule;
  final DateTime timestamp;
  final bool isUserModified;
  final String modifiedFields;
  const MacroTargetsTableData(
      {required this.id,
      required this.preRunCarbsG,
      required this.preRunProteinG,
      required this.preRunFatCapG,
      required this.preRunFluidsMl,
      required this.preRunSodiumMg,
      required this.duringCarbRateGPerH,
      required this.duringCarbTotalG,
      required this.duringFluidRateMlPerH,
      required this.duringFluidTotalMl,
      required this.duringSodiumRateMgPerH,
      required this.duringSodiumTotalMg,
      this.duringMassNormRateGPerH,
      required this.postRunCarbsG,
      required this.postRunProteinG,
      required this.postRunFluidsMl,
      required this.postRunSodiumMg,
      required this.distanceMi,
      required this.durationH,
      required this.paceMinPerMile,
      required this.caloriesGrossKcal,
      required this.met,
      required this.calculationRule,
      required this.timestamp,
      required this.isUserModified,
      required this.modifiedFields});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pre_run_carbs_g'] = Variable<double>(preRunCarbsG);
    map['pre_run_protein_g'] = Variable<double>(preRunProteinG);
    map['pre_run_fat_cap_g'] = Variable<double>(preRunFatCapG);
    map['pre_run_fluids_ml'] = Variable<double>(preRunFluidsMl);
    map['pre_run_sodium_mg'] = Variable<double>(preRunSodiumMg);
    map['during_carb_rate_g_per_h'] = Variable<double>(duringCarbRateGPerH);
    map['during_carb_total_g'] = Variable<double>(duringCarbTotalG);
    map['during_fluid_rate_ml_per_h'] = Variable<double>(duringFluidRateMlPerH);
    map['during_fluid_total_ml'] = Variable<double>(duringFluidTotalMl);
    map['during_sodium_rate_mg_per_h'] =
        Variable<double>(duringSodiumRateMgPerH);
    map['during_sodium_total_mg'] = Variable<double>(duringSodiumTotalMg);
    if (!nullToAbsent || duringMassNormRateGPerH != null) {
      map['during_mass_norm_rate_g_per_h'] =
          Variable<double>(duringMassNormRateGPerH);
    }
    map['post_run_carbs_g'] = Variable<double>(postRunCarbsG);
    map['post_run_protein_g'] = Variable<double>(postRunProteinG);
    map['post_run_fluids_ml'] = Variable<double>(postRunFluidsMl);
    map['post_run_sodium_mg'] = Variable<double>(postRunSodiumMg);
    map['distance_mi'] = Variable<double>(distanceMi);
    map['duration_h'] = Variable<double>(durationH);
    map['pace_min_per_mile'] = Variable<double>(paceMinPerMile);
    map['calories_gross_kcal'] = Variable<double>(caloriesGrossKcal);
    map['met'] = Variable<double>(met);
    map['calculation_rule'] = Variable<String>(calculationRule);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['is_user_modified'] = Variable<bool>(isUserModified);
    map['modified_fields'] = Variable<String>(modifiedFields);
    return map;
  }

  MacroTargetsTableCompanion toCompanion(bool nullToAbsent) {
    return MacroTargetsTableCompanion(
      id: Value(id),
      preRunCarbsG: Value(preRunCarbsG),
      preRunProteinG: Value(preRunProteinG),
      preRunFatCapG: Value(preRunFatCapG),
      preRunFluidsMl: Value(preRunFluidsMl),
      preRunSodiumMg: Value(preRunSodiumMg),
      duringCarbRateGPerH: Value(duringCarbRateGPerH),
      duringCarbTotalG: Value(duringCarbTotalG),
      duringFluidRateMlPerH: Value(duringFluidRateMlPerH),
      duringFluidTotalMl: Value(duringFluidTotalMl),
      duringSodiumRateMgPerH: Value(duringSodiumRateMgPerH),
      duringSodiumTotalMg: Value(duringSodiumTotalMg),
      duringMassNormRateGPerH: duringMassNormRateGPerH == null && nullToAbsent
          ? const Value.absent()
          : Value(duringMassNormRateGPerH),
      postRunCarbsG: Value(postRunCarbsG),
      postRunProteinG: Value(postRunProteinG),
      postRunFluidsMl: Value(postRunFluidsMl),
      postRunSodiumMg: Value(postRunSodiumMg),
      distanceMi: Value(distanceMi),
      durationH: Value(durationH),
      paceMinPerMile: Value(paceMinPerMile),
      caloriesGrossKcal: Value(caloriesGrossKcal),
      met: Value(met),
      calculationRule: Value(calculationRule),
      timestamp: Value(timestamp),
      isUserModified: Value(isUserModified),
      modifiedFields: Value(modifiedFields),
    );
  }

  factory MacroTargetsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MacroTargetsTableData(
      id: serializer.fromJson<String>(json['id']),
      preRunCarbsG: serializer.fromJson<double>(json['preRunCarbsG']),
      preRunProteinG: serializer.fromJson<double>(json['preRunProteinG']),
      preRunFatCapG: serializer.fromJson<double>(json['preRunFatCapG']),
      preRunFluidsMl: serializer.fromJson<double>(json['preRunFluidsMl']),
      preRunSodiumMg: serializer.fromJson<double>(json['preRunSodiumMg']),
      duringCarbRateGPerH:
          serializer.fromJson<double>(json['duringCarbRateGPerH']),
      duringCarbTotalG: serializer.fromJson<double>(json['duringCarbTotalG']),
      duringFluidRateMlPerH:
          serializer.fromJson<double>(json['duringFluidRateMlPerH']),
      duringFluidTotalMl:
          serializer.fromJson<double>(json['duringFluidTotalMl']),
      duringSodiumRateMgPerH:
          serializer.fromJson<double>(json['duringSodiumRateMgPerH']),
      duringSodiumTotalMg:
          serializer.fromJson<double>(json['duringSodiumTotalMg']),
      duringMassNormRateGPerH:
          serializer.fromJson<double?>(json['duringMassNormRateGPerH']),
      postRunCarbsG: serializer.fromJson<double>(json['postRunCarbsG']),
      postRunProteinG: serializer.fromJson<double>(json['postRunProteinG']),
      postRunFluidsMl: serializer.fromJson<double>(json['postRunFluidsMl']),
      postRunSodiumMg: serializer.fromJson<double>(json['postRunSodiumMg']),
      distanceMi: serializer.fromJson<double>(json['distanceMi']),
      durationH: serializer.fromJson<double>(json['durationH']),
      paceMinPerMile: serializer.fromJson<double>(json['paceMinPerMile']),
      caloriesGrossKcal: serializer.fromJson<double>(json['caloriesGrossKcal']),
      met: serializer.fromJson<double>(json['met']),
      calculationRule: serializer.fromJson<String>(json['calculationRule']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      isUserModified: serializer.fromJson<bool>(json['isUserModified']),
      modifiedFields: serializer.fromJson<String>(json['modifiedFields']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'preRunCarbsG': serializer.toJson<double>(preRunCarbsG),
      'preRunProteinG': serializer.toJson<double>(preRunProteinG),
      'preRunFatCapG': serializer.toJson<double>(preRunFatCapG),
      'preRunFluidsMl': serializer.toJson<double>(preRunFluidsMl),
      'preRunSodiumMg': serializer.toJson<double>(preRunSodiumMg),
      'duringCarbRateGPerH': serializer.toJson<double>(duringCarbRateGPerH),
      'duringCarbTotalG': serializer.toJson<double>(duringCarbTotalG),
      'duringFluidRateMlPerH': serializer.toJson<double>(duringFluidRateMlPerH),
      'duringFluidTotalMl': serializer.toJson<double>(duringFluidTotalMl),
      'duringSodiumRateMgPerH':
          serializer.toJson<double>(duringSodiumRateMgPerH),
      'duringSodiumTotalMg': serializer.toJson<double>(duringSodiumTotalMg),
      'duringMassNormRateGPerH':
          serializer.toJson<double?>(duringMassNormRateGPerH),
      'postRunCarbsG': serializer.toJson<double>(postRunCarbsG),
      'postRunProteinG': serializer.toJson<double>(postRunProteinG),
      'postRunFluidsMl': serializer.toJson<double>(postRunFluidsMl),
      'postRunSodiumMg': serializer.toJson<double>(postRunSodiumMg),
      'distanceMi': serializer.toJson<double>(distanceMi),
      'durationH': serializer.toJson<double>(durationH),
      'paceMinPerMile': serializer.toJson<double>(paceMinPerMile),
      'caloriesGrossKcal': serializer.toJson<double>(caloriesGrossKcal),
      'met': serializer.toJson<double>(met),
      'calculationRule': serializer.toJson<String>(calculationRule),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'isUserModified': serializer.toJson<bool>(isUserModified),
      'modifiedFields': serializer.toJson<String>(modifiedFields),
    };
  }

  MacroTargetsTableData copyWith(
          {String? id,
          double? preRunCarbsG,
          double? preRunProteinG,
          double? preRunFatCapG,
          double? preRunFluidsMl,
          double? preRunSodiumMg,
          double? duringCarbRateGPerH,
          double? duringCarbTotalG,
          double? duringFluidRateMlPerH,
          double? duringFluidTotalMl,
          double? duringSodiumRateMgPerH,
          double? duringSodiumTotalMg,
          Value<double?> duringMassNormRateGPerH = const Value.absent(),
          double? postRunCarbsG,
          double? postRunProteinG,
          double? postRunFluidsMl,
          double? postRunSodiumMg,
          double? distanceMi,
          double? durationH,
          double? paceMinPerMile,
          double? caloriesGrossKcal,
          double? met,
          String? calculationRule,
          DateTime? timestamp,
          bool? isUserModified,
          String? modifiedFields}) =>
      MacroTargetsTableData(
        id: id ?? this.id,
        preRunCarbsG: preRunCarbsG ?? this.preRunCarbsG,
        preRunProteinG: preRunProteinG ?? this.preRunProteinG,
        preRunFatCapG: preRunFatCapG ?? this.preRunFatCapG,
        preRunFluidsMl: preRunFluidsMl ?? this.preRunFluidsMl,
        preRunSodiumMg: preRunSodiumMg ?? this.preRunSodiumMg,
        duringCarbRateGPerH: duringCarbRateGPerH ?? this.duringCarbRateGPerH,
        duringCarbTotalG: duringCarbTotalG ?? this.duringCarbTotalG,
        duringFluidRateMlPerH:
            duringFluidRateMlPerH ?? this.duringFluidRateMlPerH,
        duringFluidTotalMl: duringFluidTotalMl ?? this.duringFluidTotalMl,
        duringSodiumRateMgPerH:
            duringSodiumRateMgPerH ?? this.duringSodiumRateMgPerH,
        duringSodiumTotalMg: duringSodiumTotalMg ?? this.duringSodiumTotalMg,
        duringMassNormRateGPerH: duringMassNormRateGPerH.present
            ? duringMassNormRateGPerH.value
            : this.duringMassNormRateGPerH,
        postRunCarbsG: postRunCarbsG ?? this.postRunCarbsG,
        postRunProteinG: postRunProteinG ?? this.postRunProteinG,
        postRunFluidsMl: postRunFluidsMl ?? this.postRunFluidsMl,
        postRunSodiumMg: postRunSodiumMg ?? this.postRunSodiumMg,
        distanceMi: distanceMi ?? this.distanceMi,
        durationH: durationH ?? this.durationH,
        paceMinPerMile: paceMinPerMile ?? this.paceMinPerMile,
        caloriesGrossKcal: caloriesGrossKcal ?? this.caloriesGrossKcal,
        met: met ?? this.met,
        calculationRule: calculationRule ?? this.calculationRule,
        timestamp: timestamp ?? this.timestamp,
        isUserModified: isUserModified ?? this.isUserModified,
        modifiedFields: modifiedFields ?? this.modifiedFields,
      );
  MacroTargetsTableData copyWithCompanion(MacroTargetsTableCompanion data) {
    return MacroTargetsTableData(
      id: data.id.present ? data.id.value : this.id,
      preRunCarbsG: data.preRunCarbsG.present
          ? data.preRunCarbsG.value
          : this.preRunCarbsG,
      preRunProteinG: data.preRunProteinG.present
          ? data.preRunProteinG.value
          : this.preRunProteinG,
      preRunFatCapG: data.preRunFatCapG.present
          ? data.preRunFatCapG.value
          : this.preRunFatCapG,
      preRunFluidsMl: data.preRunFluidsMl.present
          ? data.preRunFluidsMl.value
          : this.preRunFluidsMl,
      preRunSodiumMg: data.preRunSodiumMg.present
          ? data.preRunSodiumMg.value
          : this.preRunSodiumMg,
      duringCarbRateGPerH: data.duringCarbRateGPerH.present
          ? data.duringCarbRateGPerH.value
          : this.duringCarbRateGPerH,
      duringCarbTotalG: data.duringCarbTotalG.present
          ? data.duringCarbTotalG.value
          : this.duringCarbTotalG,
      duringFluidRateMlPerH: data.duringFluidRateMlPerH.present
          ? data.duringFluidRateMlPerH.value
          : this.duringFluidRateMlPerH,
      duringFluidTotalMl: data.duringFluidTotalMl.present
          ? data.duringFluidTotalMl.value
          : this.duringFluidTotalMl,
      duringSodiumRateMgPerH: data.duringSodiumRateMgPerH.present
          ? data.duringSodiumRateMgPerH.value
          : this.duringSodiumRateMgPerH,
      duringSodiumTotalMg: data.duringSodiumTotalMg.present
          ? data.duringSodiumTotalMg.value
          : this.duringSodiumTotalMg,
      duringMassNormRateGPerH: data.duringMassNormRateGPerH.present
          ? data.duringMassNormRateGPerH.value
          : this.duringMassNormRateGPerH,
      postRunCarbsG: data.postRunCarbsG.present
          ? data.postRunCarbsG.value
          : this.postRunCarbsG,
      postRunProteinG: data.postRunProteinG.present
          ? data.postRunProteinG.value
          : this.postRunProteinG,
      postRunFluidsMl: data.postRunFluidsMl.present
          ? data.postRunFluidsMl.value
          : this.postRunFluidsMl,
      postRunSodiumMg: data.postRunSodiumMg.present
          ? data.postRunSodiumMg.value
          : this.postRunSodiumMg,
      distanceMi:
          data.distanceMi.present ? data.distanceMi.value : this.distanceMi,
      durationH: data.durationH.present ? data.durationH.value : this.durationH,
      paceMinPerMile: data.paceMinPerMile.present
          ? data.paceMinPerMile.value
          : this.paceMinPerMile,
      caloriesGrossKcal: data.caloriesGrossKcal.present
          ? data.caloriesGrossKcal.value
          : this.caloriesGrossKcal,
      met: data.met.present ? data.met.value : this.met,
      calculationRule: data.calculationRule.present
          ? data.calculationRule.value
          : this.calculationRule,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isUserModified: data.isUserModified.present
          ? data.isUserModified.value
          : this.isUserModified,
      modifiedFields: data.modifiedFields.present
          ? data.modifiedFields.value
          : this.modifiedFields,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MacroTargetsTableData(')
          ..write('id: $id, ')
          ..write('preRunCarbsG: $preRunCarbsG, ')
          ..write('preRunProteinG: $preRunProteinG, ')
          ..write('preRunFatCapG: $preRunFatCapG, ')
          ..write('preRunFluidsMl: $preRunFluidsMl, ')
          ..write('preRunSodiumMg: $preRunSodiumMg, ')
          ..write('duringCarbRateGPerH: $duringCarbRateGPerH, ')
          ..write('duringCarbTotalG: $duringCarbTotalG, ')
          ..write('duringFluidRateMlPerH: $duringFluidRateMlPerH, ')
          ..write('duringFluidTotalMl: $duringFluidTotalMl, ')
          ..write('duringSodiumRateMgPerH: $duringSodiumRateMgPerH, ')
          ..write('duringSodiumTotalMg: $duringSodiumTotalMg, ')
          ..write('duringMassNormRateGPerH: $duringMassNormRateGPerH, ')
          ..write('postRunCarbsG: $postRunCarbsG, ')
          ..write('postRunProteinG: $postRunProteinG, ')
          ..write('postRunFluidsMl: $postRunFluidsMl, ')
          ..write('postRunSodiumMg: $postRunSodiumMg, ')
          ..write('distanceMi: $distanceMi, ')
          ..write('durationH: $durationH, ')
          ..write('paceMinPerMile: $paceMinPerMile, ')
          ..write('caloriesGrossKcal: $caloriesGrossKcal, ')
          ..write('met: $met, ')
          ..write('calculationRule: $calculationRule, ')
          ..write('timestamp: $timestamp, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('modifiedFields: $modifiedFields')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        preRunCarbsG,
        preRunProteinG,
        preRunFatCapG,
        preRunFluidsMl,
        preRunSodiumMg,
        duringCarbRateGPerH,
        duringCarbTotalG,
        duringFluidRateMlPerH,
        duringFluidTotalMl,
        duringSodiumRateMgPerH,
        duringSodiumTotalMg,
        duringMassNormRateGPerH,
        postRunCarbsG,
        postRunProteinG,
        postRunFluidsMl,
        postRunSodiumMg,
        distanceMi,
        durationH,
        paceMinPerMile,
        caloriesGrossKcal,
        met,
        calculationRule,
        timestamp,
        isUserModified,
        modifiedFields
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MacroTargetsTableData &&
          other.id == this.id &&
          other.preRunCarbsG == this.preRunCarbsG &&
          other.preRunProteinG == this.preRunProteinG &&
          other.preRunFatCapG == this.preRunFatCapG &&
          other.preRunFluidsMl == this.preRunFluidsMl &&
          other.preRunSodiumMg == this.preRunSodiumMg &&
          other.duringCarbRateGPerH == this.duringCarbRateGPerH &&
          other.duringCarbTotalG == this.duringCarbTotalG &&
          other.duringFluidRateMlPerH == this.duringFluidRateMlPerH &&
          other.duringFluidTotalMl == this.duringFluidTotalMl &&
          other.duringSodiumRateMgPerH == this.duringSodiumRateMgPerH &&
          other.duringSodiumTotalMg == this.duringSodiumTotalMg &&
          other.duringMassNormRateGPerH == this.duringMassNormRateGPerH &&
          other.postRunCarbsG == this.postRunCarbsG &&
          other.postRunProteinG == this.postRunProteinG &&
          other.postRunFluidsMl == this.postRunFluidsMl &&
          other.postRunSodiumMg == this.postRunSodiumMg &&
          other.distanceMi == this.distanceMi &&
          other.durationH == this.durationH &&
          other.paceMinPerMile == this.paceMinPerMile &&
          other.caloriesGrossKcal == this.caloriesGrossKcal &&
          other.met == this.met &&
          other.calculationRule == this.calculationRule &&
          other.timestamp == this.timestamp &&
          other.isUserModified == this.isUserModified &&
          other.modifiedFields == this.modifiedFields);
}

class MacroTargetsTableCompanion
    extends UpdateCompanion<MacroTargetsTableData> {
  final Value<String> id;
  final Value<double> preRunCarbsG;
  final Value<double> preRunProteinG;
  final Value<double> preRunFatCapG;
  final Value<double> preRunFluidsMl;
  final Value<double> preRunSodiumMg;
  final Value<double> duringCarbRateGPerH;
  final Value<double> duringCarbTotalG;
  final Value<double> duringFluidRateMlPerH;
  final Value<double> duringFluidTotalMl;
  final Value<double> duringSodiumRateMgPerH;
  final Value<double> duringSodiumTotalMg;
  final Value<double?> duringMassNormRateGPerH;
  final Value<double> postRunCarbsG;
  final Value<double> postRunProteinG;
  final Value<double> postRunFluidsMl;
  final Value<double> postRunSodiumMg;
  final Value<double> distanceMi;
  final Value<double> durationH;
  final Value<double> paceMinPerMile;
  final Value<double> caloriesGrossKcal;
  final Value<double> met;
  final Value<String> calculationRule;
  final Value<DateTime> timestamp;
  final Value<bool> isUserModified;
  final Value<String> modifiedFields;
  final Value<int> rowid;
  const MacroTargetsTableCompanion({
    this.id = const Value.absent(),
    this.preRunCarbsG = const Value.absent(),
    this.preRunProteinG = const Value.absent(),
    this.preRunFatCapG = const Value.absent(),
    this.preRunFluidsMl = const Value.absent(),
    this.preRunSodiumMg = const Value.absent(),
    this.duringCarbRateGPerH = const Value.absent(),
    this.duringCarbTotalG = const Value.absent(),
    this.duringFluidRateMlPerH = const Value.absent(),
    this.duringFluidTotalMl = const Value.absent(),
    this.duringSodiumRateMgPerH = const Value.absent(),
    this.duringSodiumTotalMg = const Value.absent(),
    this.duringMassNormRateGPerH = const Value.absent(),
    this.postRunCarbsG = const Value.absent(),
    this.postRunProteinG = const Value.absent(),
    this.postRunFluidsMl = const Value.absent(),
    this.postRunSodiumMg = const Value.absent(),
    this.distanceMi = const Value.absent(),
    this.durationH = const Value.absent(),
    this.paceMinPerMile = const Value.absent(),
    this.caloriesGrossKcal = const Value.absent(),
    this.met = const Value.absent(),
    this.calculationRule = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isUserModified = const Value.absent(),
    this.modifiedFields = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MacroTargetsTableCompanion.insert({
    required String id,
    required double preRunCarbsG,
    required double preRunProteinG,
    required double preRunFatCapG,
    required double preRunFluidsMl,
    required double preRunSodiumMg,
    required double duringCarbRateGPerH,
    required double duringCarbTotalG,
    required double duringFluidRateMlPerH,
    required double duringFluidTotalMl,
    required double duringSodiumRateMgPerH,
    required double duringSodiumTotalMg,
    this.duringMassNormRateGPerH = const Value.absent(),
    required double postRunCarbsG,
    required double postRunProteinG,
    required double postRunFluidsMl,
    required double postRunSodiumMg,
    required double distanceMi,
    required double durationH,
    required double paceMinPerMile,
    required double caloriesGrossKcal,
    required double met,
    required String calculationRule,
    required DateTime timestamp,
    this.isUserModified = const Value.absent(),
    this.modifiedFields = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        preRunCarbsG = Value(preRunCarbsG),
        preRunProteinG = Value(preRunProteinG),
        preRunFatCapG = Value(preRunFatCapG),
        preRunFluidsMl = Value(preRunFluidsMl),
        preRunSodiumMg = Value(preRunSodiumMg),
        duringCarbRateGPerH = Value(duringCarbRateGPerH),
        duringCarbTotalG = Value(duringCarbTotalG),
        duringFluidRateMlPerH = Value(duringFluidRateMlPerH),
        duringFluidTotalMl = Value(duringFluidTotalMl),
        duringSodiumRateMgPerH = Value(duringSodiumRateMgPerH),
        duringSodiumTotalMg = Value(duringSodiumTotalMg),
        postRunCarbsG = Value(postRunCarbsG),
        postRunProteinG = Value(postRunProteinG),
        postRunFluidsMl = Value(postRunFluidsMl),
        postRunSodiumMg = Value(postRunSodiumMg),
        distanceMi = Value(distanceMi),
        durationH = Value(durationH),
        paceMinPerMile = Value(paceMinPerMile),
        caloriesGrossKcal = Value(caloriesGrossKcal),
        met = Value(met),
        calculationRule = Value(calculationRule),
        timestamp = Value(timestamp);
  static Insertable<MacroTargetsTableData> custom({
    Expression<String>? id,
    Expression<double>? preRunCarbsG,
    Expression<double>? preRunProteinG,
    Expression<double>? preRunFatCapG,
    Expression<double>? preRunFluidsMl,
    Expression<double>? preRunSodiumMg,
    Expression<double>? duringCarbRateGPerH,
    Expression<double>? duringCarbTotalG,
    Expression<double>? duringFluidRateMlPerH,
    Expression<double>? duringFluidTotalMl,
    Expression<double>? duringSodiumRateMgPerH,
    Expression<double>? duringSodiumTotalMg,
    Expression<double>? duringMassNormRateGPerH,
    Expression<double>? postRunCarbsG,
    Expression<double>? postRunProteinG,
    Expression<double>? postRunFluidsMl,
    Expression<double>? postRunSodiumMg,
    Expression<double>? distanceMi,
    Expression<double>? durationH,
    Expression<double>? paceMinPerMile,
    Expression<double>? caloriesGrossKcal,
    Expression<double>? met,
    Expression<String>? calculationRule,
    Expression<DateTime>? timestamp,
    Expression<bool>? isUserModified,
    Expression<String>? modifiedFields,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (preRunCarbsG != null) 'pre_run_carbs_g': preRunCarbsG,
      if (preRunProteinG != null) 'pre_run_protein_g': preRunProteinG,
      if (preRunFatCapG != null) 'pre_run_fat_cap_g': preRunFatCapG,
      if (preRunFluidsMl != null) 'pre_run_fluids_ml': preRunFluidsMl,
      if (preRunSodiumMg != null) 'pre_run_sodium_mg': preRunSodiumMg,
      if (duringCarbRateGPerH != null)
        'during_carb_rate_g_per_h': duringCarbRateGPerH,
      if (duringCarbTotalG != null) 'during_carb_total_g': duringCarbTotalG,
      if (duringFluidRateMlPerH != null)
        'during_fluid_rate_ml_per_h': duringFluidRateMlPerH,
      if (duringFluidTotalMl != null)
        'during_fluid_total_ml': duringFluidTotalMl,
      if (duringSodiumRateMgPerH != null)
        'during_sodium_rate_mg_per_h': duringSodiumRateMgPerH,
      if (duringSodiumTotalMg != null)
        'during_sodium_total_mg': duringSodiumTotalMg,
      if (duringMassNormRateGPerH != null)
        'during_mass_norm_rate_g_per_h': duringMassNormRateGPerH,
      if (postRunCarbsG != null) 'post_run_carbs_g': postRunCarbsG,
      if (postRunProteinG != null) 'post_run_protein_g': postRunProteinG,
      if (postRunFluidsMl != null) 'post_run_fluids_ml': postRunFluidsMl,
      if (postRunSodiumMg != null) 'post_run_sodium_mg': postRunSodiumMg,
      if (distanceMi != null) 'distance_mi': distanceMi,
      if (durationH != null) 'duration_h': durationH,
      if (paceMinPerMile != null) 'pace_min_per_mile': paceMinPerMile,
      if (caloriesGrossKcal != null) 'calories_gross_kcal': caloriesGrossKcal,
      if (met != null) 'met': met,
      if (calculationRule != null) 'calculation_rule': calculationRule,
      if (timestamp != null) 'timestamp': timestamp,
      if (isUserModified != null) 'is_user_modified': isUserModified,
      if (modifiedFields != null) 'modified_fields': modifiedFields,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MacroTargetsTableCompanion copyWith(
      {Value<String>? id,
      Value<double>? preRunCarbsG,
      Value<double>? preRunProteinG,
      Value<double>? preRunFatCapG,
      Value<double>? preRunFluidsMl,
      Value<double>? preRunSodiumMg,
      Value<double>? duringCarbRateGPerH,
      Value<double>? duringCarbTotalG,
      Value<double>? duringFluidRateMlPerH,
      Value<double>? duringFluidTotalMl,
      Value<double>? duringSodiumRateMgPerH,
      Value<double>? duringSodiumTotalMg,
      Value<double?>? duringMassNormRateGPerH,
      Value<double>? postRunCarbsG,
      Value<double>? postRunProteinG,
      Value<double>? postRunFluidsMl,
      Value<double>? postRunSodiumMg,
      Value<double>? distanceMi,
      Value<double>? durationH,
      Value<double>? paceMinPerMile,
      Value<double>? caloriesGrossKcal,
      Value<double>? met,
      Value<String>? calculationRule,
      Value<DateTime>? timestamp,
      Value<bool>? isUserModified,
      Value<String>? modifiedFields,
      Value<int>? rowid}) {
    return MacroTargetsTableCompanion(
      id: id ?? this.id,
      preRunCarbsG: preRunCarbsG ?? this.preRunCarbsG,
      preRunProteinG: preRunProteinG ?? this.preRunProteinG,
      preRunFatCapG: preRunFatCapG ?? this.preRunFatCapG,
      preRunFluidsMl: preRunFluidsMl ?? this.preRunFluidsMl,
      preRunSodiumMg: preRunSodiumMg ?? this.preRunSodiumMg,
      duringCarbRateGPerH: duringCarbRateGPerH ?? this.duringCarbRateGPerH,
      duringCarbTotalG: duringCarbTotalG ?? this.duringCarbTotalG,
      duringFluidRateMlPerH:
          duringFluidRateMlPerH ?? this.duringFluidRateMlPerH,
      duringFluidTotalMl: duringFluidTotalMl ?? this.duringFluidTotalMl,
      duringSodiumRateMgPerH:
          duringSodiumRateMgPerH ?? this.duringSodiumRateMgPerH,
      duringSodiumTotalMg: duringSodiumTotalMg ?? this.duringSodiumTotalMg,
      duringMassNormRateGPerH:
          duringMassNormRateGPerH ?? this.duringMassNormRateGPerH,
      postRunCarbsG: postRunCarbsG ?? this.postRunCarbsG,
      postRunProteinG: postRunProteinG ?? this.postRunProteinG,
      postRunFluidsMl: postRunFluidsMl ?? this.postRunFluidsMl,
      postRunSodiumMg: postRunSodiumMg ?? this.postRunSodiumMg,
      distanceMi: distanceMi ?? this.distanceMi,
      durationH: durationH ?? this.durationH,
      paceMinPerMile: paceMinPerMile ?? this.paceMinPerMile,
      caloriesGrossKcal: caloriesGrossKcal ?? this.caloriesGrossKcal,
      met: met ?? this.met,
      calculationRule: calculationRule ?? this.calculationRule,
      timestamp: timestamp ?? this.timestamp,
      isUserModified: isUserModified ?? this.isUserModified,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (preRunCarbsG.present) {
      map['pre_run_carbs_g'] = Variable<double>(preRunCarbsG.value);
    }
    if (preRunProteinG.present) {
      map['pre_run_protein_g'] = Variable<double>(preRunProteinG.value);
    }
    if (preRunFatCapG.present) {
      map['pre_run_fat_cap_g'] = Variable<double>(preRunFatCapG.value);
    }
    if (preRunFluidsMl.present) {
      map['pre_run_fluids_ml'] = Variable<double>(preRunFluidsMl.value);
    }
    if (preRunSodiumMg.present) {
      map['pre_run_sodium_mg'] = Variable<double>(preRunSodiumMg.value);
    }
    if (duringCarbRateGPerH.present) {
      map['during_carb_rate_g_per_h'] =
          Variable<double>(duringCarbRateGPerH.value);
    }
    if (duringCarbTotalG.present) {
      map['during_carb_total_g'] = Variable<double>(duringCarbTotalG.value);
    }
    if (duringFluidRateMlPerH.present) {
      map['during_fluid_rate_ml_per_h'] =
          Variable<double>(duringFluidRateMlPerH.value);
    }
    if (duringFluidTotalMl.present) {
      map['during_fluid_total_ml'] = Variable<double>(duringFluidTotalMl.value);
    }
    if (duringSodiumRateMgPerH.present) {
      map['during_sodium_rate_mg_per_h'] =
          Variable<double>(duringSodiumRateMgPerH.value);
    }
    if (duringSodiumTotalMg.present) {
      map['during_sodium_total_mg'] =
          Variable<double>(duringSodiumTotalMg.value);
    }
    if (duringMassNormRateGPerH.present) {
      map['during_mass_norm_rate_g_per_h'] =
          Variable<double>(duringMassNormRateGPerH.value);
    }
    if (postRunCarbsG.present) {
      map['post_run_carbs_g'] = Variable<double>(postRunCarbsG.value);
    }
    if (postRunProteinG.present) {
      map['post_run_protein_g'] = Variable<double>(postRunProteinG.value);
    }
    if (postRunFluidsMl.present) {
      map['post_run_fluids_ml'] = Variable<double>(postRunFluidsMl.value);
    }
    if (postRunSodiumMg.present) {
      map['post_run_sodium_mg'] = Variable<double>(postRunSodiumMg.value);
    }
    if (distanceMi.present) {
      map['distance_mi'] = Variable<double>(distanceMi.value);
    }
    if (durationH.present) {
      map['duration_h'] = Variable<double>(durationH.value);
    }
    if (paceMinPerMile.present) {
      map['pace_min_per_mile'] = Variable<double>(paceMinPerMile.value);
    }
    if (caloriesGrossKcal.present) {
      map['calories_gross_kcal'] = Variable<double>(caloriesGrossKcal.value);
    }
    if (met.present) {
      map['met'] = Variable<double>(met.value);
    }
    if (calculationRule.present) {
      map['calculation_rule'] = Variable<String>(calculationRule.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (isUserModified.present) {
      map['is_user_modified'] = Variable<bool>(isUserModified.value);
    }
    if (modifiedFields.present) {
      map['modified_fields'] = Variable<String>(modifiedFields.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MacroTargetsTableCompanion(')
          ..write('id: $id, ')
          ..write('preRunCarbsG: $preRunCarbsG, ')
          ..write('preRunProteinG: $preRunProteinG, ')
          ..write('preRunFatCapG: $preRunFatCapG, ')
          ..write('preRunFluidsMl: $preRunFluidsMl, ')
          ..write('preRunSodiumMg: $preRunSodiumMg, ')
          ..write('duringCarbRateGPerH: $duringCarbRateGPerH, ')
          ..write('duringCarbTotalG: $duringCarbTotalG, ')
          ..write('duringFluidRateMlPerH: $duringFluidRateMlPerH, ')
          ..write('duringFluidTotalMl: $duringFluidTotalMl, ')
          ..write('duringSodiumRateMgPerH: $duringSodiumRateMgPerH, ')
          ..write('duringSodiumTotalMg: $duringSodiumTotalMg, ')
          ..write('duringMassNormRateGPerH: $duringMassNormRateGPerH, ')
          ..write('postRunCarbsG: $postRunCarbsG, ')
          ..write('postRunProteinG: $postRunProteinG, ')
          ..write('postRunFluidsMl: $postRunFluidsMl, ')
          ..write('postRunSodiumMg: $postRunSodiumMg, ')
          ..write('distanceMi: $distanceMi, ')
          ..write('durationH: $durationH, ')
          ..write('paceMinPerMile: $paceMinPerMile, ')
          ..write('caloriesGrossKcal: $caloriesGrossKcal, ')
          ..write('met: $met, ')
          ..write('calculationRule: $calculationRule, ')
          ..write('timestamp: $timestamp, ')
          ..write('isUserModified: $isUserModified, ')
          ..write('modifiedFields: $modifiedFields, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeedbackTableTable extends FeedbackTable
    with TableInfo<$FeedbackTableTable, FeedbackEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedbackTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _satisfactionLevelMeta =
      const VerificationMeta('satisfactionLevel');
  @override
  late final GeneratedColumn<int> satisfactionLevel = GeneratedColumn<int>(
      'satisfaction_level', aliasedName, false,
      check: () => ComparableExpr(satisfactionLevel).isBetweenValues(1, 3),
      type: DriftSqlType.int,
      requiredDuringInsert: true);
  static const VerificationMeta _satisfactionEmojiMeta =
      const VerificationMeta('satisfactionEmoji');
  @override
  late final GeneratedColumn<String> satisfactionEmoji =
      GeneratedColumn<String>('satisfaction_emoji', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _satisfactionLabelMeta =
      const VerificationMeta('satisfactionLabel');
  @override
  late final GeneratedColumn<String> satisfactionLabel =
      GeneratedColumn<String>('satisfaction_label', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _appFeedbackMeta =
      const VerificationMeta('appFeedback');
  @override
  late final GeneratedColumn<String> appFeedback = GeneratedColumn<String>(
      'app_feedback', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _suggestionsMeta =
      const VerificationMeta('suggestions');
  @override
  late final GeneratedColumn<String> suggestions = GeneratedColumn<String>(
      'suggestions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _planNameMeta =
      const VerificationMeta('planName');
  @override
  late final GeneratedColumn<String> planName = GeneratedColumn<String>(
      'plan_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userNameMeta =
      const VerificationMeta('userName');
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
      'user_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _confidenceLevelMeta =
      const VerificationMeta('confidenceLevel');
  @override
  late final GeneratedColumn<int> confidenceLevel = GeneratedColumn<int>(
      'confidence_level', aliasedName, true,
      check: () => ComparableExpr(confidenceLevel).isBetweenValues(1, 5),
      type: DriftSqlType.int,
      requiredDuringInsert: false);
  static const VerificationMeta _confidenceLabelMeta =
      const VerificationMeta('confidenceLabel');
  @override
  late final GeneratedColumn<String> confidenceLabel = GeneratedColumn<String>(
      'confidence_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reuseIntentMeta =
      const VerificationMeta('reuseIntent');
  @override
  late final GeneratedColumn<String> reuseIntent = GeneratedColumn<String>(
      'reuse_intent', aliasedName, true,
      check: () => reuseIntent.isIn(['yes', 'maybe', 'no']),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _reminderRequestedMeta =
      const VerificationMeta('reminderRequested');
  @override
  late final GeneratedColumn<bool> reminderRequested = GeneratedColumn<bool>(
      'reminder_requested', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("reminder_requested" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _missedReasonsMeta =
      const VerificationMeta('missedReasons');
  @override
  late final GeneratedColumn<String> missedReasons = GeneratedColumn<String>(
      'missed_reasons', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _missedOtherMeta =
      const VerificationMeta('missedOther');
  @override
  late final GeneratedColumn<String> missedOther = GeneratedColumn<String>(
      'missed_other', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reminderDayOfWeekMeta =
      const VerificationMeta('reminderDayOfWeek');
  @override
  late final GeneratedColumn<int> reminderDayOfWeek = GeneratedColumn<int>(
      'reminder_day_of_week', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reminderHourMeta =
      const VerificationMeta('reminderHour');
  @override
  late final GeneratedColumn<int> reminderHour = GeneratedColumn<int>(
      'reminder_hour', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(17));
  static const VerificationMeta _reminderMinuteMeta =
      const VerificationMeta('reminderMinute');
  @override
  late final GeneratedColumn<int> reminderMinute = GeneratedColumn<int>(
      'reminder_minute', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _reminderRecurringMeta =
      const VerificationMeta('reminderRecurring');
  @override
  late final GeneratedColumn<bool> reminderRecurring = GeneratedColumn<bool>(
      'reminder_recurring', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("reminder_recurring" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deviceId,
        satisfactionLevel,
        satisfactionEmoji,
        satisfactionLabel,
        appFeedback,
        suggestions,
        planName,
        userName,
        timestamp,
        confidenceLevel,
        confidenceLabel,
        reuseIntent,
        reminderRequested,
        missedReasons,
        missedOther,
        reminderDayOfWeek,
        reminderHour,
        reminderMinute,
        reminderRecurring,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feedback';
  @override
  VerificationContext validateIntegrity(Insertable<FeedbackEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('satisfaction_level')) {
      context.handle(
          _satisfactionLevelMeta,
          satisfactionLevel.isAcceptableOrUnknown(
              data['satisfaction_level']!, _satisfactionLevelMeta));
    } else if (isInserting) {
      context.missing(_satisfactionLevelMeta);
    }
    if (data.containsKey('satisfaction_emoji')) {
      context.handle(
          _satisfactionEmojiMeta,
          satisfactionEmoji.isAcceptableOrUnknown(
              data['satisfaction_emoji']!, _satisfactionEmojiMeta));
    } else if (isInserting) {
      context.missing(_satisfactionEmojiMeta);
    }
    if (data.containsKey('satisfaction_label')) {
      context.handle(
          _satisfactionLabelMeta,
          satisfactionLabel.isAcceptableOrUnknown(
              data['satisfaction_label']!, _satisfactionLabelMeta));
    } else if (isInserting) {
      context.missing(_satisfactionLabelMeta);
    }
    if (data.containsKey('app_feedback')) {
      context.handle(
          _appFeedbackMeta,
          appFeedback.isAcceptableOrUnknown(
              data['app_feedback']!, _appFeedbackMeta));
    }
    if (data.containsKey('suggestions')) {
      context.handle(
          _suggestionsMeta,
          suggestions.isAcceptableOrUnknown(
              data['suggestions']!, _suggestionsMeta));
    }
    if (data.containsKey('plan_name')) {
      context.handle(_planNameMeta,
          planName.isAcceptableOrUnknown(data['plan_name']!, _planNameMeta));
    }
    if (data.containsKey('user_name')) {
      context.handle(_userNameMeta,
          userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('confidence_level')) {
      context.handle(
          _confidenceLevelMeta,
          confidenceLevel.isAcceptableOrUnknown(
              data['confidence_level']!, _confidenceLevelMeta));
    }
    if (data.containsKey('confidence_label')) {
      context.handle(
          _confidenceLabelMeta,
          confidenceLabel.isAcceptableOrUnknown(
              data['confidence_label']!, _confidenceLabelMeta));
    }
    if (data.containsKey('reuse_intent')) {
      context.handle(
          _reuseIntentMeta,
          reuseIntent.isAcceptableOrUnknown(
              data['reuse_intent']!, _reuseIntentMeta));
    }
    if (data.containsKey('reminder_requested')) {
      context.handle(
          _reminderRequestedMeta,
          reminderRequested.isAcceptableOrUnknown(
              data['reminder_requested']!, _reminderRequestedMeta));
    }
    if (data.containsKey('missed_reasons')) {
      context.handle(
          _missedReasonsMeta,
          missedReasons.isAcceptableOrUnknown(
              data['missed_reasons']!, _missedReasonsMeta));
    }
    if (data.containsKey('missed_other')) {
      context.handle(
          _missedOtherMeta,
          missedOther.isAcceptableOrUnknown(
              data['missed_other']!, _missedOtherMeta));
    }
    if (data.containsKey('reminder_day_of_week')) {
      context.handle(
          _reminderDayOfWeekMeta,
          reminderDayOfWeek.isAcceptableOrUnknown(
              data['reminder_day_of_week']!, _reminderDayOfWeekMeta));
    }
    if (data.containsKey('reminder_hour')) {
      context.handle(
          _reminderHourMeta,
          reminderHour.isAcceptableOrUnknown(
              data['reminder_hour']!, _reminderHourMeta));
    }
    if (data.containsKey('reminder_minute')) {
      context.handle(
          _reminderMinuteMeta,
          reminderMinute.isAcceptableOrUnknown(
              data['reminder_minute']!, _reminderMinuteMeta));
    }
    if (data.containsKey('reminder_recurring')) {
      context.handle(
          _reminderRecurringMeta,
          reminderRecurring.isAcceptableOrUnknown(
              data['reminder_recurring']!, _reminderRecurringMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeedbackEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedbackEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id']),
      satisfactionLevel: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}satisfaction_level'])!,
      satisfactionEmoji: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}satisfaction_emoji'])!,
      satisfactionLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}satisfaction_label'])!,
      appFeedback: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_feedback']),
      suggestions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}suggestions']),
      planName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_name']),
      userName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_name']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp']),
      confidenceLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}confidence_level']),
      confidenceLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}confidence_label']),
      reuseIntent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reuse_intent']),
      reminderRequested: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}reminder_requested'])!,
      missedReasons: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}missed_reasons']),
      missedOther: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}missed_other']),
      reminderDayOfWeek: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}reminder_day_of_week']),
      reminderHour: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reminder_hour'])!,
      reminderMinute: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reminder_minute'])!,
      reminderRecurring: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}reminder_recurring'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $FeedbackTableTable createAlias(String alias) {
    return $FeedbackTableTable(attachedDatabase, alias);
  }
}

class FeedbackEntry extends DataClass implements Insertable<FeedbackEntry> {
  /// Primary key - auto-generated UUID
  final String id;

  /// Device ID to associate with user
  final String? deviceId;

  /// Original feedback fields (existing)
  final int satisfactionLevel;
  final String satisfactionEmoji;
  final String satisfactionLabel;
  final String? appFeedback;
  final String? suggestions;
  final String? planName;
  final String? userName;
  final DateTime? timestamp;

  /// New survey fields
  final int? confidenceLevel;
  final String? confidenceLabel;
  final String? reuseIntent;
  final bool reminderRequested;

  /// Missed reasons stored as JSON array (for single selection + other text)
  final String? missedReasons;
  final String? missedOther;

  /// Notification preferences
  final int? reminderDayOfWeek;
  final int reminderHour;
  final int reminderMinute;
  final bool reminderRecurring;

  /// Audit fields
  final DateTime createdAt;
  const FeedbackEntry(
      {required this.id,
      this.deviceId,
      required this.satisfactionLevel,
      required this.satisfactionEmoji,
      required this.satisfactionLabel,
      this.appFeedback,
      this.suggestions,
      this.planName,
      this.userName,
      this.timestamp,
      this.confidenceLevel,
      this.confidenceLabel,
      this.reuseIntent,
      required this.reminderRequested,
      this.missedReasons,
      this.missedOther,
      this.reminderDayOfWeek,
      required this.reminderHour,
      required this.reminderMinute,
      required this.reminderRecurring,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['satisfaction_level'] = Variable<int>(satisfactionLevel);
    map['satisfaction_emoji'] = Variable<String>(satisfactionEmoji);
    map['satisfaction_label'] = Variable<String>(satisfactionLabel);
    if (!nullToAbsent || appFeedback != null) {
      map['app_feedback'] = Variable<String>(appFeedback);
    }
    if (!nullToAbsent || suggestions != null) {
      map['suggestions'] = Variable<String>(suggestions);
    }
    if (!nullToAbsent || planName != null) {
      map['plan_name'] = Variable<String>(planName);
    }
    if (!nullToAbsent || userName != null) {
      map['user_name'] = Variable<String>(userName);
    }
    if (!nullToAbsent || timestamp != null) {
      map['timestamp'] = Variable<DateTime>(timestamp);
    }
    if (!nullToAbsent || confidenceLevel != null) {
      map['confidence_level'] = Variable<int>(confidenceLevel);
    }
    if (!nullToAbsent || confidenceLabel != null) {
      map['confidence_label'] = Variable<String>(confidenceLabel);
    }
    if (!nullToAbsent || reuseIntent != null) {
      map['reuse_intent'] = Variable<String>(reuseIntent);
    }
    map['reminder_requested'] = Variable<bool>(reminderRequested);
    if (!nullToAbsent || missedReasons != null) {
      map['missed_reasons'] = Variable<String>(missedReasons);
    }
    if (!nullToAbsent || missedOther != null) {
      map['missed_other'] = Variable<String>(missedOther);
    }
    if (!nullToAbsent || reminderDayOfWeek != null) {
      map['reminder_day_of_week'] = Variable<int>(reminderDayOfWeek);
    }
    map['reminder_hour'] = Variable<int>(reminderHour);
    map['reminder_minute'] = Variable<int>(reminderMinute);
    map['reminder_recurring'] = Variable<bool>(reminderRecurring);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FeedbackTableCompanion toCompanion(bool nullToAbsent) {
    return FeedbackTableCompanion(
      id: Value(id),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      satisfactionLevel: Value(satisfactionLevel),
      satisfactionEmoji: Value(satisfactionEmoji),
      satisfactionLabel: Value(satisfactionLabel),
      appFeedback: appFeedback == null && nullToAbsent
          ? const Value.absent()
          : Value(appFeedback),
      suggestions: suggestions == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestions),
      planName: planName == null && nullToAbsent
          ? const Value.absent()
          : Value(planName),
      userName: userName == null && nullToAbsent
          ? const Value.absent()
          : Value(userName),
      timestamp: timestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(timestamp),
      confidenceLevel: confidenceLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(confidenceLevel),
      confidenceLabel: confidenceLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(confidenceLabel),
      reuseIntent: reuseIntent == null && nullToAbsent
          ? const Value.absent()
          : Value(reuseIntent),
      reminderRequested: Value(reminderRequested),
      missedReasons: missedReasons == null && nullToAbsent
          ? const Value.absent()
          : Value(missedReasons),
      missedOther: missedOther == null && nullToAbsent
          ? const Value.absent()
          : Value(missedOther),
      reminderDayOfWeek: reminderDayOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderDayOfWeek),
      reminderHour: Value(reminderHour),
      reminderMinute: Value(reminderMinute),
      reminderRecurring: Value(reminderRecurring),
      createdAt: Value(createdAt),
    );
  }

  factory FeedbackEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedbackEntry(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      satisfactionLevel: serializer.fromJson<int>(json['satisfactionLevel']),
      satisfactionEmoji: serializer.fromJson<String>(json['satisfactionEmoji']),
      satisfactionLabel: serializer.fromJson<String>(json['satisfactionLabel']),
      appFeedback: serializer.fromJson<String?>(json['appFeedback']),
      suggestions: serializer.fromJson<String?>(json['suggestions']),
      planName: serializer.fromJson<String?>(json['planName']),
      userName: serializer.fromJson<String?>(json['userName']),
      timestamp: serializer.fromJson<DateTime?>(json['timestamp']),
      confidenceLevel: serializer.fromJson<int?>(json['confidenceLevel']),
      confidenceLabel: serializer.fromJson<String?>(json['confidenceLabel']),
      reuseIntent: serializer.fromJson<String?>(json['reuseIntent']),
      reminderRequested: serializer.fromJson<bool>(json['reminderRequested']),
      missedReasons: serializer.fromJson<String?>(json['missedReasons']),
      missedOther: serializer.fromJson<String?>(json['missedOther']),
      reminderDayOfWeek: serializer.fromJson<int?>(json['reminderDayOfWeek']),
      reminderHour: serializer.fromJson<int>(json['reminderHour']),
      reminderMinute: serializer.fromJson<int>(json['reminderMinute']),
      reminderRecurring: serializer.fromJson<bool>(json['reminderRecurring']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String?>(deviceId),
      'satisfactionLevel': serializer.toJson<int>(satisfactionLevel),
      'satisfactionEmoji': serializer.toJson<String>(satisfactionEmoji),
      'satisfactionLabel': serializer.toJson<String>(satisfactionLabel),
      'appFeedback': serializer.toJson<String?>(appFeedback),
      'suggestions': serializer.toJson<String?>(suggestions),
      'planName': serializer.toJson<String?>(planName),
      'userName': serializer.toJson<String?>(userName),
      'timestamp': serializer.toJson<DateTime?>(timestamp),
      'confidenceLevel': serializer.toJson<int?>(confidenceLevel),
      'confidenceLabel': serializer.toJson<String?>(confidenceLabel),
      'reuseIntent': serializer.toJson<String?>(reuseIntent),
      'reminderRequested': serializer.toJson<bool>(reminderRequested),
      'missedReasons': serializer.toJson<String?>(missedReasons),
      'missedOther': serializer.toJson<String?>(missedOther),
      'reminderDayOfWeek': serializer.toJson<int?>(reminderDayOfWeek),
      'reminderHour': serializer.toJson<int>(reminderHour),
      'reminderMinute': serializer.toJson<int>(reminderMinute),
      'reminderRecurring': serializer.toJson<bool>(reminderRecurring),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FeedbackEntry copyWith(
          {String? id,
          Value<String?> deviceId = const Value.absent(),
          int? satisfactionLevel,
          String? satisfactionEmoji,
          String? satisfactionLabel,
          Value<String?> appFeedback = const Value.absent(),
          Value<String?> suggestions = const Value.absent(),
          Value<String?> planName = const Value.absent(),
          Value<String?> userName = const Value.absent(),
          Value<DateTime?> timestamp = const Value.absent(),
          Value<int?> confidenceLevel = const Value.absent(),
          Value<String?> confidenceLabel = const Value.absent(),
          Value<String?> reuseIntent = const Value.absent(),
          bool? reminderRequested,
          Value<String?> missedReasons = const Value.absent(),
          Value<String?> missedOther = const Value.absent(),
          Value<int?> reminderDayOfWeek = const Value.absent(),
          int? reminderHour,
          int? reminderMinute,
          bool? reminderRecurring,
          DateTime? createdAt}) =>
      FeedbackEntry(
        id: id ?? this.id,
        deviceId: deviceId.present ? deviceId.value : this.deviceId,
        satisfactionLevel: satisfactionLevel ?? this.satisfactionLevel,
        satisfactionEmoji: satisfactionEmoji ?? this.satisfactionEmoji,
        satisfactionLabel: satisfactionLabel ?? this.satisfactionLabel,
        appFeedback: appFeedback.present ? appFeedback.value : this.appFeedback,
        suggestions: suggestions.present ? suggestions.value : this.suggestions,
        planName: planName.present ? planName.value : this.planName,
        userName: userName.present ? userName.value : this.userName,
        timestamp: timestamp.present ? timestamp.value : this.timestamp,
        confidenceLevel: confidenceLevel.present
            ? confidenceLevel.value
            : this.confidenceLevel,
        confidenceLabel: confidenceLabel.present
            ? confidenceLabel.value
            : this.confidenceLabel,
        reuseIntent: reuseIntent.present ? reuseIntent.value : this.reuseIntent,
        reminderRequested: reminderRequested ?? this.reminderRequested,
        missedReasons:
            missedReasons.present ? missedReasons.value : this.missedReasons,
        missedOther: missedOther.present ? missedOther.value : this.missedOther,
        reminderDayOfWeek: reminderDayOfWeek.present
            ? reminderDayOfWeek.value
            : this.reminderDayOfWeek,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        reminderRecurring: reminderRecurring ?? this.reminderRecurring,
        createdAt: createdAt ?? this.createdAt,
      );
  FeedbackEntry copyWithCompanion(FeedbackTableCompanion data) {
    return FeedbackEntry(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      satisfactionLevel: data.satisfactionLevel.present
          ? data.satisfactionLevel.value
          : this.satisfactionLevel,
      satisfactionEmoji: data.satisfactionEmoji.present
          ? data.satisfactionEmoji.value
          : this.satisfactionEmoji,
      satisfactionLabel: data.satisfactionLabel.present
          ? data.satisfactionLabel.value
          : this.satisfactionLabel,
      appFeedback:
          data.appFeedback.present ? data.appFeedback.value : this.appFeedback,
      suggestions:
          data.suggestions.present ? data.suggestions.value : this.suggestions,
      planName: data.planName.present ? data.planName.value : this.planName,
      userName: data.userName.present ? data.userName.value : this.userName,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      confidenceLevel: data.confidenceLevel.present
          ? data.confidenceLevel.value
          : this.confidenceLevel,
      confidenceLabel: data.confidenceLabel.present
          ? data.confidenceLabel.value
          : this.confidenceLabel,
      reuseIntent:
          data.reuseIntent.present ? data.reuseIntent.value : this.reuseIntent,
      reminderRequested: data.reminderRequested.present
          ? data.reminderRequested.value
          : this.reminderRequested,
      missedReasons: data.missedReasons.present
          ? data.missedReasons.value
          : this.missedReasons,
      missedOther:
          data.missedOther.present ? data.missedOther.value : this.missedOther,
      reminderDayOfWeek: data.reminderDayOfWeek.present
          ? data.reminderDayOfWeek.value
          : this.reminderDayOfWeek,
      reminderHour: data.reminderHour.present
          ? data.reminderHour.value
          : this.reminderHour,
      reminderMinute: data.reminderMinute.present
          ? data.reminderMinute.value
          : this.reminderMinute,
      reminderRecurring: data.reminderRecurring.present
          ? data.reminderRecurring.value
          : this.reminderRecurring,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedbackEntry(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('satisfactionLevel: $satisfactionLevel, ')
          ..write('satisfactionEmoji: $satisfactionEmoji, ')
          ..write('satisfactionLabel: $satisfactionLabel, ')
          ..write('appFeedback: $appFeedback, ')
          ..write('suggestions: $suggestions, ')
          ..write('planName: $planName, ')
          ..write('userName: $userName, ')
          ..write('timestamp: $timestamp, ')
          ..write('confidenceLevel: $confidenceLevel, ')
          ..write('confidenceLabel: $confidenceLabel, ')
          ..write('reuseIntent: $reuseIntent, ')
          ..write('reminderRequested: $reminderRequested, ')
          ..write('missedReasons: $missedReasons, ')
          ..write('missedOther: $missedOther, ')
          ..write('reminderDayOfWeek: $reminderDayOfWeek, ')
          ..write('reminderHour: $reminderHour, ')
          ..write('reminderMinute: $reminderMinute, ')
          ..write('reminderRecurring: $reminderRecurring, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        deviceId,
        satisfactionLevel,
        satisfactionEmoji,
        satisfactionLabel,
        appFeedback,
        suggestions,
        planName,
        userName,
        timestamp,
        confidenceLevel,
        confidenceLabel,
        reuseIntent,
        reminderRequested,
        missedReasons,
        missedOther,
        reminderDayOfWeek,
        reminderHour,
        reminderMinute,
        reminderRecurring,
        createdAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedbackEntry &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.satisfactionLevel == this.satisfactionLevel &&
          other.satisfactionEmoji == this.satisfactionEmoji &&
          other.satisfactionLabel == this.satisfactionLabel &&
          other.appFeedback == this.appFeedback &&
          other.suggestions == this.suggestions &&
          other.planName == this.planName &&
          other.userName == this.userName &&
          other.timestamp == this.timestamp &&
          other.confidenceLevel == this.confidenceLevel &&
          other.confidenceLabel == this.confidenceLabel &&
          other.reuseIntent == this.reuseIntent &&
          other.reminderRequested == this.reminderRequested &&
          other.missedReasons == this.missedReasons &&
          other.missedOther == this.missedOther &&
          other.reminderDayOfWeek == this.reminderDayOfWeek &&
          other.reminderHour == this.reminderHour &&
          other.reminderMinute == this.reminderMinute &&
          other.reminderRecurring == this.reminderRecurring &&
          other.createdAt == this.createdAt);
}

class FeedbackTableCompanion extends UpdateCompanion<FeedbackEntry> {
  final Value<String> id;
  final Value<String?> deviceId;
  final Value<int> satisfactionLevel;
  final Value<String> satisfactionEmoji;
  final Value<String> satisfactionLabel;
  final Value<String?> appFeedback;
  final Value<String?> suggestions;
  final Value<String?> planName;
  final Value<String?> userName;
  final Value<DateTime?> timestamp;
  final Value<int?> confidenceLevel;
  final Value<String?> confidenceLabel;
  final Value<String?> reuseIntent;
  final Value<bool> reminderRequested;
  final Value<String?> missedReasons;
  final Value<String?> missedOther;
  final Value<int?> reminderDayOfWeek;
  final Value<int> reminderHour;
  final Value<int> reminderMinute;
  final Value<bool> reminderRecurring;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FeedbackTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.satisfactionLevel = const Value.absent(),
    this.satisfactionEmoji = const Value.absent(),
    this.satisfactionLabel = const Value.absent(),
    this.appFeedback = const Value.absent(),
    this.suggestions = const Value.absent(),
    this.planName = const Value.absent(),
    this.userName = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.confidenceLevel = const Value.absent(),
    this.confidenceLabel = const Value.absent(),
    this.reuseIntent = const Value.absent(),
    this.reminderRequested = const Value.absent(),
    this.missedReasons = const Value.absent(),
    this.missedOther = const Value.absent(),
    this.reminderDayOfWeek = const Value.absent(),
    this.reminderHour = const Value.absent(),
    this.reminderMinute = const Value.absent(),
    this.reminderRecurring = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedbackTableCompanion.insert({
    required String id,
    this.deviceId = const Value.absent(),
    required int satisfactionLevel,
    required String satisfactionEmoji,
    required String satisfactionLabel,
    this.appFeedback = const Value.absent(),
    this.suggestions = const Value.absent(),
    this.planName = const Value.absent(),
    this.userName = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.confidenceLevel = const Value.absent(),
    this.confidenceLabel = const Value.absent(),
    this.reuseIntent = const Value.absent(),
    this.reminderRequested = const Value.absent(),
    this.missedReasons = const Value.absent(),
    this.missedOther = const Value.absent(),
    this.reminderDayOfWeek = const Value.absent(),
    this.reminderHour = const Value.absent(),
    this.reminderMinute = const Value.absent(),
    this.reminderRecurring = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        satisfactionLevel = Value(satisfactionLevel),
        satisfactionEmoji = Value(satisfactionEmoji),
        satisfactionLabel = Value(satisfactionLabel);
  static Insertable<FeedbackEntry> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<int>? satisfactionLevel,
    Expression<String>? satisfactionEmoji,
    Expression<String>? satisfactionLabel,
    Expression<String>? appFeedback,
    Expression<String>? suggestions,
    Expression<String>? planName,
    Expression<String>? userName,
    Expression<DateTime>? timestamp,
    Expression<int>? confidenceLevel,
    Expression<String>? confidenceLabel,
    Expression<String>? reuseIntent,
    Expression<bool>? reminderRequested,
    Expression<String>? missedReasons,
    Expression<String>? missedOther,
    Expression<int>? reminderDayOfWeek,
    Expression<int>? reminderHour,
    Expression<int>? reminderMinute,
    Expression<bool>? reminderRecurring,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (satisfactionLevel != null) 'satisfaction_level': satisfactionLevel,
      if (satisfactionEmoji != null) 'satisfaction_emoji': satisfactionEmoji,
      if (satisfactionLabel != null) 'satisfaction_label': satisfactionLabel,
      if (appFeedback != null) 'app_feedback': appFeedback,
      if (suggestions != null) 'suggestions': suggestions,
      if (planName != null) 'plan_name': planName,
      if (userName != null) 'user_name': userName,
      if (timestamp != null) 'timestamp': timestamp,
      if (confidenceLevel != null) 'confidence_level': confidenceLevel,
      if (confidenceLabel != null) 'confidence_label': confidenceLabel,
      if (reuseIntent != null) 'reuse_intent': reuseIntent,
      if (reminderRequested != null) 'reminder_requested': reminderRequested,
      if (missedReasons != null) 'missed_reasons': missedReasons,
      if (missedOther != null) 'missed_other': missedOther,
      if (reminderDayOfWeek != null) 'reminder_day_of_week': reminderDayOfWeek,
      if (reminderHour != null) 'reminder_hour': reminderHour,
      if (reminderMinute != null) 'reminder_minute': reminderMinute,
      if (reminderRecurring != null) 'reminder_recurring': reminderRecurring,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedbackTableCompanion copyWith(
      {Value<String>? id,
      Value<String?>? deviceId,
      Value<int>? satisfactionLevel,
      Value<String>? satisfactionEmoji,
      Value<String>? satisfactionLabel,
      Value<String?>? appFeedback,
      Value<String?>? suggestions,
      Value<String?>? planName,
      Value<String?>? userName,
      Value<DateTime?>? timestamp,
      Value<int?>? confidenceLevel,
      Value<String?>? confidenceLabel,
      Value<String?>? reuseIntent,
      Value<bool>? reminderRequested,
      Value<String?>? missedReasons,
      Value<String?>? missedOther,
      Value<int?>? reminderDayOfWeek,
      Value<int>? reminderHour,
      Value<int>? reminderMinute,
      Value<bool>? reminderRecurring,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return FeedbackTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      satisfactionLevel: satisfactionLevel ?? this.satisfactionLevel,
      satisfactionEmoji: satisfactionEmoji ?? this.satisfactionEmoji,
      satisfactionLabel: satisfactionLabel ?? this.satisfactionLabel,
      appFeedback: appFeedback ?? this.appFeedback,
      suggestions: suggestions ?? this.suggestions,
      planName: planName ?? this.planName,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
      reuseIntent: reuseIntent ?? this.reuseIntent,
      reminderRequested: reminderRequested ?? this.reminderRequested,
      missedReasons: missedReasons ?? this.missedReasons,
      missedOther: missedOther ?? this.missedOther,
      reminderDayOfWeek: reminderDayOfWeek ?? this.reminderDayOfWeek,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderRecurring: reminderRecurring ?? this.reminderRecurring,
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (satisfactionLevel.present) {
      map['satisfaction_level'] = Variable<int>(satisfactionLevel.value);
    }
    if (satisfactionEmoji.present) {
      map['satisfaction_emoji'] = Variable<String>(satisfactionEmoji.value);
    }
    if (satisfactionLabel.present) {
      map['satisfaction_label'] = Variable<String>(satisfactionLabel.value);
    }
    if (appFeedback.present) {
      map['app_feedback'] = Variable<String>(appFeedback.value);
    }
    if (suggestions.present) {
      map['suggestions'] = Variable<String>(suggestions.value);
    }
    if (planName.present) {
      map['plan_name'] = Variable<String>(planName.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (confidenceLevel.present) {
      map['confidence_level'] = Variable<int>(confidenceLevel.value);
    }
    if (confidenceLabel.present) {
      map['confidence_label'] = Variable<String>(confidenceLabel.value);
    }
    if (reuseIntent.present) {
      map['reuse_intent'] = Variable<String>(reuseIntent.value);
    }
    if (reminderRequested.present) {
      map['reminder_requested'] = Variable<bool>(reminderRequested.value);
    }
    if (missedReasons.present) {
      map['missed_reasons'] = Variable<String>(missedReasons.value);
    }
    if (missedOther.present) {
      map['missed_other'] = Variable<String>(missedOther.value);
    }
    if (reminderDayOfWeek.present) {
      map['reminder_day_of_week'] = Variable<int>(reminderDayOfWeek.value);
    }
    if (reminderHour.present) {
      map['reminder_hour'] = Variable<int>(reminderHour.value);
    }
    if (reminderMinute.present) {
      map['reminder_minute'] = Variable<int>(reminderMinute.value);
    }
    if (reminderRecurring.present) {
      map['reminder_recurring'] = Variable<bool>(reminderRecurring.value);
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
    return (StringBuffer('FeedbackTableCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('satisfactionLevel: $satisfactionLevel, ')
          ..write('satisfactionEmoji: $satisfactionEmoji, ')
          ..write('satisfactionLabel: $satisfactionLabel, ')
          ..write('appFeedback: $appFeedback, ')
          ..write('suggestions: $suggestions, ')
          ..write('planName: $planName, ')
          ..write('userName: $userName, ')
          ..write('timestamp: $timestamp, ')
          ..write('confidenceLevel: $confidenceLevel, ')
          ..write('confidenceLabel: $confidenceLabel, ')
          ..write('reuseIntent: $reuseIntent, ')
          ..write('reminderRequested: $reminderRequested, ')
          ..write('missedReasons: $missedReasons, ')
          ..write('missedOther: $missedOther, ')
          ..write('reminderDayOfWeek: $reminderDayOfWeek, ')
          ..write('reminderHour: $reminderHour, ')
          ..write('reminderMinute: $reminderMinute, ')
          ..write('reminderRecurring: $reminderRecurring, ')
          ..write('createdAt: $createdAt, ')
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
  late final $MacroTargetsTableTable macroTargetsTable =
      $MacroTargetsTableTable(this);
  late final $FeedbackTableTable feedbackTable = $FeedbackTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        userProfilesTable,
        foodPreferencesTable,
        nutritionPlans,
        macroTargetsTable,
        feedbackTable
      ];
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
  Value<bool> notificationsEnabled,
  Value<int> defaultReminderDay,
  Value<int> defaultReminderHour,
  Value<int> defaultReminderMinute,
  Value<bool> defaultReminderRecurring,
  Value<String?> tempPlanData,
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
  Value<bool> notificationsEnabled,
  Value<int> defaultReminderDay,
  Value<int> defaultReminderHour,
  Value<int> defaultReminderMinute,
  Value<bool> defaultReminderRecurring,
  Value<String?> tempPlanData,
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

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
      column: $table.notificationsEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultReminderDay => $composableBuilder(
      column: $table.defaultReminderDay,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultReminderHour => $composableBuilder(
      column: $table.defaultReminderHour,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultReminderMinute => $composableBuilder(
      column: $table.defaultReminderMinute,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get defaultReminderRecurring => $composableBuilder(
      column: $table.defaultReminderRecurring,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tempPlanData => $composableBuilder(
      column: $table.tempPlanData, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
      column: $table.notificationsEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultReminderDay => $composableBuilder(
      column: $table.defaultReminderDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultReminderHour => $composableBuilder(
      column: $table.defaultReminderHour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultReminderMinute => $composableBuilder(
      column: $table.defaultReminderMinute,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get defaultReminderRecurring => $composableBuilder(
      column: $table.defaultReminderRecurring,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tempPlanData => $composableBuilder(
      column: $table.tempPlanData,
      builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
      column: $table.notificationsEnabled, builder: (column) => column);

  GeneratedColumn<int> get defaultReminderDay => $composableBuilder(
      column: $table.defaultReminderDay, builder: (column) => column);

  GeneratedColumn<int> get defaultReminderHour => $composableBuilder(
      column: $table.defaultReminderHour, builder: (column) => column);

  GeneratedColumn<int> get defaultReminderMinute => $composableBuilder(
      column: $table.defaultReminderMinute, builder: (column) => column);

  GeneratedColumn<bool> get defaultReminderRecurring => $composableBuilder(
      column: $table.defaultReminderRecurring, builder: (column) => column);

  GeneratedColumn<String> get tempPlanData => $composableBuilder(
      column: $table.tempPlanData, builder: (column) => column);
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
            Value<bool> notificationsEnabled = const Value.absent(),
            Value<int> defaultReminderDay = const Value.absent(),
            Value<int> defaultReminderHour = const Value.absent(),
            Value<int> defaultReminderMinute = const Value.absent(),
            Value<bool> defaultReminderRecurring = const Value.absent(),
            Value<String?> tempPlanData = const Value.absent(),
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
            notificationsEnabled: notificationsEnabled,
            defaultReminderDay: defaultReminderDay,
            defaultReminderHour: defaultReminderHour,
            defaultReminderMinute: defaultReminderMinute,
            defaultReminderRecurring: defaultReminderRecurring,
            tempPlanData: tempPlanData,
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
            Value<bool> notificationsEnabled = const Value.absent(),
            Value<int> defaultReminderDay = const Value.absent(),
            Value<int> defaultReminderHour = const Value.absent(),
            Value<int> defaultReminderMinute = const Value.absent(),
            Value<bool> defaultReminderRecurring = const Value.absent(),
            Value<String?> tempPlanData = const Value.absent(),
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
            notificationsEnabled: notificationsEnabled,
            defaultReminderDay: defaultReminderDay,
            defaultReminderHour: defaultReminderHour,
            defaultReminderMinute: defaultReminderMinute,
            defaultReminderRecurring: defaultReminderRecurring,
            tempPlanData: tempPlanData,
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
typedef $$MacroTargetsTableTableCreateCompanionBuilder
    = MacroTargetsTableCompanion Function({
  required String id,
  required double preRunCarbsG,
  required double preRunProteinG,
  required double preRunFatCapG,
  required double preRunFluidsMl,
  required double preRunSodiumMg,
  required double duringCarbRateGPerH,
  required double duringCarbTotalG,
  required double duringFluidRateMlPerH,
  required double duringFluidTotalMl,
  required double duringSodiumRateMgPerH,
  required double duringSodiumTotalMg,
  Value<double?> duringMassNormRateGPerH,
  required double postRunCarbsG,
  required double postRunProteinG,
  required double postRunFluidsMl,
  required double postRunSodiumMg,
  required double distanceMi,
  required double durationH,
  required double paceMinPerMile,
  required double caloriesGrossKcal,
  required double met,
  required String calculationRule,
  required DateTime timestamp,
  Value<bool> isUserModified,
  Value<String> modifiedFields,
  Value<int> rowid,
});
typedef $$MacroTargetsTableTableUpdateCompanionBuilder
    = MacroTargetsTableCompanion Function({
  Value<String> id,
  Value<double> preRunCarbsG,
  Value<double> preRunProteinG,
  Value<double> preRunFatCapG,
  Value<double> preRunFluidsMl,
  Value<double> preRunSodiumMg,
  Value<double> duringCarbRateGPerH,
  Value<double> duringCarbTotalG,
  Value<double> duringFluidRateMlPerH,
  Value<double> duringFluidTotalMl,
  Value<double> duringSodiumRateMgPerH,
  Value<double> duringSodiumTotalMg,
  Value<double?> duringMassNormRateGPerH,
  Value<double> postRunCarbsG,
  Value<double> postRunProteinG,
  Value<double> postRunFluidsMl,
  Value<double> postRunSodiumMg,
  Value<double> distanceMi,
  Value<double> durationH,
  Value<double> paceMinPerMile,
  Value<double> caloriesGrossKcal,
  Value<double> met,
  Value<String> calculationRule,
  Value<DateTime> timestamp,
  Value<bool> isUserModified,
  Value<String> modifiedFields,
  Value<int> rowid,
});

class $$MacroTargetsTableTableFilterComposer
    extends Composer<_$AppDatabase, $MacroTargetsTableTable> {
  $$MacroTargetsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get preRunCarbsG => $composableBuilder(
      column: $table.preRunCarbsG, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get preRunProteinG => $composableBuilder(
      column: $table.preRunProteinG,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get preRunFatCapG => $composableBuilder(
      column: $table.preRunFatCapG, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get preRunFluidsMl => $composableBuilder(
      column: $table.preRunFluidsMl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get preRunSodiumMg => $composableBuilder(
      column: $table.preRunSodiumMg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringCarbRateGPerH => $composableBuilder(
      column: $table.duringCarbRateGPerH,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringCarbTotalG => $composableBuilder(
      column: $table.duringCarbTotalG,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringFluidRateMlPerH => $composableBuilder(
      column: $table.duringFluidRateMlPerH,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringFluidTotalMl => $composableBuilder(
      column: $table.duringFluidTotalMl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringSodiumRateMgPerH => $composableBuilder(
      column: $table.duringSodiumRateMgPerH,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringSodiumTotalMg => $composableBuilder(
      column: $table.duringSodiumTotalMg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duringMassNormRateGPerH => $composableBuilder(
      column: $table.duringMassNormRateGPerH,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get postRunCarbsG => $composableBuilder(
      column: $table.postRunCarbsG, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get postRunProteinG => $composableBuilder(
      column: $table.postRunProteinG,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get postRunFluidsMl => $composableBuilder(
      column: $table.postRunFluidsMl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get postRunSodiumMg => $composableBuilder(
      column: $table.postRunSodiumMg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceMi => $composableBuilder(
      column: $table.distanceMi, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationH => $composableBuilder(
      column: $table.durationH, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paceMinPerMile => $composableBuilder(
      column: $table.paceMinPerMile,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get caloriesGrossKcal => $composableBuilder(
      column: $table.caloriesGrossKcal,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get met => $composableBuilder(
      column: $table.met, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get calculationRule => $composableBuilder(
      column: $table.calculationRule,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUserModified => $composableBuilder(
      column: $table.isUserModified,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modifiedFields => $composableBuilder(
      column: $table.modifiedFields,
      builder: (column) => ColumnFilters(column));
}

class $$MacroTargetsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MacroTargetsTableTable> {
  $$MacroTargetsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get preRunCarbsG => $composableBuilder(
      column: $table.preRunCarbsG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get preRunProteinG => $composableBuilder(
      column: $table.preRunProteinG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get preRunFatCapG => $composableBuilder(
      column: $table.preRunFatCapG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get preRunFluidsMl => $composableBuilder(
      column: $table.preRunFluidsMl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get preRunSodiumMg => $composableBuilder(
      column: $table.preRunSodiumMg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringCarbRateGPerH => $composableBuilder(
      column: $table.duringCarbRateGPerH,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringCarbTotalG => $composableBuilder(
      column: $table.duringCarbTotalG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringFluidRateMlPerH => $composableBuilder(
      column: $table.duringFluidRateMlPerH,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringFluidTotalMl => $composableBuilder(
      column: $table.duringFluidTotalMl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringSodiumRateMgPerH => $composableBuilder(
      column: $table.duringSodiumRateMgPerH,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringSodiumTotalMg => $composableBuilder(
      column: $table.duringSodiumTotalMg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duringMassNormRateGPerH => $composableBuilder(
      column: $table.duringMassNormRateGPerH,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get postRunCarbsG => $composableBuilder(
      column: $table.postRunCarbsG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get postRunProteinG => $composableBuilder(
      column: $table.postRunProteinG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get postRunFluidsMl => $composableBuilder(
      column: $table.postRunFluidsMl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get postRunSodiumMg => $composableBuilder(
      column: $table.postRunSodiumMg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceMi => $composableBuilder(
      column: $table.distanceMi, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationH => $composableBuilder(
      column: $table.durationH, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paceMinPerMile => $composableBuilder(
      column: $table.paceMinPerMile,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get caloriesGrossKcal => $composableBuilder(
      column: $table.caloriesGrossKcal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get met => $composableBuilder(
      column: $table.met, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get calculationRule => $composableBuilder(
      column: $table.calculationRule,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUserModified => $composableBuilder(
      column: $table.isUserModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modifiedFields => $composableBuilder(
      column: $table.modifiedFields,
      builder: (column) => ColumnOrderings(column));
}

class $$MacroTargetsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MacroTargetsTableTable> {
  $$MacroTargetsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get preRunCarbsG => $composableBuilder(
      column: $table.preRunCarbsG, builder: (column) => column);

  GeneratedColumn<double> get preRunProteinG => $composableBuilder(
      column: $table.preRunProteinG, builder: (column) => column);

  GeneratedColumn<double> get preRunFatCapG => $composableBuilder(
      column: $table.preRunFatCapG, builder: (column) => column);

  GeneratedColumn<double> get preRunFluidsMl => $composableBuilder(
      column: $table.preRunFluidsMl, builder: (column) => column);

  GeneratedColumn<double> get preRunSodiumMg => $composableBuilder(
      column: $table.preRunSodiumMg, builder: (column) => column);

  GeneratedColumn<double> get duringCarbRateGPerH => $composableBuilder(
      column: $table.duringCarbRateGPerH, builder: (column) => column);

  GeneratedColumn<double> get duringCarbTotalG => $composableBuilder(
      column: $table.duringCarbTotalG, builder: (column) => column);

  GeneratedColumn<double> get duringFluidRateMlPerH => $composableBuilder(
      column: $table.duringFluidRateMlPerH, builder: (column) => column);

  GeneratedColumn<double> get duringFluidTotalMl => $composableBuilder(
      column: $table.duringFluidTotalMl, builder: (column) => column);

  GeneratedColumn<double> get duringSodiumRateMgPerH => $composableBuilder(
      column: $table.duringSodiumRateMgPerH, builder: (column) => column);

  GeneratedColumn<double> get duringSodiumTotalMg => $composableBuilder(
      column: $table.duringSodiumTotalMg, builder: (column) => column);

  GeneratedColumn<double> get duringMassNormRateGPerH => $composableBuilder(
      column: $table.duringMassNormRateGPerH, builder: (column) => column);

  GeneratedColumn<double> get postRunCarbsG => $composableBuilder(
      column: $table.postRunCarbsG, builder: (column) => column);

  GeneratedColumn<double> get postRunProteinG => $composableBuilder(
      column: $table.postRunProteinG, builder: (column) => column);

  GeneratedColumn<double> get postRunFluidsMl => $composableBuilder(
      column: $table.postRunFluidsMl, builder: (column) => column);

  GeneratedColumn<double> get postRunSodiumMg => $composableBuilder(
      column: $table.postRunSodiumMg, builder: (column) => column);

  GeneratedColumn<double> get distanceMi => $composableBuilder(
      column: $table.distanceMi, builder: (column) => column);

  GeneratedColumn<double> get durationH =>
      $composableBuilder(column: $table.durationH, builder: (column) => column);

  GeneratedColumn<double> get paceMinPerMile => $composableBuilder(
      column: $table.paceMinPerMile, builder: (column) => column);

  GeneratedColumn<double> get caloriesGrossKcal => $composableBuilder(
      column: $table.caloriesGrossKcal, builder: (column) => column);

  GeneratedColumn<double> get met =>
      $composableBuilder(column: $table.met, builder: (column) => column);

  GeneratedColumn<String> get calculationRule => $composableBuilder(
      column: $table.calculationRule, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isUserModified => $composableBuilder(
      column: $table.isUserModified, builder: (column) => column);

  GeneratedColumn<String> get modifiedFields => $composableBuilder(
      column: $table.modifiedFields, builder: (column) => column);
}

class $$MacroTargetsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MacroTargetsTableTable,
    MacroTargetsTableData,
    $$MacroTargetsTableTableFilterComposer,
    $$MacroTargetsTableTableOrderingComposer,
    $$MacroTargetsTableTableAnnotationComposer,
    $$MacroTargetsTableTableCreateCompanionBuilder,
    $$MacroTargetsTableTableUpdateCompanionBuilder,
    (
      MacroTargetsTableData,
      BaseReferences<_$AppDatabase, $MacroTargetsTableTable,
          MacroTargetsTableData>
    ),
    MacroTargetsTableData,
    PrefetchHooks Function()> {
  $$MacroTargetsTableTableTableManager(
      _$AppDatabase db, $MacroTargetsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MacroTargetsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MacroTargetsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MacroTargetsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<double> preRunCarbsG = const Value.absent(),
            Value<double> preRunProteinG = const Value.absent(),
            Value<double> preRunFatCapG = const Value.absent(),
            Value<double> preRunFluidsMl = const Value.absent(),
            Value<double> preRunSodiumMg = const Value.absent(),
            Value<double> duringCarbRateGPerH = const Value.absent(),
            Value<double> duringCarbTotalG = const Value.absent(),
            Value<double> duringFluidRateMlPerH = const Value.absent(),
            Value<double> duringFluidTotalMl = const Value.absent(),
            Value<double> duringSodiumRateMgPerH = const Value.absent(),
            Value<double> duringSodiumTotalMg = const Value.absent(),
            Value<double?> duringMassNormRateGPerH = const Value.absent(),
            Value<double> postRunCarbsG = const Value.absent(),
            Value<double> postRunProteinG = const Value.absent(),
            Value<double> postRunFluidsMl = const Value.absent(),
            Value<double> postRunSodiumMg = const Value.absent(),
            Value<double> distanceMi = const Value.absent(),
            Value<double> durationH = const Value.absent(),
            Value<double> paceMinPerMile = const Value.absent(),
            Value<double> caloriesGrossKcal = const Value.absent(),
            Value<double> met = const Value.absent(),
            Value<String> calculationRule = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<bool> isUserModified = const Value.absent(),
            Value<String> modifiedFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MacroTargetsTableCompanion(
            id: id,
            preRunCarbsG: preRunCarbsG,
            preRunProteinG: preRunProteinG,
            preRunFatCapG: preRunFatCapG,
            preRunFluidsMl: preRunFluidsMl,
            preRunSodiumMg: preRunSodiumMg,
            duringCarbRateGPerH: duringCarbRateGPerH,
            duringCarbTotalG: duringCarbTotalG,
            duringFluidRateMlPerH: duringFluidRateMlPerH,
            duringFluidTotalMl: duringFluidTotalMl,
            duringSodiumRateMgPerH: duringSodiumRateMgPerH,
            duringSodiumTotalMg: duringSodiumTotalMg,
            duringMassNormRateGPerH: duringMassNormRateGPerH,
            postRunCarbsG: postRunCarbsG,
            postRunProteinG: postRunProteinG,
            postRunFluidsMl: postRunFluidsMl,
            postRunSodiumMg: postRunSodiumMg,
            distanceMi: distanceMi,
            durationH: durationH,
            paceMinPerMile: paceMinPerMile,
            caloriesGrossKcal: caloriesGrossKcal,
            met: met,
            calculationRule: calculationRule,
            timestamp: timestamp,
            isUserModified: isUserModified,
            modifiedFields: modifiedFields,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required double preRunCarbsG,
            required double preRunProteinG,
            required double preRunFatCapG,
            required double preRunFluidsMl,
            required double preRunSodiumMg,
            required double duringCarbRateGPerH,
            required double duringCarbTotalG,
            required double duringFluidRateMlPerH,
            required double duringFluidTotalMl,
            required double duringSodiumRateMgPerH,
            required double duringSodiumTotalMg,
            Value<double?> duringMassNormRateGPerH = const Value.absent(),
            required double postRunCarbsG,
            required double postRunProteinG,
            required double postRunFluidsMl,
            required double postRunSodiumMg,
            required double distanceMi,
            required double durationH,
            required double paceMinPerMile,
            required double caloriesGrossKcal,
            required double met,
            required String calculationRule,
            required DateTime timestamp,
            Value<bool> isUserModified = const Value.absent(),
            Value<String> modifiedFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MacroTargetsTableCompanion.insert(
            id: id,
            preRunCarbsG: preRunCarbsG,
            preRunProteinG: preRunProteinG,
            preRunFatCapG: preRunFatCapG,
            preRunFluidsMl: preRunFluidsMl,
            preRunSodiumMg: preRunSodiumMg,
            duringCarbRateGPerH: duringCarbRateGPerH,
            duringCarbTotalG: duringCarbTotalG,
            duringFluidRateMlPerH: duringFluidRateMlPerH,
            duringFluidTotalMl: duringFluidTotalMl,
            duringSodiumRateMgPerH: duringSodiumRateMgPerH,
            duringSodiumTotalMg: duringSodiumTotalMg,
            duringMassNormRateGPerH: duringMassNormRateGPerH,
            postRunCarbsG: postRunCarbsG,
            postRunProteinG: postRunProteinG,
            postRunFluidsMl: postRunFluidsMl,
            postRunSodiumMg: postRunSodiumMg,
            distanceMi: distanceMi,
            durationH: durationH,
            paceMinPerMile: paceMinPerMile,
            caloriesGrossKcal: caloriesGrossKcal,
            met: met,
            calculationRule: calculationRule,
            timestamp: timestamp,
            isUserModified: isUserModified,
            modifiedFields: modifiedFields,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MacroTargetsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MacroTargetsTableTable,
    MacroTargetsTableData,
    $$MacroTargetsTableTableFilterComposer,
    $$MacroTargetsTableTableOrderingComposer,
    $$MacroTargetsTableTableAnnotationComposer,
    $$MacroTargetsTableTableCreateCompanionBuilder,
    $$MacroTargetsTableTableUpdateCompanionBuilder,
    (
      MacroTargetsTableData,
      BaseReferences<_$AppDatabase, $MacroTargetsTableTable,
          MacroTargetsTableData>
    ),
    MacroTargetsTableData,
    PrefetchHooks Function()>;
typedef $$FeedbackTableTableCreateCompanionBuilder = FeedbackTableCompanion
    Function({
  required String id,
  Value<String?> deviceId,
  required int satisfactionLevel,
  required String satisfactionEmoji,
  required String satisfactionLabel,
  Value<String?> appFeedback,
  Value<String?> suggestions,
  Value<String?> planName,
  Value<String?> userName,
  Value<DateTime?> timestamp,
  Value<int?> confidenceLevel,
  Value<String?> confidenceLabel,
  Value<String?> reuseIntent,
  Value<bool> reminderRequested,
  Value<String?> missedReasons,
  Value<String?> missedOther,
  Value<int?> reminderDayOfWeek,
  Value<int> reminderHour,
  Value<int> reminderMinute,
  Value<bool> reminderRecurring,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$FeedbackTableTableUpdateCompanionBuilder = FeedbackTableCompanion
    Function({
  Value<String> id,
  Value<String?> deviceId,
  Value<int> satisfactionLevel,
  Value<String> satisfactionEmoji,
  Value<String> satisfactionLabel,
  Value<String?> appFeedback,
  Value<String?> suggestions,
  Value<String?> planName,
  Value<String?> userName,
  Value<DateTime?> timestamp,
  Value<int?> confidenceLevel,
  Value<String?> confidenceLabel,
  Value<String?> reuseIntent,
  Value<bool> reminderRequested,
  Value<String?> missedReasons,
  Value<String?> missedOther,
  Value<int?> reminderDayOfWeek,
  Value<int> reminderHour,
  Value<int> reminderMinute,
  Value<bool> reminderRecurring,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$FeedbackTableTableFilterComposer
    extends Composer<_$AppDatabase, $FeedbackTableTable> {
  $$FeedbackTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get satisfactionLevel => $composableBuilder(
      column: $table.satisfactionLevel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get satisfactionEmoji => $composableBuilder(
      column: $table.satisfactionEmoji,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get satisfactionLabel => $composableBuilder(
      column: $table.satisfactionLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get appFeedback => $composableBuilder(
      column: $table.appFeedback, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get suggestions => $composableBuilder(
      column: $table.suggestions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planName => $composableBuilder(
      column: $table.planName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get confidenceLevel => $composableBuilder(
      column: $table.confidenceLevel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get confidenceLabel => $composableBuilder(
      column: $table.confidenceLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reuseIntent => $composableBuilder(
      column: $table.reuseIntent, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get reminderRequested => $composableBuilder(
      column: $table.reminderRequested,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get missedReasons => $composableBuilder(
      column: $table.missedReasons, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get missedOther => $composableBuilder(
      column: $table.missedOther, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderDayOfWeek => $composableBuilder(
      column: $table.reminderDayOfWeek,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderHour => $composableBuilder(
      column: $table.reminderHour, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderMinute => $composableBuilder(
      column: $table.reminderMinute,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get reminderRecurring => $composableBuilder(
      column: $table.reminderRecurring,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$FeedbackTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedbackTableTable> {
  $$FeedbackTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get satisfactionLevel => $composableBuilder(
      column: $table.satisfactionLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get satisfactionEmoji => $composableBuilder(
      column: $table.satisfactionEmoji,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get satisfactionLabel => $composableBuilder(
      column: $table.satisfactionLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get appFeedback => $composableBuilder(
      column: $table.appFeedback, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get suggestions => $composableBuilder(
      column: $table.suggestions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planName => $composableBuilder(
      column: $table.planName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get confidenceLevel => $composableBuilder(
      column: $table.confidenceLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get confidenceLabel => $composableBuilder(
      column: $table.confidenceLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reuseIntent => $composableBuilder(
      column: $table.reuseIntent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get reminderRequested => $composableBuilder(
      column: $table.reminderRequested,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get missedReasons => $composableBuilder(
      column: $table.missedReasons,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get missedOther => $composableBuilder(
      column: $table.missedOther, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderDayOfWeek => $composableBuilder(
      column: $table.reminderDayOfWeek,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderHour => $composableBuilder(
      column: $table.reminderHour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderMinute => $composableBuilder(
      column: $table.reminderMinute,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get reminderRecurring => $composableBuilder(
      column: $table.reminderRecurring,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$FeedbackTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedbackTableTable> {
  $$FeedbackTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get satisfactionLevel => $composableBuilder(
      column: $table.satisfactionLevel, builder: (column) => column);

  GeneratedColumn<String> get satisfactionEmoji => $composableBuilder(
      column: $table.satisfactionEmoji, builder: (column) => column);

  GeneratedColumn<String> get satisfactionLabel => $composableBuilder(
      column: $table.satisfactionLabel, builder: (column) => column);

  GeneratedColumn<String> get appFeedback => $composableBuilder(
      column: $table.appFeedback, builder: (column) => column);

  GeneratedColumn<String> get suggestions => $composableBuilder(
      column: $table.suggestions, builder: (column) => column);

  GeneratedColumn<String> get planName =>
      $composableBuilder(column: $table.planName, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get confidenceLevel => $composableBuilder(
      column: $table.confidenceLevel, builder: (column) => column);

  GeneratedColumn<String> get confidenceLabel => $composableBuilder(
      column: $table.confidenceLabel, builder: (column) => column);

  GeneratedColumn<String> get reuseIntent => $composableBuilder(
      column: $table.reuseIntent, builder: (column) => column);

  GeneratedColumn<bool> get reminderRequested => $composableBuilder(
      column: $table.reminderRequested, builder: (column) => column);

  GeneratedColumn<String> get missedReasons => $composableBuilder(
      column: $table.missedReasons, builder: (column) => column);

  GeneratedColumn<String> get missedOther => $composableBuilder(
      column: $table.missedOther, builder: (column) => column);

  GeneratedColumn<int> get reminderDayOfWeek => $composableBuilder(
      column: $table.reminderDayOfWeek, builder: (column) => column);

  GeneratedColumn<int> get reminderHour => $composableBuilder(
      column: $table.reminderHour, builder: (column) => column);

  GeneratedColumn<int> get reminderMinute => $composableBuilder(
      column: $table.reminderMinute, builder: (column) => column);

  GeneratedColumn<bool> get reminderRecurring => $composableBuilder(
      column: $table.reminderRecurring, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FeedbackTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeedbackTableTable,
    FeedbackEntry,
    $$FeedbackTableTableFilterComposer,
    $$FeedbackTableTableOrderingComposer,
    $$FeedbackTableTableAnnotationComposer,
    $$FeedbackTableTableCreateCompanionBuilder,
    $$FeedbackTableTableUpdateCompanionBuilder,
    (
      FeedbackEntry,
      BaseReferences<_$AppDatabase, $FeedbackTableTable, FeedbackEntry>
    ),
    FeedbackEntry,
    PrefetchHooks Function()> {
  $$FeedbackTableTableTableManager(_$AppDatabase db, $FeedbackTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedbackTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedbackTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedbackTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> deviceId = const Value.absent(),
            Value<int> satisfactionLevel = const Value.absent(),
            Value<String> satisfactionEmoji = const Value.absent(),
            Value<String> satisfactionLabel = const Value.absent(),
            Value<String?> appFeedback = const Value.absent(),
            Value<String?> suggestions = const Value.absent(),
            Value<String?> planName = const Value.absent(),
            Value<String?> userName = const Value.absent(),
            Value<DateTime?> timestamp = const Value.absent(),
            Value<int?> confidenceLevel = const Value.absent(),
            Value<String?> confidenceLabel = const Value.absent(),
            Value<String?> reuseIntent = const Value.absent(),
            Value<bool> reminderRequested = const Value.absent(),
            Value<String?> missedReasons = const Value.absent(),
            Value<String?> missedOther = const Value.absent(),
            Value<int?> reminderDayOfWeek = const Value.absent(),
            Value<int> reminderHour = const Value.absent(),
            Value<int> reminderMinute = const Value.absent(),
            Value<bool> reminderRecurring = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedbackTableCompanion(
            id: id,
            deviceId: deviceId,
            satisfactionLevel: satisfactionLevel,
            satisfactionEmoji: satisfactionEmoji,
            satisfactionLabel: satisfactionLabel,
            appFeedback: appFeedback,
            suggestions: suggestions,
            planName: planName,
            userName: userName,
            timestamp: timestamp,
            confidenceLevel: confidenceLevel,
            confidenceLabel: confidenceLabel,
            reuseIntent: reuseIntent,
            reminderRequested: reminderRequested,
            missedReasons: missedReasons,
            missedOther: missedOther,
            reminderDayOfWeek: reminderDayOfWeek,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderRecurring: reminderRecurring,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> deviceId = const Value.absent(),
            required int satisfactionLevel,
            required String satisfactionEmoji,
            required String satisfactionLabel,
            Value<String?> appFeedback = const Value.absent(),
            Value<String?> suggestions = const Value.absent(),
            Value<String?> planName = const Value.absent(),
            Value<String?> userName = const Value.absent(),
            Value<DateTime?> timestamp = const Value.absent(),
            Value<int?> confidenceLevel = const Value.absent(),
            Value<String?> confidenceLabel = const Value.absent(),
            Value<String?> reuseIntent = const Value.absent(),
            Value<bool> reminderRequested = const Value.absent(),
            Value<String?> missedReasons = const Value.absent(),
            Value<String?> missedOther = const Value.absent(),
            Value<int?> reminderDayOfWeek = const Value.absent(),
            Value<int> reminderHour = const Value.absent(),
            Value<int> reminderMinute = const Value.absent(),
            Value<bool> reminderRecurring = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedbackTableCompanion.insert(
            id: id,
            deviceId: deviceId,
            satisfactionLevel: satisfactionLevel,
            satisfactionEmoji: satisfactionEmoji,
            satisfactionLabel: satisfactionLabel,
            appFeedback: appFeedback,
            suggestions: suggestions,
            planName: planName,
            userName: userName,
            timestamp: timestamp,
            confidenceLevel: confidenceLevel,
            confidenceLabel: confidenceLabel,
            reuseIntent: reuseIntent,
            reminderRequested: reminderRequested,
            missedReasons: missedReasons,
            missedOther: missedOther,
            reminderDayOfWeek: reminderDayOfWeek,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderRecurring: reminderRecurring,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FeedbackTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeedbackTableTable,
    FeedbackEntry,
    $$FeedbackTableTableFilterComposer,
    $$FeedbackTableTableOrderingComposer,
    $$FeedbackTableTableAnnotationComposer,
    $$FeedbackTableTableCreateCompanionBuilder,
    $$FeedbackTableTableUpdateCompanionBuilder,
    (
      FeedbackEntry,
      BaseReferences<_$AppDatabase, $FeedbackTableTable, FeedbackEntry>
    ),
    FeedbackEntry,
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
  $$MacroTargetsTableTableTableManager get macroTargetsTable =>
      $$MacroTargetsTableTableTableManager(_db, _db.macroTargetsTable);
  $$FeedbackTableTableTableManager get feedbackTable =>
      $$FeedbackTableTableTableManager(_db, _db.feedbackTable);
}
