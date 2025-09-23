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
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _birthdayMeta =
      const VerificationMeta('birthday');
  @override
  late final GeneratedColumn<DateTime> birthday = GeneratedColumn<DateTime>(
      'birthday', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _heightFeetMeta =
      const VerificationMeta('heightFeet');
  @override
  late final GeneratedColumn<int> heightFeet = GeneratedColumn<int>(
      'height_feet', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heightInchesMeta =
      const VerificationMeta('heightInches');
  @override
  late final GeneratedColumn<int> heightInches = GeneratedColumn<int>(
      'height_inches', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _weightPoundsMeta =
      const VerificationMeta('weightPounds');
  @override
  late final GeneratedColumn<double> weightPounds = GeneratedColumn<double>(
      'weight_pounds', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _runsWithWaterBottleMeta =
      const VerificationMeta('runsWithWaterBottle');
  @override
  late final GeneratedColumn<bool> runsWithWaterBottle = GeneratedColumn<bool>(
      'runs_with_water_bottle', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("runs_with_water_bottle" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      foodPreferences = GeneratedColumn<String>(
              'food_preferences', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('{}'))
          .withConverter<Map<String, dynamic>>(
              $UserProfilesTableTable.$converterfoodPreferences);
  static const VerificationMeta _preferredDistanceUnitMeta =
      const VerificationMeta('preferredDistanceUnit');
  @override
  late final GeneratedColumn<String> preferredDistanceUnit =
      GeneratedColumn<String>('preferred_distance_unit', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('miles'));
  static const VerificationMeta _preferredPaceUnitMeta =
      const VerificationMeta('preferredPaceUnit');
  @override
  late final GeneratedColumn<String> preferredPaceUnit =
      GeneratedColumn<String>('preferred_pace_unit', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('min_per_mile'));
  static const VerificationMeta _gutTrainingLevelMeta =
      const VerificationMeta('gutTrainingLevel');
  @override
  late final GeneratedColumn<String> gutTrainingLevel = GeneratedColumn<String>(
      'gut_training_level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('moderate'));
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
  static const VerificationMeta _lastActiveAtMeta =
      const VerificationMeta('lastActiveAt');
  @override
  late final GeneratedColumn<DateTime> lastActiveAt = GeneratedColumn<DateTime>(
      'last_active_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _appVersionMeta =
      const VerificationMeta('appVersion');
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
      'app_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
  static const VerificationMeta _swipeHintShownMeta =
      const VerificationMeta('swipeHintShown');
  @override
  late final GeneratedColumn<bool> swipeHintShown = GeneratedColumn<bool>(
      'swipe_hint_shown', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("swipe_hint_shown" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deviceId,
        createdAt,
        updatedAt,
        gender,
        birthday,
        heightFeet,
        heightInches,
        weightPounds,
        runsWithWaterBottle,
        foodPreferences,
        preferredDistanceUnit,
        preferredPaceUnit,
        gutTrainingLevel,
        onboardingCompleted,
        lastActiveAt,
        appVersion,
        notificationsEnabled,
        defaultReminderDay,
        defaultReminderHour,
        defaultReminderMinute,
        defaultReminderRecurring,
        tempPlanData,
        swipeHintShown
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
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    }
    if (data.containsKey('birthday')) {
      context.handle(_birthdayMeta,
          birthday.isAcceptableOrUnknown(data['birthday']!, _birthdayMeta));
    }
    if (data.containsKey('height_feet')) {
      context.handle(
          _heightFeetMeta,
          heightFeet.isAcceptableOrUnknown(
              data['height_feet']!, _heightFeetMeta));
    }
    if (data.containsKey('height_inches')) {
      context.handle(
          _heightInchesMeta,
          heightInches.isAcceptableOrUnknown(
              data['height_inches']!, _heightInchesMeta));
    }
    if (data.containsKey('weight_pounds')) {
      context.handle(
          _weightPoundsMeta,
          weightPounds.isAcceptableOrUnknown(
              data['weight_pounds']!, _weightPoundsMeta));
    }
    if (data.containsKey('runs_with_water_bottle')) {
      context.handle(
          _runsWithWaterBottleMeta,
          runsWithWaterBottle.isAcceptableOrUnknown(
              data['runs_with_water_bottle']!, _runsWithWaterBottleMeta));
    }
    if (data.containsKey('preferred_distance_unit')) {
      context.handle(
          _preferredDistanceUnitMeta,
          preferredDistanceUnit.isAcceptableOrUnknown(
              data['preferred_distance_unit']!, _preferredDistanceUnitMeta));
    }
    if (data.containsKey('preferred_pace_unit')) {
      context.handle(
          _preferredPaceUnitMeta,
          preferredPaceUnit.isAcceptableOrUnknown(
              data['preferred_pace_unit']!, _preferredPaceUnitMeta));
    }
    if (data.containsKey('gut_training_level')) {
      context.handle(
          _gutTrainingLevelMeta,
          gutTrainingLevel.isAcceptableOrUnknown(
              data['gut_training_level']!, _gutTrainingLevelMeta));
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
          _onboardingCompletedMeta,
          onboardingCompleted.isAcceptableOrUnknown(
              data['onboarding_completed']!, _onboardingCompletedMeta));
    }
    if (data.containsKey('last_active_at')) {
      context.handle(
          _lastActiveAtMeta,
          lastActiveAt.isAcceptableOrUnknown(
              data['last_active_at']!, _lastActiveAtMeta));
    }
    if (data.containsKey('app_version')) {
      context.handle(
          _appVersionMeta,
          appVersion.isAcceptableOrUnknown(
              data['app_version']!, _appVersionMeta));
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
    if (data.containsKey('swipe_hint_shown')) {
      context.handle(
          _swipeHintShownMeta,
          swipeHintShown.isAcceptableOrUnknown(
              data['swipe_hint_shown']!, _swipeHintShownMeta));
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
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender']),
      birthday: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}birthday']),
      heightFeet: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height_feet']),
      heightInches: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height_inches']),
      weightPounds: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight_pounds']),
      runsWithWaterBottle: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}runs_with_water_bottle'])!,
      foodPreferences: $UserProfilesTableTable.$converterfoodPreferences
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}food_preferences'])!),
      preferredDistanceUnit: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}preferred_distance_unit'])!,
      preferredPaceUnit: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preferred_pace_unit'])!,
      gutTrainingLevel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}gut_training_level'])!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}onboarding_completed'])!,
      lastActiveAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_active_at'])!,
      appVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_version']),
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
      swipeHintShown: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}swipe_hint_shown'])!,
    );
  }

  @override
  $UserProfilesTableTable createAlias(String alias) {
    return $UserProfilesTableTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>, String> $converterfoodPreferences =
      const FoodPreferencesJsonConverter();
}

class UserProfileEntry extends DataClass
    implements Insertable<UserProfileEntry> {
  /// UUID primary key (matches Supabase users.id)
  final String id;

  /// Device ID used as unique identifier (matches Supabase users.device_id)
  final String deviceId;

  /// When the profile was created (matches Supabase users.created_at)
  final DateTime createdAt;

  /// When the profile was last updated (matches Supabase users.updated_at)
  final DateTime updatedAt;

  /// User's gender (stored as string enum: 'male', 'female', 'other')
  final String? gender;

  /// User's birthday
  final DateTime? birthday;

  /// Height in feet (integer part)
  final int? heightFeet;

  /// Height in inches (remaining part)
  final int? heightInches;

  /// Weight in pounds (numeric with 2 decimal places to match Supabase)
  final double? weightPounds;

  /// Whether user runs with a water bottle
  final bool runsWithWaterBottle;

  /// Food preferences stored as JSONB (matches Supabase users.food_preferences)
  final Map<String, dynamic> foodPreferences;

  /// Preferred distance unit: 'miles' or 'kilometers'
  final String preferredDistanceUnit;

  /// Preferred pace unit: 'min_per_mile' or 'min_per_km'
  final String preferredPaceUnit;

  /// Gut training level (stored as string enum: 'low', 'moderate', 'high')
  final String gutTrainingLevel;

  /// Whether user has completed onboarding
  final bool onboardingCompleted;

  /// Last time user was active
  final DateTime lastActiveAt;

  /// App version when profile was created/updated
  final String? appVersion;

  /// Notification preferences (matches Supabase users schema)
  final bool notificationsEnabled;
  final int defaultReminderDay;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final bool defaultReminderRecurring;

  /// Temporary plan storage (unsaved plan that persists through app restart) - Drift-only field
  final String? tempPlanData;

  /// Whether the swipe hint animation has been shown to this user - Drift-only field
  final bool swipeHintShown;
  const UserProfileEntry(
      {required this.id,
      required this.deviceId,
      required this.createdAt,
      required this.updatedAt,
      this.gender,
      this.birthday,
      this.heightFeet,
      this.heightInches,
      this.weightPounds,
      required this.runsWithWaterBottle,
      required this.foodPreferences,
      required this.preferredDistanceUnit,
      required this.preferredPaceUnit,
      required this.gutTrainingLevel,
      required this.onboardingCompleted,
      required this.lastActiveAt,
      this.appVersion,
      required this.notificationsEnabled,
      required this.defaultReminderDay,
      required this.defaultReminderHour,
      required this.defaultReminderMinute,
      required this.defaultReminderRecurring,
      this.tempPlanData,
      required this.swipeHintShown});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || birthday != null) {
      map['birthday'] = Variable<DateTime>(birthday);
    }
    if (!nullToAbsent || heightFeet != null) {
      map['height_feet'] = Variable<int>(heightFeet);
    }
    if (!nullToAbsent || heightInches != null) {
      map['height_inches'] = Variable<int>(heightInches);
    }
    if (!nullToAbsent || weightPounds != null) {
      map['weight_pounds'] = Variable<double>(weightPounds);
    }
    map['runs_with_water_bottle'] = Variable<bool>(runsWithWaterBottle);
    {
      map['food_preferences'] = Variable<String>($UserProfilesTableTable
          .$converterfoodPreferences
          .toSql(foodPreferences));
    }
    map['preferred_distance_unit'] = Variable<String>(preferredDistanceUnit);
    map['preferred_pace_unit'] = Variable<String>(preferredPaceUnit);
    map['gut_training_level'] = Variable<String>(gutTrainingLevel);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    map['last_active_at'] = Variable<DateTime>(lastActiveAt);
    if (!nullToAbsent || appVersion != null) {
      map['app_version'] = Variable<String>(appVersion);
    }
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['default_reminder_day'] = Variable<int>(defaultReminderDay);
    map['default_reminder_hour'] = Variable<int>(defaultReminderHour);
    map['default_reminder_minute'] = Variable<int>(defaultReminderMinute);
    map['default_reminder_recurring'] =
        Variable<bool>(defaultReminderRecurring);
    if (!nullToAbsent || tempPlanData != null) {
      map['temp_plan_data'] = Variable<String>(tempPlanData);
    }
    map['swipe_hint_shown'] = Variable<bool>(swipeHintShown);
    return map;
  }

  UserProfilesTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesTableCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      gender:
          gender == null && nullToAbsent ? const Value.absent() : Value(gender),
      birthday: birthday == null && nullToAbsent
          ? const Value.absent()
          : Value(birthday),
      heightFeet: heightFeet == null && nullToAbsent
          ? const Value.absent()
          : Value(heightFeet),
      heightInches: heightInches == null && nullToAbsent
          ? const Value.absent()
          : Value(heightInches),
      weightPounds: weightPounds == null && nullToAbsent
          ? const Value.absent()
          : Value(weightPounds),
      runsWithWaterBottle: Value(runsWithWaterBottle),
      foodPreferences: Value(foodPreferences),
      preferredDistanceUnit: Value(preferredDistanceUnit),
      preferredPaceUnit: Value(preferredPaceUnit),
      gutTrainingLevel: Value(gutTrainingLevel),
      onboardingCompleted: Value(onboardingCompleted),
      lastActiveAt: Value(lastActiveAt),
      appVersion: appVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(appVersion),
      notificationsEnabled: Value(notificationsEnabled),
      defaultReminderDay: Value(defaultReminderDay),
      defaultReminderHour: Value(defaultReminderHour),
      defaultReminderMinute: Value(defaultReminderMinute),
      defaultReminderRecurring: Value(defaultReminderRecurring),
      tempPlanData: tempPlanData == null && nullToAbsent
          ? const Value.absent()
          : Value(tempPlanData),
      swipeHintShown: Value(swipeHintShown),
    );
  }

  factory UserProfileEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileEntry(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      gender: serializer.fromJson<String?>(json['gender']),
      birthday: serializer.fromJson<DateTime?>(json['birthday']),
      heightFeet: serializer.fromJson<int?>(json['heightFeet']),
      heightInches: serializer.fromJson<int?>(json['heightInches']),
      weightPounds: serializer.fromJson<double?>(json['weightPounds']),
      runsWithWaterBottle:
          serializer.fromJson<bool>(json['runsWithWaterBottle']),
      foodPreferences:
          serializer.fromJson<Map<String, dynamic>>(json['foodPreferences']),
      preferredDistanceUnit:
          serializer.fromJson<String>(json['preferredDistanceUnit']),
      preferredPaceUnit: serializer.fromJson<String>(json['preferredPaceUnit']),
      gutTrainingLevel: serializer.fromJson<String>(json['gutTrainingLevel']),
      onboardingCompleted:
          serializer.fromJson<bool>(json['onboardingCompleted']),
      lastActiveAt: serializer.fromJson<DateTime>(json['lastActiveAt']),
      appVersion: serializer.fromJson<String?>(json['appVersion']),
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
      swipeHintShown: serializer.fromJson<bool>(json['swipeHintShown']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'gender': serializer.toJson<String?>(gender),
      'birthday': serializer.toJson<DateTime?>(birthday),
      'heightFeet': serializer.toJson<int?>(heightFeet),
      'heightInches': serializer.toJson<int?>(heightInches),
      'weightPounds': serializer.toJson<double?>(weightPounds),
      'runsWithWaterBottle': serializer.toJson<bool>(runsWithWaterBottle),
      'foodPreferences':
          serializer.toJson<Map<String, dynamic>>(foodPreferences),
      'preferredDistanceUnit': serializer.toJson<String>(preferredDistanceUnit),
      'preferredPaceUnit': serializer.toJson<String>(preferredPaceUnit),
      'gutTrainingLevel': serializer.toJson<String>(gutTrainingLevel),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
      'lastActiveAt': serializer.toJson<DateTime>(lastActiveAt),
      'appVersion': serializer.toJson<String?>(appVersion),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'defaultReminderDay': serializer.toJson<int>(defaultReminderDay),
      'defaultReminderHour': serializer.toJson<int>(defaultReminderHour),
      'defaultReminderMinute': serializer.toJson<int>(defaultReminderMinute),
      'defaultReminderRecurring':
          serializer.toJson<bool>(defaultReminderRecurring),
      'tempPlanData': serializer.toJson<String?>(tempPlanData),
      'swipeHintShown': serializer.toJson<bool>(swipeHintShown),
    };
  }

  UserProfileEntry copyWith(
          {String? id,
          String? deviceId,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> gender = const Value.absent(),
          Value<DateTime?> birthday = const Value.absent(),
          Value<int?> heightFeet = const Value.absent(),
          Value<int?> heightInches = const Value.absent(),
          Value<double?> weightPounds = const Value.absent(),
          bool? runsWithWaterBottle,
          Map<String, dynamic>? foodPreferences,
          String? preferredDistanceUnit,
          String? preferredPaceUnit,
          String? gutTrainingLevel,
          bool? onboardingCompleted,
          DateTime? lastActiveAt,
          Value<String?> appVersion = const Value.absent(),
          bool? notificationsEnabled,
          int? defaultReminderDay,
          int? defaultReminderHour,
          int? defaultReminderMinute,
          bool? defaultReminderRecurring,
          Value<String?> tempPlanData = const Value.absent(),
          bool? swipeHintShown}) =>
      UserProfileEntry(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        gender: gender.present ? gender.value : this.gender,
        birthday: birthday.present ? birthday.value : this.birthday,
        heightFeet: heightFeet.present ? heightFeet.value : this.heightFeet,
        heightInches:
            heightInches.present ? heightInches.value : this.heightInches,
        weightPounds:
            weightPounds.present ? weightPounds.value : this.weightPounds,
        runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
        foodPreferences: foodPreferences ?? this.foodPreferences,
        preferredDistanceUnit:
            preferredDistanceUnit ?? this.preferredDistanceUnit,
        preferredPaceUnit: preferredPaceUnit ?? this.preferredPaceUnit,
        gutTrainingLevel: gutTrainingLevel ?? this.gutTrainingLevel,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        appVersion: appVersion.present ? appVersion.value : this.appVersion,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        defaultReminderDay: defaultReminderDay ?? this.defaultReminderDay,
        defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
        defaultReminderMinute:
            defaultReminderMinute ?? this.defaultReminderMinute,
        defaultReminderRecurring:
            defaultReminderRecurring ?? this.defaultReminderRecurring,
        tempPlanData:
            tempPlanData.present ? tempPlanData.value : this.tempPlanData,
        swipeHintShown: swipeHintShown ?? this.swipeHintShown,
      );
  UserProfileEntry copyWithCompanion(UserProfilesTableCompanion data) {
    return UserProfileEntry(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
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
      foodPreferences: data.foodPreferences.present
          ? data.foodPreferences.value
          : this.foodPreferences,
      preferredDistanceUnit: data.preferredDistanceUnit.present
          ? data.preferredDistanceUnit.value
          : this.preferredDistanceUnit,
      preferredPaceUnit: data.preferredPaceUnit.present
          ? data.preferredPaceUnit.value
          : this.preferredPaceUnit,
      gutTrainingLevel: data.gutTrainingLevel.present
          ? data.gutTrainingLevel.value
          : this.gutTrainingLevel,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
      lastActiveAt: data.lastActiveAt.present
          ? data.lastActiveAt.value
          : this.lastActiveAt,
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
      swipeHintShown: data.swipeHintShown.present
          ? data.swipeHintShown.value
          : this.swipeHintShown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileEntry(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('gender: $gender, ')
          ..write('birthday: $birthday, ')
          ..write('heightFeet: $heightFeet, ')
          ..write('heightInches: $heightInches, ')
          ..write('weightPounds: $weightPounds, ')
          ..write('runsWithWaterBottle: $runsWithWaterBottle, ')
          ..write('foodPreferences: $foodPreferences, ')
          ..write('preferredDistanceUnit: $preferredDistanceUnit, ')
          ..write('preferredPaceUnit: $preferredPaceUnit, ')
          ..write('gutTrainingLevel: $gutTrainingLevel, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('defaultReminderDay: $defaultReminderDay, ')
          ..write('defaultReminderHour: $defaultReminderHour, ')
          ..write('defaultReminderMinute: $defaultReminderMinute, ')
          ..write('defaultReminderRecurring: $defaultReminderRecurring, ')
          ..write('tempPlanData: $tempPlanData, ')
          ..write('swipeHintShown: $swipeHintShown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        deviceId,
        createdAt,
        updatedAt,
        gender,
        birthday,
        heightFeet,
        heightInches,
        weightPounds,
        runsWithWaterBottle,
        foodPreferences,
        preferredDistanceUnit,
        preferredPaceUnit,
        gutTrainingLevel,
        onboardingCompleted,
        lastActiveAt,
        appVersion,
        notificationsEnabled,
        defaultReminderDay,
        defaultReminderHour,
        defaultReminderMinute,
        defaultReminderRecurring,
        tempPlanData,
        swipeHintShown
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileEntry &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.gender == this.gender &&
          other.birthday == this.birthday &&
          other.heightFeet == this.heightFeet &&
          other.heightInches == this.heightInches &&
          other.weightPounds == this.weightPounds &&
          other.runsWithWaterBottle == this.runsWithWaterBottle &&
          other.foodPreferences == this.foodPreferences &&
          other.preferredDistanceUnit == this.preferredDistanceUnit &&
          other.preferredPaceUnit == this.preferredPaceUnit &&
          other.gutTrainingLevel == this.gutTrainingLevel &&
          other.onboardingCompleted == this.onboardingCompleted &&
          other.lastActiveAt == this.lastActiveAt &&
          other.appVersion == this.appVersion &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.defaultReminderDay == this.defaultReminderDay &&
          other.defaultReminderHour == this.defaultReminderHour &&
          other.defaultReminderMinute == this.defaultReminderMinute &&
          other.defaultReminderRecurring == this.defaultReminderRecurring &&
          other.tempPlanData == this.tempPlanData &&
          other.swipeHintShown == this.swipeHintShown);
}

class UserProfilesTableCompanion extends UpdateCompanion<UserProfileEntry> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> gender;
  final Value<DateTime?> birthday;
  final Value<int?> heightFeet;
  final Value<int?> heightInches;
  final Value<double?> weightPounds;
  final Value<bool> runsWithWaterBottle;
  final Value<Map<String, dynamic>> foodPreferences;
  final Value<String> preferredDistanceUnit;
  final Value<String> preferredPaceUnit;
  final Value<String> gutTrainingLevel;
  final Value<bool> onboardingCompleted;
  final Value<DateTime> lastActiveAt;
  final Value<String?> appVersion;
  final Value<bool> notificationsEnabled;
  final Value<int> defaultReminderDay;
  final Value<int> defaultReminderHour;
  final Value<int> defaultReminderMinute;
  final Value<bool> defaultReminderRecurring;
  final Value<String?> tempPlanData;
  final Value<bool> swipeHintShown;
  final Value<int> rowid;
  const UserProfilesTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.gender = const Value.absent(),
    this.birthday = const Value.absent(),
    this.heightFeet = const Value.absent(),
    this.heightInches = const Value.absent(),
    this.weightPounds = const Value.absent(),
    this.runsWithWaterBottle = const Value.absent(),
    this.foodPreferences = const Value.absent(),
    this.preferredDistanceUnit = const Value.absent(),
    this.preferredPaceUnit = const Value.absent(),
    this.gutTrainingLevel = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.lastActiveAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.defaultReminderDay = const Value.absent(),
    this.defaultReminderHour = const Value.absent(),
    this.defaultReminderMinute = const Value.absent(),
    this.defaultReminderRecurring = const Value.absent(),
    this.tempPlanData = const Value.absent(),
    this.swipeHintShown = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesTableCompanion.insert({
    required String id,
    required String deviceId,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.gender = const Value.absent(),
    this.birthday = const Value.absent(),
    this.heightFeet = const Value.absent(),
    this.heightInches = const Value.absent(),
    this.weightPounds = const Value.absent(),
    this.runsWithWaterBottle = const Value.absent(),
    this.foodPreferences = const Value.absent(),
    this.preferredDistanceUnit = const Value.absent(),
    this.preferredPaceUnit = const Value.absent(),
    this.gutTrainingLevel = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.lastActiveAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.defaultReminderDay = const Value.absent(),
    this.defaultReminderHour = const Value.absent(),
    this.defaultReminderMinute = const Value.absent(),
    this.defaultReminderRecurring = const Value.absent(),
    this.tempPlanData = const Value.absent(),
    this.swipeHintShown = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        deviceId = Value(deviceId);
  static Insertable<UserProfileEntry> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? gender,
    Expression<DateTime>? birthday,
    Expression<int>? heightFeet,
    Expression<int>? heightInches,
    Expression<double>? weightPounds,
    Expression<bool>? runsWithWaterBottle,
    Expression<String>? foodPreferences,
    Expression<String>? preferredDistanceUnit,
    Expression<String>? preferredPaceUnit,
    Expression<String>? gutTrainingLevel,
    Expression<bool>? onboardingCompleted,
    Expression<DateTime>? lastActiveAt,
    Expression<String>? appVersion,
    Expression<bool>? notificationsEnabled,
    Expression<int>? defaultReminderDay,
    Expression<int>? defaultReminderHour,
    Expression<int>? defaultReminderMinute,
    Expression<bool>? defaultReminderRecurring,
    Expression<String>? tempPlanData,
    Expression<bool>? swipeHintShown,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (gender != null) 'gender': gender,
      if (birthday != null) 'birthday': birthday,
      if (heightFeet != null) 'height_feet': heightFeet,
      if (heightInches != null) 'height_inches': heightInches,
      if (weightPounds != null) 'weight_pounds': weightPounds,
      if (runsWithWaterBottle != null)
        'runs_with_water_bottle': runsWithWaterBottle,
      if (foodPreferences != null) 'food_preferences': foodPreferences,
      if (preferredDistanceUnit != null)
        'preferred_distance_unit': preferredDistanceUnit,
      if (preferredPaceUnit != null) 'preferred_pace_unit': preferredPaceUnit,
      if (gutTrainingLevel != null) 'gut_training_level': gutTrainingLevel,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt,
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
      if (swipeHintShown != null) 'swipe_hint_shown': swipeHintShown,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? deviceId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? gender,
      Value<DateTime?>? birthday,
      Value<int?>? heightFeet,
      Value<int?>? heightInches,
      Value<double?>? weightPounds,
      Value<bool>? runsWithWaterBottle,
      Value<Map<String, dynamic>>? foodPreferences,
      Value<String>? preferredDistanceUnit,
      Value<String>? preferredPaceUnit,
      Value<String>? gutTrainingLevel,
      Value<bool>? onboardingCompleted,
      Value<DateTime>? lastActiveAt,
      Value<String?>? appVersion,
      Value<bool>? notificationsEnabled,
      Value<int>? defaultReminderDay,
      Value<int>? defaultReminderHour,
      Value<int>? defaultReminderMinute,
      Value<bool>? defaultReminderRecurring,
      Value<String?>? tempPlanData,
      Value<bool>? swipeHintShown,
      Value<int>? rowid}) {
    return UserProfilesTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      heightFeet: heightFeet ?? this.heightFeet,
      heightInches: heightInches ?? this.heightInches,
      weightPounds: weightPounds ?? this.weightPounds,
      runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
      foodPreferences: foodPreferences ?? this.foodPreferences,
      preferredDistanceUnit:
          preferredDistanceUnit ?? this.preferredDistanceUnit,
      preferredPaceUnit: preferredPaceUnit ?? this.preferredPaceUnit,
      gutTrainingLevel: gutTrainingLevel ?? this.gutTrainingLevel,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      appVersion: appVersion ?? this.appVersion,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultReminderDay: defaultReminderDay ?? this.defaultReminderDay,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute:
          defaultReminderMinute ?? this.defaultReminderMinute,
      defaultReminderRecurring:
          defaultReminderRecurring ?? this.defaultReminderRecurring,
      tempPlanData: tempPlanData ?? this.tempPlanData,
      swipeHintShown: swipeHintShown ?? this.swipeHintShown,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
    if (foodPreferences.present) {
      map['food_preferences'] = Variable<String>($UserProfilesTableTable
          .$converterfoodPreferences
          .toSql(foodPreferences.value));
    }
    if (preferredDistanceUnit.present) {
      map['preferred_distance_unit'] =
          Variable<String>(preferredDistanceUnit.value);
    }
    if (preferredPaceUnit.present) {
      map['preferred_pace_unit'] = Variable<String>(preferredPaceUnit.value);
    }
    if (gutTrainingLevel.present) {
      map['gut_training_level'] = Variable<String>(gutTrainingLevel.value);
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    if (lastActiveAt.present) {
      map['last_active_at'] = Variable<DateTime>(lastActiveAt.value);
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
    if (swipeHintShown.present) {
      map['swipe_hint_shown'] = Variable<bool>(swipeHintShown.value);
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
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('gender: $gender, ')
          ..write('birthday: $birthday, ')
          ..write('heightFeet: $heightFeet, ')
          ..write('heightInches: $heightInches, ')
          ..write('weightPounds: $weightPounds, ')
          ..write('runsWithWaterBottle: $runsWithWaterBottle, ')
          ..write('foodPreferences: $foodPreferences, ')
          ..write('preferredDistanceUnit: $preferredDistanceUnit, ')
          ..write('preferredPaceUnit: $preferredPaceUnit, ')
          ..write('gutTrainingLevel: $gutTrainingLevel, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('defaultReminderDay: $defaultReminderDay, ')
          ..write('defaultReminderHour: $defaultReminderHour, ')
          ..write('defaultReminderMinute: $defaultReminderMinute, ')
          ..write('defaultReminderRecurring: $defaultReminderRecurring, ')
          ..write('tempPlanData: $tempPlanData, ')
          ..write('swipeHintShown: $swipeHintShown, ')
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
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _foodNameMeta =
      const VerificationMeta('foodName');
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
      'food_name', aliasedName, false,
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
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, deviceId, foodName, preference, createdAt, updatedAt];
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
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('food_name')) {
      context.handle(_foodNameMeta,
          foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta));
    } else if (isInserting) {
      context.missing(_foodNameMeta);
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
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodPreferenceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodPreferenceEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      foodName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}food_name'])!,
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
  /// UUID primary key (matches Supabase food_preferences.id)
  final String id;

  /// Device ID (foreign key reference to users.device_id)
  final String deviceId;

  /// Food name (should match foods.name) - matches Supabase food_preferences.food_name
  final String foodName;

  /// Preference type: 'like', 'dislike', 'willing_to_try' (matches Supabase constraint)
  final String preference;

  /// When the preference was created (matches Supabase food_preferences.created_at)
  final DateTime createdAt;

  /// When the preference was last updated (matches Supabase food_preferences.updated_at)
  final DateTime updatedAt;
  const FoodPreferenceEntry(
      {required this.id,
      required this.deviceId,
      required this.foodName,
      required this.preference,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['food_name'] = Variable<String>(foodName);
    map['preference'] = Variable<String>(preference);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FoodPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return FoodPreferencesTableCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      foodName: Value(foodName),
      preference: Value(preference),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FoodPreferenceEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodPreferenceEntry(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      foodName: serializer.fromJson<String>(json['foodName']),
      preference: serializer.fromJson<String>(json['preference']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'foodName': serializer.toJson<String>(foodName),
      'preference': serializer.toJson<String>(preference),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FoodPreferenceEntry copyWith(
          {String? id,
          String? deviceId,
          String? foodName,
          String? preference,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      FoodPreferenceEntry(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        foodName: foodName ?? this.foodName,
        preference: preference ?? this.preference,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FoodPreferenceEntry copyWithCompanion(FoodPreferencesTableCompanion data) {
    return FoodPreferenceEntry(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      preference:
          data.preference.present ? data.preference.value : this.preference,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodPreferenceEntry(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('foodName: $foodName, ')
          ..write('preference: $preference, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deviceId, foodName, preference, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodPreferenceEntry &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.foodName == this.foodName &&
          other.preference == this.preference &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FoodPreferencesTableCompanion
    extends UpdateCompanion<FoodPreferenceEntry> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> foodName;
  final Value<String> preference;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FoodPreferencesTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.foodName = const Value.absent(),
    this.preference = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodPreferencesTableCompanion.insert({
    required String id,
    required String deviceId,
    required String foodName,
    required String preference,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        deviceId = Value(deviceId),
        foodName = Value(foodName),
        preference = Value(preference);
  static Insertable<FoodPreferenceEntry> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? foodName,
    Expression<String>? preference,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (foodName != null) 'food_name': foodName,
      if (preference != null) 'preference': preference,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodPreferencesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? deviceId,
      Value<String>? foodName,
      Value<String>? preference,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return FoodPreferencesTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      foodName: foodName ?? this.foodName,
      preference: preference ?? this.preference,
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
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
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('foodName: $foodName, ')
          ..write('preference: $preference, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NutritionPlansTable extends NutritionPlans
    with TableInfo<$NutritionPlansTable, NutritionPlanEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NutritionPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planDataMeta =
      const VerificationMeta('planData');
  @override
  late final GeneratedColumn<String> planData = GeneratedColumn<String>(
      'plan_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planNameMeta =
      const VerificationMeta('planName');
  @override
  late final GeneratedColumn<String> planName = GeneratedColumn<String>(
      'plan_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _distanceMilesMeta =
      const VerificationMeta('distanceMiles');
  @override
  late final GeneratedColumn<double> distanceMiles = GeneratedColumn<double>(
      'distance_miles', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _paceMinutesPerMileMeta =
      const VerificationMeta('paceMinutesPerMile');
  @override
  late final GeneratedColumn<double> paceMinutesPerMile =
      GeneratedColumn<double>('pace_minutes_per_mile', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _totalCaloriesMeta =
      const VerificationMeta('totalCalories');
  @override
  late final GeneratedColumn<int> totalCalories = GeneratedColumn<int>(
      'total_calories', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lastModifiedByMeta =
      const VerificationMeta('lastModifiedBy');
  @override
  late final GeneratedColumn<String> lastModifiedBy = GeneratedColumn<String>(
      'last_modified_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>('client_updated_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _conflictResolutionMeta =
      const VerificationMeta('conflictResolution');
  @override
  late final GeneratedColumn<String> conflictResolution =
      GeneratedColumn<String>('conflict_resolution', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deviceId,
        planData,
        planId,
        planName,
        distanceMiles,
        paceMinutesPerMile,
        totalCalories,
        notes,
        version,
        lastModifiedBy,
        clientUpdatedAt,
        isDeleted,
        conflictResolution,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nutrition_plans';
  @override
  VerificationContext validateIntegrity(Insertable<NutritionPlanEntry> instance,
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
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('plan_data')) {
      context.handle(_planDataMeta,
          planData.isAcceptableOrUnknown(data['plan_data']!, _planDataMeta));
    } else if (isInserting) {
      context.missing(_planDataMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('plan_name')) {
      context.handle(_planNameMeta,
          planName.isAcceptableOrUnknown(data['plan_name']!, _planNameMeta));
    } else if (isInserting) {
      context.missing(_planNameMeta);
    }
    if (data.containsKey('distance_miles')) {
      context.handle(
          _distanceMilesMeta,
          distanceMiles.isAcceptableOrUnknown(
              data['distance_miles']!, _distanceMilesMeta));
    }
    if (data.containsKey('pace_minutes_per_mile')) {
      context.handle(
          _paceMinutesPerMileMeta,
          paceMinutesPerMile.isAcceptableOrUnknown(
              data['pace_minutes_per_mile']!, _paceMinutesPerMileMeta));
    }
    if (data.containsKey('total_calories')) {
      context.handle(
          _totalCaloriesMeta,
          totalCalories.isAcceptableOrUnknown(
              data['total_calories']!, _totalCaloriesMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('last_modified_by')) {
      context.handle(
          _lastModifiedByMeta,
          lastModifiedBy.isAcceptableOrUnknown(
              data['last_modified_by']!, _lastModifiedByMeta));
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('conflict_resolution')) {
      context.handle(
          _conflictResolutionMeta,
          conflictResolution.isAcceptableOrUnknown(
              data['conflict_resolution']!, _conflictResolutionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NutritionPlanEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NutritionPlanEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      planData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_data'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      planName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_name'])!,
      distanceMiles: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_miles']),
      paceMinutesPerMile: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pace_minutes_per_mile']),
      totalCalories: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_calories']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      lastModifiedBy: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_modified_by']),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}client_updated_at']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      conflictResolution: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conflict_resolution']),
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

class NutritionPlanEntry extends DataClass
    implements Insertable<NutritionPlanEntry> {
  /// UUID primary key (matches Supabase nutrition_plans.id)
  final String id;

  /// Device ID (foreign key reference to users.device_id)
  final String deviceId;

  /// Plan data stored as JSON (matches Supabase nutrition_plans.plan_data)
  final String planData;

  /// Plan metadata (matches Supabase schema)
  final String planId;
  final String planName;
  final double? distanceMiles;
  final double? paceMinutesPerMile;
  final int? totalCalories;
  final String? notes;

  /// Versioning and sync (matches Supabase schema)
  final int version;
  final String? lastModifiedBy;
  final DateTime? clientUpdatedAt;
  final bool isDeleted;
  final String? conflictResolution;

  /// Timestamps (matches Supabase schema)
  final DateTime createdAt;
  final DateTime updatedAt;
  const NutritionPlanEntry(
      {required this.id,
      required this.deviceId,
      required this.planData,
      required this.planId,
      required this.planName,
      this.distanceMiles,
      this.paceMinutesPerMile,
      this.totalCalories,
      this.notes,
      required this.version,
      this.lastModifiedBy,
      this.clientUpdatedAt,
      required this.isDeleted,
      this.conflictResolution,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['plan_data'] = Variable<String>(planData);
    map['plan_id'] = Variable<String>(planId);
    map['plan_name'] = Variable<String>(planName);
    if (!nullToAbsent || distanceMiles != null) {
      map['distance_miles'] = Variable<double>(distanceMiles);
    }
    if (!nullToAbsent || paceMinutesPerMile != null) {
      map['pace_minutes_per_mile'] = Variable<double>(paceMinutesPerMile);
    }
    if (!nullToAbsent || totalCalories != null) {
      map['total_calories'] = Variable<int>(totalCalories);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || lastModifiedBy != null) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy);
    }
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || conflictResolution != null) {
      map['conflict_resolution'] = Variable<String>(conflictResolution);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NutritionPlansCompanion toCompanion(bool nullToAbsent) {
    return NutritionPlansCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      planData: Value(planData),
      planId: Value(planId),
      planName: Value(planName),
      distanceMiles: distanceMiles == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMiles),
      paceMinutesPerMile: paceMinutesPerMile == null && nullToAbsent
          ? const Value.absent()
          : Value(paceMinutesPerMile),
      totalCalories: totalCalories == null && nullToAbsent
          ? const Value.absent()
          : Value(totalCalories),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      version: Value(version),
      lastModifiedBy: lastModifiedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedBy),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      isDeleted: Value(isDeleted),
      conflictResolution: conflictResolution == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictResolution),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NutritionPlanEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NutritionPlanEntry(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      planData: serializer.fromJson<String>(json['planData']),
      planId: serializer.fromJson<String>(json['planId']),
      planName: serializer.fromJson<String>(json['planName']),
      distanceMiles: serializer.fromJson<double?>(json['distanceMiles']),
      paceMinutesPerMile:
          serializer.fromJson<double?>(json['paceMinutesPerMile']),
      totalCalories: serializer.fromJson<int?>(json['totalCalories']),
      notes: serializer.fromJson<String?>(json['notes']),
      version: serializer.fromJson<int>(json['version']),
      lastModifiedBy: serializer.fromJson<String?>(json['lastModifiedBy']),
      clientUpdatedAt: serializer.fromJson<DateTime?>(json['clientUpdatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      conflictResolution:
          serializer.fromJson<String?>(json['conflictResolution']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'planData': serializer.toJson<String>(planData),
      'planId': serializer.toJson<String>(planId),
      'planName': serializer.toJson<String>(planName),
      'distanceMiles': serializer.toJson<double?>(distanceMiles),
      'paceMinutesPerMile': serializer.toJson<double?>(paceMinutesPerMile),
      'totalCalories': serializer.toJson<int?>(totalCalories),
      'notes': serializer.toJson<String?>(notes),
      'version': serializer.toJson<int>(version),
      'lastModifiedBy': serializer.toJson<String?>(lastModifiedBy),
      'clientUpdatedAt': serializer.toJson<DateTime?>(clientUpdatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'conflictResolution': serializer.toJson<String?>(conflictResolution),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NutritionPlanEntry copyWith(
          {String? id,
          String? deviceId,
          String? planData,
          String? planId,
          String? planName,
          Value<double?> distanceMiles = const Value.absent(),
          Value<double?> paceMinutesPerMile = const Value.absent(),
          Value<int?> totalCalories = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          int? version,
          Value<String?> lastModifiedBy = const Value.absent(),
          Value<DateTime?> clientUpdatedAt = const Value.absent(),
          bool? isDeleted,
          Value<String?> conflictResolution = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      NutritionPlanEntry(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        planData: planData ?? this.planData,
        planId: planId ?? this.planId,
        planName: planName ?? this.planName,
        distanceMiles:
            distanceMiles.present ? distanceMiles.value : this.distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile.present
            ? paceMinutesPerMile.value
            : this.paceMinutesPerMile,
        totalCalories:
            totalCalories.present ? totalCalories.value : this.totalCalories,
        notes: notes.present ? notes.value : this.notes,
        version: version ?? this.version,
        lastModifiedBy:
            lastModifiedBy.present ? lastModifiedBy.value : this.lastModifiedBy,
        clientUpdatedAt: clientUpdatedAt.present
            ? clientUpdatedAt.value
            : this.clientUpdatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        conflictResolution: conflictResolution.present
            ? conflictResolution.value
            : this.conflictResolution,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  NutritionPlanEntry copyWithCompanion(NutritionPlansCompanion data) {
    return NutritionPlanEntry(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      planData: data.planData.present ? data.planData.value : this.planData,
      planId: data.planId.present ? data.planId.value : this.planId,
      planName: data.planName.present ? data.planName.value : this.planName,
      distanceMiles: data.distanceMiles.present
          ? data.distanceMiles.value
          : this.distanceMiles,
      paceMinutesPerMile: data.paceMinutesPerMile.present
          ? data.paceMinutesPerMile.value
          : this.paceMinutesPerMile,
      totalCalories: data.totalCalories.present
          ? data.totalCalories.value
          : this.totalCalories,
      notes: data.notes.present ? data.notes.value : this.notes,
      version: data.version.present ? data.version.value : this.version,
      lastModifiedBy: data.lastModifiedBy.present
          ? data.lastModifiedBy.value
          : this.lastModifiedBy,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      conflictResolution: data.conflictResolution.present
          ? data.conflictResolution.value
          : this.conflictResolution,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NutritionPlanEntry(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('planData: $planData, ')
          ..write('planId: $planId, ')
          ..write('planName: $planName, ')
          ..write('distanceMiles: $distanceMiles, ')
          ..write('paceMinutesPerMile: $paceMinutesPerMile, ')
          ..write('totalCalories: $totalCalories, ')
          ..write('notes: $notes, ')
          ..write('version: $version, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('conflictResolution: $conflictResolution, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      deviceId,
      planData,
      planId,
      planName,
      distanceMiles,
      paceMinutesPerMile,
      totalCalories,
      notes,
      version,
      lastModifiedBy,
      clientUpdatedAt,
      isDeleted,
      conflictResolution,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NutritionPlanEntry &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.planData == this.planData &&
          other.planId == this.planId &&
          other.planName == this.planName &&
          other.distanceMiles == this.distanceMiles &&
          other.paceMinutesPerMile == this.paceMinutesPerMile &&
          other.totalCalories == this.totalCalories &&
          other.notes == this.notes &&
          other.version == this.version &&
          other.lastModifiedBy == this.lastModifiedBy &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.isDeleted == this.isDeleted &&
          other.conflictResolution == this.conflictResolution &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NutritionPlansCompanion extends UpdateCompanion<NutritionPlanEntry> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> planData;
  final Value<String> planId;
  final Value<String> planName;
  final Value<double?> distanceMiles;
  final Value<double?> paceMinutesPerMile;
  final Value<int?> totalCalories;
  final Value<String?> notes;
  final Value<int> version;
  final Value<String?> lastModifiedBy;
  final Value<DateTime?> clientUpdatedAt;
  final Value<bool> isDeleted;
  final Value<String?> conflictResolution;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NutritionPlansCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.planData = const Value.absent(),
    this.planId = const Value.absent(),
    this.planName = const Value.absent(),
    this.distanceMiles = const Value.absent(),
    this.paceMinutesPerMile = const Value.absent(),
    this.totalCalories = const Value.absent(),
    this.notes = const Value.absent(),
    this.version = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.conflictResolution = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NutritionPlansCompanion.insert({
    required String id,
    required String deviceId,
    required String planData,
    required String planId,
    required String planName,
    this.distanceMiles = const Value.absent(),
    this.paceMinutesPerMile = const Value.absent(),
    this.totalCalories = const Value.absent(),
    this.notes = const Value.absent(),
    this.version = const Value.absent(),
    this.lastModifiedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.conflictResolution = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        deviceId = Value(deviceId),
        planData = Value(planData),
        planId = Value(planId),
        planName = Value(planName);
  static Insertable<NutritionPlanEntry> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? planData,
    Expression<String>? planId,
    Expression<String>? planName,
    Expression<double>? distanceMiles,
    Expression<double>? paceMinutesPerMile,
    Expression<int>? totalCalories,
    Expression<String>? notes,
    Expression<int>? version,
    Expression<String>? lastModifiedBy,
    Expression<DateTime>? clientUpdatedAt,
    Expression<bool>? isDeleted,
    Expression<String>? conflictResolution,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (planData != null) 'plan_data': planData,
      if (planId != null) 'plan_id': planId,
      if (planName != null) 'plan_name': planName,
      if (distanceMiles != null) 'distance_miles': distanceMiles,
      if (paceMinutesPerMile != null)
        'pace_minutes_per_mile': paceMinutesPerMile,
      if (totalCalories != null) 'total_calories': totalCalories,
      if (notes != null) 'notes': notes,
      if (version != null) 'version': version,
      if (lastModifiedBy != null) 'last_modified_by': lastModifiedBy,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (conflictResolution != null) 'conflict_resolution': conflictResolution,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NutritionPlansCompanion copyWith(
      {Value<String>? id,
      Value<String>? deviceId,
      Value<String>? planData,
      Value<String>? planId,
      Value<String>? planName,
      Value<double?>? distanceMiles,
      Value<double?>? paceMinutesPerMile,
      Value<int?>? totalCalories,
      Value<String?>? notes,
      Value<int>? version,
      Value<String?>? lastModifiedBy,
      Value<DateTime?>? clientUpdatedAt,
      Value<bool>? isDeleted,
      Value<String?>? conflictResolution,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return NutritionPlansCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      planData: planData ?? this.planData,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile ?? this.paceMinutesPerMile,
      totalCalories: totalCalories ?? this.totalCalories,
      notes: notes ?? this.notes,
      version: version ?? this.version,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      conflictResolution: conflictResolution ?? this.conflictResolution,
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (planData.present) {
      map['plan_data'] = Variable<String>(planData.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (planName.present) {
      map['plan_name'] = Variable<String>(planName.value);
    }
    if (distanceMiles.present) {
      map['distance_miles'] = Variable<double>(distanceMiles.value);
    }
    if (paceMinutesPerMile.present) {
      map['pace_minutes_per_mile'] = Variable<double>(paceMinutesPerMile.value);
    }
    if (totalCalories.present) {
      map['total_calories'] = Variable<int>(totalCalories.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (lastModifiedBy.present) {
      map['last_modified_by'] = Variable<String>(lastModifiedBy.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (conflictResolution.present) {
      map['conflict_resolution'] = Variable<String>(conflictResolution.value);
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
          ..write('deviceId: $deviceId, ')
          ..write('planData: $planData, ')
          ..write('planId: $planId, ')
          ..write('planName: $planName, ')
          ..write('distanceMiles: $distanceMiles, ')
          ..write('paceMinutesPerMile: $paceMinutesPerMile, ')
          ..write('totalCalories: $totalCalories, ')
          ..write('notes: $notes, ')
          ..write('version: $version, ')
          ..write('lastModifiedBy: $lastModifiedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('conflictResolution: $conflictResolution, ')
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

class $FoodsTableTable extends FoodsTable
    with TableInfo<$FoodsTableTable, FoodEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageAddressMeta =
      const VerificationMeta('imageAddress');
  @override
  late final GeneratedColumn<String> imageAddress = GeneratedColumn<String>(
      'image_address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _servingAmountMeta =
      const VerificationMeta('servingAmount');
  @override
  late final GeneratedColumn<double> servingAmount = GeneratedColumn<double>(
      'serving_amount', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _maxServingsBeforeMeta =
      const VerificationMeta('maxServingsBefore');
  @override
  late final GeneratedColumn<int> maxServingsBefore = GeneratedColumn<int>(
      'max_servings_before', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _maxServingsDuringMeta =
      const VerificationMeta('maxServingsDuring');
  @override
  late final GeneratedColumn<int> maxServingsDuring = GeneratedColumn<int>(
      'max_servings_during', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _maxServingsAfterMeta =
      const VerificationMeta('maxServingsAfter');
  @override
  late final GeneratedColumn<int> maxServingsAfter = GeneratedColumn<int>(
      'max_servings_after', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _beforeRunSuitableMeta =
      const VerificationMeta('beforeRunSuitable');
  @override
  late final GeneratedColumn<bool> beforeRunSuitable = GeneratedColumn<bool>(
      'before_run_suitable', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("before_run_suitable" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _duringRunSuitableMeta =
      const VerificationMeta('duringRunSuitable');
  @override
  late final GeneratedColumn<bool> duringRunSuitable = GeneratedColumn<bool>(
      'during_run_suitable', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("during_run_suitable" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _runPortableMeta =
      const VerificationMeta('runPortable');
  @override
  late final GeneratedColumn<bool> runPortable = GeneratedColumn<bool>(
      'run_portable', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("run_portable" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _requiresPreparationMeta =
      const VerificationMeta('requiresPreparation');
  @override
  late final GeneratedColumn<bool> requiresPreparation = GeneratedColumn<bool>(
      'requires_preparation', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("requires_preparation" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _aidStationAvailableMeta =
      const VerificationMeta('aidStationAvailable');
  @override
  late final GeneratedColumn<bool> aidStationAvailable = GeneratedColumn<bool>(
      'aid_station_available', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("aid_station_available" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sodiumMgMeta =
      const VerificationMeta('sodiumMg');
  @override
  late final GeneratedColumn<int> sodiumMg = GeneratedColumn<int>(
      'sodium_mg', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _caffeineMgMeta =
      const VerificationMeta('caffeineMg');
  @override
  late final GeneratedColumn<int> caffeineMg = GeneratedColumn<int>(
      'caffeine_mg', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _potassiumMgMeta =
      const VerificationMeta('potassiumMg');
  @override
  late final GeneratedColumn<int> potassiumMg = GeneratedColumn<int>(
      'potassium_mg', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _fatPerServingMeta =
      const VerificationMeta('fatPerServing');
  @override
  late final GeneratedColumn<double> fatPerServing = GeneratedColumn<double>(
      'fat_per_serving', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _carbsPerServingMeta =
      const VerificationMeta('carbsPerServing');
  @override
  late final GeneratedColumn<double> carbsPerServing = GeneratedColumn<double>(
      'carbs_per_serving', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _proteinPerServingMeta =
      const VerificationMeta('proteinPerServing');
  @override
  late final GeneratedColumn<double> proteinPerServing =
      GeneratedColumn<double>('protein_per_serving', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _caloriesPerServingMeta =
      const VerificationMeta('caloriesPerServing');
  @override
  late final GeneratedColumn<int> caloriesPerServing = GeneratedColumn<int>(
      'calories_per_serving', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _fluidMlPerServingMeta =
      const VerificationMeta('fluidMlPerServing');
  @override
  late final GeneratedColumn<double> fluidMlPerServing =
      GeneratedColumn<double>('fluid_ml_per_serving', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _brandIdMeta =
      const VerificationMeta('brandId');
  @override
  late final GeneratedColumn<String> brandId = GeneratedColumn<String>(
      'brand_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _showInPreferencesMeta =
      const VerificationMeta('showInPreferences');
  @override
  late final GeneratedColumn<bool> showInPreferences = GeneratedColumn<bool>(
      'show_in_preferences', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("show_in_preferences" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isElectrolyteMeta =
      const VerificationMeta('isElectrolyte');
  @override
  late final GeneratedColumn<bool> isElectrolyte = GeneratedColumn<bool>(
      'is_electrolyte', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_electrolyte" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _displayNamePluralMeta =
      const VerificationMeta('displayNamePlural');
  @override
  late final GeneratedColumn<String> displayNamePlural =
      GeneratedColumn<String>('display_name_plural', aliasedName, true,
          additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
          type: DriftSqlType.string,
          requiredDuringInsert: false);
  static const VerificationMeta _servingDescriptionMeta =
      const VerificationMeta('servingDescription');
  @override
  late final GeneratedColumn<String> servingDescription =
      GeneratedColumn<String>('serving_description', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _instructionsMeta =
      const VerificationMeta('instructions');
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
      'instructions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nutritionalInfoMeta =
      const VerificationMeta('nutritionalInfo');
  @override
  late final GeneratedColumn<String> nutritionalInfo = GeneratedColumn<String>(
      'nutritional_info', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingUnitMeta =
      const VerificationMeta('servingUnit');
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
      'serving_unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingUnitPluralMeta =
      const VerificationMeta('servingUnitPlural');
  @override
  late final GeneratedColumn<String> servingUnitPlural =
      GeneratedColumn<String>('serving_unit_plural', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingQualifierMeta =
      const VerificationMeta('servingQualifier');
  @override
  late final GeneratedColumn<String> servingQualifier = GeneratedColumn<String>(
      'serving_qualifier', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingSizeMeta =
      const VerificationMeta('servingSize');
  @override
  late final GeneratedColumn<String> servingSize = GeneratedColumn<String>(
      'serving_size', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _afterRunSuitableMeta =
      const VerificationMeta('afterRunSuitable');
  @override
  late final GeneratedColumn<bool> afterRunSuitable = GeneratedColumn<bool>(
      'after_run_suitable', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("after_run_suitable" IN (0, 1))'));
  static const VerificationMeta _productTypeMeta =
      const VerificationMeta('productType');
  @override
  late final GeneratedColumn<String> productType = GeneratedColumn<String>(
      'product_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purchaseUrlMeta =
      const VerificationMeta('purchaseUrl');
  @override
  late final GeneratedColumn<String> purchaseUrl = GeneratedColumn<String>(
      'purchase_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _affiliateSourceMeta =
      const VerificationMeta('affiliateSource');
  @override
  late final GeneratedColumn<String> affiliateSource = GeneratedColumn<String>(
      'affiliate_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _preferencePriorityMeta =
      const VerificationMeta('preferencePriority');
  @override
  late final GeneratedColumn<int> preferencePriority = GeneratedColumn<int>(
      'preference_priority', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        imageAddress,
        createdAt,
        servingAmount,
        maxServingsBefore,
        maxServingsDuring,
        maxServingsAfter,
        beforeRunSuitable,
        duringRunSuitable,
        runPortable,
        requiresPreparation,
        aidStationAvailable,
        sodiumMg,
        caffeineMg,
        potassiumMg,
        fatPerServing,
        carbsPerServing,
        proteinPerServing,
        caloriesPerServing,
        fluidMlPerServing,
        brandId,
        showInPreferences,
        isElectrolyte,
        displayName,
        displayNamePlural,
        servingDescription,
        description,
        instructions,
        nutritionalInfo,
        servingUnit,
        servingUnitPlural,
        servingQualifier,
        servingSize,
        afterRunSuitable,
        productType,
        purchaseUrl,
        affiliateSource,
        preferencePriority
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods_table';
  @override
  VerificationContext validateIntegrity(Insertable<FoodEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('image_address')) {
      context.handle(
          _imageAddressMeta,
          imageAddress.isAcceptableOrUnknown(
              data['image_address']!, _imageAddressMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('serving_amount')) {
      context.handle(
          _servingAmountMeta,
          servingAmount.isAcceptableOrUnknown(
              data['serving_amount']!, _servingAmountMeta));
    }
    if (data.containsKey('max_servings_before')) {
      context.handle(
          _maxServingsBeforeMeta,
          maxServingsBefore.isAcceptableOrUnknown(
              data['max_servings_before']!, _maxServingsBeforeMeta));
    }
    if (data.containsKey('max_servings_during')) {
      context.handle(
          _maxServingsDuringMeta,
          maxServingsDuring.isAcceptableOrUnknown(
              data['max_servings_during']!, _maxServingsDuringMeta));
    }
    if (data.containsKey('max_servings_after')) {
      context.handle(
          _maxServingsAfterMeta,
          maxServingsAfter.isAcceptableOrUnknown(
              data['max_servings_after']!, _maxServingsAfterMeta));
    }
    if (data.containsKey('before_run_suitable')) {
      context.handle(
          _beforeRunSuitableMeta,
          beforeRunSuitable.isAcceptableOrUnknown(
              data['before_run_suitable']!, _beforeRunSuitableMeta));
    }
    if (data.containsKey('during_run_suitable')) {
      context.handle(
          _duringRunSuitableMeta,
          duringRunSuitable.isAcceptableOrUnknown(
              data['during_run_suitable']!, _duringRunSuitableMeta));
    }
    if (data.containsKey('run_portable')) {
      context.handle(
          _runPortableMeta,
          runPortable.isAcceptableOrUnknown(
              data['run_portable']!, _runPortableMeta));
    }
    if (data.containsKey('requires_preparation')) {
      context.handle(
          _requiresPreparationMeta,
          requiresPreparation.isAcceptableOrUnknown(
              data['requires_preparation']!, _requiresPreparationMeta));
    }
    if (data.containsKey('aid_station_available')) {
      context.handle(
          _aidStationAvailableMeta,
          aidStationAvailable.isAcceptableOrUnknown(
              data['aid_station_available']!, _aidStationAvailableMeta));
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(_sodiumMgMeta,
          sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta));
    }
    if (data.containsKey('caffeine_mg')) {
      context.handle(
          _caffeineMgMeta,
          caffeineMg.isAcceptableOrUnknown(
              data['caffeine_mg']!, _caffeineMgMeta));
    }
    if (data.containsKey('potassium_mg')) {
      context.handle(
          _potassiumMgMeta,
          potassiumMg.isAcceptableOrUnknown(
              data['potassium_mg']!, _potassiumMgMeta));
    }
    if (data.containsKey('fat_per_serving')) {
      context.handle(
          _fatPerServingMeta,
          fatPerServing.isAcceptableOrUnknown(
              data['fat_per_serving']!, _fatPerServingMeta));
    }
    if (data.containsKey('carbs_per_serving')) {
      context.handle(
          _carbsPerServingMeta,
          carbsPerServing.isAcceptableOrUnknown(
              data['carbs_per_serving']!, _carbsPerServingMeta));
    }
    if (data.containsKey('protein_per_serving')) {
      context.handle(
          _proteinPerServingMeta,
          proteinPerServing.isAcceptableOrUnknown(
              data['protein_per_serving']!, _proteinPerServingMeta));
    }
    if (data.containsKey('calories_per_serving')) {
      context.handle(
          _caloriesPerServingMeta,
          caloriesPerServing.isAcceptableOrUnknown(
              data['calories_per_serving']!, _caloriesPerServingMeta));
    }
    if (data.containsKey('fluid_ml_per_serving')) {
      context.handle(
          _fluidMlPerServingMeta,
          fluidMlPerServing.isAcceptableOrUnknown(
              data['fluid_ml_per_serving']!, _fluidMlPerServingMeta));
    }
    if (data.containsKey('brand_id')) {
      context.handle(_brandIdMeta,
          brandId.isAcceptableOrUnknown(data['brand_id']!, _brandIdMeta));
    }
    if (data.containsKey('show_in_preferences')) {
      context.handle(
          _showInPreferencesMeta,
          showInPreferences.isAcceptableOrUnknown(
              data['show_in_preferences']!, _showInPreferencesMeta));
    }
    if (data.containsKey('is_electrolyte')) {
      context.handle(
          _isElectrolyteMeta,
          isElectrolyte.isAcceptableOrUnknown(
              data['is_electrolyte']!, _isElectrolyteMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('display_name_plural')) {
      context.handle(
          _displayNamePluralMeta,
          displayNamePlural.isAcceptableOrUnknown(
              data['display_name_plural']!, _displayNamePluralMeta));
    }
    if (data.containsKey('serving_description')) {
      context.handle(
          _servingDescriptionMeta,
          servingDescription.isAcceptableOrUnknown(
              data['serving_description']!, _servingDescriptionMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('instructions')) {
      context.handle(
          _instructionsMeta,
          instructions.isAcceptableOrUnknown(
              data['instructions']!, _instructionsMeta));
    }
    if (data.containsKey('nutritional_info')) {
      context.handle(
          _nutritionalInfoMeta,
          nutritionalInfo.isAcceptableOrUnknown(
              data['nutritional_info']!, _nutritionalInfoMeta));
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
          _servingUnitMeta,
          servingUnit.isAcceptableOrUnknown(
              data['serving_unit']!, _servingUnitMeta));
    }
    if (data.containsKey('serving_unit_plural')) {
      context.handle(
          _servingUnitPluralMeta,
          servingUnitPlural.isAcceptableOrUnknown(
              data['serving_unit_plural']!, _servingUnitPluralMeta));
    }
    if (data.containsKey('serving_qualifier')) {
      context.handle(
          _servingQualifierMeta,
          servingQualifier.isAcceptableOrUnknown(
              data['serving_qualifier']!, _servingQualifierMeta));
    }
    if (data.containsKey('serving_size')) {
      context.handle(
          _servingSizeMeta,
          servingSize.isAcceptableOrUnknown(
              data['serving_size']!, _servingSizeMeta));
    }
    if (data.containsKey('after_run_suitable')) {
      context.handle(
          _afterRunSuitableMeta,
          afterRunSuitable.isAcceptableOrUnknown(
              data['after_run_suitable']!, _afterRunSuitableMeta));
    }
    if (data.containsKey('product_type')) {
      context.handle(
          _productTypeMeta,
          productType.isAcceptableOrUnknown(
              data['product_type']!, _productTypeMeta));
    }
    if (data.containsKey('purchase_url')) {
      context.handle(
          _purchaseUrlMeta,
          purchaseUrl.isAcceptableOrUnknown(
              data['purchase_url']!, _purchaseUrlMeta));
    }
    if (data.containsKey('affiliate_source')) {
      context.handle(
          _affiliateSourceMeta,
          affiliateSource.isAcceptableOrUnknown(
              data['affiliate_source']!, _affiliateSourceMeta));
    }
    if (data.containsKey('preference_priority')) {
      context.handle(
          _preferencePriorityMeta,
          preferencePriority.isAcceptableOrUnknown(
              data['preference_priority']!, _preferencePriorityMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      imageAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_address']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      servingAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}serving_amount']),
      maxServingsBefore: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}max_servings_before']),
      maxServingsDuring: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}max_servings_during']),
      maxServingsAfter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_servings_after']),
      beforeRunSuitable: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}before_run_suitable'])!,
      duringRunSuitable: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}during_run_suitable'])!,
      runPortable: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}run_portable'])!,
      requiresPreparation: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}requires_preparation'])!,
      aidStationAvailable: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}aid_station_available'])!,
      sodiumMg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sodium_mg']),
      caffeineMg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}caffeine_mg']),
      potassiumMg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}potassium_mg']),
      fatPerServing: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat_per_serving']),
      carbsPerServing: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}carbs_per_serving']),
      proteinPerServing: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}protein_per_serving']),
      caloriesPerServing: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}calories_per_serving']),
      fluidMlPerServing: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}fluid_ml_per_serving']),
      brandId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand_id']),
      showInPreferences: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}show_in_preferences'])!,
      isElectrolyte: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_electrolyte'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      displayNamePlural: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}display_name_plural']),
      servingDescription: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}serving_description']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      instructions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}instructions']),
      nutritionalInfo: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}nutritional_info']),
      servingUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serving_unit']),
      servingUnitPlural: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}serving_unit_plural']),
      servingQualifier: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}serving_qualifier']),
      servingSize: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serving_size']),
      afterRunSuitable: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}after_run_suitable']),
      productType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_type']),
      purchaseUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}purchase_url']),
      affiliateSource: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}affiliate_source']),
      preferencePriority: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}preference_priority']),
    );
  }

  @override
  $FoodsTableTable createAlias(String alias) {
    return $FoodsTableTable(attachedDatabase, alias);
  }
}

class FoodEntry extends DataClass implements Insertable<FoodEntry> {
  /// UUID primary key (matches Supabase foods.id)
  final String id;

  /// Food name (matches Supabase foods.name)
  final String? name;

  /// Image URL (matches Supabase foods.image_address)
  final String? imageAddress;

  /// When the food was created (matches Supabase foods.created_at)
  final DateTime createdAt;
  final double? servingAmount;
  final int? maxServingsBefore;
  final int? maxServingsDuring;
  final int? maxServingsAfter;
  final bool beforeRunSuitable;
  final bool duringRunSuitable;
  final bool runPortable;
  final bool requiresPreparation;
  final bool aidStationAvailable;
  final int? sodiumMg;
  final int? caffeineMg;
  final int? potassiumMg;
  final double? fatPerServing;
  final double? carbsPerServing;
  final double? proteinPerServing;
  final int? caloriesPerServing;
  final double? fluidMlPerServing;
  final String? brandId;
  final bool showInPreferences;
  final bool isElectrolyte;
  final String? displayName;
  final String? displayNamePlural;
  final String? servingDescription;
  final String? description;
  final String? instructions;
  final String? nutritionalInfo;
  final String? servingUnit;
  final String? servingUnitPlural;
  final String? servingQualifier;
  final String? servingSize;
  final bool? afterRunSuitable;
  final String? productType;
  final String? purchaseUrl;
  final String? affiliateSource;
  final int? preferencePriority;
  const FoodEntry(
      {required this.id,
      this.name,
      this.imageAddress,
      required this.createdAt,
      this.servingAmount,
      this.maxServingsBefore,
      this.maxServingsDuring,
      this.maxServingsAfter,
      required this.beforeRunSuitable,
      required this.duringRunSuitable,
      required this.runPortable,
      required this.requiresPreparation,
      required this.aidStationAvailable,
      this.sodiumMg,
      this.caffeineMg,
      this.potassiumMg,
      this.fatPerServing,
      this.carbsPerServing,
      this.proteinPerServing,
      this.caloriesPerServing,
      this.fluidMlPerServing,
      this.brandId,
      required this.showInPreferences,
      required this.isElectrolyte,
      this.displayName,
      this.displayNamePlural,
      this.servingDescription,
      this.description,
      this.instructions,
      this.nutritionalInfo,
      this.servingUnit,
      this.servingUnitPlural,
      this.servingQualifier,
      this.servingSize,
      this.afterRunSuitable,
      this.productType,
      this.purchaseUrl,
      this.affiliateSource,
      this.preferencePriority});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || imageAddress != null) {
      map['image_address'] = Variable<String>(imageAddress);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || servingAmount != null) {
      map['serving_amount'] = Variable<double>(servingAmount);
    }
    if (!nullToAbsent || maxServingsBefore != null) {
      map['max_servings_before'] = Variable<int>(maxServingsBefore);
    }
    if (!nullToAbsent || maxServingsDuring != null) {
      map['max_servings_during'] = Variable<int>(maxServingsDuring);
    }
    if (!nullToAbsent || maxServingsAfter != null) {
      map['max_servings_after'] = Variable<int>(maxServingsAfter);
    }
    map['before_run_suitable'] = Variable<bool>(beforeRunSuitable);
    map['during_run_suitable'] = Variable<bool>(duringRunSuitable);
    map['run_portable'] = Variable<bool>(runPortable);
    map['requires_preparation'] = Variable<bool>(requiresPreparation);
    map['aid_station_available'] = Variable<bool>(aidStationAvailable);
    if (!nullToAbsent || sodiumMg != null) {
      map['sodium_mg'] = Variable<int>(sodiumMg);
    }
    if (!nullToAbsent || caffeineMg != null) {
      map['caffeine_mg'] = Variable<int>(caffeineMg);
    }
    if (!nullToAbsent || potassiumMg != null) {
      map['potassium_mg'] = Variable<int>(potassiumMg);
    }
    if (!nullToAbsent || fatPerServing != null) {
      map['fat_per_serving'] = Variable<double>(fatPerServing);
    }
    if (!nullToAbsent || carbsPerServing != null) {
      map['carbs_per_serving'] = Variable<double>(carbsPerServing);
    }
    if (!nullToAbsent || proteinPerServing != null) {
      map['protein_per_serving'] = Variable<double>(proteinPerServing);
    }
    if (!nullToAbsent || caloriesPerServing != null) {
      map['calories_per_serving'] = Variable<int>(caloriesPerServing);
    }
    if (!nullToAbsent || fluidMlPerServing != null) {
      map['fluid_ml_per_serving'] = Variable<double>(fluidMlPerServing);
    }
    if (!nullToAbsent || brandId != null) {
      map['brand_id'] = Variable<String>(brandId);
    }
    map['show_in_preferences'] = Variable<bool>(showInPreferences);
    map['is_electrolyte'] = Variable<bool>(isElectrolyte);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || displayNamePlural != null) {
      map['display_name_plural'] = Variable<String>(displayNamePlural);
    }
    if (!nullToAbsent || servingDescription != null) {
      map['serving_description'] = Variable<String>(servingDescription);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || instructions != null) {
      map['instructions'] = Variable<String>(instructions);
    }
    if (!nullToAbsent || nutritionalInfo != null) {
      map['nutritional_info'] = Variable<String>(nutritionalInfo);
    }
    if (!nullToAbsent || servingUnit != null) {
      map['serving_unit'] = Variable<String>(servingUnit);
    }
    if (!nullToAbsent || servingUnitPlural != null) {
      map['serving_unit_plural'] = Variable<String>(servingUnitPlural);
    }
    if (!nullToAbsent || servingQualifier != null) {
      map['serving_qualifier'] = Variable<String>(servingQualifier);
    }
    if (!nullToAbsent || servingSize != null) {
      map['serving_size'] = Variable<String>(servingSize);
    }
    if (!nullToAbsent || afterRunSuitable != null) {
      map['after_run_suitable'] = Variable<bool>(afterRunSuitable);
    }
    if (!nullToAbsent || productType != null) {
      map['product_type'] = Variable<String>(productType);
    }
    if (!nullToAbsent || purchaseUrl != null) {
      map['purchase_url'] = Variable<String>(purchaseUrl);
    }
    if (!nullToAbsent || affiliateSource != null) {
      map['affiliate_source'] = Variable<String>(affiliateSource);
    }
    if (!nullToAbsent || preferencePriority != null) {
      map['preference_priority'] = Variable<int>(preferencePriority);
    }
    return map;
  }

  FoodsTableCompanion toCompanion(bool nullToAbsent) {
    return FoodsTableCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      imageAddress: imageAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAddress),
      createdAt: Value(createdAt),
      servingAmount: servingAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(servingAmount),
      maxServingsBefore: maxServingsBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(maxServingsBefore),
      maxServingsDuring: maxServingsDuring == null && nullToAbsent
          ? const Value.absent()
          : Value(maxServingsDuring),
      maxServingsAfter: maxServingsAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(maxServingsAfter),
      beforeRunSuitable: Value(beforeRunSuitable),
      duringRunSuitable: Value(duringRunSuitable),
      runPortable: Value(runPortable),
      requiresPreparation: Value(requiresPreparation),
      aidStationAvailable: Value(aidStationAvailable),
      sodiumMg: sodiumMg == null && nullToAbsent
          ? const Value.absent()
          : Value(sodiumMg),
      caffeineMg: caffeineMg == null && nullToAbsent
          ? const Value.absent()
          : Value(caffeineMg),
      potassiumMg: potassiumMg == null && nullToAbsent
          ? const Value.absent()
          : Value(potassiumMg),
      fatPerServing: fatPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(fatPerServing),
      carbsPerServing: carbsPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(carbsPerServing),
      proteinPerServing: proteinPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinPerServing),
      caloriesPerServing: caloriesPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriesPerServing),
      fluidMlPerServing: fluidMlPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(fluidMlPerServing),
      brandId: brandId == null && nullToAbsent
          ? const Value.absent()
          : Value(brandId),
      showInPreferences: Value(showInPreferences),
      isElectrolyte: Value(isElectrolyte),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      displayNamePlural: displayNamePlural == null && nullToAbsent
          ? const Value.absent()
          : Value(displayNamePlural),
      servingDescription: servingDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(servingDescription),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      instructions: instructions == null && nullToAbsent
          ? const Value.absent()
          : Value(instructions),
      nutritionalInfo: nutritionalInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(nutritionalInfo),
      servingUnit: servingUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(servingUnit),
      servingUnitPlural: servingUnitPlural == null && nullToAbsent
          ? const Value.absent()
          : Value(servingUnitPlural),
      servingQualifier: servingQualifier == null && nullToAbsent
          ? const Value.absent()
          : Value(servingQualifier),
      servingSize: servingSize == null && nullToAbsent
          ? const Value.absent()
          : Value(servingSize),
      afterRunSuitable: afterRunSuitable == null && nullToAbsent
          ? const Value.absent()
          : Value(afterRunSuitable),
      productType: productType == null && nullToAbsent
          ? const Value.absent()
          : Value(productType),
      purchaseUrl: purchaseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseUrl),
      affiliateSource: affiliateSource == null && nullToAbsent
          ? const Value.absent()
          : Value(affiliateSource),
      preferencePriority: preferencePriority == null && nullToAbsent
          ? const Value.absent()
          : Value(preferencePriority),
    );
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      imageAddress: serializer.fromJson<String?>(json['imageAddress']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      servingAmount: serializer.fromJson<double?>(json['servingAmount']),
      maxServingsBefore: serializer.fromJson<int?>(json['maxServingsBefore']),
      maxServingsDuring: serializer.fromJson<int?>(json['maxServingsDuring']),
      maxServingsAfter: serializer.fromJson<int?>(json['maxServingsAfter']),
      beforeRunSuitable: serializer.fromJson<bool>(json['beforeRunSuitable']),
      duringRunSuitable: serializer.fromJson<bool>(json['duringRunSuitable']),
      runPortable: serializer.fromJson<bool>(json['runPortable']),
      requiresPreparation:
          serializer.fromJson<bool>(json['requiresPreparation']),
      aidStationAvailable:
          serializer.fromJson<bool>(json['aidStationAvailable']),
      sodiumMg: serializer.fromJson<int?>(json['sodiumMg']),
      caffeineMg: serializer.fromJson<int?>(json['caffeineMg']),
      potassiumMg: serializer.fromJson<int?>(json['potassiumMg']),
      fatPerServing: serializer.fromJson<double?>(json['fatPerServing']),
      carbsPerServing: serializer.fromJson<double?>(json['carbsPerServing']),
      proteinPerServing:
          serializer.fromJson<double?>(json['proteinPerServing']),
      caloriesPerServing: serializer.fromJson<int?>(json['caloriesPerServing']),
      fluidMlPerServing:
          serializer.fromJson<double?>(json['fluidMlPerServing']),
      brandId: serializer.fromJson<String?>(json['brandId']),
      showInPreferences: serializer.fromJson<bool>(json['showInPreferences']),
      isElectrolyte: serializer.fromJson<bool>(json['isElectrolyte']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      displayNamePlural:
          serializer.fromJson<String?>(json['displayNamePlural']),
      servingDescription:
          serializer.fromJson<String?>(json['servingDescription']),
      description: serializer.fromJson<String?>(json['description']),
      instructions: serializer.fromJson<String?>(json['instructions']),
      nutritionalInfo: serializer.fromJson<String?>(json['nutritionalInfo']),
      servingUnit: serializer.fromJson<String?>(json['servingUnit']),
      servingUnitPlural:
          serializer.fromJson<String?>(json['servingUnitPlural']),
      servingQualifier: serializer.fromJson<String?>(json['servingQualifier']),
      servingSize: serializer.fromJson<String?>(json['servingSize']),
      afterRunSuitable: serializer.fromJson<bool?>(json['afterRunSuitable']),
      productType: serializer.fromJson<String?>(json['productType']),
      purchaseUrl: serializer.fromJson<String?>(json['purchaseUrl']),
      affiliateSource: serializer.fromJson<String?>(json['affiliateSource']),
      preferencePriority: serializer.fromJson<int?>(json['preferencePriority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'imageAddress': serializer.toJson<String?>(imageAddress),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'servingAmount': serializer.toJson<double?>(servingAmount),
      'maxServingsBefore': serializer.toJson<int?>(maxServingsBefore),
      'maxServingsDuring': serializer.toJson<int?>(maxServingsDuring),
      'maxServingsAfter': serializer.toJson<int?>(maxServingsAfter),
      'beforeRunSuitable': serializer.toJson<bool>(beforeRunSuitable),
      'duringRunSuitable': serializer.toJson<bool>(duringRunSuitable),
      'runPortable': serializer.toJson<bool>(runPortable),
      'requiresPreparation': serializer.toJson<bool>(requiresPreparation),
      'aidStationAvailable': serializer.toJson<bool>(aidStationAvailable),
      'sodiumMg': serializer.toJson<int?>(sodiumMg),
      'caffeineMg': serializer.toJson<int?>(caffeineMg),
      'potassiumMg': serializer.toJson<int?>(potassiumMg),
      'fatPerServing': serializer.toJson<double?>(fatPerServing),
      'carbsPerServing': serializer.toJson<double?>(carbsPerServing),
      'proteinPerServing': serializer.toJson<double?>(proteinPerServing),
      'caloriesPerServing': serializer.toJson<int?>(caloriesPerServing),
      'fluidMlPerServing': serializer.toJson<double?>(fluidMlPerServing),
      'brandId': serializer.toJson<String?>(brandId),
      'showInPreferences': serializer.toJson<bool>(showInPreferences),
      'isElectrolyte': serializer.toJson<bool>(isElectrolyte),
      'displayName': serializer.toJson<String?>(displayName),
      'displayNamePlural': serializer.toJson<String?>(displayNamePlural),
      'servingDescription': serializer.toJson<String?>(servingDescription),
      'description': serializer.toJson<String?>(description),
      'instructions': serializer.toJson<String?>(instructions),
      'nutritionalInfo': serializer.toJson<String?>(nutritionalInfo),
      'servingUnit': serializer.toJson<String?>(servingUnit),
      'servingUnitPlural': serializer.toJson<String?>(servingUnitPlural),
      'servingQualifier': serializer.toJson<String?>(servingQualifier),
      'servingSize': serializer.toJson<String?>(servingSize),
      'afterRunSuitable': serializer.toJson<bool?>(afterRunSuitable),
      'productType': serializer.toJson<String?>(productType),
      'purchaseUrl': serializer.toJson<String?>(purchaseUrl),
      'affiliateSource': serializer.toJson<String?>(affiliateSource),
      'preferencePriority': serializer.toJson<int?>(preferencePriority),
    };
  }

  FoodEntry copyWith(
          {String? id,
          Value<String?> name = const Value.absent(),
          Value<String?> imageAddress = const Value.absent(),
          DateTime? createdAt,
          Value<double?> servingAmount = const Value.absent(),
          Value<int?> maxServingsBefore = const Value.absent(),
          Value<int?> maxServingsDuring = const Value.absent(),
          Value<int?> maxServingsAfter = const Value.absent(),
          bool? beforeRunSuitable,
          bool? duringRunSuitable,
          bool? runPortable,
          bool? requiresPreparation,
          bool? aidStationAvailable,
          Value<int?> sodiumMg = const Value.absent(),
          Value<int?> caffeineMg = const Value.absent(),
          Value<int?> potassiumMg = const Value.absent(),
          Value<double?> fatPerServing = const Value.absent(),
          Value<double?> carbsPerServing = const Value.absent(),
          Value<double?> proteinPerServing = const Value.absent(),
          Value<int?> caloriesPerServing = const Value.absent(),
          Value<double?> fluidMlPerServing = const Value.absent(),
          Value<String?> brandId = const Value.absent(),
          bool? showInPreferences,
          bool? isElectrolyte,
          Value<String?> displayName = const Value.absent(),
          Value<String?> displayNamePlural = const Value.absent(),
          Value<String?> servingDescription = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<String?> instructions = const Value.absent(),
          Value<String?> nutritionalInfo = const Value.absent(),
          Value<String?> servingUnit = const Value.absent(),
          Value<String?> servingUnitPlural = const Value.absent(),
          Value<String?> servingQualifier = const Value.absent(),
          Value<String?> servingSize = const Value.absent(),
          Value<bool?> afterRunSuitable = const Value.absent(),
          Value<String?> productType = const Value.absent(),
          Value<String?> purchaseUrl = const Value.absent(),
          Value<String?> affiliateSource = const Value.absent(),
          Value<int?> preferencePriority = const Value.absent()}) =>
      FoodEntry(
        id: id ?? this.id,
        name: name.present ? name.value : this.name,
        imageAddress:
            imageAddress.present ? imageAddress.value : this.imageAddress,
        createdAt: createdAt ?? this.createdAt,
        servingAmount:
            servingAmount.present ? servingAmount.value : this.servingAmount,
        maxServingsBefore: maxServingsBefore.present
            ? maxServingsBefore.value
            : this.maxServingsBefore,
        maxServingsDuring: maxServingsDuring.present
            ? maxServingsDuring.value
            : this.maxServingsDuring,
        maxServingsAfter: maxServingsAfter.present
            ? maxServingsAfter.value
            : this.maxServingsAfter,
        beforeRunSuitable: beforeRunSuitable ?? this.beforeRunSuitable,
        duringRunSuitable: duringRunSuitable ?? this.duringRunSuitable,
        runPortable: runPortable ?? this.runPortable,
        requiresPreparation: requiresPreparation ?? this.requiresPreparation,
        aidStationAvailable: aidStationAvailable ?? this.aidStationAvailable,
        sodiumMg: sodiumMg.present ? sodiumMg.value : this.sodiumMg,
        caffeineMg: caffeineMg.present ? caffeineMg.value : this.caffeineMg,
        potassiumMg: potassiumMg.present ? potassiumMg.value : this.potassiumMg,
        fatPerServing:
            fatPerServing.present ? fatPerServing.value : this.fatPerServing,
        carbsPerServing: carbsPerServing.present
            ? carbsPerServing.value
            : this.carbsPerServing,
        proteinPerServing: proteinPerServing.present
            ? proteinPerServing.value
            : this.proteinPerServing,
        caloriesPerServing: caloriesPerServing.present
            ? caloriesPerServing.value
            : this.caloriesPerServing,
        fluidMlPerServing: fluidMlPerServing.present
            ? fluidMlPerServing.value
            : this.fluidMlPerServing,
        brandId: brandId.present ? brandId.value : this.brandId,
        showInPreferences: showInPreferences ?? this.showInPreferences,
        isElectrolyte: isElectrolyte ?? this.isElectrolyte,
        displayName: displayName.present ? displayName.value : this.displayName,
        displayNamePlural: displayNamePlural.present
            ? displayNamePlural.value
            : this.displayNamePlural,
        servingDescription: servingDescription.present
            ? servingDescription.value
            : this.servingDescription,
        description: description.present ? description.value : this.description,
        instructions:
            instructions.present ? instructions.value : this.instructions,
        nutritionalInfo: nutritionalInfo.present
            ? nutritionalInfo.value
            : this.nutritionalInfo,
        servingUnit: servingUnit.present ? servingUnit.value : this.servingUnit,
        servingUnitPlural: servingUnitPlural.present
            ? servingUnitPlural.value
            : this.servingUnitPlural,
        servingQualifier: servingQualifier.present
            ? servingQualifier.value
            : this.servingQualifier,
        servingSize: servingSize.present ? servingSize.value : this.servingSize,
        afterRunSuitable: afterRunSuitable.present
            ? afterRunSuitable.value
            : this.afterRunSuitable,
        productType: productType.present ? productType.value : this.productType,
        purchaseUrl: purchaseUrl.present ? purchaseUrl.value : this.purchaseUrl,
        affiliateSource: affiliateSource.present
            ? affiliateSource.value
            : this.affiliateSource,
        preferencePriority: preferencePriority.present
            ? preferencePriority.value
            : this.preferencePriority,
      );
  FoodEntry copyWithCompanion(FoodsTableCompanion data) {
    return FoodEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      imageAddress: data.imageAddress.present
          ? data.imageAddress.value
          : this.imageAddress,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      servingAmount: data.servingAmount.present
          ? data.servingAmount.value
          : this.servingAmount,
      maxServingsBefore: data.maxServingsBefore.present
          ? data.maxServingsBefore.value
          : this.maxServingsBefore,
      maxServingsDuring: data.maxServingsDuring.present
          ? data.maxServingsDuring.value
          : this.maxServingsDuring,
      maxServingsAfter: data.maxServingsAfter.present
          ? data.maxServingsAfter.value
          : this.maxServingsAfter,
      beforeRunSuitable: data.beforeRunSuitable.present
          ? data.beforeRunSuitable.value
          : this.beforeRunSuitable,
      duringRunSuitable: data.duringRunSuitable.present
          ? data.duringRunSuitable.value
          : this.duringRunSuitable,
      runPortable:
          data.runPortable.present ? data.runPortable.value : this.runPortable,
      requiresPreparation: data.requiresPreparation.present
          ? data.requiresPreparation.value
          : this.requiresPreparation,
      aidStationAvailable: data.aidStationAvailable.present
          ? data.aidStationAvailable.value
          : this.aidStationAvailable,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
      caffeineMg:
          data.caffeineMg.present ? data.caffeineMg.value : this.caffeineMg,
      potassiumMg:
          data.potassiumMg.present ? data.potassiumMg.value : this.potassiumMg,
      fatPerServing: data.fatPerServing.present
          ? data.fatPerServing.value
          : this.fatPerServing,
      carbsPerServing: data.carbsPerServing.present
          ? data.carbsPerServing.value
          : this.carbsPerServing,
      proteinPerServing: data.proteinPerServing.present
          ? data.proteinPerServing.value
          : this.proteinPerServing,
      caloriesPerServing: data.caloriesPerServing.present
          ? data.caloriesPerServing.value
          : this.caloriesPerServing,
      fluidMlPerServing: data.fluidMlPerServing.present
          ? data.fluidMlPerServing.value
          : this.fluidMlPerServing,
      brandId: data.brandId.present ? data.brandId.value : this.brandId,
      showInPreferences: data.showInPreferences.present
          ? data.showInPreferences.value
          : this.showInPreferences,
      isElectrolyte: data.isElectrolyte.present
          ? data.isElectrolyte.value
          : this.isElectrolyte,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      displayNamePlural: data.displayNamePlural.present
          ? data.displayNamePlural.value
          : this.displayNamePlural,
      servingDescription: data.servingDescription.present
          ? data.servingDescription.value
          : this.servingDescription,
      description:
          data.description.present ? data.description.value : this.description,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      nutritionalInfo: data.nutritionalInfo.present
          ? data.nutritionalInfo.value
          : this.nutritionalInfo,
      servingUnit:
          data.servingUnit.present ? data.servingUnit.value : this.servingUnit,
      servingUnitPlural: data.servingUnitPlural.present
          ? data.servingUnitPlural.value
          : this.servingUnitPlural,
      servingQualifier: data.servingQualifier.present
          ? data.servingQualifier.value
          : this.servingQualifier,
      servingSize:
          data.servingSize.present ? data.servingSize.value : this.servingSize,
      afterRunSuitable: data.afterRunSuitable.present
          ? data.afterRunSuitable.value
          : this.afterRunSuitable,
      productType:
          data.productType.present ? data.productType.value : this.productType,
      purchaseUrl:
          data.purchaseUrl.present ? data.purchaseUrl.value : this.purchaseUrl,
      affiliateSource: data.affiliateSource.present
          ? data.affiliateSource.value
          : this.affiliateSource,
      preferencePriority: data.preferencePriority.present
          ? data.preferencePriority.value
          : this.preferencePriority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('createdAt: $createdAt, ')
          ..write('servingAmount: $servingAmount, ')
          ..write('maxServingsBefore: $maxServingsBefore, ')
          ..write('maxServingsDuring: $maxServingsDuring, ')
          ..write('maxServingsAfter: $maxServingsAfter, ')
          ..write('beforeRunSuitable: $beforeRunSuitable, ')
          ..write('duringRunSuitable: $duringRunSuitable, ')
          ..write('runPortable: $runPortable, ')
          ..write('requiresPreparation: $requiresPreparation, ')
          ..write('aidStationAvailable: $aidStationAvailable, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('caffeineMg: $caffeineMg, ')
          ..write('potassiumMg: $potassiumMg, ')
          ..write('fatPerServing: $fatPerServing, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('proteinPerServing: $proteinPerServing, ')
          ..write('caloriesPerServing: $caloriesPerServing, ')
          ..write('fluidMlPerServing: $fluidMlPerServing, ')
          ..write('brandId: $brandId, ')
          ..write('showInPreferences: $showInPreferences, ')
          ..write('isElectrolyte: $isElectrolyte, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('servingDescription: $servingDescription, ')
          ..write('description: $description, ')
          ..write('instructions: $instructions, ')
          ..write('nutritionalInfo: $nutritionalInfo, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('servingUnitPlural: $servingUnitPlural, ')
          ..write('servingQualifier: $servingQualifier, ')
          ..write('servingSize: $servingSize, ')
          ..write('afterRunSuitable: $afterRunSuitable, ')
          ..write('productType: $productType, ')
          ..write('purchaseUrl: $purchaseUrl, ')
          ..write('affiliateSource: $affiliateSource, ')
          ..write('preferencePriority: $preferencePriority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        imageAddress,
        createdAt,
        servingAmount,
        maxServingsBefore,
        maxServingsDuring,
        maxServingsAfter,
        beforeRunSuitable,
        duringRunSuitable,
        runPortable,
        requiresPreparation,
        aidStationAvailable,
        sodiumMg,
        caffeineMg,
        potassiumMg,
        fatPerServing,
        carbsPerServing,
        proteinPerServing,
        caloriesPerServing,
        fluidMlPerServing,
        brandId,
        showInPreferences,
        isElectrolyte,
        displayName,
        displayNamePlural,
        servingDescription,
        description,
        instructions,
        nutritionalInfo,
        servingUnit,
        servingUnitPlural,
        servingQualifier,
        servingSize,
        afterRunSuitable,
        productType,
        purchaseUrl,
        affiliateSource,
        preferencePriority
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.imageAddress == this.imageAddress &&
          other.createdAt == this.createdAt &&
          other.servingAmount == this.servingAmount &&
          other.maxServingsBefore == this.maxServingsBefore &&
          other.maxServingsDuring == this.maxServingsDuring &&
          other.maxServingsAfter == this.maxServingsAfter &&
          other.beforeRunSuitable == this.beforeRunSuitable &&
          other.duringRunSuitable == this.duringRunSuitable &&
          other.runPortable == this.runPortable &&
          other.requiresPreparation == this.requiresPreparation &&
          other.aidStationAvailable == this.aidStationAvailable &&
          other.sodiumMg == this.sodiumMg &&
          other.caffeineMg == this.caffeineMg &&
          other.potassiumMg == this.potassiumMg &&
          other.fatPerServing == this.fatPerServing &&
          other.carbsPerServing == this.carbsPerServing &&
          other.proteinPerServing == this.proteinPerServing &&
          other.caloriesPerServing == this.caloriesPerServing &&
          other.fluidMlPerServing == this.fluidMlPerServing &&
          other.brandId == this.brandId &&
          other.showInPreferences == this.showInPreferences &&
          other.isElectrolyte == this.isElectrolyte &&
          other.displayName == this.displayName &&
          other.displayNamePlural == this.displayNamePlural &&
          other.servingDescription == this.servingDescription &&
          other.description == this.description &&
          other.instructions == this.instructions &&
          other.nutritionalInfo == this.nutritionalInfo &&
          other.servingUnit == this.servingUnit &&
          other.servingUnitPlural == this.servingUnitPlural &&
          other.servingQualifier == this.servingQualifier &&
          other.servingSize == this.servingSize &&
          other.afterRunSuitable == this.afterRunSuitable &&
          other.productType == this.productType &&
          other.purchaseUrl == this.purchaseUrl &&
          other.affiliateSource == this.affiliateSource &&
          other.preferencePriority == this.preferencePriority);
}

class FoodsTableCompanion extends UpdateCompanion<FoodEntry> {
  final Value<String> id;
  final Value<String?> name;
  final Value<String?> imageAddress;
  final Value<DateTime> createdAt;
  final Value<double?> servingAmount;
  final Value<int?> maxServingsBefore;
  final Value<int?> maxServingsDuring;
  final Value<int?> maxServingsAfter;
  final Value<bool> beforeRunSuitable;
  final Value<bool> duringRunSuitable;
  final Value<bool> runPortable;
  final Value<bool> requiresPreparation;
  final Value<bool> aidStationAvailable;
  final Value<int?> sodiumMg;
  final Value<int?> caffeineMg;
  final Value<int?> potassiumMg;
  final Value<double?> fatPerServing;
  final Value<double?> carbsPerServing;
  final Value<double?> proteinPerServing;
  final Value<int?> caloriesPerServing;
  final Value<double?> fluidMlPerServing;
  final Value<String?> brandId;
  final Value<bool> showInPreferences;
  final Value<bool> isElectrolyte;
  final Value<String?> displayName;
  final Value<String?> displayNamePlural;
  final Value<String?> servingDescription;
  final Value<String?> description;
  final Value<String?> instructions;
  final Value<String?> nutritionalInfo;
  final Value<String?> servingUnit;
  final Value<String?> servingUnitPlural;
  final Value<String?> servingQualifier;
  final Value<String?> servingSize;
  final Value<bool?> afterRunSuitable;
  final Value<String?> productType;
  final Value<String?> purchaseUrl;
  final Value<String?> affiliateSource;
  final Value<int?> preferencePriority;
  final Value<int> rowid;
  const FoodsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.imageAddress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.servingAmount = const Value.absent(),
    this.maxServingsBefore = const Value.absent(),
    this.maxServingsDuring = const Value.absent(),
    this.maxServingsAfter = const Value.absent(),
    this.beforeRunSuitable = const Value.absent(),
    this.duringRunSuitable = const Value.absent(),
    this.runPortable = const Value.absent(),
    this.requiresPreparation = const Value.absent(),
    this.aidStationAvailable = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.caffeineMg = const Value.absent(),
    this.potassiumMg = const Value.absent(),
    this.fatPerServing = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.proteinPerServing = const Value.absent(),
    this.caloriesPerServing = const Value.absent(),
    this.fluidMlPerServing = const Value.absent(),
    this.brandId = const Value.absent(),
    this.showInPreferences = const Value.absent(),
    this.isElectrolyte = const Value.absent(),
    this.displayName = const Value.absent(),
    this.displayNamePlural = const Value.absent(),
    this.servingDescription = const Value.absent(),
    this.description = const Value.absent(),
    this.instructions = const Value.absent(),
    this.nutritionalInfo = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.servingUnitPlural = const Value.absent(),
    this.servingQualifier = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.afterRunSuitable = const Value.absent(),
    this.productType = const Value.absent(),
    this.purchaseUrl = const Value.absent(),
    this.affiliateSource = const Value.absent(),
    this.preferencePriority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodsTableCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.imageAddress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.servingAmount = const Value.absent(),
    this.maxServingsBefore = const Value.absent(),
    this.maxServingsDuring = const Value.absent(),
    this.maxServingsAfter = const Value.absent(),
    this.beforeRunSuitable = const Value.absent(),
    this.duringRunSuitable = const Value.absent(),
    this.runPortable = const Value.absent(),
    this.requiresPreparation = const Value.absent(),
    this.aidStationAvailable = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.caffeineMg = const Value.absent(),
    this.potassiumMg = const Value.absent(),
    this.fatPerServing = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.proteinPerServing = const Value.absent(),
    this.caloriesPerServing = const Value.absent(),
    this.fluidMlPerServing = const Value.absent(),
    this.brandId = const Value.absent(),
    this.showInPreferences = const Value.absent(),
    this.isElectrolyte = const Value.absent(),
    this.displayName = const Value.absent(),
    this.displayNamePlural = const Value.absent(),
    this.servingDescription = const Value.absent(),
    this.description = const Value.absent(),
    this.instructions = const Value.absent(),
    this.nutritionalInfo = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.servingUnitPlural = const Value.absent(),
    this.servingQualifier = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.afterRunSuitable = const Value.absent(),
    this.productType = const Value.absent(),
    this.purchaseUrl = const Value.absent(),
    this.affiliateSource = const Value.absent(),
    this.preferencePriority = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<FoodEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? imageAddress,
    Expression<DateTime>? createdAt,
    Expression<double>? servingAmount,
    Expression<int>? maxServingsBefore,
    Expression<int>? maxServingsDuring,
    Expression<int>? maxServingsAfter,
    Expression<bool>? beforeRunSuitable,
    Expression<bool>? duringRunSuitable,
    Expression<bool>? runPortable,
    Expression<bool>? requiresPreparation,
    Expression<bool>? aidStationAvailable,
    Expression<int>? sodiumMg,
    Expression<int>? caffeineMg,
    Expression<int>? potassiumMg,
    Expression<double>? fatPerServing,
    Expression<double>? carbsPerServing,
    Expression<double>? proteinPerServing,
    Expression<int>? caloriesPerServing,
    Expression<double>? fluidMlPerServing,
    Expression<String>? brandId,
    Expression<bool>? showInPreferences,
    Expression<bool>? isElectrolyte,
    Expression<String>? displayName,
    Expression<String>? displayNamePlural,
    Expression<String>? servingDescription,
    Expression<String>? description,
    Expression<String>? instructions,
    Expression<String>? nutritionalInfo,
    Expression<String>? servingUnit,
    Expression<String>? servingUnitPlural,
    Expression<String>? servingQualifier,
    Expression<String>? servingSize,
    Expression<bool>? afterRunSuitable,
    Expression<String>? productType,
    Expression<String>? purchaseUrl,
    Expression<String>? affiliateSource,
    Expression<int>? preferencePriority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (imageAddress != null) 'image_address': imageAddress,
      if (createdAt != null) 'created_at': createdAt,
      if (servingAmount != null) 'serving_amount': servingAmount,
      if (maxServingsBefore != null) 'max_servings_before': maxServingsBefore,
      if (maxServingsDuring != null) 'max_servings_during': maxServingsDuring,
      if (maxServingsAfter != null) 'max_servings_after': maxServingsAfter,
      if (beforeRunSuitable != null) 'before_run_suitable': beforeRunSuitable,
      if (duringRunSuitable != null) 'during_run_suitable': duringRunSuitable,
      if (runPortable != null) 'run_portable': runPortable,
      if (requiresPreparation != null)
        'requires_preparation': requiresPreparation,
      if (aidStationAvailable != null)
        'aid_station_available': aidStationAvailable,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (caffeineMg != null) 'caffeine_mg': caffeineMg,
      if (potassiumMg != null) 'potassium_mg': potassiumMg,
      if (fatPerServing != null) 'fat_per_serving': fatPerServing,
      if (carbsPerServing != null) 'carbs_per_serving': carbsPerServing,
      if (proteinPerServing != null) 'protein_per_serving': proteinPerServing,
      if (caloriesPerServing != null)
        'calories_per_serving': caloriesPerServing,
      if (fluidMlPerServing != null) 'fluid_ml_per_serving': fluidMlPerServing,
      if (brandId != null) 'brand_id': brandId,
      if (showInPreferences != null) 'show_in_preferences': showInPreferences,
      if (isElectrolyte != null) 'is_electrolyte': isElectrolyte,
      if (displayName != null) 'display_name': displayName,
      if (displayNamePlural != null) 'display_name_plural': displayNamePlural,
      if (servingDescription != null) 'serving_description': servingDescription,
      if (description != null) 'description': description,
      if (instructions != null) 'instructions': instructions,
      if (nutritionalInfo != null) 'nutritional_info': nutritionalInfo,
      if (servingUnit != null) 'serving_unit': servingUnit,
      if (servingUnitPlural != null) 'serving_unit_plural': servingUnitPlural,
      if (servingQualifier != null) 'serving_qualifier': servingQualifier,
      if (servingSize != null) 'serving_size': servingSize,
      if (afterRunSuitable != null) 'after_run_suitable': afterRunSuitable,
      if (productType != null) 'product_type': productType,
      if (purchaseUrl != null) 'purchase_url': purchaseUrl,
      if (affiliateSource != null) 'affiliate_source': affiliateSource,
      if (preferencePriority != null) 'preference_priority': preferencePriority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodsTableCompanion copyWith(
      {Value<String>? id,
      Value<String?>? name,
      Value<String?>? imageAddress,
      Value<DateTime>? createdAt,
      Value<double?>? servingAmount,
      Value<int?>? maxServingsBefore,
      Value<int?>? maxServingsDuring,
      Value<int?>? maxServingsAfter,
      Value<bool>? beforeRunSuitable,
      Value<bool>? duringRunSuitable,
      Value<bool>? runPortable,
      Value<bool>? requiresPreparation,
      Value<bool>? aidStationAvailable,
      Value<int?>? sodiumMg,
      Value<int?>? caffeineMg,
      Value<int?>? potassiumMg,
      Value<double?>? fatPerServing,
      Value<double?>? carbsPerServing,
      Value<double?>? proteinPerServing,
      Value<int?>? caloriesPerServing,
      Value<double?>? fluidMlPerServing,
      Value<String?>? brandId,
      Value<bool>? showInPreferences,
      Value<bool>? isElectrolyte,
      Value<String?>? displayName,
      Value<String?>? displayNamePlural,
      Value<String?>? servingDescription,
      Value<String?>? description,
      Value<String?>? instructions,
      Value<String?>? nutritionalInfo,
      Value<String?>? servingUnit,
      Value<String?>? servingUnitPlural,
      Value<String?>? servingQualifier,
      Value<String?>? servingSize,
      Value<bool?>? afterRunSuitable,
      Value<String?>? productType,
      Value<String?>? purchaseUrl,
      Value<String?>? affiliateSource,
      Value<int?>? preferencePriority,
      Value<int>? rowid}) {
    return FoodsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      imageAddress: imageAddress ?? this.imageAddress,
      createdAt: createdAt ?? this.createdAt,
      servingAmount: servingAmount ?? this.servingAmount,
      maxServingsBefore: maxServingsBefore ?? this.maxServingsBefore,
      maxServingsDuring: maxServingsDuring ?? this.maxServingsDuring,
      maxServingsAfter: maxServingsAfter ?? this.maxServingsAfter,
      beforeRunSuitable: beforeRunSuitable ?? this.beforeRunSuitable,
      duringRunSuitable: duringRunSuitable ?? this.duringRunSuitable,
      runPortable: runPortable ?? this.runPortable,
      requiresPreparation: requiresPreparation ?? this.requiresPreparation,
      aidStationAvailable: aidStationAvailable ?? this.aidStationAvailable,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      caffeineMg: caffeineMg ?? this.caffeineMg,
      potassiumMg: potassiumMg ?? this.potassiumMg,
      fatPerServing: fatPerServing ?? this.fatPerServing,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      proteinPerServing: proteinPerServing ?? this.proteinPerServing,
      caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
      fluidMlPerServing: fluidMlPerServing ?? this.fluidMlPerServing,
      brandId: brandId ?? this.brandId,
      showInPreferences: showInPreferences ?? this.showInPreferences,
      isElectrolyte: isElectrolyte ?? this.isElectrolyte,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      servingDescription: servingDescription ?? this.servingDescription,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      servingUnit: servingUnit ?? this.servingUnit,
      servingUnitPlural: servingUnitPlural ?? this.servingUnitPlural,
      servingQualifier: servingQualifier ?? this.servingQualifier,
      servingSize: servingSize ?? this.servingSize,
      afterRunSuitable: afterRunSuitable ?? this.afterRunSuitable,
      productType: productType ?? this.productType,
      purchaseUrl: purchaseUrl ?? this.purchaseUrl,
      affiliateSource: affiliateSource ?? this.affiliateSource,
      preferencePriority: preferencePriority ?? this.preferencePriority,
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
    if (imageAddress.present) {
      map['image_address'] = Variable<String>(imageAddress.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (servingAmount.present) {
      map['serving_amount'] = Variable<double>(servingAmount.value);
    }
    if (maxServingsBefore.present) {
      map['max_servings_before'] = Variable<int>(maxServingsBefore.value);
    }
    if (maxServingsDuring.present) {
      map['max_servings_during'] = Variable<int>(maxServingsDuring.value);
    }
    if (maxServingsAfter.present) {
      map['max_servings_after'] = Variable<int>(maxServingsAfter.value);
    }
    if (beforeRunSuitable.present) {
      map['before_run_suitable'] = Variable<bool>(beforeRunSuitable.value);
    }
    if (duringRunSuitable.present) {
      map['during_run_suitable'] = Variable<bool>(duringRunSuitable.value);
    }
    if (runPortable.present) {
      map['run_portable'] = Variable<bool>(runPortable.value);
    }
    if (requiresPreparation.present) {
      map['requires_preparation'] = Variable<bool>(requiresPreparation.value);
    }
    if (aidStationAvailable.present) {
      map['aid_station_available'] = Variable<bool>(aidStationAvailable.value);
    }
    if (sodiumMg.present) {
      map['sodium_mg'] = Variable<int>(sodiumMg.value);
    }
    if (caffeineMg.present) {
      map['caffeine_mg'] = Variable<int>(caffeineMg.value);
    }
    if (potassiumMg.present) {
      map['potassium_mg'] = Variable<int>(potassiumMg.value);
    }
    if (fatPerServing.present) {
      map['fat_per_serving'] = Variable<double>(fatPerServing.value);
    }
    if (carbsPerServing.present) {
      map['carbs_per_serving'] = Variable<double>(carbsPerServing.value);
    }
    if (proteinPerServing.present) {
      map['protein_per_serving'] = Variable<double>(proteinPerServing.value);
    }
    if (caloriesPerServing.present) {
      map['calories_per_serving'] = Variable<int>(caloriesPerServing.value);
    }
    if (fluidMlPerServing.present) {
      map['fluid_ml_per_serving'] = Variable<double>(fluidMlPerServing.value);
    }
    if (brandId.present) {
      map['brand_id'] = Variable<String>(brandId.value);
    }
    if (showInPreferences.present) {
      map['show_in_preferences'] = Variable<bool>(showInPreferences.value);
    }
    if (isElectrolyte.present) {
      map['is_electrolyte'] = Variable<bool>(isElectrolyte.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (displayNamePlural.present) {
      map['display_name_plural'] = Variable<String>(displayNamePlural.value);
    }
    if (servingDescription.present) {
      map['serving_description'] = Variable<String>(servingDescription.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (instructions.present) {
      map['instructions'] = Variable<String>(instructions.value);
    }
    if (nutritionalInfo.present) {
      map['nutritional_info'] = Variable<String>(nutritionalInfo.value);
    }
    if (servingUnit.present) {
      map['serving_unit'] = Variable<String>(servingUnit.value);
    }
    if (servingUnitPlural.present) {
      map['serving_unit_plural'] = Variable<String>(servingUnitPlural.value);
    }
    if (servingQualifier.present) {
      map['serving_qualifier'] = Variable<String>(servingQualifier.value);
    }
    if (servingSize.present) {
      map['serving_size'] = Variable<String>(servingSize.value);
    }
    if (afterRunSuitable.present) {
      map['after_run_suitable'] = Variable<bool>(afterRunSuitable.value);
    }
    if (productType.present) {
      map['product_type'] = Variable<String>(productType.value);
    }
    if (purchaseUrl.present) {
      map['purchase_url'] = Variable<String>(purchaseUrl.value);
    }
    if (affiliateSource.present) {
      map['affiliate_source'] = Variable<String>(affiliateSource.value);
    }
    if (preferencePriority.present) {
      map['preference_priority'] = Variable<int>(preferencePriority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('createdAt: $createdAt, ')
          ..write('servingAmount: $servingAmount, ')
          ..write('maxServingsBefore: $maxServingsBefore, ')
          ..write('maxServingsDuring: $maxServingsDuring, ')
          ..write('maxServingsAfter: $maxServingsAfter, ')
          ..write('beforeRunSuitable: $beforeRunSuitable, ')
          ..write('duringRunSuitable: $duringRunSuitable, ')
          ..write('runPortable: $runPortable, ')
          ..write('requiresPreparation: $requiresPreparation, ')
          ..write('aidStationAvailable: $aidStationAvailable, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('caffeineMg: $caffeineMg, ')
          ..write('potassiumMg: $potassiumMg, ')
          ..write('fatPerServing: $fatPerServing, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('proteinPerServing: $proteinPerServing, ')
          ..write('caloriesPerServing: $caloriesPerServing, ')
          ..write('fluidMlPerServing: $fluidMlPerServing, ')
          ..write('brandId: $brandId, ')
          ..write('showInPreferences: $showInPreferences, ')
          ..write('isElectrolyte: $isElectrolyte, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('servingDescription: $servingDescription, ')
          ..write('description: $description, ')
          ..write('instructions: $instructions, ')
          ..write('nutritionalInfo: $nutritionalInfo, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('servingUnitPlural: $servingUnitPlural, ')
          ..write('servingQualifier: $servingQualifier, ')
          ..write('servingSize: $servingSize, ')
          ..write('afterRunSuitable: $afterRunSuitable, ')
          ..write('productType: $productType, ')
          ..write('purchaseUrl: $purchaseUrl, ')
          ..write('affiliateSource: $affiliateSource, ')
          ..write('preferencePriority: $preferencePriority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTableTable extends CategoriesTable
    with TableInfo<$CategoriesTableTable, CategoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories_table';
  @override
  VerificationContext validateIntegrity(Insertable<CategoryEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $CategoriesTableTable createAlias(String alias) {
    return $CategoriesTableTable(attachedDatabase, alias);
  }
}

class CategoryEntry extends DataClass implements Insertable<CategoryEntry> {
  final int id;
  final String name;
  const CategoryEntry({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  CategoriesTableCompanion toCompanion(bool nullToAbsent) {
    return CategoriesTableCompanion(
      id: Value(id),
      name: Value(name),
    );
  }

  factory CategoryEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryEntry(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  CategoryEntry copyWith({int? id, String? name}) => CategoryEntry(
        id: id ?? this.id,
        name: name ?? this.name,
      );
  CategoryEntry copyWithCompanion(CategoriesTableCompanion data) {
    return CategoryEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryEntry(')
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
      (other is CategoryEntry &&
          other.id == this.id &&
          other.name == this.name);
}

class CategoriesTableCompanion extends UpdateCompanion<CategoryEntry> {
  final Value<int> id;
  final Value<String> name;
  const CategoriesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  CategoriesTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<CategoryEntry> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  CategoriesTableCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return CategoriesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $FoodCategoriesTableTable extends FoodCategoriesTable
    with TableInfo<$FoodCategoriesTableTable, FoodCategoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodCategoriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<String> foodId = GeneratedColumn<String>(
      'food_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES foods_table (id) ON DELETE CASCADE'));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES categories_table (id)'));
  @override
  List<GeneratedColumn> get $columns => [foodId, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_categories_table';
  @override
  VerificationContext validateIntegrity(Insertable<FoodCategoryEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('food_id')) {
      context.handle(_foodIdMeta,
          foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta));
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {foodId, categoryId};
  @override
  FoodCategoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodCategoryEntry(
      foodId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}food_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
    );
  }

  @override
  $FoodCategoriesTableTable createAlias(String alias) {
    return $FoodCategoriesTableTable(attachedDatabase, alias);
  }
}

class FoodCategoryEntry extends DataClass
    implements Insertable<FoodCategoryEntry> {
  final String foodId;
  final int categoryId;
  const FoodCategoryEntry({required this.foodId, required this.categoryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['food_id'] = Variable<String>(foodId);
    map['category_id'] = Variable<int>(categoryId);
    return map;
  }

  FoodCategoriesTableCompanion toCompanion(bool nullToAbsent) {
    return FoodCategoriesTableCompanion(
      foodId: Value(foodId),
      categoryId: Value(categoryId),
    );
  }

  factory FoodCategoryEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodCategoryEntry(
      foodId: serializer.fromJson<String>(json['foodId']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'foodId': serializer.toJson<String>(foodId),
      'categoryId': serializer.toJson<int>(categoryId),
    };
  }

  FoodCategoryEntry copyWith({String? foodId, int? categoryId}) =>
      FoodCategoryEntry(
        foodId: foodId ?? this.foodId,
        categoryId: categoryId ?? this.categoryId,
      );
  FoodCategoryEntry copyWithCompanion(FoodCategoriesTableCompanion data) {
    return FoodCategoryEntry(
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodCategoryEntry(')
          ..write('foodId: $foodId, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(foodId, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodCategoryEntry &&
          other.foodId == this.foodId &&
          other.categoryId == this.categoryId);
}

class FoodCategoriesTableCompanion extends UpdateCompanion<FoodCategoryEntry> {
  final Value<String> foodId;
  final Value<int> categoryId;
  final Value<int> rowid;
  const FoodCategoriesTableCompanion({
    this.foodId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodCategoriesTableCompanion.insert({
    required String foodId,
    required int categoryId,
    this.rowid = const Value.absent(),
  })  : foodId = Value(foodId),
        categoryId = Value(categoryId);
  static Insertable<FoodCategoryEntry> custom({
    Expression<String>? foodId,
    Expression<int>? categoryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (foodId != null) 'food_id': foodId,
      if (categoryId != null) 'category_id': categoryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodCategoriesTableCompanion copyWith(
      {Value<String>? foodId, Value<int>? categoryId, Value<int>? rowid}) {
    return FoodCategoriesTableCompanion(
      foodId: foodId ?? this.foodId,
      categoryId: categoryId ?? this.categoryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (foodId.present) {
      map['food_id'] = Variable<String>(foodId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodCategoriesTableCompanion(')
          ..write('foodId: $foodId, ')
          ..write('categoryId: $categoryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrandsTableTable extends BrandsTable
    with TableInfo<$BrandsTableTable, BrandEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrandsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _websiteUrlMeta =
      const VerificationMeta('websiteUrl');
  @override
  late final GeneratedColumn<String> websiteUrl = GeneratedColumn<String>(
      'website_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _affiliateProgramUrlMeta =
      const VerificationMeta('affiliateProgramUrl');
  @override
  late final GeneratedColumn<String> affiliateProgramUrl =
      GeneratedColumn<String>('affiliate_program_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _affiliateNetworkMeta =
      const VerificationMeta('affiliateNetwork');
  @override
  late final GeneratedColumn<String> affiliateNetwork = GeneratedColumn<String>(
      'affiliate_network', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _defaultAffiliateUrlMeta =
      const VerificationMeta('defaultAffiliateUrl');
  @override
  late final GeneratedColumn<String> defaultAffiliateUrl =
      GeneratedColumn<String>('default_affiliate_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        websiteUrl,
        affiliateProgramUrl,
        affiliateNetwork,
        defaultAffiliateUrl,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brands_table';
  @override
  VerificationContext validateIntegrity(Insertable<BrandEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('website_url')) {
      context.handle(
          _websiteUrlMeta,
          websiteUrl.isAcceptableOrUnknown(
              data['website_url']!, _websiteUrlMeta));
    }
    if (data.containsKey('affiliate_program_url')) {
      context.handle(
          _affiliateProgramUrlMeta,
          affiliateProgramUrl.isAcceptableOrUnknown(
              data['affiliate_program_url']!, _affiliateProgramUrlMeta));
    }
    if (data.containsKey('affiliate_network')) {
      context.handle(
          _affiliateNetworkMeta,
          affiliateNetwork.isAcceptableOrUnknown(
              data['affiliate_network']!, _affiliateNetworkMeta));
    }
    if (data.containsKey('default_affiliate_url')) {
      context.handle(
          _defaultAffiliateUrlMeta,
          defaultAffiliateUrl.isAcceptableOrUnknown(
              data['default_affiliate_url']!, _defaultAffiliateUrlMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BrandEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrandEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      websiteUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}website_url']),
      affiliateProgramUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}affiliate_program_url']),
      affiliateNetwork: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}affiliate_network']),
      defaultAffiliateUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}default_affiliate_url']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $BrandsTableTable createAlias(String alias) {
    return $BrandsTableTable(attachedDatabase, alias);
  }
}

class BrandEntry extends DataClass implements Insertable<BrandEntry> {
  final String id;
  final String name;
  final String? websiteUrl;
  final String? affiliateProgramUrl;
  final String? affiliateNetwork;
  final String? defaultAffiliateUrl;
  final String? notes;
  const BrandEntry(
      {required this.id,
      required this.name,
      this.websiteUrl,
      this.affiliateProgramUrl,
      this.affiliateNetwork,
      this.defaultAffiliateUrl,
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || websiteUrl != null) {
      map['website_url'] = Variable<String>(websiteUrl);
    }
    if (!nullToAbsent || affiliateProgramUrl != null) {
      map['affiliate_program_url'] = Variable<String>(affiliateProgramUrl);
    }
    if (!nullToAbsent || affiliateNetwork != null) {
      map['affiliate_network'] = Variable<String>(affiliateNetwork);
    }
    if (!nullToAbsent || defaultAffiliateUrl != null) {
      map['default_affiliate_url'] = Variable<String>(defaultAffiliateUrl);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  BrandsTableCompanion toCompanion(bool nullToAbsent) {
    return BrandsTableCompanion(
      id: Value(id),
      name: Value(name),
      websiteUrl: websiteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(websiteUrl),
      affiliateProgramUrl: affiliateProgramUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(affiliateProgramUrl),
      affiliateNetwork: affiliateNetwork == null && nullToAbsent
          ? const Value.absent()
          : Value(affiliateNetwork),
      defaultAffiliateUrl: defaultAffiliateUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAffiliateUrl),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory BrandEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrandEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      websiteUrl: serializer.fromJson<String?>(json['websiteUrl']),
      affiliateProgramUrl:
          serializer.fromJson<String?>(json['affiliateProgramUrl']),
      affiliateNetwork: serializer.fromJson<String?>(json['affiliateNetwork']),
      defaultAffiliateUrl:
          serializer.fromJson<String?>(json['defaultAffiliateUrl']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'websiteUrl': serializer.toJson<String?>(websiteUrl),
      'affiliateProgramUrl': serializer.toJson<String?>(affiliateProgramUrl),
      'affiliateNetwork': serializer.toJson<String?>(affiliateNetwork),
      'defaultAffiliateUrl': serializer.toJson<String?>(defaultAffiliateUrl),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  BrandEntry copyWith(
          {String? id,
          String? name,
          Value<String?> websiteUrl = const Value.absent(),
          Value<String?> affiliateProgramUrl = const Value.absent(),
          Value<String?> affiliateNetwork = const Value.absent(),
          Value<String?> defaultAffiliateUrl = const Value.absent(),
          Value<String?> notes = const Value.absent()}) =>
      BrandEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        websiteUrl: websiteUrl.present ? websiteUrl.value : this.websiteUrl,
        affiliateProgramUrl: affiliateProgramUrl.present
            ? affiliateProgramUrl.value
            : this.affiliateProgramUrl,
        affiliateNetwork: affiliateNetwork.present
            ? affiliateNetwork.value
            : this.affiliateNetwork,
        defaultAffiliateUrl: defaultAffiliateUrl.present
            ? defaultAffiliateUrl.value
            : this.defaultAffiliateUrl,
        notes: notes.present ? notes.value : this.notes,
      );
  BrandEntry copyWithCompanion(BrandsTableCompanion data) {
    return BrandEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      websiteUrl:
          data.websiteUrl.present ? data.websiteUrl.value : this.websiteUrl,
      affiliateProgramUrl: data.affiliateProgramUrl.present
          ? data.affiliateProgramUrl.value
          : this.affiliateProgramUrl,
      affiliateNetwork: data.affiliateNetwork.present
          ? data.affiliateNetwork.value
          : this.affiliateNetwork,
      defaultAffiliateUrl: data.defaultAffiliateUrl.present
          ? data.defaultAffiliateUrl.value
          : this.defaultAffiliateUrl,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrandEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('websiteUrl: $websiteUrl, ')
          ..write('affiliateProgramUrl: $affiliateProgramUrl, ')
          ..write('affiliateNetwork: $affiliateNetwork, ')
          ..write('defaultAffiliateUrl: $defaultAffiliateUrl, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, websiteUrl, affiliateProgramUrl,
      affiliateNetwork, defaultAffiliateUrl, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrandEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.websiteUrl == this.websiteUrl &&
          other.affiliateProgramUrl == this.affiliateProgramUrl &&
          other.affiliateNetwork == this.affiliateNetwork &&
          other.defaultAffiliateUrl == this.defaultAffiliateUrl &&
          other.notes == this.notes);
}

class BrandsTableCompanion extends UpdateCompanion<BrandEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> websiteUrl;
  final Value<String?> affiliateProgramUrl;
  final Value<String?> affiliateNetwork;
  final Value<String?> defaultAffiliateUrl;
  final Value<String?> notes;
  final Value<int> rowid;
  const BrandsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.websiteUrl = const Value.absent(),
    this.affiliateProgramUrl = const Value.absent(),
    this.affiliateNetwork = const Value.absent(),
    this.defaultAffiliateUrl = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BrandsTableCompanion.insert({
    required String id,
    required String name,
    this.websiteUrl = const Value.absent(),
    this.affiliateProgramUrl = const Value.absent(),
    this.affiliateNetwork = const Value.absent(),
    this.defaultAffiliateUrl = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<BrandEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? websiteUrl,
    Expression<String>? affiliateProgramUrl,
    Expression<String>? affiliateNetwork,
    Expression<String>? defaultAffiliateUrl,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (websiteUrl != null) 'website_url': websiteUrl,
      if (affiliateProgramUrl != null)
        'affiliate_program_url': affiliateProgramUrl,
      if (affiliateNetwork != null) 'affiliate_network': affiliateNetwork,
      if (defaultAffiliateUrl != null)
        'default_affiliate_url': defaultAffiliateUrl,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BrandsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? websiteUrl,
      Value<String?>? affiliateProgramUrl,
      Value<String?>? affiliateNetwork,
      Value<String?>? defaultAffiliateUrl,
      Value<String?>? notes,
      Value<int>? rowid}) {
    return BrandsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      affiliateProgramUrl: affiliateProgramUrl ?? this.affiliateProgramUrl,
      affiliateNetwork: affiliateNetwork ?? this.affiliateNetwork,
      defaultAffiliateUrl: defaultAffiliateUrl ?? this.defaultAffiliateUrl,
      notes: notes ?? this.notes,
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
    if (websiteUrl.present) {
      map['website_url'] = Variable<String>(websiteUrl.value);
    }
    if (affiliateProgramUrl.present) {
      map['affiliate_program_url'] =
          Variable<String>(affiliateProgramUrl.value);
    }
    if (affiliateNetwork.present) {
      map['affiliate_network'] = Variable<String>(affiliateNetwork.value);
    }
    if (defaultAffiliateUrl.present) {
      map['default_affiliate_url'] =
          Variable<String>(defaultAffiliateUrl.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrandsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('websiteUrl: $websiteUrl, ')
          ..write('affiliateProgramUrl: $affiliateProgramUrl, ')
          ..write('affiliateNetwork: $affiliateNetwork, ')
          ..write('defaultAffiliateUrl: $defaultAffiliateUrl, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductTypesTableTable extends ProductTypesTable
    with TableInfo<$ProductTypesTableTable, ProductTypeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductTypesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _namePluralMeta =
      const VerificationMeta('namePlural');
  @override
  late final GeneratedColumn<String> namePlural = GeneratedColumn<String>(
      'name_plural', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, code, name, namePlural, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_types_table';
  @override
  VerificationContext validateIntegrity(Insertable<ProductTypeEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_plural')) {
      context.handle(
          _namePluralMeta,
          namePlural.isAcceptableOrUnknown(
              data['name_plural']!, _namePluralMeta));
    } else if (isInserting) {
      context.missing(_namePluralMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
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
  ProductTypeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductTypeEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      namePlural: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_plural'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ProductTypesTableTable createAlias(String alias) {
    return $ProductTypesTableTable(attachedDatabase, alias);
  }
}

class ProductTypeEntry extends DataClass
    implements Insertable<ProductTypeEntry> {
  /// UUID primary key (matches Supabase product_types.id)
  final String id;

  /// Product type code (unique, matches Supabase product_types.code)
  final String code;

  /// Display name singular (matches Supabase product_types.name)
  final String name;

  /// Display name plural (matches Supabase product_types.name_plural)
  final String namePlural;

  /// Sort order for UI display (matches Supabase product_types.sort_order)
  final int? sortOrder;

  /// When the product type was created (matches Supabase product_types.created_at)
  final DateTime createdAt;
  const ProductTypeEntry(
      {required this.id,
      required this.code,
      required this.name,
      required this.namePlural,
      this.sortOrder,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['name_plural'] = Variable<String>(namePlural);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProductTypesTableCompanion toCompanion(bool nullToAbsent) {
    return ProductTypesTableCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      namePlural: Value(namePlural),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory ProductTypeEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductTypeEntry(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      namePlural: serializer.fromJson<String>(json['namePlural']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'namePlural': serializer.toJson<String>(namePlural),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProductTypeEntry copyWith(
          {String? id,
          String? code,
          String? name,
          String? namePlural,
          Value<int?> sortOrder = const Value.absent(),
          DateTime? createdAt}) =>
      ProductTypeEntry(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        namePlural: namePlural ?? this.namePlural,
        sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );
  ProductTypeEntry copyWithCompanion(ProductTypesTableCompanion data) {
    return ProductTypeEntry(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      namePlural:
          data.namePlural.present ? data.namePlural.value : this.namePlural,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductTypeEntry(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('namePlural: $namePlural, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, name, namePlural, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductTypeEntry &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.namePlural == this.namePlural &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class ProductTypesTableCompanion extends UpdateCompanion<ProductTypeEntry> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> namePlural;
  final Value<int?> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProductTypesTableCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.namePlural = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductTypesTableCompanion.insert({
    required String id,
    required String code,
    required String name,
    required String namePlural,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        code = Value(code),
        name = Value(name),
        namePlural = Value(namePlural);
  static Insertable<ProductTypeEntry> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? namePlural,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (namePlural != null) 'name_plural': namePlural,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductTypesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? code,
      Value<String>? name,
      Value<String>? namePlural,
      Value<int?>? sortOrder,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ProductTypesTableCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      namePlural: namePlural ?? this.namePlural,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (namePlural.present) {
      map['name_plural'] = Variable<String>(namePlural.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
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
    return (StringBuffer('ProductTypesTableCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('namePlural: $namePlural, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppContentTableTable extends AppContentTable
    with TableInfo<$AppContentTableTable, AppContentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppContentTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _environmentMeta =
      const VerificationMeta('environment');
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
      'environment', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('production'));
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
      'locale', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('en'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedByMeta =
      const VerificationMeta('updatedBy');
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
      'updated_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncAtMeta =
      const VerificationMeta('lastSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
      'last_sync_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isCachedMeta =
      const VerificationMeta('isCached');
  @override
  late final GeneratedColumn<bool> isCached = GeneratedColumn<bool>(
      'is_cached', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_cached" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        version,
        environment,
        locale,
        content,
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
        lastSyncAt,
        isCached
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_content_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppContentEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('environment')) {
      context.handle(
          _environmentMeta,
          environment.isAcceptableOrUnknown(
              data['environment']!, _environmentMeta));
    }
    if (data.containsKey('locale')) {
      context.handle(_localeMeta,
          locale.isAcceptableOrUnknown(data['locale']!, _localeMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('updated_by')) {
      context.handle(_updatedByMeta,
          updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta));
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
          _lastSyncAtMeta,
          lastSyncAt.isAcceptableOrUnknown(
              data['last_sync_at']!, _lastSyncAtMeta));
    }
    if (data.containsKey('is_cached')) {
      context.handle(_isCachedMeta,
          isCached.isAcceptableOrUnknown(data['is_cached']!, _isCachedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppContentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      environment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}environment'])!,
      locale: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}locale'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      updatedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_by']),
      lastSyncAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_at']),
      isCached: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_cached'])!,
    );
  }

  @override
  $AppContentTableTable createAlias(String alias) {
    return $AppContentTableTable(attachedDatabase, alias);
  }
}

class AppContentEntry extends DataClass implements Insertable<AppContentEntry> {
  final String id;
  final int version;
  final String environment;
  final String locale;
  final String content;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? lastSyncAt;
  final bool isCached;
  const AppContentEntry(
      {required this.id,
      required this.version,
      required this.environment,
      required this.locale,
      required this.content,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt,
      this.createdBy,
      this.updatedBy,
      this.lastSyncAt,
      required this.isCached});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    map['environment'] = Variable<String>(environment);
    map['locale'] = Variable<String>(locale);
    map['content'] = Variable<String>(content);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    map['is_cached'] = Variable<bool>(isCached);
    return map;
  }

  AppContentTableCompanion toCompanion(bool nullToAbsent) {
    return AppContentTableCompanion(
      id: Value(id),
      version: Value(version),
      environment: Value(environment),
      locale: Value(locale),
      content: Value(content),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      isCached: Value(isCached),
    );
  }

  factory AppContentEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppContentEntry(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      environment: serializer.fromJson<String>(json['environment']),
      locale: serializer.fromJson<String>(json['locale']),
      content: serializer.fromJson<String>(json['content']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      isCached: serializer.fromJson<bool>(json['isCached']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'environment': serializer.toJson<String>(environment),
      'locale': serializer.toJson<String>(locale),
      'content': serializer.toJson<String>(content),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'isCached': serializer.toJson<bool>(isCached),
    };
  }

  AppContentEntry copyWith(
          {String? id,
          int? version,
          String? environment,
          String? locale,
          String? content,
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> createdBy = const Value.absent(),
          Value<String?> updatedBy = const Value.absent(),
          Value<DateTime?> lastSyncAt = const Value.absent(),
          bool? isCached}) =>
      AppContentEntry(
        id: id ?? this.id,
        version: version ?? this.version,
        environment: environment ?? this.environment,
        locale: locale ?? this.locale,
        content: content ?? this.content,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
        lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
        isCached: isCached ?? this.isCached,
      );
  AppContentEntry copyWithCompanion(AppContentTableCompanion data) {
    return AppContentEntry(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      environment:
          data.environment.present ? data.environment.value : this.environment,
      locale: data.locale.present ? data.locale.value : this.locale,
      content: data.content.present ? data.content.value : this.content,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      lastSyncAt:
          data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
      isCached: data.isCached.present ? data.isCached.value : this.isCached,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppContentEntry(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('environment: $environment, ')
          ..write('locale: $locale, ')
          ..write('content: $content, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('isCached: $isCached')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      version,
      environment,
      locale,
      content,
      isActive,
      createdAt,
      updatedAt,
      createdBy,
      updatedBy,
      lastSyncAt,
      isCached);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppContentEntry &&
          other.id == this.id &&
          other.version == this.version &&
          other.environment == this.environment &&
          other.locale == this.locale &&
          other.content == this.content &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.lastSyncAt == this.lastSyncAt &&
          other.isCached == this.isCached);
}

class AppContentTableCompanion extends UpdateCompanion<AppContentEntry> {
  final Value<String> id;
  final Value<int> version;
  final Value<String> environment;
  final Value<String> locale;
  final Value<String> content;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> createdBy;
  final Value<String?> updatedBy;
  final Value<DateTime?> lastSyncAt;
  final Value<bool> isCached;
  final Value<int> rowid;
  const AppContentTableCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.environment = const Value.absent(),
    this.locale = const Value.absent(),
    this.content = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.isCached = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppContentTableCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.environment = const Value.absent(),
    this.locale = const Value.absent(),
    required String content,
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.isCached = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        content = Value(content);
  static Insertable<AppContentEntry> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<String>? environment,
    Expression<String>? locale,
    Expression<String>? content,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<DateTime>? lastSyncAt,
    Expression<bool>? isCached,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (environment != null) 'environment': environment,
      if (locale != null) 'locale': locale,
      if (content != null) 'content': content,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (isCached != null) 'is_cached': isCached,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppContentTableCompanion copyWith(
      {Value<String>? id,
      Value<int>? version,
      Value<String>? environment,
      Value<String>? locale,
      Value<String>? content,
      Value<bool>? isActive,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? createdBy,
      Value<String?>? updatedBy,
      Value<DateTime?>? lastSyncAt,
      Value<bool>? isCached,
      Value<int>? rowid}) {
    return AppContentTableCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      environment: environment ?? this.environment,
      locale: locale ?? this.locale,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      isCached: isCached ?? this.isCached,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (isCached.present) {
      map['is_cached'] = Variable<bool>(isCached.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppContentTableCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('environment: $environment, ')
          ..write('locale: $locale, ')
          ..write('content: $content, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('isCached: $isCached, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutNotesTableTable extends WorkoutNotesTable
    with TableInfo<$WorkoutNotesTableTable, WorkoutNoteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutNotesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteTextMeta =
      const VerificationMeta('noteText');
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
      'note_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
      'rating', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
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
      [id, userId, planId, noteText, rating, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_notes';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutNoteEntry> instance,
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
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    }
    if (data.containsKey('note_text')) {
      context.handle(_noteTextMeta,
          noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta));
    } else if (isInserting) {
      context.missing(_noteTextMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
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
  WorkoutNoteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutNoteEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id']),
      noteText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_text'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WorkoutNotesTableTable createAlias(String alias) {
    return $WorkoutNotesTableTable(attachedDatabase, alias);
  }
}

class WorkoutNoteEntry extends DataClass
    implements Insertable<WorkoutNoteEntry> {
  /// Primary key - UUID
  final String id;

  /// User ID - references user_profiles.id
  final String userId;

  /// Optional reference to nutrition plan ID
  final String? planId;

  /// Note content
  final String noteText;

  /// Optional rating associated with the note (1-5 scale)
  final int? rating;

  /// When the note was created
  final DateTime createdAt;

  /// When the note was last updated
  final DateTime updatedAt;
  const WorkoutNoteEntry(
      {required this.id,
      required this.userId,
      this.planId,
      required this.noteText,
      this.rating,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<String>(planId);
    }
    map['note_text'] = Variable<String>(noteText);
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkoutNotesTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutNotesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      planId:
          planId == null && nullToAbsent ? const Value.absent() : Value(planId),
      noteText: Value(noteText),
      rating:
          rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkoutNoteEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutNoteEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      planId: serializer.fromJson<String?>(json['planId']),
      noteText: serializer.fromJson<String>(json['noteText']),
      rating: serializer.fromJson<int?>(json['rating']),
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
      'planId': serializer.toJson<String?>(planId),
      'noteText': serializer.toJson<String>(noteText),
      'rating': serializer.toJson<int?>(rating),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkoutNoteEntry copyWith(
          {String? id,
          String? userId,
          Value<String?> planId = const Value.absent(),
          String? noteText,
          Value<int?> rating = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      WorkoutNoteEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        planId: planId.present ? planId.value : this.planId,
        noteText: noteText ?? this.noteText,
        rating: rating.present ? rating.value : this.rating,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WorkoutNoteEntry copyWithCompanion(WorkoutNotesTableCompanion data) {
    return WorkoutNoteEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      planId: data.planId.present ? data.planId.value : this.planId,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      rating: data.rating.present ? data.rating.value : this.rating,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutNoteEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('planId: $planId, ')
          ..write('noteText: $noteText, ')
          ..write('rating: $rating, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, planId, noteText, rating, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutNoteEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.planId == this.planId &&
          other.noteText == this.noteText &&
          other.rating == this.rating &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkoutNotesTableCompanion extends UpdateCompanion<WorkoutNoteEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> planId;
  final Value<String> noteText;
  final Value<int?> rating;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkoutNotesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.planId = const Value.absent(),
    this.noteText = const Value.absent(),
    this.rating = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutNotesTableCompanion.insert({
    required String id,
    required String userId,
    this.planId = const Value.absent(),
    required String noteText,
    this.rating = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        noteText = Value(noteText),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<WorkoutNoteEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? planId,
    Expression<String>? noteText,
    Expression<int>? rating,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (planId != null) 'plan_id': planId,
      if (noteText != null) 'note_text': noteText,
      if (rating != null) 'rating': rating,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutNotesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String?>? planId,
      Value<String>? noteText,
      Value<int?>? rating,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return WorkoutNotesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      noteText: noteText ?? this.noteText,
      rating: rating ?? this.rating,
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
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
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
    return (StringBuffer('WorkoutNotesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('planId: $planId, ')
          ..write('noteText: $noteText, ')
          ..write('rating: $rating, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingTableTable extends CarbLoadingTable
    with TableInfo<$CarbLoadingTableTable, CarbLoadingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _raceDateMeta =
      const VerificationMeta('raceDate');
  @override
  late final GeneratedColumn<DateTime> raceDate = GeneratedColumn<DateTime>(
      'race_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _raceDistanceMeta =
      const VerificationMeta('raceDistance');
  @override
  late final GeneratedColumn<String> raceDistance = GeneratedColumn<String>(
      'race_distance', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trainingVolumeMeta =
      const VerificationMeta('trainingVolume');
  @override
  late final GeneratedColumn<String> trainingVolume = GeneratedColumn<String>(
      'training_volume', aliasedName, false,
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
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        raceDate,
        raceDistance,
        trainingVolume,
        planData,
        createdAt,
        updatedAt,
        isActive
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_plans';
  @override
  VerificationContext validateIntegrity(Insertable<CarbLoadingEntry> instance,
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
    if (data.containsKey('race_date')) {
      context.handle(_raceDateMeta,
          raceDate.isAcceptableOrUnknown(data['race_date']!, _raceDateMeta));
    } else if (isInserting) {
      context.missing(_raceDateMeta);
    }
    if (data.containsKey('race_distance')) {
      context.handle(
          _raceDistanceMeta,
          raceDistance.isAcceptableOrUnknown(
              data['race_distance']!, _raceDistanceMeta));
    } else if (isInserting) {
      context.missing(_raceDistanceMeta);
    }
    if (data.containsKey('training_volume')) {
      context.handle(
          _trainingVolumeMeta,
          trainingVolume.isAcceptableOrUnknown(
              data['training_volume']!, _trainingVolumeMeta));
    } else if (isInserting) {
      context.missing(_trainingVolumeMeta);
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
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarbLoadingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      raceDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}race_date'])!,
      raceDistance: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}race_distance'])!,
      trainingVolume: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}training_volume'])!,
      planData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_data'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $CarbLoadingTableTable createAlias(String alias) {
    return $CarbLoadingTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingEntry extends DataClass
    implements Insertable<CarbLoadingEntry> {
  final String id;
  final String userId;
  final DateTime raceDate;
  final String raceDistance;
  final String trainingVolume;
  final String planData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  const CarbLoadingEntry(
      {required this.id,
      required this.userId,
      required this.raceDate,
      required this.raceDistance,
      required this.trainingVolume,
      required this.planData,
      required this.createdAt,
      required this.updatedAt,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['race_date'] = Variable<DateTime>(raceDate);
    map['race_distance'] = Variable<String>(raceDistance);
    map['training_volume'] = Variable<String>(trainingVolume);
    map['plan_data'] = Variable<String>(planData);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CarbLoadingTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingTableCompanion(
      id: Value(id),
      userId: Value(userId),
      raceDate: Value(raceDate),
      raceDistance: Value(raceDistance),
      trainingVolume: Value(trainingVolume),
      planData: Value(planData),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isActive: Value(isActive),
    );
  }

  factory CarbLoadingEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      raceDate: serializer.fromJson<DateTime>(json['raceDate']),
      raceDistance: serializer.fromJson<String>(json['raceDistance']),
      trainingVolume: serializer.fromJson<String>(json['trainingVolume']),
      planData: serializer.fromJson<String>(json['planData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'raceDate': serializer.toJson<DateTime>(raceDate),
      'raceDistance': serializer.toJson<String>(raceDistance),
      'trainingVolume': serializer.toJson<String>(trainingVolume),
      'planData': serializer.toJson<String>(planData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  CarbLoadingEntry copyWith(
          {String? id,
          String? userId,
          DateTime? raceDate,
          String? raceDistance,
          String? trainingVolume,
          String? planData,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? isActive}) =>
      CarbLoadingEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        raceDate: raceDate ?? this.raceDate,
        raceDistance: raceDistance ?? this.raceDistance,
        trainingVolume: trainingVolume ?? this.trainingVolume,
        planData: planData ?? this.planData,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isActive: isActive ?? this.isActive,
      );
  CarbLoadingEntry copyWithCompanion(CarbLoadingTableCompanion data) {
    return CarbLoadingEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      raceDate: data.raceDate.present ? data.raceDate.value : this.raceDate,
      raceDistance: data.raceDistance.present
          ? data.raceDistance.value
          : this.raceDistance,
      trainingVolume: data.trainingVolume.present
          ? data.trainingVolume.value
          : this.trainingVolume,
      planData: data.planData.present ? data.planData.value : this.planData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('raceDate: $raceDate, ')
          ..write('raceDistance: $raceDistance, ')
          ..write('trainingVolume: $trainingVolume, ')
          ..write('planData: $planData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, raceDate, raceDistance,
      trainingVolume, planData, createdAt, updatedAt, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.raceDate == this.raceDate &&
          other.raceDistance == this.raceDistance &&
          other.trainingVolume == this.trainingVolume &&
          other.planData == this.planData &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isActive == this.isActive);
}

class CarbLoadingTableCompanion extends UpdateCompanion<CarbLoadingEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<DateTime> raceDate;
  final Value<String> raceDistance;
  final Value<String> trainingVolume;
  final Value<String> planData;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isActive;
  final Value<int> rowid;
  const CarbLoadingTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.raceDate = const Value.absent(),
    this.raceDistance = const Value.absent(),
    this.trainingVolume = const Value.absent(),
    this.planData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarbLoadingTableCompanion.insert({
    required String id,
    required String userId,
    required DateTime raceDate,
    required String raceDistance,
    required String trainingVolume,
    required String planData,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        raceDate = Value(raceDate),
        raceDistance = Value(raceDistance),
        trainingVolume = Value(trainingVolume),
        planData = Value(planData),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CarbLoadingEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<DateTime>? raceDate,
    Expression<String>? raceDistance,
    Expression<String>? trainingVolume,
    Expression<String>? planData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (raceDate != null) 'race_date': raceDate,
      if (raceDistance != null) 'race_distance': raceDistance,
      if (trainingVolume != null) 'training_volume': trainingVolume,
      if (planData != null) 'plan_data': planData,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarbLoadingTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<DateTime>? raceDate,
      Value<String>? raceDistance,
      Value<String>? trainingVolume,
      Value<String>? planData,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? isActive,
      Value<int>? rowid}) {
    return CarbLoadingTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      raceDate: raceDate ?? this.raceDate,
      raceDistance: raceDistance ?? this.raceDistance,
      trainingVolume: trainingVolume ?? this.trainingVolume,
      planData: planData ?? this.planData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
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
    if (raceDate.present) {
      map['race_date'] = Variable<DateTime>(raceDate.value);
    }
    if (raceDistance.present) {
      map['race_distance'] = Variable<String>(raceDistance.value);
    }
    if (trainingVolume.present) {
      map['training_volume'] = Variable<String>(trainingVolume.value);
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
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('raceDate: $raceDate, ')
          ..write('raceDistance: $raceDistance, ')
          ..write('trainingVolume: $trainingVolume, ')
          ..write('planData: $planData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingSimpleTableTable extends CarbLoadingSimpleTable
    with TableInfo<$CarbLoadingSimpleTableTable, CarbLoadingSimpleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingSimpleTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _raceDateMeta =
      const VerificationMeta('raceDate');
  @override
  late final GeneratedColumn<DateTime> raceDate = GeneratedColumn<DateTime>(
      'race_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _raceDistanceMeta =
      const VerificationMeta('raceDistance');
  @override
  late final GeneratedColumn<String> raceDistance = GeneratedColumn<String>(
      'race_distance', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trainingVolumeMeta =
      const VerificationMeta('trainingVolume');
  @override
  late final GeneratedColumn<String> trainingVolume = GeneratedColumn<String>(
      'training_volume', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dailyCarbTargetGMeta =
      const VerificationMeta('dailyCarbTargetG');
  @override
  late final GeneratedColumn<int> dailyCarbTargetG = GeneratedColumn<int>(
      'daily_carb_target_g', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dailyServingsTargetMeta =
      const VerificationMeta('dailyServingsTarget');
  @override
  late final GeneratedColumn<int> dailyServingsTarget = GeneratedColumn<int>(
      'daily_servings_target', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _bodyWeightKgMeta =
      const VerificationMeta('bodyWeightKg');
  @override
  late final GeneratedColumn<double> bodyWeightKg = GeneratedColumn<double>(
      'body_weight_kg', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsPerKgTargetMeta =
      const VerificationMeta('carbsPerKgTarget');
  @override
  late final GeneratedColumn<double> carbsPerKgTarget = GeneratedColumn<double>(
      'carbs_per_kg_target', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _daySelectionsJsonMeta =
      const VerificationMeta('daySelectionsJson');
  @override
  late final GeneratedColumn<String> daySelectionsJson =
      GeneratedColumn<String>('day_selections_json', aliasedName, false,
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
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        raceDate,
        raceDistance,
        trainingVolume,
        dailyCarbTargetG,
        dailyServingsTarget,
        bodyWeightKg,
        carbsPerKgTarget,
        daySelectionsJson,
        createdAt,
        updatedAt,
        isActive
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_simple_plans';
  @override
  VerificationContext validateIntegrity(
      Insertable<CarbLoadingSimpleEntry> instance,
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
    if (data.containsKey('race_date')) {
      context.handle(_raceDateMeta,
          raceDate.isAcceptableOrUnknown(data['race_date']!, _raceDateMeta));
    } else if (isInserting) {
      context.missing(_raceDateMeta);
    }
    if (data.containsKey('race_distance')) {
      context.handle(
          _raceDistanceMeta,
          raceDistance.isAcceptableOrUnknown(
              data['race_distance']!, _raceDistanceMeta));
    } else if (isInserting) {
      context.missing(_raceDistanceMeta);
    }
    if (data.containsKey('training_volume')) {
      context.handle(
          _trainingVolumeMeta,
          trainingVolume.isAcceptableOrUnknown(
              data['training_volume']!, _trainingVolumeMeta));
    } else if (isInserting) {
      context.missing(_trainingVolumeMeta);
    }
    if (data.containsKey('daily_carb_target_g')) {
      context.handle(
          _dailyCarbTargetGMeta,
          dailyCarbTargetG.isAcceptableOrUnknown(
              data['daily_carb_target_g']!, _dailyCarbTargetGMeta));
    } else if (isInserting) {
      context.missing(_dailyCarbTargetGMeta);
    }
    if (data.containsKey('daily_servings_target')) {
      context.handle(
          _dailyServingsTargetMeta,
          dailyServingsTarget.isAcceptableOrUnknown(
              data['daily_servings_target']!, _dailyServingsTargetMeta));
    } else if (isInserting) {
      context.missing(_dailyServingsTargetMeta);
    }
    if (data.containsKey('body_weight_kg')) {
      context.handle(
          _bodyWeightKgMeta,
          bodyWeightKg.isAcceptableOrUnknown(
              data['body_weight_kg']!, _bodyWeightKgMeta));
    } else if (isInserting) {
      context.missing(_bodyWeightKgMeta);
    }
    if (data.containsKey('carbs_per_kg_target')) {
      context.handle(
          _carbsPerKgTargetMeta,
          carbsPerKgTarget.isAcceptableOrUnknown(
              data['carbs_per_kg_target']!, _carbsPerKgTargetMeta));
    } else if (isInserting) {
      context.missing(_carbsPerKgTargetMeta);
    }
    if (data.containsKey('day_selections_json')) {
      context.handle(
          _daySelectionsJsonMeta,
          daySelectionsJson.isAcceptableOrUnknown(
              data['day_selections_json']!, _daySelectionsJsonMeta));
    } else if (isInserting) {
      context.missing(_daySelectionsJsonMeta);
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
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarbLoadingSimpleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingSimpleEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      raceDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}race_date'])!,
      raceDistance: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}race_distance'])!,
      trainingVolume: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}training_volume'])!,
      dailyCarbTargetG: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}daily_carb_target_g'])!,
      dailyServingsTarget: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}daily_servings_target'])!,
      bodyWeightKg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}body_weight_kg'])!,
      carbsPerKgTarget: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}carbs_per_kg_target'])!,
      daySelectionsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}day_selections_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $CarbLoadingSimpleTableTable createAlias(String alias) {
    return $CarbLoadingSimpleTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingSimpleEntry extends DataClass
    implements Insertable<CarbLoadingSimpleEntry> {
  final String id;
  final String userId;
  final DateTime raceDate;
  final String raceDistance;
  final String trainingVolume;
  final int dailyCarbTargetG;
  final int dailyServingsTarget;
  final double bodyWeightKg;
  final double carbsPerKgTarget;
  final String daySelectionsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  const CarbLoadingSimpleEntry(
      {required this.id,
      required this.userId,
      required this.raceDate,
      required this.raceDistance,
      required this.trainingVolume,
      required this.dailyCarbTargetG,
      required this.dailyServingsTarget,
      required this.bodyWeightKg,
      required this.carbsPerKgTarget,
      required this.daySelectionsJson,
      required this.createdAt,
      required this.updatedAt,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['race_date'] = Variable<DateTime>(raceDate);
    map['race_distance'] = Variable<String>(raceDistance);
    map['training_volume'] = Variable<String>(trainingVolume);
    map['daily_carb_target_g'] = Variable<int>(dailyCarbTargetG);
    map['daily_servings_target'] = Variable<int>(dailyServingsTarget);
    map['body_weight_kg'] = Variable<double>(bodyWeightKg);
    map['carbs_per_kg_target'] = Variable<double>(carbsPerKgTarget);
    map['day_selections_json'] = Variable<String>(daySelectionsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CarbLoadingSimpleTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingSimpleTableCompanion(
      id: Value(id),
      userId: Value(userId),
      raceDate: Value(raceDate),
      raceDistance: Value(raceDistance),
      trainingVolume: Value(trainingVolume),
      dailyCarbTargetG: Value(dailyCarbTargetG),
      dailyServingsTarget: Value(dailyServingsTarget),
      bodyWeightKg: Value(bodyWeightKg),
      carbsPerKgTarget: Value(carbsPerKgTarget),
      daySelectionsJson: Value(daySelectionsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isActive: Value(isActive),
    );
  }

  factory CarbLoadingSimpleEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingSimpleEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      raceDate: serializer.fromJson<DateTime>(json['raceDate']),
      raceDistance: serializer.fromJson<String>(json['raceDistance']),
      trainingVolume: serializer.fromJson<String>(json['trainingVolume']),
      dailyCarbTargetG: serializer.fromJson<int>(json['dailyCarbTargetG']),
      dailyServingsTarget:
          serializer.fromJson<int>(json['dailyServingsTarget']),
      bodyWeightKg: serializer.fromJson<double>(json['bodyWeightKg']),
      carbsPerKgTarget: serializer.fromJson<double>(json['carbsPerKgTarget']),
      daySelectionsJson: serializer.fromJson<String>(json['daySelectionsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'raceDate': serializer.toJson<DateTime>(raceDate),
      'raceDistance': serializer.toJson<String>(raceDistance),
      'trainingVolume': serializer.toJson<String>(trainingVolume),
      'dailyCarbTargetG': serializer.toJson<int>(dailyCarbTargetG),
      'dailyServingsTarget': serializer.toJson<int>(dailyServingsTarget),
      'bodyWeightKg': serializer.toJson<double>(bodyWeightKg),
      'carbsPerKgTarget': serializer.toJson<double>(carbsPerKgTarget),
      'daySelectionsJson': serializer.toJson<String>(daySelectionsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  CarbLoadingSimpleEntry copyWith(
          {String? id,
          String? userId,
          DateTime? raceDate,
          String? raceDistance,
          String? trainingVolume,
          int? dailyCarbTargetG,
          int? dailyServingsTarget,
          double? bodyWeightKg,
          double? carbsPerKgTarget,
          String? daySelectionsJson,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? isActive}) =>
      CarbLoadingSimpleEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        raceDate: raceDate ?? this.raceDate,
        raceDistance: raceDistance ?? this.raceDistance,
        trainingVolume: trainingVolume ?? this.trainingVolume,
        dailyCarbTargetG: dailyCarbTargetG ?? this.dailyCarbTargetG,
        dailyServingsTarget: dailyServingsTarget ?? this.dailyServingsTarget,
        bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
        carbsPerKgTarget: carbsPerKgTarget ?? this.carbsPerKgTarget,
        daySelectionsJson: daySelectionsJson ?? this.daySelectionsJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isActive: isActive ?? this.isActive,
      );
  CarbLoadingSimpleEntry copyWithCompanion(
      CarbLoadingSimpleTableCompanion data) {
    return CarbLoadingSimpleEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      raceDate: data.raceDate.present ? data.raceDate.value : this.raceDate,
      raceDistance: data.raceDistance.present
          ? data.raceDistance.value
          : this.raceDistance,
      trainingVolume: data.trainingVolume.present
          ? data.trainingVolume.value
          : this.trainingVolume,
      dailyCarbTargetG: data.dailyCarbTargetG.present
          ? data.dailyCarbTargetG.value
          : this.dailyCarbTargetG,
      dailyServingsTarget: data.dailyServingsTarget.present
          ? data.dailyServingsTarget.value
          : this.dailyServingsTarget,
      bodyWeightKg: data.bodyWeightKg.present
          ? data.bodyWeightKg.value
          : this.bodyWeightKg,
      carbsPerKgTarget: data.carbsPerKgTarget.present
          ? data.carbsPerKgTarget.value
          : this.carbsPerKgTarget,
      daySelectionsJson: data.daySelectionsJson.present
          ? data.daySelectionsJson.value
          : this.daySelectionsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingSimpleEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('raceDate: $raceDate, ')
          ..write('raceDistance: $raceDistance, ')
          ..write('trainingVolume: $trainingVolume, ')
          ..write('dailyCarbTargetG: $dailyCarbTargetG, ')
          ..write('dailyServingsTarget: $dailyServingsTarget, ')
          ..write('bodyWeightKg: $bodyWeightKg, ')
          ..write('carbsPerKgTarget: $carbsPerKgTarget, ')
          ..write('daySelectionsJson: $daySelectionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      userId,
      raceDate,
      raceDistance,
      trainingVolume,
      dailyCarbTargetG,
      dailyServingsTarget,
      bodyWeightKg,
      carbsPerKgTarget,
      daySelectionsJson,
      createdAt,
      updatedAt,
      isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingSimpleEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.raceDate == this.raceDate &&
          other.raceDistance == this.raceDistance &&
          other.trainingVolume == this.trainingVolume &&
          other.dailyCarbTargetG == this.dailyCarbTargetG &&
          other.dailyServingsTarget == this.dailyServingsTarget &&
          other.bodyWeightKg == this.bodyWeightKg &&
          other.carbsPerKgTarget == this.carbsPerKgTarget &&
          other.daySelectionsJson == this.daySelectionsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isActive == this.isActive);
}

class CarbLoadingSimpleTableCompanion
    extends UpdateCompanion<CarbLoadingSimpleEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<DateTime> raceDate;
  final Value<String> raceDistance;
  final Value<String> trainingVolume;
  final Value<int> dailyCarbTargetG;
  final Value<int> dailyServingsTarget;
  final Value<double> bodyWeightKg;
  final Value<double> carbsPerKgTarget;
  final Value<String> daySelectionsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isActive;
  final Value<int> rowid;
  const CarbLoadingSimpleTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.raceDate = const Value.absent(),
    this.raceDistance = const Value.absent(),
    this.trainingVolume = const Value.absent(),
    this.dailyCarbTargetG = const Value.absent(),
    this.dailyServingsTarget = const Value.absent(),
    this.bodyWeightKg = const Value.absent(),
    this.carbsPerKgTarget = const Value.absent(),
    this.daySelectionsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarbLoadingSimpleTableCompanion.insert({
    required String id,
    required String userId,
    required DateTime raceDate,
    required String raceDistance,
    required String trainingVolume,
    required int dailyCarbTargetG,
    required int dailyServingsTarget,
    required double bodyWeightKg,
    required double carbsPerKgTarget,
    required String daySelectionsJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        raceDate = Value(raceDate),
        raceDistance = Value(raceDistance),
        trainingVolume = Value(trainingVolume),
        dailyCarbTargetG = Value(dailyCarbTargetG),
        dailyServingsTarget = Value(dailyServingsTarget),
        bodyWeightKg = Value(bodyWeightKg),
        carbsPerKgTarget = Value(carbsPerKgTarget),
        daySelectionsJson = Value(daySelectionsJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CarbLoadingSimpleEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<DateTime>? raceDate,
    Expression<String>? raceDistance,
    Expression<String>? trainingVolume,
    Expression<int>? dailyCarbTargetG,
    Expression<int>? dailyServingsTarget,
    Expression<double>? bodyWeightKg,
    Expression<double>? carbsPerKgTarget,
    Expression<String>? daySelectionsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (raceDate != null) 'race_date': raceDate,
      if (raceDistance != null) 'race_distance': raceDistance,
      if (trainingVolume != null) 'training_volume': trainingVolume,
      if (dailyCarbTargetG != null) 'daily_carb_target_g': dailyCarbTargetG,
      if (dailyServingsTarget != null)
        'daily_servings_target': dailyServingsTarget,
      if (bodyWeightKg != null) 'body_weight_kg': bodyWeightKg,
      if (carbsPerKgTarget != null) 'carbs_per_kg_target': carbsPerKgTarget,
      if (daySelectionsJson != null) 'day_selections_json': daySelectionsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarbLoadingSimpleTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<DateTime>? raceDate,
      Value<String>? raceDistance,
      Value<String>? trainingVolume,
      Value<int>? dailyCarbTargetG,
      Value<int>? dailyServingsTarget,
      Value<double>? bodyWeightKg,
      Value<double>? carbsPerKgTarget,
      Value<String>? daySelectionsJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? isActive,
      Value<int>? rowid}) {
    return CarbLoadingSimpleTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      raceDate: raceDate ?? this.raceDate,
      raceDistance: raceDistance ?? this.raceDistance,
      trainingVolume: trainingVolume ?? this.trainingVolume,
      dailyCarbTargetG: dailyCarbTargetG ?? this.dailyCarbTargetG,
      dailyServingsTarget: dailyServingsTarget ?? this.dailyServingsTarget,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      carbsPerKgTarget: carbsPerKgTarget ?? this.carbsPerKgTarget,
      daySelectionsJson: daySelectionsJson ?? this.daySelectionsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
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
    if (raceDate.present) {
      map['race_date'] = Variable<DateTime>(raceDate.value);
    }
    if (raceDistance.present) {
      map['race_distance'] = Variable<String>(raceDistance.value);
    }
    if (trainingVolume.present) {
      map['training_volume'] = Variable<String>(trainingVolume.value);
    }
    if (dailyCarbTargetG.present) {
      map['daily_carb_target_g'] = Variable<int>(dailyCarbTargetG.value);
    }
    if (dailyServingsTarget.present) {
      map['daily_servings_target'] = Variable<int>(dailyServingsTarget.value);
    }
    if (bodyWeightKg.present) {
      map['body_weight_kg'] = Variable<double>(bodyWeightKg.value);
    }
    if (carbsPerKgTarget.present) {
      map['carbs_per_kg_target'] = Variable<double>(carbsPerKgTarget.value);
    }
    if (daySelectionsJson.present) {
      map['day_selections_json'] = Variable<String>(daySelectionsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingSimpleTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('raceDate: $raceDate, ')
          ..write('raceDistance: $raceDistance, ')
          ..write('trainingVolume: $trainingVolume, ')
          ..write('dailyCarbTargetG: $dailyCarbTargetG, ')
          ..write('dailyServingsTarget: $dailyServingsTarget, ')
          ..write('bodyWeightKg: $bodyWeightKg, ')
          ..write('carbsPerKgTarget: $carbsPerKgTarget, ')
          ..write('daySelectionsJson: $daySelectionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EdgeFunctionsTableTable extends EdgeFunctionsTable
    with TableInfo<$EdgeFunctionsTableTable, EdgeFunctionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EdgeFunctionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, code, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'edge_functions_table';
  @override
  VerificationContext validateIntegrity(Insertable<EdgeFunctionEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EdgeFunctionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EdgeFunctionEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $EdgeFunctionsTableTable createAlias(String alias) {
    return $EdgeFunctionsTableTable(attachedDatabase, alias);
  }
}

class EdgeFunctionEntry extends DataClass
    implements Insertable<EdgeFunctionEntry> {
  /// UUID primary key (matches Supabase edge_functions.id)
  final String id;

  /// Function name (unique identifier)
  final String name;

  /// Function code (JavaScript/TypeScript source)
  final String code;

  /// When the function was created (matches Supabase edge_functions.created_at)
  final DateTime createdAt;

  /// When the function was last updated (matches Supabase edge_functions.updated_at)
  final DateTime updatedAt;
  const EdgeFunctionEntry(
      {required this.id,
      required this.name,
      required this.code,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EdgeFunctionsTableCompanion toCompanion(bool nullToAbsent) {
    return EdgeFunctionsTableCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EdgeFunctionEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EdgeFunctionEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EdgeFunctionEntry copyWith(
          {String? id,
          String? name,
          String? code,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      EdgeFunctionEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        code: code ?? this.code,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  EdgeFunctionEntry copyWithCompanion(EdgeFunctionsTableCompanion data) {
    return EdgeFunctionEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EdgeFunctionEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, code, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EdgeFunctionEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EdgeFunctionsTableCompanion extends UpdateCompanion<EdgeFunctionEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> code;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EdgeFunctionsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EdgeFunctionsTableCompanion.insert({
    required String id,
    required String name,
    required String code,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        code = Value(code);
  static Insertable<EdgeFunctionEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EdgeFunctionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? code,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return EdgeFunctionsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
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
    return (StringBuffer('EdgeFunctionsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
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
  late final $MacroTargetsTableTable macroTargetsTable =
      $MacroTargetsTableTable(this);
  late final $FeedbackTableTable feedbackTable = $FeedbackTableTable(this);
  late final $FoodsTableTable foodsTable = $FoodsTableTable(this);
  late final $CategoriesTableTable categoriesTable =
      $CategoriesTableTable(this);
  late final $FoodCategoriesTableTable foodCategoriesTable =
      $FoodCategoriesTableTable(this);
  late final $BrandsTableTable brandsTable = $BrandsTableTable(this);
  late final $ProductTypesTableTable productTypesTable =
      $ProductTypesTableTable(this);
  late final $AppContentTableTable appContentTable =
      $AppContentTableTable(this);
  late final $WorkoutNotesTableTable workoutNotesTable =
      $WorkoutNotesTableTable(this);
  late final $CarbLoadingTableTable carbLoadingTable =
      $CarbLoadingTableTable(this);
  late final $CarbLoadingSimpleTableTable carbLoadingSimpleTable =
      $CarbLoadingSimpleTableTable(this);
  late final $EdgeFunctionsTableTable edgeFunctionsTable =
      $EdgeFunctionsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        userProfilesTable,
        foodPreferencesTable,
        nutritionPlans,
        macroTargetsTable,
        feedbackTable,
        foodsTable,
        categoriesTable,
        foodCategoriesTable,
        brandsTable,
        productTypesTable,
        appContentTable,
        workoutNotesTable,
        carbLoadingTable,
        carbLoadingSimpleTable,
        edgeFunctionsTable
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('foods_table',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('food_categories_table', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$UserProfilesTableTableCreateCompanionBuilder
    = UserProfilesTableCompanion Function({
  required String id,
  required String deviceId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> gender,
  Value<DateTime?> birthday,
  Value<int?> heightFeet,
  Value<int?> heightInches,
  Value<double?> weightPounds,
  Value<bool> runsWithWaterBottle,
  Value<Map<String, dynamic>> foodPreferences,
  Value<String> preferredDistanceUnit,
  Value<String> preferredPaceUnit,
  Value<String> gutTrainingLevel,
  Value<bool> onboardingCompleted,
  Value<DateTime> lastActiveAt,
  Value<String?> appVersion,
  Value<bool> notificationsEnabled,
  Value<int> defaultReminderDay,
  Value<int> defaultReminderHour,
  Value<int> defaultReminderMinute,
  Value<bool> defaultReminderRecurring,
  Value<String?> tempPlanData,
  Value<bool> swipeHintShown,
  Value<int> rowid,
});
typedef $$UserProfilesTableTableUpdateCompanionBuilder
    = UserProfilesTableCompanion Function({
  Value<String> id,
  Value<String> deviceId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> gender,
  Value<DateTime?> birthday,
  Value<int?> heightFeet,
  Value<int?> heightInches,
  Value<double?> weightPounds,
  Value<bool> runsWithWaterBottle,
  Value<Map<String, dynamic>> foodPreferences,
  Value<String> preferredDistanceUnit,
  Value<String> preferredPaceUnit,
  Value<String> gutTrainingLevel,
  Value<bool> onboardingCompleted,
  Value<DateTime> lastActiveAt,
  Value<String?> appVersion,
  Value<bool> notificationsEnabled,
  Value<int> defaultReminderDay,
  Value<int> defaultReminderHour,
  Value<int> defaultReminderMinute,
  Value<bool> defaultReminderRecurring,
  Value<String?> tempPlanData,
  Value<bool> swipeHintShown,
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

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

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

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get foodPreferences => $composableBuilder(
          column: $table.foodPreferences,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get preferredDistanceUnit => $composableBuilder(
      column: $table.preferredDistanceUnit,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferredPaceUnit => $composableBuilder(
      column: $table.preferredPaceUnit,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gutTrainingLevel => $composableBuilder(
      column: $table.gutTrainingLevel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
      column: $table.onboardingCompleted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt, builder: (column) => ColumnFilters(column));

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

  ColumnFilters<bool> get swipeHintShown => $composableBuilder(
      column: $table.swipeHintShown,
      builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

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

  ColumnOrderings<String> get foodPreferences => $composableBuilder(
      column: $table.foodPreferences,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferredDistanceUnit => $composableBuilder(
      column: $table.preferredDistanceUnit,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferredPaceUnit => $composableBuilder(
      column: $table.preferredPaceUnit,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gutTrainingLevel => $composableBuilder(
      column: $table.gutTrainingLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
      column: $table.onboardingCompleted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt,
      builder: (column) => ColumnOrderings(column));

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

  ColumnOrderings<bool> get swipeHintShown => $composableBuilder(
      column: $table.swipeHintShown,
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

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

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

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      get foodPreferences => $composableBuilder(
          column: $table.foodPreferences, builder: (column) => column);

  GeneratedColumn<String> get preferredDistanceUnit => $composableBuilder(
      column: $table.preferredDistanceUnit, builder: (column) => column);

  GeneratedColumn<String> get preferredPaceUnit => $composableBuilder(
      column: $table.preferredPaceUnit, builder: (column) => column);

  GeneratedColumn<String> get gutTrainingLevel => $composableBuilder(
      column: $table.gutTrainingLevel, builder: (column) => column);

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
      column: $table.onboardingCompleted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt, builder: (column) => column);

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

  GeneratedColumn<bool> get swipeHintShown => $composableBuilder(
      column: $table.swipeHintShown, builder: (column) => column);
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
            Value<String> deviceId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> gender = const Value.absent(),
            Value<DateTime?> birthday = const Value.absent(),
            Value<int?> heightFeet = const Value.absent(),
            Value<int?> heightInches = const Value.absent(),
            Value<double?> weightPounds = const Value.absent(),
            Value<bool> runsWithWaterBottle = const Value.absent(),
            Value<Map<String, dynamic>> foodPreferences = const Value.absent(),
            Value<String> preferredDistanceUnit = const Value.absent(),
            Value<String> preferredPaceUnit = const Value.absent(),
            Value<String> gutTrainingLevel = const Value.absent(),
            Value<bool> onboardingCompleted = const Value.absent(),
            Value<DateTime> lastActiveAt = const Value.absent(),
            Value<String?> appVersion = const Value.absent(),
            Value<bool> notificationsEnabled = const Value.absent(),
            Value<int> defaultReminderDay = const Value.absent(),
            Value<int> defaultReminderHour = const Value.absent(),
            Value<int> defaultReminderMinute = const Value.absent(),
            Value<bool> defaultReminderRecurring = const Value.absent(),
            Value<String?> tempPlanData = const Value.absent(),
            Value<bool> swipeHintShown = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfilesTableCompanion(
            id: id,
            deviceId: deviceId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            gender: gender,
            birthday: birthday,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightPounds: weightPounds,
            runsWithWaterBottle: runsWithWaterBottle,
            foodPreferences: foodPreferences,
            preferredDistanceUnit: preferredDistanceUnit,
            preferredPaceUnit: preferredPaceUnit,
            gutTrainingLevel: gutTrainingLevel,
            onboardingCompleted: onboardingCompleted,
            lastActiveAt: lastActiveAt,
            appVersion: appVersion,
            notificationsEnabled: notificationsEnabled,
            defaultReminderDay: defaultReminderDay,
            defaultReminderHour: defaultReminderHour,
            defaultReminderMinute: defaultReminderMinute,
            defaultReminderRecurring: defaultReminderRecurring,
            tempPlanData: tempPlanData,
            swipeHintShown: swipeHintShown,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String deviceId,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> gender = const Value.absent(),
            Value<DateTime?> birthday = const Value.absent(),
            Value<int?> heightFeet = const Value.absent(),
            Value<int?> heightInches = const Value.absent(),
            Value<double?> weightPounds = const Value.absent(),
            Value<bool> runsWithWaterBottle = const Value.absent(),
            Value<Map<String, dynamic>> foodPreferences = const Value.absent(),
            Value<String> preferredDistanceUnit = const Value.absent(),
            Value<String> preferredPaceUnit = const Value.absent(),
            Value<String> gutTrainingLevel = const Value.absent(),
            Value<bool> onboardingCompleted = const Value.absent(),
            Value<DateTime> lastActiveAt = const Value.absent(),
            Value<String?> appVersion = const Value.absent(),
            Value<bool> notificationsEnabled = const Value.absent(),
            Value<int> defaultReminderDay = const Value.absent(),
            Value<int> defaultReminderHour = const Value.absent(),
            Value<int> defaultReminderMinute = const Value.absent(),
            Value<bool> defaultReminderRecurring = const Value.absent(),
            Value<String?> tempPlanData = const Value.absent(),
            Value<bool> swipeHintShown = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfilesTableCompanion.insert(
            id: id,
            deviceId: deviceId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            gender: gender,
            birthday: birthday,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightPounds: weightPounds,
            runsWithWaterBottle: runsWithWaterBottle,
            foodPreferences: foodPreferences,
            preferredDistanceUnit: preferredDistanceUnit,
            preferredPaceUnit: preferredPaceUnit,
            gutTrainingLevel: gutTrainingLevel,
            onboardingCompleted: onboardingCompleted,
            lastActiveAt: lastActiveAt,
            appVersion: appVersion,
            notificationsEnabled: notificationsEnabled,
            defaultReminderDay: defaultReminderDay,
            defaultReminderHour: defaultReminderHour,
            defaultReminderMinute: defaultReminderMinute,
            defaultReminderRecurring: defaultReminderRecurring,
            tempPlanData: tempPlanData,
            swipeHintShown: swipeHintShown,
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
  required String id,
  required String deviceId,
  required String foodName,
  required String preference,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$FoodPreferencesTableTableUpdateCompanionBuilder
    = FoodPreferencesTableCompanion Function({
  Value<String> id,
  Value<String> deviceId,
  Value<String> foodName,
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
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodName => $composableBuilder(
      column: $table.foodName, builder: (column) => ColumnFilters(column));

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
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodName => $composableBuilder(
      column: $table.foodName, builder: (column) => ColumnOrderings(column));

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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

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
            Value<String> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> foodName = const Value.absent(),
            Value<String> preference = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodPreferencesTableCompanion(
            id: id,
            deviceId: deviceId,
            foodName: foodName,
            preference: preference,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String deviceId,
            required String foodName,
            required String preference,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodPreferencesTableCompanion.insert(
            id: id,
            deviceId: deviceId,
            foodName: foodName,
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
  required String deviceId,
  required String planData,
  required String planId,
  required String planName,
  Value<double?> distanceMiles,
  Value<double?> paceMinutesPerMile,
  Value<int?> totalCalories,
  Value<String?> notes,
  Value<int> version,
  Value<String?> lastModifiedBy,
  Value<DateTime?> clientUpdatedAt,
  Value<bool> isDeleted,
  Value<String?> conflictResolution,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$NutritionPlansTableUpdateCompanionBuilder = NutritionPlansCompanion
    Function({
  Value<String> id,
  Value<String> deviceId,
  Value<String> planData,
  Value<String> planId,
  Value<String> planName,
  Value<double?> distanceMiles,
  Value<double?> paceMinutesPerMile,
  Value<int?> totalCalories,
  Value<String?> notes,
  Value<int> version,
  Value<String?> lastModifiedBy,
  Value<DateTime?> clientUpdatedAt,
  Value<bool> isDeleted,
  Value<String?> conflictResolution,
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

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planData => $composableBuilder(
      column: $table.planData, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planName => $composableBuilder(
      column: $table.planName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceMiles => $composableBuilder(
      column: $table.distanceMiles, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paceMinutesPerMile => $composableBuilder(
      column: $table.paceMinutesPerMile,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalCalories => $composableBuilder(
      column: $table.totalCalories, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastModifiedBy => $composableBuilder(
      column: $table.lastModifiedBy,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conflictResolution => $composableBuilder(
      column: $table.conflictResolution,
      builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planData => $composableBuilder(
      column: $table.planData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planName => $composableBuilder(
      column: $table.planName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceMiles => $composableBuilder(
      column: $table.distanceMiles,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paceMinutesPerMile => $composableBuilder(
      column: $table.paceMinutesPerMile,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalCalories => $composableBuilder(
      column: $table.totalCalories,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastModifiedBy => $composableBuilder(
      column: $table.lastModifiedBy,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conflictResolution => $composableBuilder(
      column: $table.conflictResolution,
      builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get planData =>
      $composableBuilder(column: $table.planData, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get planName =>
      $composableBuilder(column: $table.planName, builder: (column) => column);

  GeneratedColumn<double> get distanceMiles => $composableBuilder(
      column: $table.distanceMiles, builder: (column) => column);

  GeneratedColumn<double> get paceMinutesPerMile => $composableBuilder(
      column: $table.paceMinutesPerMile, builder: (column) => column);

  GeneratedColumn<int> get totalCalories => $composableBuilder(
      column: $table.totalCalories, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get lastModifiedBy => $composableBuilder(
      column: $table.lastModifiedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get conflictResolution => $composableBuilder(
      column: $table.conflictResolution, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NutritionPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NutritionPlansTable,
    NutritionPlanEntry,
    $$NutritionPlansTableFilterComposer,
    $$NutritionPlansTableOrderingComposer,
    $$NutritionPlansTableAnnotationComposer,
    $$NutritionPlansTableCreateCompanionBuilder,
    $$NutritionPlansTableUpdateCompanionBuilder,
    (
      NutritionPlanEntry,
      BaseReferences<_$AppDatabase, $NutritionPlansTable, NutritionPlanEntry>
    ),
    NutritionPlanEntry,
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
            Value<String> deviceId = const Value.absent(),
            Value<String> planData = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<String> planName = const Value.absent(),
            Value<double?> distanceMiles = const Value.absent(),
            Value<double?> paceMinutesPerMile = const Value.absent(),
            Value<int?> totalCalories = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> lastModifiedBy = const Value.absent(),
            Value<DateTime?> clientUpdatedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> conflictResolution = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NutritionPlansCompanion(
            id: id,
            deviceId: deviceId,
            planData: planData,
            planId: planId,
            planName: planName,
            distanceMiles: distanceMiles,
            paceMinutesPerMile: paceMinutesPerMile,
            totalCalories: totalCalories,
            notes: notes,
            version: version,
            lastModifiedBy: lastModifiedBy,
            clientUpdatedAt: clientUpdatedAt,
            isDeleted: isDeleted,
            conflictResolution: conflictResolution,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String deviceId,
            required String planData,
            required String planId,
            required String planName,
            Value<double?> distanceMiles = const Value.absent(),
            Value<double?> paceMinutesPerMile = const Value.absent(),
            Value<int?> totalCalories = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> lastModifiedBy = const Value.absent(),
            Value<DateTime?> clientUpdatedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> conflictResolution = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NutritionPlansCompanion.insert(
            id: id,
            deviceId: deviceId,
            planData: planData,
            planId: planId,
            planName: planName,
            distanceMiles: distanceMiles,
            paceMinutesPerMile: paceMinutesPerMile,
            totalCalories: totalCalories,
            notes: notes,
            version: version,
            lastModifiedBy: lastModifiedBy,
            clientUpdatedAt: clientUpdatedAt,
            isDeleted: isDeleted,
            conflictResolution: conflictResolution,
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
    NutritionPlanEntry,
    $$NutritionPlansTableFilterComposer,
    $$NutritionPlansTableOrderingComposer,
    $$NutritionPlansTableAnnotationComposer,
    $$NutritionPlansTableCreateCompanionBuilder,
    $$NutritionPlansTableUpdateCompanionBuilder,
    (
      NutritionPlanEntry,
      BaseReferences<_$AppDatabase, $NutritionPlansTable, NutritionPlanEntry>
    ),
    NutritionPlanEntry,
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
typedef $$FoodsTableTableCreateCompanionBuilder = FoodsTableCompanion Function({
  required String id,
  Value<String?> name,
  Value<String?> imageAddress,
  Value<DateTime> createdAt,
  Value<double?> servingAmount,
  Value<int?> maxServingsBefore,
  Value<int?> maxServingsDuring,
  Value<int?> maxServingsAfter,
  Value<bool> beforeRunSuitable,
  Value<bool> duringRunSuitable,
  Value<bool> runPortable,
  Value<bool> requiresPreparation,
  Value<bool> aidStationAvailable,
  Value<int?> sodiumMg,
  Value<int?> caffeineMg,
  Value<int?> potassiumMg,
  Value<double?> fatPerServing,
  Value<double?> carbsPerServing,
  Value<double?> proteinPerServing,
  Value<int?> caloriesPerServing,
  Value<double?> fluidMlPerServing,
  Value<String?> brandId,
  Value<bool> showInPreferences,
  Value<bool> isElectrolyte,
  Value<String?> displayName,
  Value<String?> displayNamePlural,
  Value<String?> servingDescription,
  Value<String?> description,
  Value<String?> instructions,
  Value<String?> nutritionalInfo,
  Value<String?> servingUnit,
  Value<String?> servingUnitPlural,
  Value<String?> servingQualifier,
  Value<String?> servingSize,
  Value<bool?> afterRunSuitable,
  Value<String?> productType,
  Value<String?> purchaseUrl,
  Value<String?> affiliateSource,
  Value<int?> preferencePriority,
  Value<int> rowid,
});
typedef $$FoodsTableTableUpdateCompanionBuilder = FoodsTableCompanion Function({
  Value<String> id,
  Value<String?> name,
  Value<String?> imageAddress,
  Value<DateTime> createdAt,
  Value<double?> servingAmount,
  Value<int?> maxServingsBefore,
  Value<int?> maxServingsDuring,
  Value<int?> maxServingsAfter,
  Value<bool> beforeRunSuitable,
  Value<bool> duringRunSuitable,
  Value<bool> runPortable,
  Value<bool> requiresPreparation,
  Value<bool> aidStationAvailable,
  Value<int?> sodiumMg,
  Value<int?> caffeineMg,
  Value<int?> potassiumMg,
  Value<double?> fatPerServing,
  Value<double?> carbsPerServing,
  Value<double?> proteinPerServing,
  Value<int?> caloriesPerServing,
  Value<double?> fluidMlPerServing,
  Value<String?> brandId,
  Value<bool> showInPreferences,
  Value<bool> isElectrolyte,
  Value<String?> displayName,
  Value<String?> displayNamePlural,
  Value<String?> servingDescription,
  Value<String?> description,
  Value<String?> instructions,
  Value<String?> nutritionalInfo,
  Value<String?> servingUnit,
  Value<String?> servingUnitPlural,
  Value<String?> servingQualifier,
  Value<String?> servingSize,
  Value<bool?> afterRunSuitable,
  Value<String?> productType,
  Value<String?> purchaseUrl,
  Value<String?> affiliateSource,
  Value<int?> preferencePriority,
  Value<int> rowid,
});

final class $$FoodsTableTableReferences
    extends BaseReferences<_$AppDatabase, $FoodsTableTable, FoodEntry> {
  $$FoodsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FoodCategoriesTableTable, List<FoodCategoryEntry>>
      _foodCategoriesTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.foodCategoriesTable,
              aliasName: $_aliasNameGenerator(
                  db.foodsTable.id, db.foodCategoriesTable.foodId));

  $$FoodCategoriesTableTableProcessedTableManager get foodCategoriesTableRefs {
    final manager =
        $$FoodCategoriesTableTableTableManager($_db, $_db.foodCategoriesTable)
            .filter((f) => f.foodId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_foodCategoriesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FoodsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FoodsTableTable> {
  $$FoodsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageAddress => $composableBuilder(
      column: $table.imageAddress, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get servingAmount => $composableBuilder(
      column: $table.servingAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxServingsBefore => $composableBuilder(
      column: $table.maxServingsBefore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxServingsDuring => $composableBuilder(
      column: $table.maxServingsDuring,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxServingsAfter => $composableBuilder(
      column: $table.maxServingsAfter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get beforeRunSuitable => $composableBuilder(
      column: $table.beforeRunSuitable,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get duringRunSuitable => $composableBuilder(
      column: $table.duringRunSuitable,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get runPortable => $composableBuilder(
      column: $table.runPortable, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get requiresPreparation => $composableBuilder(
      column: $table.requiresPreparation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get aidStationAvailable => $composableBuilder(
      column: $table.aidStationAvailable,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sodiumMg => $composableBuilder(
      column: $table.sodiumMg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caffeineMg => $composableBuilder(
      column: $table.caffeineMg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get potassiumMg => $composableBuilder(
      column: $table.potassiumMg, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fatPerServing => $composableBuilder(
      column: $table.fatPerServing, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbsPerServing => $composableBuilder(
      column: $table.carbsPerServing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get proteinPerServing => $composableBuilder(
      column: $table.proteinPerServing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caloriesPerServing => $composableBuilder(
      column: $table.caloriesPerServing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fluidMlPerServing => $composableBuilder(
      column: $table.fluidMlPerServing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brandId => $composableBuilder(
      column: $table.brandId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get showInPreferences => $composableBuilder(
      column: $table.showInPreferences,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isElectrolyte => $composableBuilder(
      column: $table.isElectrolyte, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayNamePlural => $composableBuilder(
      column: $table.displayNamePlural,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servingDescription => $composableBuilder(
      column: $table.servingDescription,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instructions => $composableBuilder(
      column: $table.instructions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nutritionalInfo => $composableBuilder(
      column: $table.nutritionalInfo,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servingUnit => $composableBuilder(
      column: $table.servingUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servingUnitPlural => $composableBuilder(
      column: $table.servingUnitPlural,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servingQualifier => $composableBuilder(
      column: $table.servingQualifier,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servingSize => $composableBuilder(
      column: $table.servingSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get afterRunSuitable => $composableBuilder(
      column: $table.afterRunSuitable,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purchaseUrl => $composableBuilder(
      column: $table.purchaseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get affiliateSource => $composableBuilder(
      column: $table.affiliateSource,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get preferencePriority => $composableBuilder(
      column: $table.preferencePriority,
      builder: (column) => ColumnFilters(column));

  Expression<bool> foodCategoriesTableRefs(
      Expression<bool> Function($$FoodCategoriesTableTableFilterComposer f) f) {
    final $$FoodCategoriesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.foodCategoriesTable,
        getReferencedColumn: (t) => t.foodId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoodCategoriesTableTableFilterComposer(
              $db: $db,
              $table: $db.foodCategoriesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FoodsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodsTableTable> {
  $$FoodsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageAddress => $composableBuilder(
      column: $table.imageAddress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get servingAmount => $composableBuilder(
      column: $table.servingAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxServingsBefore => $composableBuilder(
      column: $table.maxServingsBefore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxServingsDuring => $composableBuilder(
      column: $table.maxServingsDuring,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxServingsAfter => $composableBuilder(
      column: $table.maxServingsAfter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get beforeRunSuitable => $composableBuilder(
      column: $table.beforeRunSuitable,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get duringRunSuitable => $composableBuilder(
      column: $table.duringRunSuitable,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get runPortable => $composableBuilder(
      column: $table.runPortable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get requiresPreparation => $composableBuilder(
      column: $table.requiresPreparation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get aidStationAvailable => $composableBuilder(
      column: $table.aidStationAvailable,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sodiumMg => $composableBuilder(
      column: $table.sodiumMg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caffeineMg => $composableBuilder(
      column: $table.caffeineMg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get potassiumMg => $composableBuilder(
      column: $table.potassiumMg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fatPerServing => $composableBuilder(
      column: $table.fatPerServing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbsPerServing => $composableBuilder(
      column: $table.carbsPerServing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get proteinPerServing => $composableBuilder(
      column: $table.proteinPerServing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caloriesPerServing => $composableBuilder(
      column: $table.caloriesPerServing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fluidMlPerServing => $composableBuilder(
      column: $table.fluidMlPerServing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brandId => $composableBuilder(
      column: $table.brandId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get showInPreferences => $composableBuilder(
      column: $table.showInPreferences,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isElectrolyte => $composableBuilder(
      column: $table.isElectrolyte,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayNamePlural => $composableBuilder(
      column: $table.displayNamePlural,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingDescription => $composableBuilder(
      column: $table.servingDescription,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instructions => $composableBuilder(
      column: $table.instructions,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nutritionalInfo => $composableBuilder(
      column: $table.nutritionalInfo,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingUnit => $composableBuilder(
      column: $table.servingUnit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingUnitPlural => $composableBuilder(
      column: $table.servingUnitPlural,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingQualifier => $composableBuilder(
      column: $table.servingQualifier,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servingSize => $composableBuilder(
      column: $table.servingSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get afterRunSuitable => $composableBuilder(
      column: $table.afterRunSuitable,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purchaseUrl => $composableBuilder(
      column: $table.purchaseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get affiliateSource => $composableBuilder(
      column: $table.affiliateSource,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get preferencePriority => $composableBuilder(
      column: $table.preferencePriority,
      builder: (column) => ColumnOrderings(column));
}

class $$FoodsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodsTableTable> {
  $$FoodsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get imageAddress => $composableBuilder(
      column: $table.imageAddress, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<double> get servingAmount => $composableBuilder(
      column: $table.servingAmount, builder: (column) => column);

  GeneratedColumn<int> get maxServingsBefore => $composableBuilder(
      column: $table.maxServingsBefore, builder: (column) => column);

  GeneratedColumn<int> get maxServingsDuring => $composableBuilder(
      column: $table.maxServingsDuring, builder: (column) => column);

  GeneratedColumn<int> get maxServingsAfter => $composableBuilder(
      column: $table.maxServingsAfter, builder: (column) => column);

  GeneratedColumn<bool> get beforeRunSuitable => $composableBuilder(
      column: $table.beforeRunSuitable, builder: (column) => column);

  GeneratedColumn<bool> get duringRunSuitable => $composableBuilder(
      column: $table.duringRunSuitable, builder: (column) => column);

  GeneratedColumn<bool> get runPortable => $composableBuilder(
      column: $table.runPortable, builder: (column) => column);

  GeneratedColumn<bool> get requiresPreparation => $composableBuilder(
      column: $table.requiresPreparation, builder: (column) => column);

  GeneratedColumn<bool> get aidStationAvailable => $composableBuilder(
      column: $table.aidStationAvailable, builder: (column) => column);

  GeneratedColumn<int> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);

  GeneratedColumn<int> get caffeineMg => $composableBuilder(
      column: $table.caffeineMg, builder: (column) => column);

  GeneratedColumn<int> get potassiumMg => $composableBuilder(
      column: $table.potassiumMg, builder: (column) => column);

  GeneratedColumn<double> get fatPerServing => $composableBuilder(
      column: $table.fatPerServing, builder: (column) => column);

  GeneratedColumn<double> get carbsPerServing => $composableBuilder(
      column: $table.carbsPerServing, builder: (column) => column);

  GeneratedColumn<double> get proteinPerServing => $composableBuilder(
      column: $table.proteinPerServing, builder: (column) => column);

  GeneratedColumn<int> get caloriesPerServing => $composableBuilder(
      column: $table.caloriesPerServing, builder: (column) => column);

  GeneratedColumn<double> get fluidMlPerServing => $composableBuilder(
      column: $table.fluidMlPerServing, builder: (column) => column);

  GeneratedColumn<String> get brandId =>
      $composableBuilder(column: $table.brandId, builder: (column) => column);

  GeneratedColumn<bool> get showInPreferences => $composableBuilder(
      column: $table.showInPreferences, builder: (column) => column);

  GeneratedColumn<bool> get isElectrolyte => $composableBuilder(
      column: $table.isElectrolyte, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get displayNamePlural => $composableBuilder(
      column: $table.displayNamePlural, builder: (column) => column);

  GeneratedColumn<String> get servingDescription => $composableBuilder(
      column: $table.servingDescription, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get instructions => $composableBuilder(
      column: $table.instructions, builder: (column) => column);

  GeneratedColumn<String> get nutritionalInfo => $composableBuilder(
      column: $table.nutritionalInfo, builder: (column) => column);

  GeneratedColumn<String> get servingUnit => $composableBuilder(
      column: $table.servingUnit, builder: (column) => column);

  GeneratedColumn<String> get servingUnitPlural => $composableBuilder(
      column: $table.servingUnitPlural, builder: (column) => column);

  GeneratedColumn<String> get servingQualifier => $composableBuilder(
      column: $table.servingQualifier, builder: (column) => column);

  GeneratedColumn<String> get servingSize => $composableBuilder(
      column: $table.servingSize, builder: (column) => column);

  GeneratedColumn<bool> get afterRunSuitable => $composableBuilder(
      column: $table.afterRunSuitable, builder: (column) => column);

  GeneratedColumn<String> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => column);

  GeneratedColumn<String> get purchaseUrl => $composableBuilder(
      column: $table.purchaseUrl, builder: (column) => column);

  GeneratedColumn<String> get affiliateSource => $composableBuilder(
      column: $table.affiliateSource, builder: (column) => column);

  GeneratedColumn<int> get preferencePriority => $composableBuilder(
      column: $table.preferencePriority, builder: (column) => column);

  Expression<T> foodCategoriesTableRefs<T extends Object>(
      Expression<T> Function($$FoodCategoriesTableTableAnnotationComposer a)
          f) {
    final $$FoodCategoriesTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.foodCategoriesTable,
            getReferencedColumn: (t) => t.foodId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$FoodCategoriesTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.foodCategoriesTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$FoodsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoodsTableTable,
    FoodEntry,
    $$FoodsTableTableFilterComposer,
    $$FoodsTableTableOrderingComposer,
    $$FoodsTableTableAnnotationComposer,
    $$FoodsTableTableCreateCompanionBuilder,
    $$FoodsTableTableUpdateCompanionBuilder,
    (FoodEntry, $$FoodsTableTableReferences),
    FoodEntry,
    PrefetchHooks Function({bool foodCategoriesTableRefs})> {
  $$FoodsTableTableTableManager(_$AppDatabase db, $FoodsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> imageAddress = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<double?> servingAmount = const Value.absent(),
            Value<int?> maxServingsBefore = const Value.absent(),
            Value<int?> maxServingsDuring = const Value.absent(),
            Value<int?> maxServingsAfter = const Value.absent(),
            Value<bool> beforeRunSuitable = const Value.absent(),
            Value<bool> duringRunSuitable = const Value.absent(),
            Value<bool> runPortable = const Value.absent(),
            Value<bool> requiresPreparation = const Value.absent(),
            Value<bool> aidStationAvailable = const Value.absent(),
            Value<int?> sodiumMg = const Value.absent(),
            Value<int?> caffeineMg = const Value.absent(),
            Value<int?> potassiumMg = const Value.absent(),
            Value<double?> fatPerServing = const Value.absent(),
            Value<double?> carbsPerServing = const Value.absent(),
            Value<double?> proteinPerServing = const Value.absent(),
            Value<int?> caloriesPerServing = const Value.absent(),
            Value<double?> fluidMlPerServing = const Value.absent(),
            Value<String?> brandId = const Value.absent(),
            Value<bool> showInPreferences = const Value.absent(),
            Value<bool> isElectrolyte = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> displayNamePlural = const Value.absent(),
            Value<String?> servingDescription = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> instructions = const Value.absent(),
            Value<String?> nutritionalInfo = const Value.absent(),
            Value<String?> servingUnit = const Value.absent(),
            Value<String?> servingUnitPlural = const Value.absent(),
            Value<String?> servingQualifier = const Value.absent(),
            Value<String?> servingSize = const Value.absent(),
            Value<bool?> afterRunSuitable = const Value.absent(),
            Value<String?> productType = const Value.absent(),
            Value<String?> purchaseUrl = const Value.absent(),
            Value<String?> affiliateSource = const Value.absent(),
            Value<int?> preferencePriority = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodsTableCompanion(
            id: id,
            name: name,
            imageAddress: imageAddress,
            createdAt: createdAt,
            servingAmount: servingAmount,
            maxServingsBefore: maxServingsBefore,
            maxServingsDuring: maxServingsDuring,
            maxServingsAfter: maxServingsAfter,
            beforeRunSuitable: beforeRunSuitable,
            duringRunSuitable: duringRunSuitable,
            runPortable: runPortable,
            requiresPreparation: requiresPreparation,
            aidStationAvailable: aidStationAvailable,
            sodiumMg: sodiumMg,
            caffeineMg: caffeineMg,
            potassiumMg: potassiumMg,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing,
            proteinPerServing: proteinPerServing,
            caloriesPerServing: caloriesPerServing,
            fluidMlPerServing: fluidMlPerServing,
            brandId: brandId,
            showInPreferences: showInPreferences,
            isElectrolyte: isElectrolyte,
            displayName: displayName,
            displayNamePlural: displayNamePlural,
            servingDescription: servingDescription,
            description: description,
            instructions: instructions,
            nutritionalInfo: nutritionalInfo,
            servingUnit: servingUnit,
            servingUnitPlural: servingUnitPlural,
            servingQualifier: servingQualifier,
            servingSize: servingSize,
            afterRunSuitable: afterRunSuitable,
            productType: productType,
            purchaseUrl: purchaseUrl,
            affiliateSource: affiliateSource,
            preferencePriority: preferencePriority,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> name = const Value.absent(),
            Value<String?> imageAddress = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<double?> servingAmount = const Value.absent(),
            Value<int?> maxServingsBefore = const Value.absent(),
            Value<int?> maxServingsDuring = const Value.absent(),
            Value<int?> maxServingsAfter = const Value.absent(),
            Value<bool> beforeRunSuitable = const Value.absent(),
            Value<bool> duringRunSuitable = const Value.absent(),
            Value<bool> runPortable = const Value.absent(),
            Value<bool> requiresPreparation = const Value.absent(),
            Value<bool> aidStationAvailable = const Value.absent(),
            Value<int?> sodiumMg = const Value.absent(),
            Value<int?> caffeineMg = const Value.absent(),
            Value<int?> potassiumMg = const Value.absent(),
            Value<double?> fatPerServing = const Value.absent(),
            Value<double?> carbsPerServing = const Value.absent(),
            Value<double?> proteinPerServing = const Value.absent(),
            Value<int?> caloriesPerServing = const Value.absent(),
            Value<double?> fluidMlPerServing = const Value.absent(),
            Value<String?> brandId = const Value.absent(),
            Value<bool> showInPreferences = const Value.absent(),
            Value<bool> isElectrolyte = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> displayNamePlural = const Value.absent(),
            Value<String?> servingDescription = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> instructions = const Value.absent(),
            Value<String?> nutritionalInfo = const Value.absent(),
            Value<String?> servingUnit = const Value.absent(),
            Value<String?> servingUnitPlural = const Value.absent(),
            Value<String?> servingQualifier = const Value.absent(),
            Value<String?> servingSize = const Value.absent(),
            Value<bool?> afterRunSuitable = const Value.absent(),
            Value<String?> productType = const Value.absent(),
            Value<String?> purchaseUrl = const Value.absent(),
            Value<String?> affiliateSource = const Value.absent(),
            Value<int?> preferencePriority = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodsTableCompanion.insert(
            id: id,
            name: name,
            imageAddress: imageAddress,
            createdAt: createdAt,
            servingAmount: servingAmount,
            maxServingsBefore: maxServingsBefore,
            maxServingsDuring: maxServingsDuring,
            maxServingsAfter: maxServingsAfter,
            beforeRunSuitable: beforeRunSuitable,
            duringRunSuitable: duringRunSuitable,
            runPortable: runPortable,
            requiresPreparation: requiresPreparation,
            aidStationAvailable: aidStationAvailable,
            sodiumMg: sodiumMg,
            caffeineMg: caffeineMg,
            potassiumMg: potassiumMg,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing,
            proteinPerServing: proteinPerServing,
            caloriesPerServing: caloriesPerServing,
            fluidMlPerServing: fluidMlPerServing,
            brandId: brandId,
            showInPreferences: showInPreferences,
            isElectrolyte: isElectrolyte,
            displayName: displayName,
            displayNamePlural: displayNamePlural,
            servingDescription: servingDescription,
            description: description,
            instructions: instructions,
            nutritionalInfo: nutritionalInfo,
            servingUnit: servingUnit,
            servingUnitPlural: servingUnitPlural,
            servingQualifier: servingQualifier,
            servingSize: servingSize,
            afterRunSuitable: afterRunSuitable,
            productType: productType,
            purchaseUrl: purchaseUrl,
            affiliateSource: affiliateSource,
            preferencePriority: preferencePriority,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FoodsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({foodCategoriesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (foodCategoriesTableRefs) db.foodCategoriesTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (foodCategoriesTableRefs)
                    await $_getPrefetchedData<FoodEntry, $FoodsTableTable,
                            FoodCategoryEntry>(
                        currentTable: table,
                        referencedTable: $$FoodsTableTableReferences
                            ._foodCategoriesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$FoodsTableTableReferences(db, table, p0)
                                .foodCategoriesTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.foodId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$FoodsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FoodsTableTable,
    FoodEntry,
    $$FoodsTableTableFilterComposer,
    $$FoodsTableTableOrderingComposer,
    $$FoodsTableTableAnnotationComposer,
    $$FoodsTableTableCreateCompanionBuilder,
    $$FoodsTableTableUpdateCompanionBuilder,
    (FoodEntry, $$FoodsTableTableReferences),
    FoodEntry,
    PrefetchHooks Function({bool foodCategoriesTableRefs})>;
typedef $$CategoriesTableTableCreateCompanionBuilder = CategoriesTableCompanion
    Function({
  Value<int> id,
  required String name,
});
typedef $$CategoriesTableTableUpdateCompanionBuilder = CategoriesTableCompanion
    Function({
  Value<int> id,
  Value<String> name,
});

final class $$CategoriesTableTableReferences extends BaseReferences<
    _$AppDatabase, $CategoriesTableTable, CategoryEntry> {
  $$CategoriesTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FoodCategoriesTableTable, List<FoodCategoryEntry>>
      _foodCategoriesTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.foodCategoriesTable,
              aliasName: $_aliasNameGenerator(
                  db.categoriesTable.id, db.foodCategoriesTable.categoryId));

  $$FoodCategoriesTableTableProcessedTableManager get foodCategoriesTableRefs {
    final manager =
        $$FoodCategoriesTableTableTableManager($_db, $_db.foodCategoriesTable)
            .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_foodCategoriesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  Expression<bool> foodCategoriesTableRefs(
      Expression<bool> Function($$FoodCategoriesTableTableFilterComposer f) f) {
    final $$FoodCategoriesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.foodCategoriesTable,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoodCategoriesTableTableFilterComposer(
              $db: $db,
              $table: $db.foodCategoriesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableAnnotationComposer({
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

  Expression<T> foodCategoriesTableRefs<T extends Object>(
      Expression<T> Function($$FoodCategoriesTableTableAnnotationComposer a)
          f) {
    final $$FoodCategoriesTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.foodCategoriesTable,
            getReferencedColumn: (t) => t.categoryId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$FoodCategoriesTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.foodCategoriesTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$CategoriesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTableTable,
    CategoryEntry,
    $$CategoriesTableTableFilterComposer,
    $$CategoriesTableTableOrderingComposer,
    $$CategoriesTableTableAnnotationComposer,
    $$CategoriesTableTableCreateCompanionBuilder,
    $$CategoriesTableTableUpdateCompanionBuilder,
    (CategoryEntry, $$CategoriesTableTableReferences),
    CategoryEntry,
    PrefetchHooks Function({bool foodCategoriesTableRefs})> {
  $$CategoriesTableTableTableManager(
      _$AppDatabase db, $CategoriesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) =>
              CategoriesTableCompanion(
            id: id,
            name: name,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) =>
              CategoriesTableCompanion.insert(
            id: id,
            name: name,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CategoriesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({foodCategoriesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (foodCategoriesTableRefs) db.foodCategoriesTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (foodCategoriesTableRefs)
                    await $_getPrefetchedData<CategoryEntry,
                            $CategoriesTableTable, FoodCategoryEntry>(
                        currentTable: table,
                        referencedTable: $$CategoriesTableTableReferences
                            ._foodCategoriesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableTableReferences(db, table, p0)
                                .foodCategoriesTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CategoriesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTableTable,
    CategoryEntry,
    $$CategoriesTableTableFilterComposer,
    $$CategoriesTableTableOrderingComposer,
    $$CategoriesTableTableAnnotationComposer,
    $$CategoriesTableTableCreateCompanionBuilder,
    $$CategoriesTableTableUpdateCompanionBuilder,
    (CategoryEntry, $$CategoriesTableTableReferences),
    CategoryEntry,
    PrefetchHooks Function({bool foodCategoriesTableRefs})>;
typedef $$FoodCategoriesTableTableCreateCompanionBuilder
    = FoodCategoriesTableCompanion Function({
  required String foodId,
  required int categoryId,
  Value<int> rowid,
});
typedef $$FoodCategoriesTableTableUpdateCompanionBuilder
    = FoodCategoriesTableCompanion Function({
  Value<String> foodId,
  Value<int> categoryId,
  Value<int> rowid,
});

final class $$FoodCategoriesTableTableReferences extends BaseReferences<
    _$AppDatabase, $FoodCategoriesTableTable, FoodCategoryEntry> {
  $$FoodCategoriesTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $FoodsTableTable _foodIdTable(_$AppDatabase db) =>
      db.foodsTable.createAlias($_aliasNameGenerator(
          db.foodCategoriesTable.foodId, db.foodsTable.id));

  $$FoodsTableTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<String>('food_id')!;

    final manager = $$FoodsTableTableTableManager($_db, $_db.foodsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $CategoriesTableTable _categoryIdTable(_$AppDatabase db) =>
      db.categoriesTable.createAlias($_aliasNameGenerator(
          db.foodCategoriesTable.categoryId, db.categoriesTable.id));

  $$CategoriesTableTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager =
        $$CategoriesTableTableTableManager($_db, $_db.categoriesTable)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FoodCategoriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FoodCategoriesTableTable> {
  $$FoodCategoriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FoodsTableTableFilterComposer get foodId {
    final $$FoodsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.foodId,
        referencedTable: $db.foodsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoodsTableTableFilterComposer(
              $db: $db,
              $table: $db.foodsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CategoriesTableTableFilterComposer get categoryId {
    final $$CategoriesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categoriesTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableTableFilterComposer(
              $db: $db,
              $table: $db.categoriesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FoodCategoriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodCategoriesTableTable> {
  $$FoodCategoriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FoodsTableTableOrderingComposer get foodId {
    final $$FoodsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.foodId,
        referencedTable: $db.foodsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoodsTableTableOrderingComposer(
              $db: $db,
              $table: $db.foodsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CategoriesTableTableOrderingComposer get categoryId {
    final $$CategoriesTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categoriesTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableTableOrderingComposer(
              $db: $db,
              $table: $db.categoriesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FoodCategoriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodCategoriesTableTable> {
  $$FoodCategoriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FoodsTableTableAnnotationComposer get foodId {
    final $$FoodsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.foodId,
        referencedTable: $db.foodsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoodsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.foodsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CategoriesTableTableAnnotationComposer get categoryId {
    final $$CategoriesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categoriesTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.categoriesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FoodCategoriesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoodCategoriesTableTable,
    FoodCategoryEntry,
    $$FoodCategoriesTableTableFilterComposer,
    $$FoodCategoriesTableTableOrderingComposer,
    $$FoodCategoriesTableTableAnnotationComposer,
    $$FoodCategoriesTableTableCreateCompanionBuilder,
    $$FoodCategoriesTableTableUpdateCompanionBuilder,
    (FoodCategoryEntry, $$FoodCategoriesTableTableReferences),
    FoodCategoryEntry,
    PrefetchHooks Function({bool foodId, bool categoryId})> {
  $$FoodCategoriesTableTableTableManager(
      _$AppDatabase db, $FoodCategoriesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodCategoriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodCategoriesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodCategoriesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> foodId = const Value.absent(),
            Value<int> categoryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodCategoriesTableCompanion(
            foodId: foodId,
            categoryId: categoryId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String foodId,
            required int categoryId,
            Value<int> rowid = const Value.absent(),
          }) =>
              FoodCategoriesTableCompanion.insert(
            foodId: foodId,
            categoryId: categoryId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FoodCategoriesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({foodId = false, categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (foodId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.foodId,
                    referencedTable:
                        $$FoodCategoriesTableTableReferences._foodIdTable(db),
                    referencedColumn: $$FoodCategoriesTableTableReferences
                        ._foodIdTable(db)
                        .id,
                  ) as T;
                }
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable: $$FoodCategoriesTableTableReferences
                        ._categoryIdTable(db),
                    referencedColumn: $$FoodCategoriesTableTableReferences
                        ._categoryIdTable(db)
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
        ));
}

typedef $$FoodCategoriesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FoodCategoriesTableTable,
    FoodCategoryEntry,
    $$FoodCategoriesTableTableFilterComposer,
    $$FoodCategoriesTableTableOrderingComposer,
    $$FoodCategoriesTableTableAnnotationComposer,
    $$FoodCategoriesTableTableCreateCompanionBuilder,
    $$FoodCategoriesTableTableUpdateCompanionBuilder,
    (FoodCategoryEntry, $$FoodCategoriesTableTableReferences),
    FoodCategoryEntry,
    PrefetchHooks Function({bool foodId, bool categoryId})>;
typedef $$BrandsTableTableCreateCompanionBuilder = BrandsTableCompanion
    Function({
  required String id,
  required String name,
  Value<String?> websiteUrl,
  Value<String?> affiliateProgramUrl,
  Value<String?> affiliateNetwork,
  Value<String?> defaultAffiliateUrl,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $$BrandsTableTableUpdateCompanionBuilder = BrandsTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String?> websiteUrl,
  Value<String?> affiliateProgramUrl,
  Value<String?> affiliateNetwork,
  Value<String?> defaultAffiliateUrl,
  Value<String?> notes,
  Value<int> rowid,
});

class $$BrandsTableTableFilterComposer
    extends Composer<_$AppDatabase, $BrandsTableTable> {
  $$BrandsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get websiteUrl => $composableBuilder(
      column: $table.websiteUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get affiliateProgramUrl => $composableBuilder(
      column: $table.affiliateProgramUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get affiliateNetwork => $composableBuilder(
      column: $table.affiliateNetwork,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultAffiliateUrl => $composableBuilder(
      column: $table.defaultAffiliateUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$BrandsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BrandsTableTable> {
  $$BrandsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get websiteUrl => $composableBuilder(
      column: $table.websiteUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get affiliateProgramUrl => $composableBuilder(
      column: $table.affiliateProgramUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get affiliateNetwork => $composableBuilder(
      column: $table.affiliateNetwork,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultAffiliateUrl => $composableBuilder(
      column: $table.defaultAffiliateUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$BrandsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrandsTableTable> {
  $$BrandsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get websiteUrl => $composableBuilder(
      column: $table.websiteUrl, builder: (column) => column);

  GeneratedColumn<String> get affiliateProgramUrl => $composableBuilder(
      column: $table.affiliateProgramUrl, builder: (column) => column);

  GeneratedColumn<String> get affiliateNetwork => $composableBuilder(
      column: $table.affiliateNetwork, builder: (column) => column);

  GeneratedColumn<String> get defaultAffiliateUrl => $composableBuilder(
      column: $table.defaultAffiliateUrl, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$BrandsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BrandsTableTable,
    BrandEntry,
    $$BrandsTableTableFilterComposer,
    $$BrandsTableTableOrderingComposer,
    $$BrandsTableTableAnnotationComposer,
    $$BrandsTableTableCreateCompanionBuilder,
    $$BrandsTableTableUpdateCompanionBuilder,
    (BrandEntry, BaseReferences<_$AppDatabase, $BrandsTableTable, BrandEntry>),
    BrandEntry,
    PrefetchHooks Function()> {
  $$BrandsTableTableTableManager(_$AppDatabase db, $BrandsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrandsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrandsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrandsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> websiteUrl = const Value.absent(),
            Value<String?> affiliateProgramUrl = const Value.absent(),
            Value<String?> affiliateNetwork = const Value.absent(),
            Value<String?> defaultAffiliateUrl = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BrandsTableCompanion(
            id: id,
            name: name,
            websiteUrl: websiteUrl,
            affiliateProgramUrl: affiliateProgramUrl,
            affiliateNetwork: affiliateNetwork,
            defaultAffiliateUrl: defaultAffiliateUrl,
            notes: notes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> websiteUrl = const Value.absent(),
            Value<String?> affiliateProgramUrl = const Value.absent(),
            Value<String?> affiliateNetwork = const Value.absent(),
            Value<String?> defaultAffiliateUrl = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BrandsTableCompanion.insert(
            id: id,
            name: name,
            websiteUrl: websiteUrl,
            affiliateProgramUrl: affiliateProgramUrl,
            affiliateNetwork: affiliateNetwork,
            defaultAffiliateUrl: defaultAffiliateUrl,
            notes: notes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BrandsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BrandsTableTable,
    BrandEntry,
    $$BrandsTableTableFilterComposer,
    $$BrandsTableTableOrderingComposer,
    $$BrandsTableTableAnnotationComposer,
    $$BrandsTableTableCreateCompanionBuilder,
    $$BrandsTableTableUpdateCompanionBuilder,
    (BrandEntry, BaseReferences<_$AppDatabase, $BrandsTableTable, BrandEntry>),
    BrandEntry,
    PrefetchHooks Function()>;
typedef $$ProductTypesTableTableCreateCompanionBuilder
    = ProductTypesTableCompanion Function({
  required String id,
  required String code,
  required String name,
  required String namePlural,
  Value<int?> sortOrder,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ProductTypesTableTableUpdateCompanionBuilder
    = ProductTypesTableCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<String> namePlural,
  Value<int?> sortOrder,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProductTypesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProductTypesTableTable> {
  $$ProductTypesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get namePlural => $composableBuilder(
      column: $table.namePlural, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ProductTypesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductTypesTableTable> {
  $$ProductTypesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get namePlural => $composableBuilder(
      column: $table.namePlural, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ProductTypesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductTypesTableTable> {
  $$ProductTypesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get namePlural => $composableBuilder(
      column: $table.namePlural, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProductTypesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductTypesTableTable,
    ProductTypeEntry,
    $$ProductTypesTableTableFilterComposer,
    $$ProductTypesTableTableOrderingComposer,
    $$ProductTypesTableTableAnnotationComposer,
    $$ProductTypesTableTableCreateCompanionBuilder,
    $$ProductTypesTableTableUpdateCompanionBuilder,
    (
      ProductTypeEntry,
      BaseReferences<_$AppDatabase, $ProductTypesTableTable, ProductTypeEntry>
    ),
    ProductTypeEntry,
    PrefetchHooks Function()> {
  $$ProductTypesTableTableTableManager(
      _$AppDatabase db, $ProductTypesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductTypesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductTypesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductTypesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> namePlural = const Value.absent(),
            Value<int?> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductTypesTableCompanion(
            id: id,
            code: code,
            name: name,
            namePlural: namePlural,
            sortOrder: sortOrder,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String code,
            required String name,
            required String namePlural,
            Value<int?> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductTypesTableCompanion.insert(
            id: id,
            code: code,
            name: name,
            namePlural: namePlural,
            sortOrder: sortOrder,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProductTypesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductTypesTableTable,
    ProductTypeEntry,
    $$ProductTypesTableTableFilterComposer,
    $$ProductTypesTableTableOrderingComposer,
    $$ProductTypesTableTableAnnotationComposer,
    $$ProductTypesTableTableCreateCompanionBuilder,
    $$ProductTypesTableTableUpdateCompanionBuilder,
    (
      ProductTypeEntry,
      BaseReferences<_$AppDatabase, $ProductTypesTableTable, ProductTypeEntry>
    ),
    ProductTypeEntry,
    PrefetchHooks Function()>;
typedef $$AppContentTableTableCreateCompanionBuilder = AppContentTableCompanion
    Function({
  required String id,
  Value<int> version,
  Value<String> environment,
  Value<String> locale,
  required String content,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> createdBy,
  Value<String?> updatedBy,
  Value<DateTime?> lastSyncAt,
  Value<bool> isCached,
  Value<int> rowid,
});
typedef $$AppContentTableTableUpdateCompanionBuilder = AppContentTableCompanion
    Function({
  Value<String> id,
  Value<int> version,
  Value<String> environment,
  Value<String> locale,
  Value<String> content,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> createdBy,
  Value<String?> updatedBy,
  Value<DateTime?> lastSyncAt,
  Value<bool> isCached,
  Value<int> rowid,
});

class $$AppContentTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppContentTableTable> {
  $$AppContentTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locale => $composableBuilder(
      column: $table.locale, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedBy => $composableBuilder(
      column: $table.updatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCached => $composableBuilder(
      column: $table.isCached, builder: (column) => ColumnFilters(column));
}

class $$AppContentTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppContentTableTable> {
  $$AppContentTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locale => $composableBuilder(
      column: $table.locale, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedBy => $composableBuilder(
      column: $table.updatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCached => $composableBuilder(
      column: $table.isCached, builder: (column) => ColumnOrderings(column));
}

class $$AppContentTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppContentTableTable> {
  $$AppContentTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => column);

  GeneratedColumn<bool> get isCached =>
      $composableBuilder(column: $table.isCached, builder: (column) => column);
}

class $$AppContentTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppContentTableTable,
    AppContentEntry,
    $$AppContentTableTableFilterComposer,
    $$AppContentTableTableOrderingComposer,
    $$AppContentTableTableAnnotationComposer,
    $$AppContentTableTableCreateCompanionBuilder,
    $$AppContentTableTableUpdateCompanionBuilder,
    (
      AppContentEntry,
      BaseReferences<_$AppDatabase, $AppContentTableTable, AppContentEntry>
    ),
    AppContentEntry,
    PrefetchHooks Function()> {
  $$AppContentTableTableTableManager(
      _$AppDatabase db, $AppContentTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> environment = const Value.absent(),
            Value<String> locale = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String?> updatedBy = const Value.absent(),
            Value<DateTime?> lastSyncAt = const Value.absent(),
            Value<bool> isCached = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentTableCompanion(
            id: id,
            version: version,
            environment: environment,
            locale: locale,
            content: content,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            updatedBy: updatedBy,
            lastSyncAt: lastSyncAt,
            isCached: isCached,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<int> version = const Value.absent(),
            Value<String> environment = const Value.absent(),
            Value<String> locale = const Value.absent(),
            required String content,
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String?> updatedBy = const Value.absent(),
            Value<DateTime?> lastSyncAt = const Value.absent(),
            Value<bool> isCached = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppContentTableCompanion.insert(
            id: id,
            version: version,
            environment: environment,
            locale: locale,
            content: content,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            updatedBy: updatedBy,
            lastSyncAt: lastSyncAt,
            isCached: isCached,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppContentTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppContentTableTable,
    AppContentEntry,
    $$AppContentTableTableFilterComposer,
    $$AppContentTableTableOrderingComposer,
    $$AppContentTableTableAnnotationComposer,
    $$AppContentTableTableCreateCompanionBuilder,
    $$AppContentTableTableUpdateCompanionBuilder,
    (
      AppContentEntry,
      BaseReferences<_$AppDatabase, $AppContentTableTable, AppContentEntry>
    ),
    AppContentEntry,
    PrefetchHooks Function()>;
typedef $$WorkoutNotesTableTableCreateCompanionBuilder
    = WorkoutNotesTableCompanion Function({
  required String id,
  required String userId,
  Value<String?> planId,
  required String noteText,
  Value<int?> rating,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$WorkoutNotesTableTableUpdateCompanionBuilder
    = WorkoutNotesTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String?> planId,
  Value<String> noteText,
  Value<int?> rating,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$WorkoutNotesTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutNotesTableTable> {
  $$WorkoutNotesTableTableFilterComposer({
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

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$WorkoutNotesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutNotesTableTable> {
  $$WorkoutNotesTableTableOrderingComposer({
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

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutNotesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutNotesTableTable> {
  $$WorkoutNotesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkoutNotesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutNotesTableTable,
    WorkoutNoteEntry,
    $$WorkoutNotesTableTableFilterComposer,
    $$WorkoutNotesTableTableOrderingComposer,
    $$WorkoutNotesTableTableAnnotationComposer,
    $$WorkoutNotesTableTableCreateCompanionBuilder,
    $$WorkoutNotesTableTableUpdateCompanionBuilder,
    (
      WorkoutNoteEntry,
      BaseReferences<_$AppDatabase, $WorkoutNotesTableTable, WorkoutNoteEntry>
    ),
    WorkoutNoteEntry,
    PrefetchHooks Function()> {
  $$WorkoutNotesTableTableTableManager(
      _$AppDatabase db, $WorkoutNotesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutNotesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutNotesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutNotesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String?> planId = const Value.absent(),
            Value<String> noteText = const Value.absent(),
            Value<int?> rating = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutNotesTableCompanion(
            id: id,
            userId: userId,
            planId: planId,
            noteText: noteText,
            rating: rating,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            Value<String?> planId = const Value.absent(),
            required String noteText,
            Value<int?> rating = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutNotesTableCompanion.insert(
            id: id,
            userId: userId,
            planId: planId,
            noteText: noteText,
            rating: rating,
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

typedef $$WorkoutNotesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkoutNotesTableTable,
    WorkoutNoteEntry,
    $$WorkoutNotesTableTableFilterComposer,
    $$WorkoutNotesTableTableOrderingComposer,
    $$WorkoutNotesTableTableAnnotationComposer,
    $$WorkoutNotesTableTableCreateCompanionBuilder,
    $$WorkoutNotesTableTableUpdateCompanionBuilder,
    (
      WorkoutNoteEntry,
      BaseReferences<_$AppDatabase, $WorkoutNotesTableTable, WorkoutNoteEntry>
    ),
    WorkoutNoteEntry,
    PrefetchHooks Function()>;
typedef $$CarbLoadingTableTableCreateCompanionBuilder
    = CarbLoadingTableCompanion Function({
  required String id,
  required String userId,
  required DateTime raceDate,
  required String raceDistance,
  required String trainingVolume,
  required String planData,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> isActive,
  Value<int> rowid,
});
typedef $$CarbLoadingTableTableUpdateCompanionBuilder
    = CarbLoadingTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<DateTime> raceDate,
  Value<String> raceDistance,
  Value<String> trainingVolume,
  Value<String> planData,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isActive,
  Value<int> rowid,
});

class $$CarbLoadingTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingTableTable> {
  $$CarbLoadingTableTableFilterComposer({
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

  ColumnFilters<DateTime> get raceDate => $composableBuilder(
      column: $table.raceDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get raceDistance => $composableBuilder(
      column: $table.raceDistance, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trainingVolume => $composableBuilder(
      column: $table.trainingVolume,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planData => $composableBuilder(
      column: $table.planData, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));
}

class $$CarbLoadingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingTableTable> {
  $$CarbLoadingTableTableOrderingComposer({
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

  ColumnOrderings<DateTime> get raceDate => $composableBuilder(
      column: $table.raceDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get raceDistance => $composableBuilder(
      column: $table.raceDistance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trainingVolume => $composableBuilder(
      column: $table.trainingVolume,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planData => $composableBuilder(
      column: $table.planData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$CarbLoadingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingTableTable> {
  $$CarbLoadingTableTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get raceDate =>
      $composableBuilder(column: $table.raceDate, builder: (column) => column);

  GeneratedColumn<String> get raceDistance => $composableBuilder(
      column: $table.raceDistance, builder: (column) => column);

  GeneratedColumn<String> get trainingVolume => $composableBuilder(
      column: $table.trainingVolume, builder: (column) => column);

  GeneratedColumn<String> get planData =>
      $composableBuilder(column: $table.planData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$CarbLoadingTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CarbLoadingTableTable,
    CarbLoadingEntry,
    $$CarbLoadingTableTableFilterComposer,
    $$CarbLoadingTableTableOrderingComposer,
    $$CarbLoadingTableTableAnnotationComposer,
    $$CarbLoadingTableTableCreateCompanionBuilder,
    $$CarbLoadingTableTableUpdateCompanionBuilder,
    (
      CarbLoadingEntry,
      BaseReferences<_$AppDatabase, $CarbLoadingTableTable, CarbLoadingEntry>
    ),
    CarbLoadingEntry,
    PrefetchHooks Function()> {
  $$CarbLoadingTableTableTableManager(
      _$AppDatabase db, $CarbLoadingTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarbLoadingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarbLoadingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime> raceDate = const Value.absent(),
            Value<String> raceDistance = const Value.absent(),
            Value<String> trainingVolume = const Value.absent(),
            Value<String> planData = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CarbLoadingTableCompanion(
            id: id,
            userId: userId,
            raceDate: raceDate,
            raceDistance: raceDistance,
            trainingVolume: trainingVolume,
            planData: planData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required DateTime raceDate,
            required String raceDistance,
            required String trainingVolume,
            required String planData,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CarbLoadingTableCompanion.insert(
            id: id,
            userId: userId,
            raceDate: raceDate,
            raceDistance: raceDistance,
            trainingVolume: trainingVolume,
            planData: planData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CarbLoadingTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CarbLoadingTableTable,
    CarbLoadingEntry,
    $$CarbLoadingTableTableFilterComposer,
    $$CarbLoadingTableTableOrderingComposer,
    $$CarbLoadingTableTableAnnotationComposer,
    $$CarbLoadingTableTableCreateCompanionBuilder,
    $$CarbLoadingTableTableUpdateCompanionBuilder,
    (
      CarbLoadingEntry,
      BaseReferences<_$AppDatabase, $CarbLoadingTableTable, CarbLoadingEntry>
    ),
    CarbLoadingEntry,
    PrefetchHooks Function()>;
typedef $$CarbLoadingSimpleTableTableCreateCompanionBuilder
    = CarbLoadingSimpleTableCompanion Function({
  required String id,
  required String userId,
  required DateTime raceDate,
  required String raceDistance,
  required String trainingVolume,
  required int dailyCarbTargetG,
  required int dailyServingsTarget,
  required double bodyWeightKg,
  required double carbsPerKgTarget,
  required String daySelectionsJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> isActive,
  Value<int> rowid,
});
typedef $$CarbLoadingSimpleTableTableUpdateCompanionBuilder
    = CarbLoadingSimpleTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<DateTime> raceDate,
  Value<String> raceDistance,
  Value<String> trainingVolume,
  Value<int> dailyCarbTargetG,
  Value<int> dailyServingsTarget,
  Value<double> bodyWeightKg,
  Value<double> carbsPerKgTarget,
  Value<String> daySelectionsJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isActive,
  Value<int> rowid,
});

class $$CarbLoadingSimpleTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingSimpleTableTable> {
  $$CarbLoadingSimpleTableTableFilterComposer({
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

  ColumnFilters<DateTime> get raceDate => $composableBuilder(
      column: $table.raceDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get raceDistance => $composableBuilder(
      column: $table.raceDistance, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trainingVolume => $composableBuilder(
      column: $table.trainingVolume,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyCarbTargetG => $composableBuilder(
      column: $table.dailyCarbTargetG,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyServingsTarget => $composableBuilder(
      column: $table.dailyServingsTarget,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get bodyWeightKg => $composableBuilder(
      column: $table.bodyWeightKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbsPerKgTarget => $composableBuilder(
      column: $table.carbsPerKgTarget,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get daySelectionsJson => $composableBuilder(
      column: $table.daySelectionsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));
}

class $$CarbLoadingSimpleTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingSimpleTableTable> {
  $$CarbLoadingSimpleTableTableOrderingComposer({
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

  ColumnOrderings<DateTime> get raceDate => $composableBuilder(
      column: $table.raceDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get raceDistance => $composableBuilder(
      column: $table.raceDistance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trainingVolume => $composableBuilder(
      column: $table.trainingVolume,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyCarbTargetG => $composableBuilder(
      column: $table.dailyCarbTargetG,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyServingsTarget => $composableBuilder(
      column: $table.dailyServingsTarget,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get bodyWeightKg => $composableBuilder(
      column: $table.bodyWeightKg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbsPerKgTarget => $composableBuilder(
      column: $table.carbsPerKgTarget,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get daySelectionsJson => $composableBuilder(
      column: $table.daySelectionsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$CarbLoadingSimpleTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingSimpleTableTable> {
  $$CarbLoadingSimpleTableTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get raceDate =>
      $composableBuilder(column: $table.raceDate, builder: (column) => column);

  GeneratedColumn<String> get raceDistance => $composableBuilder(
      column: $table.raceDistance, builder: (column) => column);

  GeneratedColumn<String> get trainingVolume => $composableBuilder(
      column: $table.trainingVolume, builder: (column) => column);

  GeneratedColumn<int> get dailyCarbTargetG => $composableBuilder(
      column: $table.dailyCarbTargetG, builder: (column) => column);

  GeneratedColumn<int> get dailyServingsTarget => $composableBuilder(
      column: $table.dailyServingsTarget, builder: (column) => column);

  GeneratedColumn<double> get bodyWeightKg => $composableBuilder(
      column: $table.bodyWeightKg, builder: (column) => column);

  GeneratedColumn<double> get carbsPerKgTarget => $composableBuilder(
      column: $table.carbsPerKgTarget, builder: (column) => column);

  GeneratedColumn<String> get daySelectionsJson => $composableBuilder(
      column: $table.daySelectionsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$CarbLoadingSimpleTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CarbLoadingSimpleTableTable,
    CarbLoadingSimpleEntry,
    $$CarbLoadingSimpleTableTableFilterComposer,
    $$CarbLoadingSimpleTableTableOrderingComposer,
    $$CarbLoadingSimpleTableTableAnnotationComposer,
    $$CarbLoadingSimpleTableTableCreateCompanionBuilder,
    $$CarbLoadingSimpleTableTableUpdateCompanionBuilder,
    (
      CarbLoadingSimpleEntry,
      BaseReferences<_$AppDatabase, $CarbLoadingSimpleTableTable,
          CarbLoadingSimpleEntry>
    ),
    CarbLoadingSimpleEntry,
    PrefetchHooks Function()> {
  $$CarbLoadingSimpleTableTableTableManager(
      _$AppDatabase db, $CarbLoadingSimpleTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingSimpleTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$CarbLoadingSimpleTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarbLoadingSimpleTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime> raceDate = const Value.absent(),
            Value<String> raceDistance = const Value.absent(),
            Value<String> trainingVolume = const Value.absent(),
            Value<int> dailyCarbTargetG = const Value.absent(),
            Value<int> dailyServingsTarget = const Value.absent(),
            Value<double> bodyWeightKg = const Value.absent(),
            Value<double> carbsPerKgTarget = const Value.absent(),
            Value<String> daySelectionsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CarbLoadingSimpleTableCompanion(
            id: id,
            userId: userId,
            raceDate: raceDate,
            raceDistance: raceDistance,
            trainingVolume: trainingVolume,
            dailyCarbTargetG: dailyCarbTargetG,
            dailyServingsTarget: dailyServingsTarget,
            bodyWeightKg: bodyWeightKg,
            carbsPerKgTarget: carbsPerKgTarget,
            daySelectionsJson: daySelectionsJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required DateTime raceDate,
            required String raceDistance,
            required String trainingVolume,
            required int dailyCarbTargetG,
            required int dailyServingsTarget,
            required double bodyWeightKg,
            required double carbsPerKgTarget,
            required String daySelectionsJson,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CarbLoadingSimpleTableCompanion.insert(
            id: id,
            userId: userId,
            raceDate: raceDate,
            raceDistance: raceDistance,
            trainingVolume: trainingVolume,
            dailyCarbTargetG: dailyCarbTargetG,
            dailyServingsTarget: dailyServingsTarget,
            bodyWeightKg: bodyWeightKg,
            carbsPerKgTarget: carbsPerKgTarget,
            daySelectionsJson: daySelectionsJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CarbLoadingSimpleTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $CarbLoadingSimpleTableTable,
        CarbLoadingSimpleEntry,
        $$CarbLoadingSimpleTableTableFilterComposer,
        $$CarbLoadingSimpleTableTableOrderingComposer,
        $$CarbLoadingSimpleTableTableAnnotationComposer,
        $$CarbLoadingSimpleTableTableCreateCompanionBuilder,
        $$CarbLoadingSimpleTableTableUpdateCompanionBuilder,
        (
          CarbLoadingSimpleEntry,
          BaseReferences<_$AppDatabase, $CarbLoadingSimpleTableTable,
              CarbLoadingSimpleEntry>
        ),
        CarbLoadingSimpleEntry,
        PrefetchHooks Function()>;
typedef $$EdgeFunctionsTableTableCreateCompanionBuilder
    = EdgeFunctionsTableCompanion Function({
  required String id,
  required String name,
  required String code,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$EdgeFunctionsTableTableUpdateCompanionBuilder
    = EdgeFunctionsTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> code,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$EdgeFunctionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EdgeFunctionsTableTable> {
  $$EdgeFunctionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$EdgeFunctionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EdgeFunctionsTableTable> {
  $$EdgeFunctionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$EdgeFunctionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EdgeFunctionsTableTable> {
  $$EdgeFunctionsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EdgeFunctionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EdgeFunctionsTableTable,
    EdgeFunctionEntry,
    $$EdgeFunctionsTableTableFilterComposer,
    $$EdgeFunctionsTableTableOrderingComposer,
    $$EdgeFunctionsTableTableAnnotationComposer,
    $$EdgeFunctionsTableTableCreateCompanionBuilder,
    $$EdgeFunctionsTableTableUpdateCompanionBuilder,
    (
      EdgeFunctionEntry,
      BaseReferences<_$AppDatabase, $EdgeFunctionsTableTable, EdgeFunctionEntry>
    ),
    EdgeFunctionEntry,
    PrefetchHooks Function()> {
  $$EdgeFunctionsTableTableTableManager(
      _$AppDatabase db, $EdgeFunctionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EdgeFunctionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EdgeFunctionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EdgeFunctionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EdgeFunctionsTableCompanion(
            id: id,
            name: name,
            code: code,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String code,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EdgeFunctionsTableCompanion.insert(
            id: id,
            name: name,
            code: code,
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

typedef $$EdgeFunctionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EdgeFunctionsTableTable,
    EdgeFunctionEntry,
    $$EdgeFunctionsTableTableFilterComposer,
    $$EdgeFunctionsTableTableOrderingComposer,
    $$EdgeFunctionsTableTableAnnotationComposer,
    $$EdgeFunctionsTableTableCreateCompanionBuilder,
    $$EdgeFunctionsTableTableUpdateCompanionBuilder,
    (
      EdgeFunctionEntry,
      BaseReferences<_$AppDatabase, $EdgeFunctionsTableTable, EdgeFunctionEntry>
    ),
    EdgeFunctionEntry,
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
  $$FoodsTableTableTableManager get foodsTable =>
      $$FoodsTableTableTableManager(_db, _db.foodsTable);
  $$CategoriesTableTableTableManager get categoriesTable =>
      $$CategoriesTableTableTableManager(_db, _db.categoriesTable);
  $$FoodCategoriesTableTableTableManager get foodCategoriesTable =>
      $$FoodCategoriesTableTableTableManager(_db, _db.foodCategoriesTable);
  $$BrandsTableTableTableManager get brandsTable =>
      $$BrandsTableTableTableManager(_db, _db.brandsTable);
  $$ProductTypesTableTableTableManager get productTypesTable =>
      $$ProductTypesTableTableTableManager(_db, _db.productTypesTable);
  $$AppContentTableTableTableManager get appContentTable =>
      $$AppContentTableTableTableManager(_db, _db.appContentTable);
  $$WorkoutNotesTableTableTableManager get workoutNotesTable =>
      $$WorkoutNotesTableTableTableManager(_db, _db.workoutNotesTable);
  $$CarbLoadingTableTableTableManager get carbLoadingTable =>
      $$CarbLoadingTableTableTableManager(_db, _db.carbLoadingTable);
  $$CarbLoadingSimpleTableTableTableManager get carbLoadingSimpleTable =>
      $$CarbLoadingSimpleTableTableTableManager(
          _db, _db.carbLoadingSimpleTable);
  $$EdgeFunctionsTableTableTableManager get edgeFunctionsTable =>
      $$EdgeFunctionsTableTableTableManager(_db, _db.edgeFunctionsTable);
}
