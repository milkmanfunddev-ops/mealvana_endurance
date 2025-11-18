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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _authUserIdMeta = const VerificationMeta(
    'authUserId',
  );
  @override
  late final GeneratedColumn<String> authUserId = GeneratedColumn<String>(
    'auth_user_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authProviderMeta = const VerificationMeta(
    'authProvider',
  );
  @override
  late final GeneratedColumn<String> authProvider = GeneratedColumn<String>(
    'auth_provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('anonymous'),
  );
  static const VerificationMeta _isAnonymousMeta = const VerificationMeta(
    'isAnonymous',
  );
  @override
  late final GeneratedColumn<bool> isAnonymous = GeneratedColumn<bool>(
    'is_anonymous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_anonymous" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthdayMeta = const VerificationMeta(
    'birthday',
  );
  @override
  late final GeneratedColumn<DateTime> birthday = GeneratedColumn<DateTime>(
    'birthday',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightFeetMeta = const VerificationMeta(
    'heightFeet',
  );
  @override
  late final GeneratedColumn<int> heightFeet = GeneratedColumn<int>(
    'height_feet',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightInchesMeta = const VerificationMeta(
    'heightInches',
  );
  @override
  late final GeneratedColumn<int> heightInches = GeneratedColumn<int>(
    'height_inches',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightPoundsMeta = const VerificationMeta(
    'weightPounds',
  );
  @override
  late final GeneratedColumn<double> weightPounds = GeneratedColumn<double>(
    'weight_pounds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runsWithWaterBottleMeta =
      const VerificationMeta('runsWithWaterBottle');
  @override
  late final GeneratedColumn<bool> runsWithWaterBottle = GeneratedColumn<bool>(
    'runs_with_water_bottle',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("runs_with_water_bottle" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  foodPreferences =
      GeneratedColumn<String>(
        'food_preferences',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      ).withConverter<Map<String, dynamic>>(
        $UserProfilesTableTable.$converterfoodPreferences,
      );
  static const VerificationMeta _preferredDistanceUnitMeta =
      const VerificationMeta('preferredDistanceUnit');
  @override
  late final GeneratedColumn<String> preferredDistanceUnit =
      GeneratedColumn<String>(
        'preferred_distance_unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('miles'),
      );
  static const VerificationMeta _preferredPaceUnitMeta = const VerificationMeta(
    'preferredPaceUnit',
  );
  @override
  late final GeneratedColumn<String> preferredPaceUnit =
      GeneratedColumn<String>(
        'preferred_pace_unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('min_per_mile'),
      );
  static const VerificationMeta _gutTrainingLevelMeta = const VerificationMeta(
    'gutTrainingLevel',
  );
  @override
  late final GeneratedColumn<String> gutTrainingLevel = GeneratedColumn<String>(
    'gut_training_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('moderate'),
  );
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
    'onboarding_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastActiveAtMeta = const VerificationMeta(
    'lastActiveAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastActiveAt = GeneratedColumn<DateTime>(
    'last_active_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _defaultReminderDayMeta =
      const VerificationMeta('defaultReminderDay');
  @override
  late final GeneratedColumn<int> defaultReminderDay = GeneratedColumn<int>(
    'default_reminder_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _defaultReminderHourMeta =
      const VerificationMeta('defaultReminderHour');
  @override
  late final GeneratedColumn<int> defaultReminderHour = GeneratedColumn<int>(
    'default_reminder_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(17),
  );
  static const VerificationMeta _defaultReminderMinuteMeta =
      const VerificationMeta('defaultReminderMinute');
  @override
  late final GeneratedColumn<int> defaultReminderMinute = GeneratedColumn<int>(
    'default_reminder_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _defaultReminderRecurringMeta =
      const VerificationMeta('defaultReminderRecurring');
  @override
  late final GeneratedColumn<bool> defaultReminderRecurring =
      GeneratedColumn<bool>(
        'default_reminder_recurring',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("default_reminder_recurring" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _tempPlanDataMeta = const VerificationMeta(
    'tempPlanData',
  );
  @override
  late final GeneratedColumn<String> tempPlanData = GeneratedColumn<String>(
    'temp_plan_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _swipeHintShownMeta = const VerificationMeta(
    'swipeHintShown',
  );
  @override
  late final GeneratedColumn<bool> swipeHintShown = GeneratedColumn<bool>(
    'swipe_hint_shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("swipe_hint_shown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _calendarWeekStartMeta = const VerificationMeta(
    'calendarWeekStart',
  );
  @override
  late final GeneratedColumn<String> calendarWeekStart =
      GeneratedColumn<String>(
        'calendar_week_start',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('monday'),
      );
  static const VerificationMeta _defaultActivityTimeMeta =
      const VerificationMeta('defaultActivityTime');
  @override
  late final GeneratedColumn<String> defaultActivityTime =
      GeneratedColumn<String>(
        'default_activity_time',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('07:00:00'),
      );
  static const VerificationMeta _defaultActivityDayMeta =
      const VerificationMeta('defaultActivityDay');
  @override
  late final GeneratedColumn<String> defaultActivityDay =
      GeneratedColumn<String>(
        'default_activity_day',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('saturday'),
      );
  static const VerificationMeta _autoGenerateNutritionMeta =
      const VerificationMeta('autoGenerateNutrition');
  @override
  late final GeneratedColumn<bool> autoGenerateNutrition =
      GeneratedColumn<bool>(
        'auto_generate_nutrition',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_generate_nutrition" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _completionRemindersMeta =
      const VerificationMeta('completionReminders');
  @override
  late final GeneratedColumn<bool> completionReminders = GeneratedColumn<bool>(
    'completion_reminders',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completion_reminders" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    authUserId,
    authProvider,
    isAnonymous,
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
    swipeHintShown,
    calendarWeekStart,
    defaultActivityTime,
    defaultActivityDay,
    autoGenerateNutrition,
    completionReminders,
    senderName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('auth_user_id')) {
      context.handle(
        _authUserIdMeta,
        authUserId.isAcceptableOrUnknown(
          data['auth_user_id']!,
          _authUserIdMeta,
        ),
      );
    }
    if (data.containsKey('auth_provider')) {
      context.handle(
        _authProviderMeta,
        authProvider.isAcceptableOrUnknown(
          data['auth_provider']!,
          _authProviderMeta,
        ),
      );
    }
    if (data.containsKey('is_anonymous')) {
      context.handle(
        _isAnonymousMeta,
        isAnonymous.isAcceptableOrUnknown(
          data['is_anonymous']!,
          _isAnonymousMeta,
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
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('birthday')) {
      context.handle(
        _birthdayMeta,
        birthday.isAcceptableOrUnknown(data['birthday']!, _birthdayMeta),
      );
    }
    if (data.containsKey('height_feet')) {
      context.handle(
        _heightFeetMeta,
        heightFeet.isAcceptableOrUnknown(data['height_feet']!, _heightFeetMeta),
      );
    }
    if (data.containsKey('height_inches')) {
      context.handle(
        _heightInchesMeta,
        heightInches.isAcceptableOrUnknown(
          data['height_inches']!,
          _heightInchesMeta,
        ),
      );
    }
    if (data.containsKey('weight_pounds')) {
      context.handle(
        _weightPoundsMeta,
        weightPounds.isAcceptableOrUnknown(
          data['weight_pounds']!,
          _weightPoundsMeta,
        ),
      );
    }
    if (data.containsKey('runs_with_water_bottle')) {
      context.handle(
        _runsWithWaterBottleMeta,
        runsWithWaterBottle.isAcceptableOrUnknown(
          data['runs_with_water_bottle']!,
          _runsWithWaterBottleMeta,
        ),
      );
    }
    if (data.containsKey('preferred_distance_unit')) {
      context.handle(
        _preferredDistanceUnitMeta,
        preferredDistanceUnit.isAcceptableOrUnknown(
          data['preferred_distance_unit']!,
          _preferredDistanceUnitMeta,
        ),
      );
    }
    if (data.containsKey('preferred_pace_unit')) {
      context.handle(
        _preferredPaceUnitMeta,
        preferredPaceUnit.isAcceptableOrUnknown(
          data['preferred_pace_unit']!,
          _preferredPaceUnitMeta,
        ),
      );
    }
    if (data.containsKey('gut_training_level')) {
      context.handle(
        _gutTrainingLevelMeta,
        gutTrainingLevel.isAcceptableOrUnknown(
          data['gut_training_level']!,
          _gutTrainingLevelMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
        _onboardingCompletedMeta,
        onboardingCompleted.isAcceptableOrUnknown(
          data['onboarding_completed']!,
          _onboardingCompletedMeta,
        ),
      );
    }
    if (data.containsKey('last_active_at')) {
      context.handle(
        _lastActiveAtMeta,
        lastActiveAt.isAcceptableOrUnknown(
          data['last_active_at']!,
          _lastActiveAtMeta,
        ),
      );
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('default_reminder_day')) {
      context.handle(
        _defaultReminderDayMeta,
        defaultReminderDay.isAcceptableOrUnknown(
          data['default_reminder_day']!,
          _defaultReminderDayMeta,
        ),
      );
    }
    if (data.containsKey('default_reminder_hour')) {
      context.handle(
        _defaultReminderHourMeta,
        defaultReminderHour.isAcceptableOrUnknown(
          data['default_reminder_hour']!,
          _defaultReminderHourMeta,
        ),
      );
    }
    if (data.containsKey('default_reminder_minute')) {
      context.handle(
        _defaultReminderMinuteMeta,
        defaultReminderMinute.isAcceptableOrUnknown(
          data['default_reminder_minute']!,
          _defaultReminderMinuteMeta,
        ),
      );
    }
    if (data.containsKey('default_reminder_recurring')) {
      context.handle(
        _defaultReminderRecurringMeta,
        defaultReminderRecurring.isAcceptableOrUnknown(
          data['default_reminder_recurring']!,
          _defaultReminderRecurringMeta,
        ),
      );
    }
    if (data.containsKey('temp_plan_data')) {
      context.handle(
        _tempPlanDataMeta,
        tempPlanData.isAcceptableOrUnknown(
          data['temp_plan_data']!,
          _tempPlanDataMeta,
        ),
      );
    }
    if (data.containsKey('swipe_hint_shown')) {
      context.handle(
        _swipeHintShownMeta,
        swipeHintShown.isAcceptableOrUnknown(
          data['swipe_hint_shown']!,
          _swipeHintShownMeta,
        ),
      );
    }
    if (data.containsKey('calendar_week_start')) {
      context.handle(
        _calendarWeekStartMeta,
        calendarWeekStart.isAcceptableOrUnknown(
          data['calendar_week_start']!,
          _calendarWeekStartMeta,
        ),
      );
    }
    if (data.containsKey('default_activity_time')) {
      context.handle(
        _defaultActivityTimeMeta,
        defaultActivityTime.isAcceptableOrUnknown(
          data['default_activity_time']!,
          _defaultActivityTimeMeta,
        ),
      );
    }
    if (data.containsKey('default_activity_day')) {
      context.handle(
        _defaultActivityDayMeta,
        defaultActivityDay.isAcceptableOrUnknown(
          data['default_activity_day']!,
          _defaultActivityDayMeta,
        ),
      );
    }
    if (data.containsKey('auto_generate_nutrition')) {
      context.handle(
        _autoGenerateNutritionMeta,
        autoGenerateNutrition.isAcceptableOrUnknown(
          data['auto_generate_nutrition']!,
          _autoGenerateNutritionMeta,
        ),
      );
    }
    if (data.containsKey('completion_reminders')) {
      context.handle(
        _completionRemindersMeta,
        completionReminders.isAcceptableOrUnknown(
          data['completion_reminders']!,
          _completionRemindersMeta,
        ),
      );
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      authUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_user_id'],
      ),
      authProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_provider'],
      )!,
      isAnonymous: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_anonymous'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      birthday: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birthday'],
      ),
      heightFeet: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_feet'],
      ),
      heightInches: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_inches'],
      ),
      weightPounds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_pounds'],
      ),
      runsWithWaterBottle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}runs_with_water_bottle'],
      )!,
      foodPreferences: $UserProfilesTableTable.$converterfoodPreferences
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}food_preferences'],
            )!,
          ),
      preferredDistanceUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_distance_unit'],
      )!,
      preferredPaceUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_pace_unit'],
      )!,
      gutTrainingLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gut_training_level'],
      )!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_completed'],
      )!,
      lastActiveAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_active_at'],
      )!,
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      ),
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      defaultReminderDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_reminder_day'],
      )!,
      defaultReminderHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_reminder_hour'],
      )!,
      defaultReminderMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_reminder_minute'],
      )!,
      defaultReminderRecurring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}default_reminder_recurring'],
      )!,
      tempPlanData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temp_plan_data'],
      ),
      swipeHintShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}swipe_hint_shown'],
      )!,
      calendarWeekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_week_start'],
      )!,
      defaultActivityTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_activity_time'],
      )!,
      defaultActivityDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_activity_day'],
      )!,
      autoGenerateNutrition: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_generate_nutrition'],
      )!,
      completionReminders: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completion_reminders'],
      )!,
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      ),
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
  /// Note: During migration from device_id, this accepts any string length
  /// Will eventually be UUID-only after full migration to Supabase Auth
  final String id;

  /// Device ID used as unique identifier (matches Supabase users.device_id)
  /// This will become nullable during auth migration (legacy field)
  final String deviceId;

  /// Auth columns for Supabase authentication integration
  /// Explicit reference to Supabase auth.uid() - this is the canonical user ID
  final String? authUserId;

  /// OAuth provider used: 'anonymous', 'google', 'apple', 'email'
  final String authProvider;

  /// Whether this user is anonymous (not linked to permanent account)
  final bool isAnonymous;

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
  final String calendarWeekStart;
  final String defaultActivityTime;
  final String defaultActivityDay;
  final bool autoGenerateNutrition;
  final bool completionReminders;
  final String? senderName;
  const UserProfileEntry({
    required this.id,
    required this.deviceId,
    this.authUserId,
    required this.authProvider,
    required this.isAnonymous,
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
    required this.swipeHintShown,
    required this.calendarWeekStart,
    required this.defaultActivityTime,
    required this.defaultActivityDay,
    required this.autoGenerateNutrition,
    required this.completionReminders,
    this.senderName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || authUserId != null) {
      map['auth_user_id'] = Variable<String>(authUserId);
    }
    map['auth_provider'] = Variable<String>(authProvider);
    map['is_anonymous'] = Variable<bool>(isAnonymous);
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
      map['food_preferences'] = Variable<String>(
        $UserProfilesTableTable.$converterfoodPreferences.toSql(
          foodPreferences,
        ),
      );
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
    map['default_reminder_recurring'] = Variable<bool>(
      defaultReminderRecurring,
    );
    if (!nullToAbsent || tempPlanData != null) {
      map['temp_plan_data'] = Variable<String>(tempPlanData);
    }
    map['swipe_hint_shown'] = Variable<bool>(swipeHintShown);
    map['calendar_week_start'] = Variable<String>(calendarWeekStart);
    map['default_activity_time'] = Variable<String>(defaultActivityTime);
    map['default_activity_day'] = Variable<String>(defaultActivityDay);
    map['auto_generate_nutrition'] = Variable<bool>(autoGenerateNutrition);
    map['completion_reminders'] = Variable<bool>(completionReminders);
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    return map;
  }

  UserProfilesTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesTableCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      authUserId: authUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(authUserId),
      authProvider: Value(authProvider),
      isAnonymous: Value(isAnonymous),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
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
      calendarWeekStart: Value(calendarWeekStart),
      defaultActivityTime: Value(defaultActivityTime),
      defaultActivityDay: Value(defaultActivityDay),
      autoGenerateNutrition: Value(autoGenerateNutrition),
      completionReminders: Value(completionReminders),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
    );
  }

  factory UserProfileEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileEntry(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      authUserId: serializer.fromJson<String?>(json['authUserId']),
      authProvider: serializer.fromJson<String>(json['authProvider']),
      isAnonymous: serializer.fromJson<bool>(json['isAnonymous']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      gender: serializer.fromJson<String?>(json['gender']),
      birthday: serializer.fromJson<DateTime?>(json['birthday']),
      heightFeet: serializer.fromJson<int?>(json['heightFeet']),
      heightInches: serializer.fromJson<int?>(json['heightInches']),
      weightPounds: serializer.fromJson<double?>(json['weightPounds']),
      runsWithWaterBottle: serializer.fromJson<bool>(
        json['runsWithWaterBottle'],
      ),
      foodPreferences: serializer.fromJson<Map<String, dynamic>>(
        json['foodPreferences'],
      ),
      preferredDistanceUnit: serializer.fromJson<String>(
        json['preferredDistanceUnit'],
      ),
      preferredPaceUnit: serializer.fromJson<String>(json['preferredPaceUnit']),
      gutTrainingLevel: serializer.fromJson<String>(json['gutTrainingLevel']),
      onboardingCompleted: serializer.fromJson<bool>(
        json['onboardingCompleted'],
      ),
      lastActiveAt: serializer.fromJson<DateTime>(json['lastActiveAt']),
      appVersion: serializer.fromJson<String?>(json['appVersion']),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      defaultReminderDay: serializer.fromJson<int>(json['defaultReminderDay']),
      defaultReminderHour: serializer.fromJson<int>(
        json['defaultReminderHour'],
      ),
      defaultReminderMinute: serializer.fromJson<int>(
        json['defaultReminderMinute'],
      ),
      defaultReminderRecurring: serializer.fromJson<bool>(
        json['defaultReminderRecurring'],
      ),
      tempPlanData: serializer.fromJson<String?>(json['tempPlanData']),
      swipeHintShown: serializer.fromJson<bool>(json['swipeHintShown']),
      calendarWeekStart: serializer.fromJson<String>(json['calendarWeekStart']),
      defaultActivityTime: serializer.fromJson<String>(
        json['defaultActivityTime'],
      ),
      defaultActivityDay: serializer.fromJson<String>(
        json['defaultActivityDay'],
      ),
      autoGenerateNutrition: serializer.fromJson<bool>(
        json['autoGenerateNutrition'],
      ),
      completionReminders: serializer.fromJson<bool>(
        json['completionReminders'],
      ),
      senderName: serializer.fromJson<String?>(json['senderName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'authUserId': serializer.toJson<String?>(authUserId),
      'authProvider': serializer.toJson<String>(authProvider),
      'isAnonymous': serializer.toJson<bool>(isAnonymous),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'gender': serializer.toJson<String?>(gender),
      'birthday': serializer.toJson<DateTime?>(birthday),
      'heightFeet': serializer.toJson<int?>(heightFeet),
      'heightInches': serializer.toJson<int?>(heightInches),
      'weightPounds': serializer.toJson<double?>(weightPounds),
      'runsWithWaterBottle': serializer.toJson<bool>(runsWithWaterBottle),
      'foodPreferences': serializer.toJson<Map<String, dynamic>>(
        foodPreferences,
      ),
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
      'defaultReminderRecurring': serializer.toJson<bool>(
        defaultReminderRecurring,
      ),
      'tempPlanData': serializer.toJson<String?>(tempPlanData),
      'swipeHintShown': serializer.toJson<bool>(swipeHintShown),
      'calendarWeekStart': serializer.toJson<String>(calendarWeekStart),
      'defaultActivityTime': serializer.toJson<String>(defaultActivityTime),
      'defaultActivityDay': serializer.toJson<String>(defaultActivityDay),
      'autoGenerateNutrition': serializer.toJson<bool>(autoGenerateNutrition),
      'completionReminders': serializer.toJson<bool>(completionReminders),
      'senderName': serializer.toJson<String?>(senderName),
    };
  }

  UserProfileEntry copyWith({
    String? id,
    String? deviceId,
    Value<String?> authUserId = const Value.absent(),
    String? authProvider,
    bool? isAnonymous,
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
    bool? swipeHintShown,
    String? calendarWeekStart,
    String? defaultActivityTime,
    String? defaultActivityDay,
    bool? autoGenerateNutrition,
    bool? completionReminders,
    Value<String?> senderName = const Value.absent(),
  }) => UserProfileEntry(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    authUserId: authUserId.present ? authUserId.value : this.authUserId,
    authProvider: authProvider ?? this.authProvider,
    isAnonymous: isAnonymous ?? this.isAnonymous,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    gender: gender.present ? gender.value : this.gender,
    birthday: birthday.present ? birthday.value : this.birthday,
    heightFeet: heightFeet.present ? heightFeet.value : this.heightFeet,
    heightInches: heightInches.present ? heightInches.value : this.heightInches,
    weightPounds: weightPounds.present ? weightPounds.value : this.weightPounds,
    runsWithWaterBottle: runsWithWaterBottle ?? this.runsWithWaterBottle,
    foodPreferences: foodPreferences ?? this.foodPreferences,
    preferredDistanceUnit: preferredDistanceUnit ?? this.preferredDistanceUnit,
    preferredPaceUnit: preferredPaceUnit ?? this.preferredPaceUnit,
    gutTrainingLevel: gutTrainingLevel ?? this.gutTrainingLevel,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    appVersion: appVersion.present ? appVersion.value : this.appVersion,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultReminderDay: defaultReminderDay ?? this.defaultReminderDay,
    defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
    defaultReminderMinute: defaultReminderMinute ?? this.defaultReminderMinute,
    defaultReminderRecurring:
        defaultReminderRecurring ?? this.defaultReminderRecurring,
    tempPlanData: tempPlanData.present ? tempPlanData.value : this.tempPlanData,
    swipeHintShown: swipeHintShown ?? this.swipeHintShown,
    calendarWeekStart: calendarWeekStart ?? this.calendarWeekStart,
    defaultActivityTime: defaultActivityTime ?? this.defaultActivityTime,
    defaultActivityDay: defaultActivityDay ?? this.defaultActivityDay,
    autoGenerateNutrition: autoGenerateNutrition ?? this.autoGenerateNutrition,
    completionReminders: completionReminders ?? this.completionReminders,
    senderName: senderName.present ? senderName.value : this.senderName,
  );
  UserProfileEntry copyWithCompanion(UserProfilesTableCompanion data) {
    return UserProfileEntry(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      authUserId: data.authUserId.present
          ? data.authUserId.value
          : this.authUserId,
      authProvider: data.authProvider.present
          ? data.authProvider.value
          : this.authProvider,
      isAnonymous: data.isAnonymous.present
          ? data.isAnonymous.value
          : this.isAnonymous,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      gender: data.gender.present ? data.gender.value : this.gender,
      birthday: data.birthday.present ? data.birthday.value : this.birthday,
      heightFeet: data.heightFeet.present
          ? data.heightFeet.value
          : this.heightFeet,
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
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
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
      calendarWeekStart: data.calendarWeekStart.present
          ? data.calendarWeekStart.value
          : this.calendarWeekStart,
      defaultActivityTime: data.defaultActivityTime.present
          ? data.defaultActivityTime.value
          : this.defaultActivityTime,
      defaultActivityDay: data.defaultActivityDay.present
          ? data.defaultActivityDay.value
          : this.defaultActivityDay,
      autoGenerateNutrition: data.autoGenerateNutrition.present
          ? data.autoGenerateNutrition.value
          : this.autoGenerateNutrition,
      completionReminders: data.completionReminders.present
          ? data.completionReminders.value
          : this.completionReminders,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileEntry(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('authUserId: $authUserId, ')
          ..write('authProvider: $authProvider, ')
          ..write('isAnonymous: $isAnonymous, ')
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
          ..write('calendarWeekStart: $calendarWeekStart, ')
          ..write('defaultActivityTime: $defaultActivityTime, ')
          ..write('defaultActivityDay: $defaultActivityDay, ')
          ..write('autoGenerateNutrition: $autoGenerateNutrition, ')
          ..write('completionReminders: $completionReminders, ')
          ..write('senderName: $senderName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    deviceId,
    authUserId,
    authProvider,
    isAnonymous,
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
    swipeHintShown,
    calendarWeekStart,
    defaultActivityTime,
    defaultActivityDay,
    autoGenerateNutrition,
    completionReminders,
    senderName,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileEntry &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.authUserId == this.authUserId &&
          other.authProvider == this.authProvider &&
          other.isAnonymous == this.isAnonymous &&
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
          other.swipeHintShown == this.swipeHintShown &&
          other.calendarWeekStart == this.calendarWeekStart &&
          other.defaultActivityTime == this.defaultActivityTime &&
          other.defaultActivityDay == this.defaultActivityDay &&
          other.autoGenerateNutrition == this.autoGenerateNutrition &&
          other.completionReminders == this.completionReminders &&
          other.senderName == this.senderName);
}

class UserProfilesTableCompanion extends UpdateCompanion<UserProfileEntry> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String?> authUserId;
  final Value<String> authProvider;
  final Value<bool> isAnonymous;
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
  final Value<String> calendarWeekStart;
  final Value<String> defaultActivityTime;
  final Value<String> defaultActivityDay;
  final Value<bool> autoGenerateNutrition;
  final Value<bool> completionReminders;
  final Value<String?> senderName;
  final Value<int> rowid;
  const UserProfilesTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.authUserId = const Value.absent(),
    this.authProvider = const Value.absent(),
    this.isAnonymous = const Value.absent(),
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
    this.calendarWeekStart = const Value.absent(),
    this.defaultActivityTime = const Value.absent(),
    this.defaultActivityDay = const Value.absent(),
    this.autoGenerateNutrition = const Value.absent(),
    this.completionReminders = const Value.absent(),
    this.senderName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesTableCompanion.insert({
    required String id,
    required String deviceId,
    this.authUserId = const Value.absent(),
    this.authProvider = const Value.absent(),
    this.isAnonymous = const Value.absent(),
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
    this.calendarWeekStart = const Value.absent(),
    this.defaultActivityTime = const Value.absent(),
    this.defaultActivityDay = const Value.absent(),
    this.autoGenerateNutrition = const Value.absent(),
    this.completionReminders = const Value.absent(),
    this.senderName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId);
  static Insertable<UserProfileEntry> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? authUserId,
    Expression<String>? authProvider,
    Expression<bool>? isAnonymous,
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
    Expression<String>? calendarWeekStart,
    Expression<String>? defaultActivityTime,
    Expression<String>? defaultActivityDay,
    Expression<bool>? autoGenerateNutrition,
    Expression<bool>? completionReminders,
    Expression<String>? senderName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (authUserId != null) 'auth_user_id': authUserId,
      if (authProvider != null) 'auth_provider': authProvider,
      if (isAnonymous != null) 'is_anonymous': isAnonymous,
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
      if (calendarWeekStart != null) 'calendar_week_start': calendarWeekStart,
      if (defaultActivityTime != null)
        'default_activity_time': defaultActivityTime,
      if (defaultActivityDay != null)
        'default_activity_day': defaultActivityDay,
      if (autoGenerateNutrition != null)
        'auto_generate_nutrition': autoGenerateNutrition,
      if (completionReminders != null)
        'completion_reminders': completionReminders,
      if (senderName != null) 'sender_name': senderName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String?>? authUserId,
    Value<String>? authProvider,
    Value<bool>? isAnonymous,
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
    Value<String>? calendarWeekStart,
    Value<String>? defaultActivityTime,
    Value<String>? defaultActivityDay,
    Value<bool>? autoGenerateNutrition,
    Value<bool>? completionReminders,
    Value<String?>? senderName,
    Value<int>? rowid,
  }) {
    return UserProfilesTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      authUserId: authUserId ?? this.authUserId,
      authProvider: authProvider ?? this.authProvider,
      isAnonymous: isAnonymous ?? this.isAnonymous,
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
      calendarWeekStart: calendarWeekStart ?? this.calendarWeekStart,
      defaultActivityTime: defaultActivityTime ?? this.defaultActivityTime,
      defaultActivityDay: defaultActivityDay ?? this.defaultActivityDay,
      autoGenerateNutrition:
          autoGenerateNutrition ?? this.autoGenerateNutrition,
      completionReminders: completionReminders ?? this.completionReminders,
      senderName: senderName ?? this.senderName,
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
    if (authUserId.present) {
      map['auth_user_id'] = Variable<String>(authUserId.value);
    }
    if (authProvider.present) {
      map['auth_provider'] = Variable<String>(authProvider.value);
    }
    if (isAnonymous.present) {
      map['is_anonymous'] = Variable<bool>(isAnonymous.value);
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
      map['food_preferences'] = Variable<String>(
        $UserProfilesTableTable.$converterfoodPreferences.toSql(
          foodPreferences.value,
        ),
      );
    }
    if (preferredDistanceUnit.present) {
      map['preferred_distance_unit'] = Variable<String>(
        preferredDistanceUnit.value,
      );
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
      map['default_reminder_minute'] = Variable<int>(
        defaultReminderMinute.value,
      );
    }
    if (defaultReminderRecurring.present) {
      map['default_reminder_recurring'] = Variable<bool>(
        defaultReminderRecurring.value,
      );
    }
    if (tempPlanData.present) {
      map['temp_plan_data'] = Variable<String>(tempPlanData.value);
    }
    if (swipeHintShown.present) {
      map['swipe_hint_shown'] = Variable<bool>(swipeHintShown.value);
    }
    if (calendarWeekStart.present) {
      map['calendar_week_start'] = Variable<String>(calendarWeekStart.value);
    }
    if (defaultActivityTime.present) {
      map['default_activity_time'] = Variable<String>(
        defaultActivityTime.value,
      );
    }
    if (defaultActivityDay.present) {
      map['default_activity_day'] = Variable<String>(defaultActivityDay.value);
    }
    if (autoGenerateNutrition.present) {
      map['auto_generate_nutrition'] = Variable<bool>(
        autoGenerateNutrition.value,
      );
    }
    if (completionReminders.present) {
      map['completion_reminders'] = Variable<bool>(completionReminders.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
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
          ..write('authUserId: $authUserId, ')
          ..write('authProvider: $authProvider, ')
          ..write('isAnonymous: $isAnonymous, ')
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
          ..write('calendarWeekStart: $calendarWeekStart, ')
          ..write('defaultActivityTime: $defaultActivityTime, ')
          ..write('defaultActivityDay: $defaultActivityDay, ')
          ..write('autoGenerateNutrition: $autoGenerateNutrition, ')
          ..write('completionReminders: $completionReminders, ')
          ..write('senderName: $senderName, ')
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
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferenceMeta = const VerificationMeta(
    'preference',
  );
  @override
  late final GeneratedColumn<String> preference = GeneratedColumn<String>(
    'preference',
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
    userId,
    foodName,
    preference,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_preferences_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodPreferenceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('preference')) {
      context.handle(
        _preferenceMeta,
        preference.isAcceptableOrUnknown(data['preference']!, _preferenceMeta),
      );
    } else if (isInserting) {
      context.missing(_preferenceMeta);
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
  FoodPreferenceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodPreferenceEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      preference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preference'],
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
  $FoodPreferencesTableTable createAlias(String alias) {
    return $FoodPreferencesTableTable(attachedDatabase, alias);
  }
}

class FoodPreferenceEntry extends DataClass
    implements Insertable<FoodPreferenceEntry> {
  /// UUID primary key (matches Supabase food_preferences.id)
  final String id;

  /// User ID (foreign key reference to users.id UUID)
  final String userId;

  /// Food name (should match foods.name) - matches Supabase food_preferences.food_name
  final String foodName;

  /// Preference type: 'like', 'dislike', 'willing_to_try' (matches Supabase constraint)
  final String preference;

  /// When the preference was created (matches Supabase food_preferences.created_at)
  final DateTime createdAt;

  /// When the preference was last updated (matches Supabase food_preferences.updated_at)
  final DateTime updatedAt;
  const FoodPreferenceEntry({
    required this.id,
    required this.userId,
    required this.foodName,
    required this.preference,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['food_name'] = Variable<String>(foodName);
    map['preference'] = Variable<String>(preference);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FoodPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return FoodPreferencesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      foodName: Value(foodName),
      preference: Value(preference),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FoodPreferenceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodPreferenceEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
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
      'userId': serializer.toJson<String>(userId),
      'foodName': serializer.toJson<String>(foodName),
      'preference': serializer.toJson<String>(preference),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FoodPreferenceEntry copyWith({
    String? id,
    String? userId,
    String? foodName,
    String? preference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FoodPreferenceEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    foodName: foodName ?? this.foodName,
    preference: preference ?? this.preference,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FoodPreferenceEntry copyWithCompanion(FoodPreferencesTableCompanion data) {
    return FoodPreferenceEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      preference: data.preference.present
          ? data.preference.value
          : this.preference,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodPreferenceEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('foodName: $foodName, ')
          ..write('preference: $preference, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, foodName, preference, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodPreferenceEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.foodName == this.foodName &&
          other.preference == this.preference &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FoodPreferencesTableCompanion
    extends UpdateCompanion<FoodPreferenceEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> foodName;
  final Value<String> preference;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FoodPreferencesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.foodName = const Value.absent(),
    this.preference = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodPreferencesTableCompanion.insert({
    required String id,
    required String userId,
    required String foodName,
    required String preference,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       foodName = Value(foodName),
       preference = Value(preference);
  static Insertable<FoodPreferenceEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? foodName,
    Expression<String>? preference,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (foodName != null) 'food_name': foodName,
      if (preference != null) 'preference': preference,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodPreferencesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? foodName,
    Value<String>? preference,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FoodPreferencesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
          ..write('userId: $userId, ')
          ..write('foodName: $foodName, ')
          ..write('preference: $preference, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _satisfactionLevelMeta = const VerificationMeta(
    'satisfactionLevel',
  );
  @override
  late final GeneratedColumn<int> satisfactionLevel = GeneratedColumn<int>(
    'satisfaction_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _satisfactionEmojiMeta = const VerificationMeta(
    'satisfactionEmoji',
  );
  @override
  late final GeneratedColumn<String> satisfactionEmoji =
      GeneratedColumn<String>(
        'satisfaction_emoji',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _satisfactionLabelMeta = const VerificationMeta(
    'satisfactionLabel',
  );
  @override
  late final GeneratedColumn<String> satisfactionLabel =
      GeneratedColumn<String>(
        'satisfaction_label',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _appFeedbackMeta = const VerificationMeta(
    'appFeedback',
  );
  @override
  late final GeneratedColumn<String> appFeedback = GeneratedColumn<String>(
    'app_feedback',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestionsMeta = const VerificationMeta(
    'suggestions',
  );
  @override
  late final GeneratedColumn<String> suggestions = GeneratedColumn<String>(
    'suggestions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planNameMeta = const VerificationMeta(
    'planName',
  );
  @override
  late final GeneratedColumn<String> planName = GeneratedColumn<String>(
    'plan_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceLevelMeta = const VerificationMeta(
    'confidenceLevel',
  );
  @override
  late final GeneratedColumn<int> confidenceLevel = GeneratedColumn<int>(
    'confidence_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceLabelMeta = const VerificationMeta(
    'confidenceLabel',
  );
  @override
  late final GeneratedColumn<String> confidenceLabel = GeneratedColumn<String>(
    'confidence_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reuseIntentMeta = const VerificationMeta(
    'reuseIntent',
  );
  @override
  late final GeneratedColumn<String> reuseIntent = GeneratedColumn<String>(
    'reuse_intent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderRequestedMeta = const VerificationMeta(
    'reminderRequested',
  );
  @override
  late final GeneratedColumn<bool> reminderRequested = GeneratedColumn<bool>(
    'reminder_requested',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_requested" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _missedReasonsMeta = const VerificationMeta(
    'missedReasons',
  );
  @override
  late final GeneratedColumn<String> missedReasons = GeneratedColumn<String>(
    'missed_reasons',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missedOtherMeta = const VerificationMeta(
    'missedOther',
  );
  @override
  late final GeneratedColumn<String> missedOther = GeneratedColumn<String>(
    'missed_other',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderDayOfWeekMeta = const VerificationMeta(
    'reminderDayOfWeek',
  );
  @override
  late final GeneratedColumn<int> reminderDayOfWeek = GeneratedColumn<int>(
    'reminder_day_of_week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderHourMeta = const VerificationMeta(
    'reminderHour',
  );
  @override
  late final GeneratedColumn<int> reminderHour = GeneratedColumn<int>(
    'reminder_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(17),
  );
  static const VerificationMeta _reminderMinuteMeta = const VerificationMeta(
    'reminderMinute',
  );
  @override
  late final GeneratedColumn<int> reminderMinute = GeneratedColumn<int>(
    'reminder_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reminderRecurringMeta = const VerificationMeta(
    'reminderRecurring',
  );
  @override
  late final GeneratedColumn<bool> reminderRecurring = GeneratedColumn<bool>(
    'reminder_recurring',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_recurring" IN (0, 1))',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
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
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feedback';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedbackEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('satisfaction_level')) {
      context.handle(
        _satisfactionLevelMeta,
        satisfactionLevel.isAcceptableOrUnknown(
          data['satisfaction_level']!,
          _satisfactionLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_satisfactionLevelMeta);
    }
    if (data.containsKey('satisfaction_emoji')) {
      context.handle(
        _satisfactionEmojiMeta,
        satisfactionEmoji.isAcceptableOrUnknown(
          data['satisfaction_emoji']!,
          _satisfactionEmojiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_satisfactionEmojiMeta);
    }
    if (data.containsKey('satisfaction_label')) {
      context.handle(
        _satisfactionLabelMeta,
        satisfactionLabel.isAcceptableOrUnknown(
          data['satisfaction_label']!,
          _satisfactionLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_satisfactionLabelMeta);
    }
    if (data.containsKey('app_feedback')) {
      context.handle(
        _appFeedbackMeta,
        appFeedback.isAcceptableOrUnknown(
          data['app_feedback']!,
          _appFeedbackMeta,
        ),
      );
    }
    if (data.containsKey('suggestions')) {
      context.handle(
        _suggestionsMeta,
        suggestions.isAcceptableOrUnknown(
          data['suggestions']!,
          _suggestionsMeta,
        ),
      );
    }
    if (data.containsKey('plan_name')) {
      context.handle(
        _planNameMeta,
        planName.isAcceptableOrUnknown(data['plan_name']!, _planNameMeta),
      );
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('confidence_level')) {
      context.handle(
        _confidenceLevelMeta,
        confidenceLevel.isAcceptableOrUnknown(
          data['confidence_level']!,
          _confidenceLevelMeta,
        ),
      );
    }
    if (data.containsKey('confidence_label')) {
      context.handle(
        _confidenceLabelMeta,
        confidenceLabel.isAcceptableOrUnknown(
          data['confidence_label']!,
          _confidenceLabelMeta,
        ),
      );
    }
    if (data.containsKey('reuse_intent')) {
      context.handle(
        _reuseIntentMeta,
        reuseIntent.isAcceptableOrUnknown(
          data['reuse_intent']!,
          _reuseIntentMeta,
        ),
      );
    }
    if (data.containsKey('reminder_requested')) {
      context.handle(
        _reminderRequestedMeta,
        reminderRequested.isAcceptableOrUnknown(
          data['reminder_requested']!,
          _reminderRequestedMeta,
        ),
      );
    }
    if (data.containsKey('missed_reasons')) {
      context.handle(
        _missedReasonsMeta,
        missedReasons.isAcceptableOrUnknown(
          data['missed_reasons']!,
          _missedReasonsMeta,
        ),
      );
    }
    if (data.containsKey('missed_other')) {
      context.handle(
        _missedOtherMeta,
        missedOther.isAcceptableOrUnknown(
          data['missed_other']!,
          _missedOtherMeta,
        ),
      );
    }
    if (data.containsKey('reminder_day_of_week')) {
      context.handle(
        _reminderDayOfWeekMeta,
        reminderDayOfWeek.isAcceptableOrUnknown(
          data['reminder_day_of_week']!,
          _reminderDayOfWeekMeta,
        ),
      );
    }
    if (data.containsKey('reminder_hour')) {
      context.handle(
        _reminderHourMeta,
        reminderHour.isAcceptableOrUnknown(
          data['reminder_hour']!,
          _reminderHourMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minute')) {
      context.handle(
        _reminderMinuteMeta,
        reminderMinute.isAcceptableOrUnknown(
          data['reminder_minute']!,
          _reminderMinuteMeta,
        ),
      );
    }
    if (data.containsKey('reminder_recurring')) {
      context.handle(
        _reminderRecurringMeta,
        reminderRecurring.isAcceptableOrUnknown(
          data['reminder_recurring']!,
          _reminderRecurringMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeedbackEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedbackEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      satisfactionLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}satisfaction_level'],
      )!,
      satisfactionEmoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}satisfaction_emoji'],
      )!,
      satisfactionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}satisfaction_label'],
      )!,
      appFeedback: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_feedback'],
      ),
      suggestions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggestions'],
      ),
      planName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_name'],
      ),
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      ),
      confidenceLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence_level'],
      ),
      confidenceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence_label'],
      ),
      reuseIntent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reuse_intent'],
      ),
      reminderRequested: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_requested'],
      )!,
      missedReasons: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}missed_reasons'],
      ),
      missedOther: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}missed_other'],
      ),
      reminderDayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_day_of_week'],
      ),
      reminderHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_hour'],
      )!,
      reminderMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minute'],
      )!,
      reminderRecurring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_recurring'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
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
  const FeedbackEntry({
    required this.id,
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
    required this.createdAt,
  });
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

  factory FeedbackEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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

  FeedbackEntry copyWith({
    String? id,
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
    DateTime? createdAt,
  }) => FeedbackEntry(
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
    missedReasons: missedReasons.present
        ? missedReasons.value
        : this.missedReasons,
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
      appFeedback: data.appFeedback.present
          ? data.appFeedback.value
          : this.appFeedback,
      suggestions: data.suggestions.present
          ? data.suggestions.value
          : this.suggestions,
      planName: data.planName.present ? data.planName.value : this.planName,
      userName: data.userName.present ? data.userName.value : this.userName,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      confidenceLevel: data.confidenceLevel.present
          ? data.confidenceLevel.value
          : this.confidenceLevel,
      confidenceLabel: data.confidenceLabel.present
          ? data.confidenceLabel.value
          : this.confidenceLabel,
      reuseIntent: data.reuseIntent.present
          ? data.reuseIntent.value
          : this.reuseIntent,
      reminderRequested: data.reminderRequested.present
          ? data.reminderRequested.value
          : this.reminderRequested,
      missedReasons: data.missedReasons.present
          ? data.missedReasons.value
          : this.missedReasons,
      missedOther: data.missedOther.present
          ? data.missedOther.value
          : this.missedOther,
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
    createdAt,
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
  }) : id = Value(id),
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

  FeedbackTableCompanion copyWith({
    Value<String>? id,
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
    Value<int>? rowid,
  }) {
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
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAddressMeta = const VerificationMeta(
    'imageAddress',
  );
  @override
  late final GeneratedColumn<String> imageAddress = GeneratedColumn<String>(
    'image_address',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _servingAmountMeta = const VerificationMeta(
    'servingAmount',
  );
  @override
  late final GeneratedColumn<double> servingAmount = GeneratedColumn<double>(
    'serving_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxServingsBeforeMeta = const VerificationMeta(
    'maxServingsBefore',
  );
  @override
  late final GeneratedColumn<int> maxServingsBefore = GeneratedColumn<int>(
    'max_servings_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxServingsDuringMeta = const VerificationMeta(
    'maxServingsDuring',
  );
  @override
  late final GeneratedColumn<int> maxServingsDuring = GeneratedColumn<int>(
    'max_servings_during',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxServingsAfterMeta = const VerificationMeta(
    'maxServingsAfter',
  );
  @override
  late final GeneratedColumn<int> maxServingsAfter = GeneratedColumn<int>(
    'max_servings_after',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesMeta = const VerificationMeta(
    'categories',
  );
  @override
  late final GeneratedColumn<String> categories = GeneratedColumn<String>(
    'categories',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityTypesMeta = const VerificationMeta(
    'activityTypes',
  );
  @override
  late final GeneratedColumn<String> activityTypes = GeneratedColumn<String>(
    'activity_types',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sodiumMgMeta = const VerificationMeta(
    'sodiumMg',
  );
  @override
  late final GeneratedColumn<int> sodiumMg = GeneratedColumn<int>(
    'sodium_mg',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caffeineMgMeta = const VerificationMeta(
    'caffeineMg',
  );
  @override
  late final GeneratedColumn<int> caffeineMg = GeneratedColumn<int>(
    'caffeine_mg',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _potassiumMgMeta = const VerificationMeta(
    'potassiumMg',
  );
  @override
  late final GeneratedColumn<int> potassiumMg = GeneratedColumn<int>(
    'potassium_mg',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatPerServingMeta = const VerificationMeta(
    'fatPerServing',
  );
  @override
  late final GeneratedColumn<double> fatPerServing = GeneratedColumn<double>(
    'fat_per_serving',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsPerServingMeta = const VerificationMeta(
    'carbsPerServing',
  );
  @override
  late final GeneratedColumn<double> carbsPerServing = GeneratedColumn<double>(
    'carbs_per_serving',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinPerServingMeta = const VerificationMeta(
    'proteinPerServing',
  );
  @override
  late final GeneratedColumn<double> proteinPerServing =
      GeneratedColumn<double>(
        'protein_per_serving',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _caloriesPerServingMeta =
      const VerificationMeta('caloriesPerServing');
  @override
  late final GeneratedColumn<int> caloriesPerServing = GeneratedColumn<int>(
    'calories_per_serving',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fluidMlPerServingMeta = const VerificationMeta(
    'fluidMlPerServing',
  );
  @override
  late final GeneratedColumn<double> fluidMlPerServing =
      GeneratedColumn<double>(
        'fluid_ml_per_serving',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _showInPreferencesMeta = const VerificationMeta(
    'showInPreferences',
  );
  @override
  late final GeneratedColumn<bool> showInPreferences = GeneratedColumn<bool>(
    'show_in_preferences',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_in_preferences" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isElectrolyteMeta = const VerificationMeta(
    'isElectrolyte',
  );
  @override
  late final GeneratedColumn<bool> isElectrolyte = GeneratedColumn<bool>(
    'is_electrolyte',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_electrolyte" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _toExcludeFromSolverMeta =
      const VerificationMeta('toExcludeFromSolver');
  @override
  late final GeneratedColumn<bool> toExcludeFromSolver = GeneratedColumn<bool>(
    'to_exclude_from_solver',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("to_exclude_from_solver" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEssentialMeta = const VerificationMeta(
    'isEssential',
  );
  @override
  late final GeneratedColumn<bool> isEssential = GeneratedColumn<bool>(
    'is_essential',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_essential" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNamePluralMeta = const VerificationMeta(
    'displayNamePlural',
  );
  @override
  late final GeneratedColumn<String> displayNamePlural =
      GeneratedColumn<String>(
        'display_name_plural',
        aliasedName,
        true,
        additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _servingDescriptionMeta =
      const VerificationMeta('servingDescription');
  @override
  late final GeneratedColumn<String> servingDescription =
      GeneratedColumn<String>(
        'serving_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _instructionsMeta = const VerificationMeta(
    'instructions',
  );
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
    'instructions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nutritionalInfoMeta = const VerificationMeta(
    'nutritionalInfo',
  );
  @override
  late final GeneratedColumn<String> nutritionalInfo = GeneratedColumn<String>(
    'nutritional_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingUnitMeta = const VerificationMeta(
    'servingUnit',
  );
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
    'serving_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingUnitPluralMeta = const VerificationMeta(
    'servingUnitPlural',
  );
  @override
  late final GeneratedColumn<String> servingUnitPlural =
      GeneratedColumn<String>(
        'serving_unit_plural',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _servingQualifierMeta = const VerificationMeta(
    'servingQualifier',
  );
  @override
  late final GeneratedColumn<String> servingQualifier = GeneratedColumn<String>(
    'serving_qualifier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingSizeMeta = const VerificationMeta(
    'servingSize',
  );
  @override
  late final GeneratedColumn<String> servingSize = GeneratedColumn<String>(
    'serving_size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productTypeIdMeta = const VerificationMeta(
    'productTypeId',
  );
  @override
  late final GeneratedColumn<String> productTypeId = GeneratedColumn<String>(
    'product_type_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchaseUrlMeta = const VerificationMeta(
    'purchaseUrl',
  );
  @override
  late final GeneratedColumn<String> purchaseUrl = GeneratedColumn<String>(
    'purchase_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _affiliateSourceMeta = const VerificationMeta(
    'affiliateSource',
  );
  @override
  late final GeneratedColumn<String> affiliateSource = GeneratedColumn<String>(
    'affiliate_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferencePriorityMeta =
      const VerificationMeta('preferencePriority');
  @override
  late final GeneratedColumn<int> preferencePriority = GeneratedColumn<int>(
    'preference_priority',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
    categories,
    activityTypes,
    sodiumMg,
    caffeineMg,
    potassiumMg,
    fatPerServing,
    carbsPerServing,
    proteinPerServing,
    caloriesPerServing,
    fluidMlPerServing,
    showInPreferences,
    isElectrolyte,
    toExcludeFromSolver,
    isEssential,
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
    productTypeId,
    purchaseUrl,
    affiliateSource,
    preferencePriority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodEntry> instance, {
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
    }
    if (data.containsKey('image_address')) {
      context.handle(
        _imageAddressMeta,
        imageAddress.isAcceptableOrUnknown(
          data['image_address']!,
          _imageAddressMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('serving_amount')) {
      context.handle(
        _servingAmountMeta,
        servingAmount.isAcceptableOrUnknown(
          data['serving_amount']!,
          _servingAmountMeta,
        ),
      );
    }
    if (data.containsKey('max_servings_before')) {
      context.handle(
        _maxServingsBeforeMeta,
        maxServingsBefore.isAcceptableOrUnknown(
          data['max_servings_before']!,
          _maxServingsBeforeMeta,
        ),
      );
    }
    if (data.containsKey('max_servings_during')) {
      context.handle(
        _maxServingsDuringMeta,
        maxServingsDuring.isAcceptableOrUnknown(
          data['max_servings_during']!,
          _maxServingsDuringMeta,
        ),
      );
    }
    if (data.containsKey('max_servings_after')) {
      context.handle(
        _maxServingsAfterMeta,
        maxServingsAfter.isAcceptableOrUnknown(
          data['max_servings_after']!,
          _maxServingsAfterMeta,
        ),
      );
    }
    if (data.containsKey('categories')) {
      context.handle(
        _categoriesMeta,
        categories.isAcceptableOrUnknown(data['categories']!, _categoriesMeta),
      );
    }
    if (data.containsKey('activity_types')) {
      context.handle(
        _activityTypesMeta,
        activityTypes.isAcceptableOrUnknown(
          data['activity_types']!,
          _activityTypesMeta,
        ),
      );
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(
        _sodiumMgMeta,
        sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta),
      );
    }
    if (data.containsKey('caffeine_mg')) {
      context.handle(
        _caffeineMgMeta,
        caffeineMg.isAcceptableOrUnknown(data['caffeine_mg']!, _caffeineMgMeta),
      );
    }
    if (data.containsKey('potassium_mg')) {
      context.handle(
        _potassiumMgMeta,
        potassiumMg.isAcceptableOrUnknown(
          data['potassium_mg']!,
          _potassiumMgMeta,
        ),
      );
    }
    if (data.containsKey('fat_per_serving')) {
      context.handle(
        _fatPerServingMeta,
        fatPerServing.isAcceptableOrUnknown(
          data['fat_per_serving']!,
          _fatPerServingMeta,
        ),
      );
    }
    if (data.containsKey('carbs_per_serving')) {
      context.handle(
        _carbsPerServingMeta,
        carbsPerServing.isAcceptableOrUnknown(
          data['carbs_per_serving']!,
          _carbsPerServingMeta,
        ),
      );
    }
    if (data.containsKey('protein_per_serving')) {
      context.handle(
        _proteinPerServingMeta,
        proteinPerServing.isAcceptableOrUnknown(
          data['protein_per_serving']!,
          _proteinPerServingMeta,
        ),
      );
    }
    if (data.containsKey('calories_per_serving')) {
      context.handle(
        _caloriesPerServingMeta,
        caloriesPerServing.isAcceptableOrUnknown(
          data['calories_per_serving']!,
          _caloriesPerServingMeta,
        ),
      );
    }
    if (data.containsKey('fluid_ml_per_serving')) {
      context.handle(
        _fluidMlPerServingMeta,
        fluidMlPerServing.isAcceptableOrUnknown(
          data['fluid_ml_per_serving']!,
          _fluidMlPerServingMeta,
        ),
      );
    }
    if (data.containsKey('show_in_preferences')) {
      context.handle(
        _showInPreferencesMeta,
        showInPreferences.isAcceptableOrUnknown(
          data['show_in_preferences']!,
          _showInPreferencesMeta,
        ),
      );
    }
    if (data.containsKey('is_electrolyte')) {
      context.handle(
        _isElectrolyteMeta,
        isElectrolyte.isAcceptableOrUnknown(
          data['is_electrolyte']!,
          _isElectrolyteMeta,
        ),
      );
    }
    if (data.containsKey('to_exclude_from_solver')) {
      context.handle(
        _toExcludeFromSolverMeta,
        toExcludeFromSolver.isAcceptableOrUnknown(
          data['to_exclude_from_solver']!,
          _toExcludeFromSolverMeta,
        ),
      );
    }
    if (data.containsKey('is_essential')) {
      context.handle(
        _isEssentialMeta,
        isEssential.isAcceptableOrUnknown(
          data['is_essential']!,
          _isEssentialMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('display_name_plural')) {
      context.handle(
        _displayNamePluralMeta,
        displayNamePlural.isAcceptableOrUnknown(
          data['display_name_plural']!,
          _displayNamePluralMeta,
        ),
      );
    }
    if (data.containsKey('serving_description')) {
      context.handle(
        _servingDescriptionMeta,
        servingDescription.isAcceptableOrUnknown(
          data['serving_description']!,
          _servingDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('instructions')) {
      context.handle(
        _instructionsMeta,
        instructions.isAcceptableOrUnknown(
          data['instructions']!,
          _instructionsMeta,
        ),
      );
    }
    if (data.containsKey('nutritional_info')) {
      context.handle(
        _nutritionalInfoMeta,
        nutritionalInfo.isAcceptableOrUnknown(
          data['nutritional_info']!,
          _nutritionalInfoMeta,
        ),
      );
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
        _servingUnitMeta,
        servingUnit.isAcceptableOrUnknown(
          data['serving_unit']!,
          _servingUnitMeta,
        ),
      );
    }
    if (data.containsKey('serving_unit_plural')) {
      context.handle(
        _servingUnitPluralMeta,
        servingUnitPlural.isAcceptableOrUnknown(
          data['serving_unit_plural']!,
          _servingUnitPluralMeta,
        ),
      );
    }
    if (data.containsKey('serving_qualifier')) {
      context.handle(
        _servingQualifierMeta,
        servingQualifier.isAcceptableOrUnknown(
          data['serving_qualifier']!,
          _servingQualifierMeta,
        ),
      );
    }
    if (data.containsKey('serving_size')) {
      context.handle(
        _servingSizeMeta,
        servingSize.isAcceptableOrUnknown(
          data['serving_size']!,
          _servingSizeMeta,
        ),
      );
    }
    if (data.containsKey('product_type_id')) {
      context.handle(
        _productTypeIdMeta,
        productTypeId.isAcceptableOrUnknown(
          data['product_type_id']!,
          _productTypeIdMeta,
        ),
      );
    }
    if (data.containsKey('purchase_url')) {
      context.handle(
        _purchaseUrlMeta,
        purchaseUrl.isAcceptableOrUnknown(
          data['purchase_url']!,
          _purchaseUrlMeta,
        ),
      );
    }
    if (data.containsKey('affiliate_source')) {
      context.handle(
        _affiliateSourceMeta,
        affiliateSource.isAcceptableOrUnknown(
          data['affiliate_source']!,
          _affiliateSourceMeta,
        ),
      );
    }
    if (data.containsKey('preference_priority')) {
      context.handle(
        _preferencePriorityMeta,
        preferencePriority.isAcceptableOrUnknown(
          data['preference_priority']!,
          _preferencePriorityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      imageAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_address'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      servingAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_amount'],
      ),
      maxServingsBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_servings_before'],
      ),
      maxServingsDuring: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_servings_during'],
      ),
      maxServingsAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_servings_after'],
      ),
      categories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories'],
      ),
      activityTypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_types'],
      ),
      sodiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sodium_mg'],
      ),
      caffeineMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}caffeine_mg'],
      ),
      potassiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}potassium_mg'],
      ),
      fatPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_per_serving'],
      ),
      carbsPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per_serving'],
      ),
      proteinPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_per_serving'],
      ),
      caloriesPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories_per_serving'],
      ),
      fluidMlPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fluid_ml_per_serving'],
      ),
      showInPreferences: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_in_preferences'],
      )!,
      isElectrolyte: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_electrolyte'],
      )!,
      toExcludeFromSolver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}to_exclude_from_solver'],
      )!,
      isEssential: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_essential'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      displayNamePlural: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_plural'],
      ),
      servingDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_description'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      instructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions'],
      ),
      nutritionalInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nutritional_info'],
      ),
      servingUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_unit'],
      ),
      servingUnitPlural: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_unit_plural'],
      ),
      servingQualifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_qualifier'],
      ),
      servingSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_size'],
      ),
      productTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_type_id'],
      ),
      purchaseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_url'],
      ),
      affiliateSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}affiliate_source'],
      ),
      preferencePriority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preference_priority'],
      ),
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

  /// Categories: array of category_enum values (e.g., ['before_run', 'during_run'])
  final String? categories;

  /// Activity types: array of activity_type_enum values (e.g., ['running', 'cycling'])
  final String? activityTypes;
  final int? sodiumMg;
  final int? caffeineMg;
  final int? potassiumMg;
  final double? fatPerServing;
  final double? carbsPerServing;
  final double? proteinPerServing;
  final int? caloriesPerServing;
  final double? fluidMlPerServing;
  final bool showInPreferences;
  final bool isElectrolyte;
  final bool toExcludeFromSolver;
  final bool isEssential;
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
  final String? productTypeId;
  final String? purchaseUrl;
  final String? affiliateSource;
  final int? preferencePriority;
  const FoodEntry({
    required this.id,
    this.name,
    this.imageAddress,
    required this.createdAt,
    this.servingAmount,
    this.maxServingsBefore,
    this.maxServingsDuring,
    this.maxServingsAfter,
    this.categories,
    this.activityTypes,
    this.sodiumMg,
    this.caffeineMg,
    this.potassiumMg,
    this.fatPerServing,
    this.carbsPerServing,
    this.proteinPerServing,
    this.caloriesPerServing,
    this.fluidMlPerServing,
    required this.showInPreferences,
    required this.isElectrolyte,
    required this.toExcludeFromSolver,
    required this.isEssential,
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
    this.productTypeId,
    this.purchaseUrl,
    this.affiliateSource,
    this.preferencePriority,
  });
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
    if (!nullToAbsent || categories != null) {
      map['categories'] = Variable<String>(categories);
    }
    if (!nullToAbsent || activityTypes != null) {
      map['activity_types'] = Variable<String>(activityTypes);
    }
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
    map['show_in_preferences'] = Variable<bool>(showInPreferences);
    map['is_electrolyte'] = Variable<bool>(isElectrolyte);
    map['to_exclude_from_solver'] = Variable<bool>(toExcludeFromSolver);
    map['is_essential'] = Variable<bool>(isEssential);
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
    if (!nullToAbsent || productTypeId != null) {
      map['product_type_id'] = Variable<String>(productTypeId);
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
      categories: categories == null && nullToAbsent
          ? const Value.absent()
          : Value(categories),
      activityTypes: activityTypes == null && nullToAbsent
          ? const Value.absent()
          : Value(activityTypes),
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
      showInPreferences: Value(showInPreferences),
      isElectrolyte: Value(isElectrolyte),
      toExcludeFromSolver: Value(toExcludeFromSolver),
      isEssential: Value(isEssential),
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
      productTypeId: productTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(productTypeId),
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

  factory FoodEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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
      categories: serializer.fromJson<String?>(json['categories']),
      activityTypes: serializer.fromJson<String?>(json['activityTypes']),
      sodiumMg: serializer.fromJson<int?>(json['sodiumMg']),
      caffeineMg: serializer.fromJson<int?>(json['caffeineMg']),
      potassiumMg: serializer.fromJson<int?>(json['potassiumMg']),
      fatPerServing: serializer.fromJson<double?>(json['fatPerServing']),
      carbsPerServing: serializer.fromJson<double?>(json['carbsPerServing']),
      proteinPerServing: serializer.fromJson<double?>(
        json['proteinPerServing'],
      ),
      caloriesPerServing: serializer.fromJson<int?>(json['caloriesPerServing']),
      fluidMlPerServing: serializer.fromJson<double?>(
        json['fluidMlPerServing'],
      ),
      showInPreferences: serializer.fromJson<bool>(json['showInPreferences']),
      isElectrolyte: serializer.fromJson<bool>(json['isElectrolyte']),
      toExcludeFromSolver: serializer.fromJson<bool>(
        json['toExcludeFromSolver'],
      ),
      isEssential: serializer.fromJson<bool>(json['isEssential']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      displayNamePlural: serializer.fromJson<String?>(
        json['displayNamePlural'],
      ),
      servingDescription: serializer.fromJson<String?>(
        json['servingDescription'],
      ),
      description: serializer.fromJson<String?>(json['description']),
      instructions: serializer.fromJson<String?>(json['instructions']),
      nutritionalInfo: serializer.fromJson<String?>(json['nutritionalInfo']),
      servingUnit: serializer.fromJson<String?>(json['servingUnit']),
      servingUnitPlural: serializer.fromJson<String?>(
        json['servingUnitPlural'],
      ),
      servingQualifier: serializer.fromJson<String?>(json['servingQualifier']),
      servingSize: serializer.fromJson<String?>(json['servingSize']),
      productTypeId: serializer.fromJson<String?>(json['productTypeId']),
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
      'categories': serializer.toJson<String?>(categories),
      'activityTypes': serializer.toJson<String?>(activityTypes),
      'sodiumMg': serializer.toJson<int?>(sodiumMg),
      'caffeineMg': serializer.toJson<int?>(caffeineMg),
      'potassiumMg': serializer.toJson<int?>(potassiumMg),
      'fatPerServing': serializer.toJson<double?>(fatPerServing),
      'carbsPerServing': serializer.toJson<double?>(carbsPerServing),
      'proteinPerServing': serializer.toJson<double?>(proteinPerServing),
      'caloriesPerServing': serializer.toJson<int?>(caloriesPerServing),
      'fluidMlPerServing': serializer.toJson<double?>(fluidMlPerServing),
      'showInPreferences': serializer.toJson<bool>(showInPreferences),
      'isElectrolyte': serializer.toJson<bool>(isElectrolyte),
      'toExcludeFromSolver': serializer.toJson<bool>(toExcludeFromSolver),
      'isEssential': serializer.toJson<bool>(isEssential),
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
      'productTypeId': serializer.toJson<String?>(productTypeId),
      'purchaseUrl': serializer.toJson<String?>(purchaseUrl),
      'affiliateSource': serializer.toJson<String?>(affiliateSource),
      'preferencePriority': serializer.toJson<int?>(preferencePriority),
    };
  }

  FoodEntry copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    Value<String?> imageAddress = const Value.absent(),
    DateTime? createdAt,
    Value<double?> servingAmount = const Value.absent(),
    Value<int?> maxServingsBefore = const Value.absent(),
    Value<int?> maxServingsDuring = const Value.absent(),
    Value<int?> maxServingsAfter = const Value.absent(),
    Value<String?> categories = const Value.absent(),
    Value<String?> activityTypes = const Value.absent(),
    Value<int?> sodiumMg = const Value.absent(),
    Value<int?> caffeineMg = const Value.absent(),
    Value<int?> potassiumMg = const Value.absent(),
    Value<double?> fatPerServing = const Value.absent(),
    Value<double?> carbsPerServing = const Value.absent(),
    Value<double?> proteinPerServing = const Value.absent(),
    Value<int?> caloriesPerServing = const Value.absent(),
    Value<double?> fluidMlPerServing = const Value.absent(),
    bool? showInPreferences,
    bool? isElectrolyte,
    bool? toExcludeFromSolver,
    bool? isEssential,
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
    Value<String?> productTypeId = const Value.absent(),
    Value<String?> purchaseUrl = const Value.absent(),
    Value<String?> affiliateSource = const Value.absent(),
    Value<int?> preferencePriority = const Value.absent(),
  }) => FoodEntry(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    imageAddress: imageAddress.present ? imageAddress.value : this.imageAddress,
    createdAt: createdAt ?? this.createdAt,
    servingAmount: servingAmount.present
        ? servingAmount.value
        : this.servingAmount,
    maxServingsBefore: maxServingsBefore.present
        ? maxServingsBefore.value
        : this.maxServingsBefore,
    maxServingsDuring: maxServingsDuring.present
        ? maxServingsDuring.value
        : this.maxServingsDuring,
    maxServingsAfter: maxServingsAfter.present
        ? maxServingsAfter.value
        : this.maxServingsAfter,
    categories: categories.present ? categories.value : this.categories,
    activityTypes: activityTypes.present
        ? activityTypes.value
        : this.activityTypes,
    sodiumMg: sodiumMg.present ? sodiumMg.value : this.sodiumMg,
    caffeineMg: caffeineMg.present ? caffeineMg.value : this.caffeineMg,
    potassiumMg: potassiumMg.present ? potassiumMg.value : this.potassiumMg,
    fatPerServing: fatPerServing.present
        ? fatPerServing.value
        : this.fatPerServing,
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
    showInPreferences: showInPreferences ?? this.showInPreferences,
    isElectrolyte: isElectrolyte ?? this.isElectrolyte,
    toExcludeFromSolver: toExcludeFromSolver ?? this.toExcludeFromSolver,
    isEssential: isEssential ?? this.isEssential,
    displayName: displayName.present ? displayName.value : this.displayName,
    displayNamePlural: displayNamePlural.present
        ? displayNamePlural.value
        : this.displayNamePlural,
    servingDescription: servingDescription.present
        ? servingDescription.value
        : this.servingDescription,
    description: description.present ? description.value : this.description,
    instructions: instructions.present ? instructions.value : this.instructions,
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
    productTypeId: productTypeId.present
        ? productTypeId.value
        : this.productTypeId,
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
      categories: data.categories.present
          ? data.categories.value
          : this.categories,
      activityTypes: data.activityTypes.present
          ? data.activityTypes.value
          : this.activityTypes,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
      caffeineMg: data.caffeineMg.present
          ? data.caffeineMg.value
          : this.caffeineMg,
      potassiumMg: data.potassiumMg.present
          ? data.potassiumMg.value
          : this.potassiumMg,
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
      showInPreferences: data.showInPreferences.present
          ? data.showInPreferences.value
          : this.showInPreferences,
      isElectrolyte: data.isElectrolyte.present
          ? data.isElectrolyte.value
          : this.isElectrolyte,
      toExcludeFromSolver: data.toExcludeFromSolver.present
          ? data.toExcludeFromSolver.value
          : this.toExcludeFromSolver,
      isEssential: data.isEssential.present
          ? data.isEssential.value
          : this.isEssential,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      displayNamePlural: data.displayNamePlural.present
          ? data.displayNamePlural.value
          : this.displayNamePlural,
      servingDescription: data.servingDescription.present
          ? data.servingDescription.value
          : this.servingDescription,
      description: data.description.present
          ? data.description.value
          : this.description,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      nutritionalInfo: data.nutritionalInfo.present
          ? data.nutritionalInfo.value
          : this.nutritionalInfo,
      servingUnit: data.servingUnit.present
          ? data.servingUnit.value
          : this.servingUnit,
      servingUnitPlural: data.servingUnitPlural.present
          ? data.servingUnitPlural.value
          : this.servingUnitPlural,
      servingQualifier: data.servingQualifier.present
          ? data.servingQualifier.value
          : this.servingQualifier,
      servingSize: data.servingSize.present
          ? data.servingSize.value
          : this.servingSize,
      productTypeId: data.productTypeId.present
          ? data.productTypeId.value
          : this.productTypeId,
      purchaseUrl: data.purchaseUrl.present
          ? data.purchaseUrl.value
          : this.purchaseUrl,
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
          ..write('categories: $categories, ')
          ..write('activityTypes: $activityTypes, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('caffeineMg: $caffeineMg, ')
          ..write('potassiumMg: $potassiumMg, ')
          ..write('fatPerServing: $fatPerServing, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('proteinPerServing: $proteinPerServing, ')
          ..write('caloriesPerServing: $caloriesPerServing, ')
          ..write('fluidMlPerServing: $fluidMlPerServing, ')
          ..write('showInPreferences: $showInPreferences, ')
          ..write('isElectrolyte: $isElectrolyte, ')
          ..write('toExcludeFromSolver: $toExcludeFromSolver, ')
          ..write('isEssential: $isEssential, ')
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
          ..write('productTypeId: $productTypeId, ')
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
    categories,
    activityTypes,
    sodiumMg,
    caffeineMg,
    potassiumMg,
    fatPerServing,
    carbsPerServing,
    proteinPerServing,
    caloriesPerServing,
    fluidMlPerServing,
    showInPreferences,
    isElectrolyte,
    toExcludeFromSolver,
    isEssential,
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
    productTypeId,
    purchaseUrl,
    affiliateSource,
    preferencePriority,
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
          other.categories == this.categories &&
          other.activityTypes == this.activityTypes &&
          other.sodiumMg == this.sodiumMg &&
          other.caffeineMg == this.caffeineMg &&
          other.potassiumMg == this.potassiumMg &&
          other.fatPerServing == this.fatPerServing &&
          other.carbsPerServing == this.carbsPerServing &&
          other.proteinPerServing == this.proteinPerServing &&
          other.caloriesPerServing == this.caloriesPerServing &&
          other.fluidMlPerServing == this.fluidMlPerServing &&
          other.showInPreferences == this.showInPreferences &&
          other.isElectrolyte == this.isElectrolyte &&
          other.toExcludeFromSolver == this.toExcludeFromSolver &&
          other.isEssential == this.isEssential &&
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
          other.productTypeId == this.productTypeId &&
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
  final Value<String?> categories;
  final Value<String?> activityTypes;
  final Value<int?> sodiumMg;
  final Value<int?> caffeineMg;
  final Value<int?> potassiumMg;
  final Value<double?> fatPerServing;
  final Value<double?> carbsPerServing;
  final Value<double?> proteinPerServing;
  final Value<int?> caloriesPerServing;
  final Value<double?> fluidMlPerServing;
  final Value<bool> showInPreferences;
  final Value<bool> isElectrolyte;
  final Value<bool> toExcludeFromSolver;
  final Value<bool> isEssential;
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
  final Value<String?> productTypeId;
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
    this.categories = const Value.absent(),
    this.activityTypes = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.caffeineMg = const Value.absent(),
    this.potassiumMg = const Value.absent(),
    this.fatPerServing = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.proteinPerServing = const Value.absent(),
    this.caloriesPerServing = const Value.absent(),
    this.fluidMlPerServing = const Value.absent(),
    this.showInPreferences = const Value.absent(),
    this.isElectrolyte = const Value.absent(),
    this.toExcludeFromSolver = const Value.absent(),
    this.isEssential = const Value.absent(),
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
    this.productTypeId = const Value.absent(),
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
    this.categories = const Value.absent(),
    this.activityTypes = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.caffeineMg = const Value.absent(),
    this.potassiumMg = const Value.absent(),
    this.fatPerServing = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.proteinPerServing = const Value.absent(),
    this.caloriesPerServing = const Value.absent(),
    this.fluidMlPerServing = const Value.absent(),
    this.showInPreferences = const Value.absent(),
    this.isElectrolyte = const Value.absent(),
    this.toExcludeFromSolver = const Value.absent(),
    this.isEssential = const Value.absent(),
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
    this.productTypeId = const Value.absent(),
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
    Expression<String>? categories,
    Expression<String>? activityTypes,
    Expression<int>? sodiumMg,
    Expression<int>? caffeineMg,
    Expression<int>? potassiumMg,
    Expression<double>? fatPerServing,
    Expression<double>? carbsPerServing,
    Expression<double>? proteinPerServing,
    Expression<int>? caloriesPerServing,
    Expression<double>? fluidMlPerServing,
    Expression<bool>? showInPreferences,
    Expression<bool>? isElectrolyte,
    Expression<bool>? toExcludeFromSolver,
    Expression<bool>? isEssential,
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
    Expression<String>? productTypeId,
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
      if (categories != null) 'categories': categories,
      if (activityTypes != null) 'activity_types': activityTypes,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (caffeineMg != null) 'caffeine_mg': caffeineMg,
      if (potassiumMg != null) 'potassium_mg': potassiumMg,
      if (fatPerServing != null) 'fat_per_serving': fatPerServing,
      if (carbsPerServing != null) 'carbs_per_serving': carbsPerServing,
      if (proteinPerServing != null) 'protein_per_serving': proteinPerServing,
      if (caloriesPerServing != null)
        'calories_per_serving': caloriesPerServing,
      if (fluidMlPerServing != null) 'fluid_ml_per_serving': fluidMlPerServing,
      if (showInPreferences != null) 'show_in_preferences': showInPreferences,
      if (isElectrolyte != null) 'is_electrolyte': isElectrolyte,
      if (toExcludeFromSolver != null)
        'to_exclude_from_solver': toExcludeFromSolver,
      if (isEssential != null) 'is_essential': isEssential,
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
      if (productTypeId != null) 'product_type_id': productTypeId,
      if (purchaseUrl != null) 'purchase_url': purchaseUrl,
      if (affiliateSource != null) 'affiliate_source': affiliateSource,
      if (preferencePriority != null) 'preference_priority': preferencePriority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<String?>? imageAddress,
    Value<DateTime>? createdAt,
    Value<double?>? servingAmount,
    Value<int?>? maxServingsBefore,
    Value<int?>? maxServingsDuring,
    Value<int?>? maxServingsAfter,
    Value<String?>? categories,
    Value<String?>? activityTypes,
    Value<int?>? sodiumMg,
    Value<int?>? caffeineMg,
    Value<int?>? potassiumMg,
    Value<double?>? fatPerServing,
    Value<double?>? carbsPerServing,
    Value<double?>? proteinPerServing,
    Value<int?>? caloriesPerServing,
    Value<double?>? fluidMlPerServing,
    Value<bool>? showInPreferences,
    Value<bool>? isElectrolyte,
    Value<bool>? toExcludeFromSolver,
    Value<bool>? isEssential,
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
    Value<String?>? productTypeId,
    Value<String?>? purchaseUrl,
    Value<String?>? affiliateSource,
    Value<int?>? preferencePriority,
    Value<int>? rowid,
  }) {
    return FoodsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      imageAddress: imageAddress ?? this.imageAddress,
      createdAt: createdAt ?? this.createdAt,
      servingAmount: servingAmount ?? this.servingAmount,
      maxServingsBefore: maxServingsBefore ?? this.maxServingsBefore,
      maxServingsDuring: maxServingsDuring ?? this.maxServingsDuring,
      maxServingsAfter: maxServingsAfter ?? this.maxServingsAfter,
      categories: categories ?? this.categories,
      activityTypes: activityTypes ?? this.activityTypes,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      caffeineMg: caffeineMg ?? this.caffeineMg,
      potassiumMg: potassiumMg ?? this.potassiumMg,
      fatPerServing: fatPerServing ?? this.fatPerServing,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      proteinPerServing: proteinPerServing ?? this.proteinPerServing,
      caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
      fluidMlPerServing: fluidMlPerServing ?? this.fluidMlPerServing,
      showInPreferences: showInPreferences ?? this.showInPreferences,
      isElectrolyte: isElectrolyte ?? this.isElectrolyte,
      toExcludeFromSolver: toExcludeFromSolver ?? this.toExcludeFromSolver,
      isEssential: isEssential ?? this.isEssential,
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
      productTypeId: productTypeId ?? this.productTypeId,
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
    if (categories.present) {
      map['categories'] = Variable<String>(categories.value);
    }
    if (activityTypes.present) {
      map['activity_types'] = Variable<String>(activityTypes.value);
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
    if (showInPreferences.present) {
      map['show_in_preferences'] = Variable<bool>(showInPreferences.value);
    }
    if (isElectrolyte.present) {
      map['is_electrolyte'] = Variable<bool>(isElectrolyte.value);
    }
    if (toExcludeFromSolver.present) {
      map['to_exclude_from_solver'] = Variable<bool>(toExcludeFromSolver.value);
    }
    if (isEssential.present) {
      map['is_essential'] = Variable<bool>(isEssential.value);
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
    if (productTypeId.present) {
      map['product_type_id'] = Variable<String>(productTypeId.value);
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
          ..write('categories: $categories, ')
          ..write('activityTypes: $activityTypes, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('caffeineMg: $caffeineMg, ')
          ..write('potassiumMg: $potassiumMg, ')
          ..write('fatPerServing: $fatPerServing, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('proteinPerServing: $proteinPerServing, ')
          ..write('caloriesPerServing: $caloriesPerServing, ')
          ..write('fluidMlPerServing: $fluidMlPerServing, ')
          ..write('showInPreferences: $showInPreferences, ')
          ..write('isElectrolyte: $isElectrolyte, ')
          ..write('toExcludeFromSolver: $toExcludeFromSolver, ')
          ..write('isEssential: $isEssential, ')
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
          ..write('productTypeId: $productTypeId, ')
          ..write('purchaseUrl: $purchaseUrl, ')
          ..write('affiliateSource: $affiliateSource, ')
          ..write('preferencePriority: $preferencePriority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserFoodsTableTable extends UserFoodsTable
    with TableInfo<$UserFoodsTableTable, UserFood> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserFoodsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientFoodIdMeta = const VerificationMeta(
    'clientFoodId',
  );
  @override
  late final GeneratedColumn<String> clientFoodId = GeneratedColumn<String>(
    'client_food_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNamePluralMeta = const VerificationMeta(
    'displayNamePlural',
  );
  @override
  late final GeneratedColumn<String> displayNamePlural =
      GeneratedColumn<String>(
        'display_name_plural',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAddressMeta = const VerificationMeta(
    'imageAddress',
  );
  @override
  late final GeneratedColumn<String> imageAddress = GeneratedColumn<String>(
    'image_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingAmountMeta = const VerificationMeta(
    'servingAmount',
  );
  @override
  late final GeneratedColumn<double> servingAmount = GeneratedColumn<double>(
    'serving_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingUnitMeta = const VerificationMeta(
    'servingUnit',
  );
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
    'serving_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriesPerServingMeta =
      const VerificationMeta('caloriesPerServing');
  @override
  late final GeneratedColumn<int> caloriesPerServing = GeneratedColumn<int>(
    'calories_per_serving',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsPerServingMeta = const VerificationMeta(
    'carbsPerServing',
  );
  @override
  late final GeneratedColumn<double> carbsPerServing = GeneratedColumn<double>(
    'carbs_per_serving',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinPerServingMeta = const VerificationMeta(
    'proteinPerServing',
  );
  @override
  late final GeneratedColumn<double> proteinPerServing =
      GeneratedColumn<double>(
        'protein_per_serving',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fatPerServingMeta = const VerificationMeta(
    'fatPerServing',
  );
  @override
  late final GeneratedColumn<double> fatPerServing = GeneratedColumn<double>(
    'fat_per_serving',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sodiumMgMeta = const VerificationMeta(
    'sodiumMg',
  );
  @override
  late final GeneratedColumn<int> sodiumMg = GeneratedColumn<int>(
    'sodium_mg',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fluidMlPerServingMeta = const VerificationMeta(
    'fluidMlPerServing',
  );
  @override
  late final GeneratedColumn<double> fluidMlPerServing =
      GeneratedColumn<double>(
        'fluid_ml_per_serving',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _productTypeIdMeta = const VerificationMeta(
    'productTypeId',
  );
  @override
  late final GeneratedColumn<String> productTypeId = GeneratedColumn<String>(
    'product_type_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesMeta = const VerificationMeta(
    'categories',
  );
  @override
  late final GeneratedColumn<String> categories = GeneratedColumn<String>(
    'categories',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityTypesMeta = const VerificationMeta(
    'activityTypes',
  );
  @override
  late final GeneratedColumn<String> activityTypes = GeneratedColumn<String>(
    'activity_types',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isElectrolyteMeta = const VerificationMeta(
    'isElectrolyte',
  );
  @override
  late final GeneratedColumn<bool> isElectrolyte = GeneratedColumn<bool>(
    'is_electrolyte',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_electrolyte" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _toExcludeFromSolverMeta =
      const VerificationMeta('toExcludeFromSolver');
  @override
  late final GeneratedColumn<bool> toExcludeFromSolver = GeneratedColumn<bool>(
    'to_exclude_from_solver',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("to_exclude_from_solver" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>(
        'client_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    userId,
    clientFoodId,
    barcode,
    name,
    displayName,
    displayNamePlural,
    description,
    imageAddress,
    servingAmount,
    servingUnit,
    caloriesPerServing,
    carbsPerServing,
    proteinPerServing,
    fatPerServing,
    sodiumMg,
    fluidMlPerServing,
    productTypeId,
    categories,
    activityTypes,
    isElectrolyte,
    toExcludeFromSolver,
    isDeleted,
    createdAt,
    updatedAt,
    clientUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_foods_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserFood> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('client_food_id')) {
      context.handle(
        _clientFoodIdMeta,
        clientFoodId.isAcceptableOrUnknown(
          data['client_food_id']!,
          _clientFoodIdMeta,
        ),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('display_name_plural')) {
      context.handle(
        _displayNamePluralMeta,
        displayNamePlural.isAcceptableOrUnknown(
          data['display_name_plural']!,
          _displayNamePluralMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('image_address')) {
      context.handle(
        _imageAddressMeta,
        imageAddress.isAcceptableOrUnknown(
          data['image_address']!,
          _imageAddressMeta,
        ),
      );
    }
    if (data.containsKey('serving_amount')) {
      context.handle(
        _servingAmountMeta,
        servingAmount.isAcceptableOrUnknown(
          data['serving_amount']!,
          _servingAmountMeta,
        ),
      );
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
        _servingUnitMeta,
        servingUnit.isAcceptableOrUnknown(
          data['serving_unit']!,
          _servingUnitMeta,
        ),
      );
    }
    if (data.containsKey('calories_per_serving')) {
      context.handle(
        _caloriesPerServingMeta,
        caloriesPerServing.isAcceptableOrUnknown(
          data['calories_per_serving']!,
          _caloriesPerServingMeta,
        ),
      );
    }
    if (data.containsKey('carbs_per_serving')) {
      context.handle(
        _carbsPerServingMeta,
        carbsPerServing.isAcceptableOrUnknown(
          data['carbs_per_serving']!,
          _carbsPerServingMeta,
        ),
      );
    }
    if (data.containsKey('protein_per_serving')) {
      context.handle(
        _proteinPerServingMeta,
        proteinPerServing.isAcceptableOrUnknown(
          data['protein_per_serving']!,
          _proteinPerServingMeta,
        ),
      );
    }
    if (data.containsKey('fat_per_serving')) {
      context.handle(
        _fatPerServingMeta,
        fatPerServing.isAcceptableOrUnknown(
          data['fat_per_serving']!,
          _fatPerServingMeta,
        ),
      );
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(
        _sodiumMgMeta,
        sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta),
      );
    }
    if (data.containsKey('fluid_ml_per_serving')) {
      context.handle(
        _fluidMlPerServingMeta,
        fluidMlPerServing.isAcceptableOrUnknown(
          data['fluid_ml_per_serving']!,
          _fluidMlPerServingMeta,
        ),
      );
    }
    if (data.containsKey('product_type_id')) {
      context.handle(
        _productTypeIdMeta,
        productTypeId.isAcceptableOrUnknown(
          data['product_type_id']!,
          _productTypeIdMeta,
        ),
      );
    }
    if (data.containsKey('categories')) {
      context.handle(
        _categoriesMeta,
        categories.isAcceptableOrUnknown(data['categories']!, _categoriesMeta),
      );
    }
    if (data.containsKey('activity_types')) {
      context.handle(
        _activityTypesMeta,
        activityTypes.isAcceptableOrUnknown(
          data['activity_types']!,
          _activityTypesMeta,
        ),
      );
    }
    if (data.containsKey('is_electrolyte')) {
      context.handle(
        _isElectrolyteMeta,
        isElectrolyte.isAcceptableOrUnknown(
          data['is_electrolyte']!,
          _isElectrolyteMeta,
        ),
      );
    }
    if (data.containsKey('to_exclude_from_solver')) {
      context.handle(
        _toExcludeFromSolverMeta,
        toExcludeFromSolver.isAcceptableOrUnknown(
          data['to_exclude_from_solver']!,
          _toExcludeFromSolverMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
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
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserFood map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserFood(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      clientFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_food_id'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      displayNamePlural: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_plural'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      imageAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_address'],
      ),
      servingAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_amount'],
      ),
      servingUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_unit'],
      ),
      caloriesPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories_per_serving'],
      ),
      carbsPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per_serving'],
      ),
      proteinPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_per_serving'],
      ),
      fatPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_per_serving'],
      ),
      sodiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sodium_mg'],
      ),
      fluidMlPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fluid_ml_per_serving'],
      ),
      productTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_type_id'],
      ),
      categories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories'],
      ),
      activityTypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_types'],
      ),
      isElectrolyte: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_electrolyte'],
      )!,
      toExcludeFromSolver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}to_exclude_from_solver'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_updated_at'],
      ),
    );
  }

  @override
  $UserFoodsTableTable createAlias(String alias) {
    return $UserFoodsTableTable(attachedDatabase, alias);
  }
}

class UserFood extends DataClass implements Insertable<UserFood> {
  /// UUID primary key (matches Supabase user_foods.id)
  final String id;

  /// Device ID of the user who created this food (matches Supabase user_foods.device_id)
  final String deviceId;

  /// User ID (UUID) - references users.id (matches Supabase user_foods.user_id)
  final String userId;

  /// Client-generated food ID for offline sync (matches Supabase user_foods.client_food_id)
  final String? clientFoodId;

  /// Barcode if scanned (matches Supabase user_foods.barcode)
  final String? barcode;

  /// Food name (matches Supabase user_foods.name)
  final String name;

  /// Display names (matches Supabase user_foods.display_name and display_name_plural)
  final String? displayName;
  final String? displayNamePlural;

  /// Description (matches Supabase user_foods.description)
  final String? description;

  /// Image URL (matches Supabase user_foods.image_address)
  final String? imageAddress;

  /// Serving information (matches Supabase user_foods.serving_amount and serving_unit)
  final double? servingAmount;
  final String? servingUnit;

  /// Nutritional values per serving (matches Supabase user_foods)
  final int? caloriesPerServing;
  final double? carbsPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final int? sodiumMg;
  final double? fluidMlPerServing;

  /// Product type reference (matches Supabase user_foods.product_type_id)
  final String? productTypeId;

  /// Categories: array of category_enum values (e.g., ['before_run', 'during_run'])
  final String? categories;

  /// Activity types: array of activity_type_enum values (e.g., ['running', 'cycling'])
  final String? activityTypes;

  /// Flags (matches Supabase user_foods)
  final bool isElectrolyte;
  final bool toExcludeFromSolver;
  final bool isDeleted;

  /// Timestamps (matches Supabase user_foods)
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? clientUpdatedAt;
  const UserFood({
    required this.id,
    required this.deviceId,
    required this.userId,
    this.clientFoodId,
    this.barcode,
    required this.name,
    this.displayName,
    this.displayNamePlural,
    this.description,
    this.imageAddress,
    this.servingAmount,
    this.servingUnit,
    this.caloriesPerServing,
    this.carbsPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.sodiumMg,
    this.fluidMlPerServing,
    this.productTypeId,
    this.categories,
    this.activityTypes,
    required this.isElectrolyte,
    required this.toExcludeFromSolver,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.clientUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || clientFoodId != null) {
      map['client_food_id'] = Variable<String>(clientFoodId);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || displayNamePlural != null) {
      map['display_name_plural'] = Variable<String>(displayNamePlural);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || imageAddress != null) {
      map['image_address'] = Variable<String>(imageAddress);
    }
    if (!nullToAbsent || servingAmount != null) {
      map['serving_amount'] = Variable<double>(servingAmount);
    }
    if (!nullToAbsent || servingUnit != null) {
      map['serving_unit'] = Variable<String>(servingUnit);
    }
    if (!nullToAbsent || caloriesPerServing != null) {
      map['calories_per_serving'] = Variable<int>(caloriesPerServing);
    }
    if (!nullToAbsent || carbsPerServing != null) {
      map['carbs_per_serving'] = Variable<double>(carbsPerServing);
    }
    if (!nullToAbsent || proteinPerServing != null) {
      map['protein_per_serving'] = Variable<double>(proteinPerServing);
    }
    if (!nullToAbsent || fatPerServing != null) {
      map['fat_per_serving'] = Variable<double>(fatPerServing);
    }
    if (!nullToAbsent || sodiumMg != null) {
      map['sodium_mg'] = Variable<int>(sodiumMg);
    }
    if (!nullToAbsent || fluidMlPerServing != null) {
      map['fluid_ml_per_serving'] = Variable<double>(fluidMlPerServing);
    }
    if (!nullToAbsent || productTypeId != null) {
      map['product_type_id'] = Variable<String>(productTypeId);
    }
    if (!nullToAbsent || categories != null) {
      map['categories'] = Variable<String>(categories);
    }
    if (!nullToAbsent || activityTypes != null) {
      map['activity_types'] = Variable<String>(activityTypes);
    }
    map['is_electrolyte'] = Variable<bool>(isElectrolyte);
    map['to_exclude_from_solver'] = Variable<bool>(toExcludeFromSolver);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt);
    }
    return map;
  }

  UserFoodsTableCompanion toCompanion(bool nullToAbsent) {
    return UserFoodsTableCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      userId: Value(userId),
      clientFoodId: clientFoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientFoodId),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      name: Value(name),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      displayNamePlural: displayNamePlural == null && nullToAbsent
          ? const Value.absent()
          : Value(displayNamePlural),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      imageAddress: imageAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAddress),
      servingAmount: servingAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(servingAmount),
      servingUnit: servingUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(servingUnit),
      caloriesPerServing: caloriesPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriesPerServing),
      carbsPerServing: carbsPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(carbsPerServing),
      proteinPerServing: proteinPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinPerServing),
      fatPerServing: fatPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(fatPerServing),
      sodiumMg: sodiumMg == null && nullToAbsent
          ? const Value.absent()
          : Value(sodiumMg),
      fluidMlPerServing: fluidMlPerServing == null && nullToAbsent
          ? const Value.absent()
          : Value(fluidMlPerServing),
      productTypeId: productTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(productTypeId),
      categories: categories == null && nullToAbsent
          ? const Value.absent()
          : Value(categories),
      activityTypes: activityTypes == null && nullToAbsent
          ? const Value.absent()
          : Value(activityTypes),
      isElectrolyte: Value(isElectrolyte),
      toExcludeFromSolver: Value(toExcludeFromSolver),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
    );
  }

  factory UserFood.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserFood(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      clientFoodId: serializer.fromJson<String?>(json['clientFoodId']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      displayNamePlural: serializer.fromJson<String?>(
        json['displayNamePlural'],
      ),
      description: serializer.fromJson<String?>(json['description']),
      imageAddress: serializer.fromJson<String?>(json['imageAddress']),
      servingAmount: serializer.fromJson<double?>(json['servingAmount']),
      servingUnit: serializer.fromJson<String?>(json['servingUnit']),
      caloriesPerServing: serializer.fromJson<int?>(json['caloriesPerServing']),
      carbsPerServing: serializer.fromJson<double?>(json['carbsPerServing']),
      proteinPerServing: serializer.fromJson<double?>(
        json['proteinPerServing'],
      ),
      fatPerServing: serializer.fromJson<double?>(json['fatPerServing']),
      sodiumMg: serializer.fromJson<int?>(json['sodiumMg']),
      fluidMlPerServing: serializer.fromJson<double?>(
        json['fluidMlPerServing'],
      ),
      productTypeId: serializer.fromJson<String?>(json['productTypeId']),
      categories: serializer.fromJson<String?>(json['categories']),
      activityTypes: serializer.fromJson<String?>(json['activityTypes']),
      isElectrolyte: serializer.fromJson<bool>(json['isElectrolyte']),
      toExcludeFromSolver: serializer.fromJson<bool>(
        json['toExcludeFromSolver'],
      ),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      clientUpdatedAt: serializer.fromJson<DateTime?>(json['clientUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'clientFoodId': serializer.toJson<String?>(clientFoodId),
      'barcode': serializer.toJson<String?>(barcode),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String?>(displayName),
      'displayNamePlural': serializer.toJson<String?>(displayNamePlural),
      'description': serializer.toJson<String?>(description),
      'imageAddress': serializer.toJson<String?>(imageAddress),
      'servingAmount': serializer.toJson<double?>(servingAmount),
      'servingUnit': serializer.toJson<String?>(servingUnit),
      'caloriesPerServing': serializer.toJson<int?>(caloriesPerServing),
      'carbsPerServing': serializer.toJson<double?>(carbsPerServing),
      'proteinPerServing': serializer.toJson<double?>(proteinPerServing),
      'fatPerServing': serializer.toJson<double?>(fatPerServing),
      'sodiumMg': serializer.toJson<int?>(sodiumMg),
      'fluidMlPerServing': serializer.toJson<double?>(fluidMlPerServing),
      'productTypeId': serializer.toJson<String?>(productTypeId),
      'categories': serializer.toJson<String?>(categories),
      'activityTypes': serializer.toJson<String?>(activityTypes),
      'isElectrolyte': serializer.toJson<bool>(isElectrolyte),
      'toExcludeFromSolver': serializer.toJson<bool>(toExcludeFromSolver),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'clientUpdatedAt': serializer.toJson<DateTime?>(clientUpdatedAt),
    };
  }

  UserFood copyWith({
    String? id,
    String? deviceId,
    String? userId,
    Value<String?> clientFoodId = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    String? name,
    Value<String?> displayName = const Value.absent(),
    Value<String?> displayNamePlural = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> imageAddress = const Value.absent(),
    Value<double?> servingAmount = const Value.absent(),
    Value<String?> servingUnit = const Value.absent(),
    Value<int?> caloriesPerServing = const Value.absent(),
    Value<double?> carbsPerServing = const Value.absent(),
    Value<double?> proteinPerServing = const Value.absent(),
    Value<double?> fatPerServing = const Value.absent(),
    Value<int?> sodiumMg = const Value.absent(),
    Value<double?> fluidMlPerServing = const Value.absent(),
    Value<String?> productTypeId = const Value.absent(),
    Value<String?> categories = const Value.absent(),
    Value<String?> activityTypes = const Value.absent(),
    bool? isElectrolyte,
    bool? toExcludeFromSolver,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> clientUpdatedAt = const Value.absent(),
  }) => UserFood(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    userId: userId ?? this.userId,
    clientFoodId: clientFoodId.present ? clientFoodId.value : this.clientFoodId,
    barcode: barcode.present ? barcode.value : this.barcode,
    name: name ?? this.name,
    displayName: displayName.present ? displayName.value : this.displayName,
    displayNamePlural: displayNamePlural.present
        ? displayNamePlural.value
        : this.displayNamePlural,
    description: description.present ? description.value : this.description,
    imageAddress: imageAddress.present ? imageAddress.value : this.imageAddress,
    servingAmount: servingAmount.present
        ? servingAmount.value
        : this.servingAmount,
    servingUnit: servingUnit.present ? servingUnit.value : this.servingUnit,
    caloriesPerServing: caloriesPerServing.present
        ? caloriesPerServing.value
        : this.caloriesPerServing,
    carbsPerServing: carbsPerServing.present
        ? carbsPerServing.value
        : this.carbsPerServing,
    proteinPerServing: proteinPerServing.present
        ? proteinPerServing.value
        : this.proteinPerServing,
    fatPerServing: fatPerServing.present
        ? fatPerServing.value
        : this.fatPerServing,
    sodiumMg: sodiumMg.present ? sodiumMg.value : this.sodiumMg,
    fluidMlPerServing: fluidMlPerServing.present
        ? fluidMlPerServing.value
        : this.fluidMlPerServing,
    productTypeId: productTypeId.present
        ? productTypeId.value
        : this.productTypeId,
    categories: categories.present ? categories.value : this.categories,
    activityTypes: activityTypes.present
        ? activityTypes.value
        : this.activityTypes,
    isElectrolyte: isElectrolyte ?? this.isElectrolyte,
    toExcludeFromSolver: toExcludeFromSolver ?? this.toExcludeFromSolver,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    clientUpdatedAt: clientUpdatedAt.present
        ? clientUpdatedAt.value
        : this.clientUpdatedAt,
  );
  UserFood copyWithCompanion(UserFoodsTableCompanion data) {
    return UserFood(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      clientFoodId: data.clientFoodId.present
          ? data.clientFoodId.value
          : this.clientFoodId,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      displayNamePlural: data.displayNamePlural.present
          ? data.displayNamePlural.value
          : this.displayNamePlural,
      description: data.description.present
          ? data.description.value
          : this.description,
      imageAddress: data.imageAddress.present
          ? data.imageAddress.value
          : this.imageAddress,
      servingAmount: data.servingAmount.present
          ? data.servingAmount.value
          : this.servingAmount,
      servingUnit: data.servingUnit.present
          ? data.servingUnit.value
          : this.servingUnit,
      caloriesPerServing: data.caloriesPerServing.present
          ? data.caloriesPerServing.value
          : this.caloriesPerServing,
      carbsPerServing: data.carbsPerServing.present
          ? data.carbsPerServing.value
          : this.carbsPerServing,
      proteinPerServing: data.proteinPerServing.present
          ? data.proteinPerServing.value
          : this.proteinPerServing,
      fatPerServing: data.fatPerServing.present
          ? data.fatPerServing.value
          : this.fatPerServing,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
      fluidMlPerServing: data.fluidMlPerServing.present
          ? data.fluidMlPerServing.value
          : this.fluidMlPerServing,
      productTypeId: data.productTypeId.present
          ? data.productTypeId.value
          : this.productTypeId,
      categories: data.categories.present
          ? data.categories.value
          : this.categories,
      activityTypes: data.activityTypes.present
          ? data.activityTypes.value
          : this.activityTypes,
      isElectrolyte: data.isElectrolyte.present
          ? data.isElectrolyte.value
          : this.isElectrolyte,
      toExcludeFromSolver: data.toExcludeFromSolver.present
          ? data.toExcludeFromSolver.value
          : this.toExcludeFromSolver,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserFood(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('clientFoodId: $clientFoodId, ')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('description: $description, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('servingAmount: $servingAmount, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('caloriesPerServing: $caloriesPerServing, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('proteinPerServing: $proteinPerServing, ')
          ..write('fatPerServing: $fatPerServing, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('fluidMlPerServing: $fluidMlPerServing, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('categories: $categories, ')
          ..write('activityTypes: $activityTypes, ')
          ..write('isElectrolyte: $isElectrolyte, ')
          ..write('toExcludeFromSolver: $toExcludeFromSolver, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('clientUpdatedAt: $clientUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    deviceId,
    userId,
    clientFoodId,
    barcode,
    name,
    displayName,
    displayNamePlural,
    description,
    imageAddress,
    servingAmount,
    servingUnit,
    caloriesPerServing,
    carbsPerServing,
    proteinPerServing,
    fatPerServing,
    sodiumMg,
    fluidMlPerServing,
    productTypeId,
    categories,
    activityTypes,
    isElectrolyte,
    toExcludeFromSolver,
    isDeleted,
    createdAt,
    updatedAt,
    clientUpdatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserFood &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.clientFoodId == this.clientFoodId &&
          other.barcode == this.barcode &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.displayNamePlural == this.displayNamePlural &&
          other.description == this.description &&
          other.imageAddress == this.imageAddress &&
          other.servingAmount == this.servingAmount &&
          other.servingUnit == this.servingUnit &&
          other.caloriesPerServing == this.caloriesPerServing &&
          other.carbsPerServing == this.carbsPerServing &&
          other.proteinPerServing == this.proteinPerServing &&
          other.fatPerServing == this.fatPerServing &&
          other.sodiumMg == this.sodiumMg &&
          other.fluidMlPerServing == this.fluidMlPerServing &&
          other.productTypeId == this.productTypeId &&
          other.categories == this.categories &&
          other.activityTypes == this.activityTypes &&
          other.isElectrolyte == this.isElectrolyte &&
          other.toExcludeFromSolver == this.toExcludeFromSolver &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.clientUpdatedAt == this.clientUpdatedAt);
}

class UserFoodsTableCompanion extends UpdateCompanion<UserFood> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<String?> clientFoodId;
  final Value<String?> barcode;
  final Value<String> name;
  final Value<String?> displayName;
  final Value<String?> displayNamePlural;
  final Value<String?> description;
  final Value<String?> imageAddress;
  final Value<double?> servingAmount;
  final Value<String?> servingUnit;
  final Value<int?> caloriesPerServing;
  final Value<double?> carbsPerServing;
  final Value<double?> proteinPerServing;
  final Value<double?> fatPerServing;
  final Value<int?> sodiumMg;
  final Value<double?> fluidMlPerServing;
  final Value<String?> productTypeId;
  final Value<String?> categories;
  final Value<String?> activityTypes;
  final Value<bool> isElectrolyte;
  final Value<bool> toExcludeFromSolver;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> clientUpdatedAt;
  final Value<int> rowid;
  const UserFoodsTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.clientFoodId = const Value.absent(),
    this.barcode = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.displayNamePlural = const Value.absent(),
    this.description = const Value.absent(),
    this.imageAddress = const Value.absent(),
    this.servingAmount = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.caloriesPerServing = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.proteinPerServing = const Value.absent(),
    this.fatPerServing = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.fluidMlPerServing = const Value.absent(),
    this.productTypeId = const Value.absent(),
    this.categories = const Value.absent(),
    this.activityTypes = const Value.absent(),
    this.isElectrolyte = const Value.absent(),
    this.toExcludeFromSolver = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserFoodsTableCompanion.insert({
    required String id,
    required String deviceId,
    required String userId,
    this.clientFoodId = const Value.absent(),
    this.barcode = const Value.absent(),
    required String name,
    this.displayName = const Value.absent(),
    this.displayNamePlural = const Value.absent(),
    this.description = const Value.absent(),
    this.imageAddress = const Value.absent(),
    this.servingAmount = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.caloriesPerServing = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.proteinPerServing = const Value.absent(),
    this.fatPerServing = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.fluidMlPerServing = const Value.absent(),
    this.productTypeId = const Value.absent(),
    this.categories = const Value.absent(),
    this.activityTypes = const Value.absent(),
    this.isElectrolyte = const Value.absent(),
    this.toExcludeFromSolver = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       userId = Value(userId),
       name = Value(name);
  static Insertable<UserFood> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<String>? clientFoodId,
    Expression<String>? barcode,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? displayNamePlural,
    Expression<String>? description,
    Expression<String>? imageAddress,
    Expression<double>? servingAmount,
    Expression<String>? servingUnit,
    Expression<int>? caloriesPerServing,
    Expression<double>? carbsPerServing,
    Expression<double>? proteinPerServing,
    Expression<double>? fatPerServing,
    Expression<int>? sodiumMg,
    Expression<double>? fluidMlPerServing,
    Expression<String>? productTypeId,
    Expression<String>? categories,
    Expression<String>? activityTypes,
    Expression<bool>? isElectrolyte,
    Expression<bool>? toExcludeFromSolver,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? clientUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (clientFoodId != null) 'client_food_id': clientFoodId,
      if (barcode != null) 'barcode': barcode,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (displayNamePlural != null) 'display_name_plural': displayNamePlural,
      if (description != null) 'description': description,
      if (imageAddress != null) 'image_address': imageAddress,
      if (servingAmount != null) 'serving_amount': servingAmount,
      if (servingUnit != null) 'serving_unit': servingUnit,
      if (caloriesPerServing != null)
        'calories_per_serving': caloriesPerServing,
      if (carbsPerServing != null) 'carbs_per_serving': carbsPerServing,
      if (proteinPerServing != null) 'protein_per_serving': proteinPerServing,
      if (fatPerServing != null) 'fat_per_serving': fatPerServing,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (fluidMlPerServing != null) 'fluid_ml_per_serving': fluidMlPerServing,
      if (productTypeId != null) 'product_type_id': productTypeId,
      if (categories != null) 'categories': categories,
      if (activityTypes != null) 'activity_types': activityTypes,
      if (isElectrolyte != null) 'is_electrolyte': isElectrolyte,
      if (toExcludeFromSolver != null)
        'to_exclude_from_solver': toExcludeFromSolver,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserFoodsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? userId,
    Value<String?>? clientFoodId,
    Value<String?>? barcode,
    Value<String>? name,
    Value<String?>? displayName,
    Value<String?>? displayNamePlural,
    Value<String?>? description,
    Value<String?>? imageAddress,
    Value<double?>? servingAmount,
    Value<String?>? servingUnit,
    Value<int?>? caloriesPerServing,
    Value<double?>? carbsPerServing,
    Value<double?>? proteinPerServing,
    Value<double?>? fatPerServing,
    Value<int?>? sodiumMg,
    Value<double?>? fluidMlPerServing,
    Value<String?>? productTypeId,
    Value<String?>? categories,
    Value<String?>? activityTypes,
    Value<bool>? isElectrolyte,
    Value<bool>? toExcludeFromSolver,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? clientUpdatedAt,
    Value<int>? rowid,
  }) {
    return UserFoodsTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      clientFoodId: clientFoodId ?? this.clientFoodId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      description: description ?? this.description,
      imageAddress: imageAddress ?? this.imageAddress,
      servingAmount: servingAmount ?? this.servingAmount,
      servingUnit: servingUnit ?? this.servingUnit,
      caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      proteinPerServing: proteinPerServing ?? this.proteinPerServing,
      fatPerServing: fatPerServing ?? this.fatPerServing,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      fluidMlPerServing: fluidMlPerServing ?? this.fluidMlPerServing,
      productTypeId: productTypeId ?? this.productTypeId,
      categories: categories ?? this.categories,
      activityTypes: activityTypes ?? this.activityTypes,
      isElectrolyte: isElectrolyte ?? this.isElectrolyte,
      toExcludeFromSolver: toExcludeFromSolver ?? this.toExcludeFromSolver,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (clientFoodId.present) {
      map['client_food_id'] = Variable<String>(clientFoodId.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (displayNamePlural.present) {
      map['display_name_plural'] = Variable<String>(displayNamePlural.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageAddress.present) {
      map['image_address'] = Variable<String>(imageAddress.value);
    }
    if (servingAmount.present) {
      map['serving_amount'] = Variable<double>(servingAmount.value);
    }
    if (servingUnit.present) {
      map['serving_unit'] = Variable<String>(servingUnit.value);
    }
    if (caloriesPerServing.present) {
      map['calories_per_serving'] = Variable<int>(caloriesPerServing.value);
    }
    if (carbsPerServing.present) {
      map['carbs_per_serving'] = Variable<double>(carbsPerServing.value);
    }
    if (proteinPerServing.present) {
      map['protein_per_serving'] = Variable<double>(proteinPerServing.value);
    }
    if (fatPerServing.present) {
      map['fat_per_serving'] = Variable<double>(fatPerServing.value);
    }
    if (sodiumMg.present) {
      map['sodium_mg'] = Variable<int>(sodiumMg.value);
    }
    if (fluidMlPerServing.present) {
      map['fluid_ml_per_serving'] = Variable<double>(fluidMlPerServing.value);
    }
    if (productTypeId.present) {
      map['product_type_id'] = Variable<String>(productTypeId.value);
    }
    if (categories.present) {
      map['categories'] = Variable<String>(categories.value);
    }
    if (activityTypes.present) {
      map['activity_types'] = Variable<String>(activityTypes.value);
    }
    if (isElectrolyte.present) {
      map['is_electrolyte'] = Variable<bool>(isElectrolyte.value);
    }
    if (toExcludeFromSolver.present) {
      map['to_exclude_from_solver'] = Variable<bool>(toExcludeFromSolver.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserFoodsTableCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('clientFoodId: $clientFoodId, ')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('description: $description, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('servingAmount: $servingAmount, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('caloriesPerServing: $caloriesPerServing, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('proteinPerServing: $proteinPerServing, ')
          ..write('fatPerServing: $fatPerServing, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('fluidMlPerServing: $fluidMlPerServing, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('categories: $categories, ')
          ..write('activityTypes: $activityTypes, ')
          ..write('isElectrolyte: $isElectrolyte, ')
          ..write('toExcludeFromSolver: $toExcludeFromSolver, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
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
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _environmentMeta = const VerificationMeta(
    'environment',
  );
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
    'environment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('production'),
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCachedMeta = const VerificationMeta(
    'isCached',
  );
  @override
  late final GeneratedColumn<bool> isCached = GeneratedColumn<bool>(
    'is_cached',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cached" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
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
    isCached,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_content_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppContentEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('environment')) {
      context.handle(
        _environmentMeta,
        environment.isAcceptableOrUnknown(
          data['environment']!,
          _environmentMeta,
        ),
      );
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
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
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('is_cached')) {
      context.handle(
        _isCachedMeta,
        isCached.isAcceptableOrUnknown(data['is_cached']!, _isCachedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppContentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppContentEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      environment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      isCached: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cached'],
      )!,
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
  const AppContentEntry({
    required this.id,
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
    required this.isCached,
  });
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

  factory AppContentEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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

  AppContentEntry copyWith({
    String? id,
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
    bool? isCached,
  }) => AppContentEntry(
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
      environment: data.environment.present
          ? data.environment.value
          : this.environment,
      locale: data.locale.present ? data.locale.value : this.locale,
      content: data.content.present ? data.content.value : this.content,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
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
    isCached,
  );
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
  }) : id = Value(id),
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

  AppContentTableCompanion copyWith({
    Value<String>? id,
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
    Value<int>? rowid,
  }) {
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

class $EdgeFunctionsTableTable extends EdgeFunctionsTable
    with TableInfo<$EdgeFunctionsTableTable, EdgeFunctionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EdgeFunctionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
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
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
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
  List<GeneratedColumn> get $columns => [id, name, code, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'edge_functions_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<EdgeFunctionEntry> instance, {
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
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
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
  EdgeFunctionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EdgeFunctionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
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
  const EdgeFunctionEntry({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
  });
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

  factory EdgeFunctionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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

  EdgeFunctionEntry copyWith({
    String? id,
    String? name,
    String? code,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EdgeFunctionEntry(
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
  }) : id = Value(id),
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

  EdgeFunctionsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? code,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
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

class $ActivitiesTableTable extends ActivitiesTable
    with TableInfo<$ActivitiesTableTable, Activity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledDateTimeMeta = const VerificationMeta(
    'scheduledDateTime',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledDateTime =
      GeneratedColumn<DateTime>(
        'scheduled_date_time',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('planned'),
  );
  static const VerificationMeta _distanceMilesMeta = const VerificationMeta(
    'distanceMiles',
  );
  @override
  late final GeneratedColumn<double> distanceMiles = GeneratedColumn<double>(
    'distance_miles',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paceTargetMinutesPerMileMeta =
      const VerificationMeta('paceTargetMinutesPerMile');
  @override
  late final GeneratedColumn<double> paceTargetMinutesPerMile =
      GeneratedColumn<double>(
        'pace_target_minutes_per_mile',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _intensityLevelMeta = const VerificationMeta(
    'intensityLevel',
  );
  @override
  late final GeneratedColumn<String> intensityLevel = GeneratedColumn<String>(
    'intensity_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cyclingSpeedMphMeta = const VerificationMeta(
    'cyclingSpeedMph',
  );
  @override
  late final GeneratedColumn<double> cyclingSpeedMph = GeneratedColumn<double>(
    'cycling_speed_mph',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cyclingTerrainMeta = const VerificationMeta(
    'cyclingTerrain',
  );
  @override
  late final GeneratedColumn<String> cyclingTerrain = GeneratedColumn<String>(
    'cycling_terrain',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cyclingIndoorOutdoorMeta =
      const VerificationMeta('cyclingIndoorOutdoor');
  @override
  late final GeneratedColumn<String> cyclingIndoorOutdoor =
      GeneratedColumn<String>(
        'cycling_indoor_outdoor',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cyclingElevationGainFtMeta =
      const VerificationMeta('cyclingElevationGainFt');
  @override
  late final GeneratedColumn<int> cyclingElevationGainFt = GeneratedColumn<int>(
    'cycling_elevation_gain_ft',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cyclingSessionGoalMeta =
      const VerificationMeta('cyclingSessionGoal');
  @override
  late final GeneratedColumn<String> cyclingSessionGoal =
      GeneratedColumn<String>(
        'cycling_session_goal',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _swimmingPacePer100mSecondsMeta =
      const VerificationMeta('swimmingPacePer100mSeconds');
  @override
  late final GeneratedColumn<int> swimmingPacePer100mSeconds =
      GeneratedColumn<int>(
        'swimming_pace_per_100m_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _swimmingPoolOrOpenWaterMeta =
      const VerificationMeta('swimmingPoolOrOpenWater');
  @override
  late final GeneratedColumn<String> swimmingPoolOrOpenWater =
      GeneratedColumn<String>(
        'swimming_pool_or_open_water',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _swimmingWaterTempCMeta =
      const VerificationMeta('swimmingWaterTempC');
  @override
  late final GeneratedColumn<double> swimmingWaterTempC =
      GeneratedColumn<double>(
        'swimming_water_temp_c',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _intensityTargetMeta = const VerificationMeta(
    'intensityTarget',
  );
  @override
  late final GeneratedColumn<String> intensityTarget = GeneratedColumn<String>(
    'intensity_target',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeBeforeMinutesMeta = const VerificationMeta(
    'timeBeforeMinutes',
  );
  @override
  late final GeneratedColumn<int> timeBeforeMinutes = GeneratedColumn<int>(
    'time_before_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderDaysBeforeMeta =
      const VerificationMeta('reminderDaysBefore');
  @override
  late final GeneratedColumn<int> reminderDaysBefore = GeneratedColumn<int>(
    'reminder_days_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderTimeOfDayMeta = const VerificationMeta(
    'reminderTimeOfDay',
  );
  @override
  late final GeneratedColumn<String> reminderTimeOfDay =
      GeneratedColumn<String>(
        'reminder_time_of_day',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reminderRecurringMeta = const VerificationMeta(
    'reminderRecurring',
  );
  @override
  late final GeneratedColumn<bool> reminderRecurring = GeneratedColumn<bool>(
    'reminder_recurring',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_recurring" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsUploadMeta = const VerificationMeta(
    'needsUpload',
  );
  @override
  late final GeneratedColumn<bool> needsUpload = GeneratedColumn<bool>(
    'needs_upload',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_upload" IN (0, 1))',
    ),
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionRatingMeta = const VerificationMeta(
    'completionRating',
  );
  @override
  late final GeneratedColumn<int> completionRating = GeneratedColumn<int>(
    'completion_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionNotesMeta = const VerificationMeta(
    'completionNotes',
  );
  @override
  late final GeneratedColumn<String> completionNotes = GeneratedColumn<String>(
    'completion_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualDistanceMilesMeta =
      const VerificationMeta('actualDistanceMiles');
  @override
  late final GeneratedColumn<double> actualDistanceMiles =
      GeneratedColumn<double>(
        'actual_distance_miles',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _actualDurationMinutesMeta =
      const VerificationMeta('actualDurationMinutes');
  @override
  late final GeneratedColumn<int> actualDurationMinutes = GeneratedColumn<int>(
    'actual_duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nutritionPlanDataMeta = const VerificationMeta(
    'nutritionPlanData',
  );
  @override
  late final GeneratedColumn<String> nutritionPlanData =
      GeneratedColumn<String>(
        'nutrition_plan_data',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
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
    userId,
    activityType,
    title,
    scheduledDateTime,
    status,
    distanceMiles,
    durationMinutes,
    paceTargetMinutesPerMile,
    intensityLevel,
    cyclingSpeedMph,
    cyclingTerrain,
    cyclingIndoorOutdoor,
    cyclingElevationGainFt,
    cyclingSessionGoal,
    swimmingPacePer100mSeconds,
    swimmingPoolOrOpenWater,
    swimmingWaterTempC,
    intensityTarget,
    timeBeforeMinutes,
    reminderEnabled,
    reminderDaysBefore,
    reminderTimeOfDay,
    reminderRecurring,
    needsUpload,
    localUpdatedAt,
    completedAt,
    completionRating,
    completionNotes,
    actualDistanceMiles,
    actualDurationMinutes,
    nutritionPlanData,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Activity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('scheduled_date_time')) {
      context.handle(
        _scheduledDateTimeMeta,
        scheduledDateTime.isAcceptableOrUnknown(
          data['scheduled_date_time']!,
          _scheduledDateTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDateTimeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('distance_miles')) {
      context.handle(
        _distanceMilesMeta,
        distanceMiles.isAcceptableOrUnknown(
          data['distance_miles']!,
          _distanceMilesMeta,
        ),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('pace_target_minutes_per_mile')) {
      context.handle(
        _paceTargetMinutesPerMileMeta,
        paceTargetMinutesPerMile.isAcceptableOrUnknown(
          data['pace_target_minutes_per_mile']!,
          _paceTargetMinutesPerMileMeta,
        ),
      );
    }
    if (data.containsKey('intensity_level')) {
      context.handle(
        _intensityLevelMeta,
        intensityLevel.isAcceptableOrUnknown(
          data['intensity_level']!,
          _intensityLevelMeta,
        ),
      );
    }
    if (data.containsKey('cycling_speed_mph')) {
      context.handle(
        _cyclingSpeedMphMeta,
        cyclingSpeedMph.isAcceptableOrUnknown(
          data['cycling_speed_mph']!,
          _cyclingSpeedMphMeta,
        ),
      );
    }
    if (data.containsKey('cycling_terrain')) {
      context.handle(
        _cyclingTerrainMeta,
        cyclingTerrain.isAcceptableOrUnknown(
          data['cycling_terrain']!,
          _cyclingTerrainMeta,
        ),
      );
    }
    if (data.containsKey('cycling_indoor_outdoor')) {
      context.handle(
        _cyclingIndoorOutdoorMeta,
        cyclingIndoorOutdoor.isAcceptableOrUnknown(
          data['cycling_indoor_outdoor']!,
          _cyclingIndoorOutdoorMeta,
        ),
      );
    }
    if (data.containsKey('cycling_elevation_gain_ft')) {
      context.handle(
        _cyclingElevationGainFtMeta,
        cyclingElevationGainFt.isAcceptableOrUnknown(
          data['cycling_elevation_gain_ft']!,
          _cyclingElevationGainFtMeta,
        ),
      );
    }
    if (data.containsKey('cycling_session_goal')) {
      context.handle(
        _cyclingSessionGoalMeta,
        cyclingSessionGoal.isAcceptableOrUnknown(
          data['cycling_session_goal']!,
          _cyclingSessionGoalMeta,
        ),
      );
    }
    if (data.containsKey('swimming_pace_per_100m_seconds')) {
      context.handle(
        _swimmingPacePer100mSecondsMeta,
        swimmingPacePer100mSeconds.isAcceptableOrUnknown(
          data['swimming_pace_per_100m_seconds']!,
          _swimmingPacePer100mSecondsMeta,
        ),
      );
    }
    if (data.containsKey('swimming_pool_or_open_water')) {
      context.handle(
        _swimmingPoolOrOpenWaterMeta,
        swimmingPoolOrOpenWater.isAcceptableOrUnknown(
          data['swimming_pool_or_open_water']!,
          _swimmingPoolOrOpenWaterMeta,
        ),
      );
    }
    if (data.containsKey('swimming_water_temp_c')) {
      context.handle(
        _swimmingWaterTempCMeta,
        swimmingWaterTempC.isAcceptableOrUnknown(
          data['swimming_water_temp_c']!,
          _swimmingWaterTempCMeta,
        ),
      );
    }
    if (data.containsKey('intensity_target')) {
      context.handle(
        _intensityTargetMeta,
        intensityTarget.isAcceptableOrUnknown(
          data['intensity_target']!,
          _intensityTargetMeta,
        ),
      );
    }
    if (data.containsKey('time_before_minutes')) {
      context.handle(
        _timeBeforeMinutesMeta,
        timeBeforeMinutes.isAcceptableOrUnknown(
          data['time_before_minutes']!,
          _timeBeforeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_days_before')) {
      context.handle(
        _reminderDaysBeforeMeta,
        reminderDaysBefore.isAcceptableOrUnknown(
          data['reminder_days_before']!,
          _reminderDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('reminder_time_of_day')) {
      context.handle(
        _reminderTimeOfDayMeta,
        reminderTimeOfDay.isAcceptableOrUnknown(
          data['reminder_time_of_day']!,
          _reminderTimeOfDayMeta,
        ),
      );
    }
    if (data.containsKey('reminder_recurring')) {
      context.handle(
        _reminderRecurringMeta,
        reminderRecurring.isAcceptableOrUnknown(
          data['reminder_recurring']!,
          _reminderRecurringMeta,
        ),
      );
    }
    if (data.containsKey('needs_upload')) {
      context.handle(
        _needsUploadMeta,
        needsUpload.isAcceptableOrUnknown(
          data['needs_upload']!,
          _needsUploadMeta,
        ),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('completion_rating')) {
      context.handle(
        _completionRatingMeta,
        completionRating.isAcceptableOrUnknown(
          data['completion_rating']!,
          _completionRatingMeta,
        ),
      );
    }
    if (data.containsKey('completion_notes')) {
      context.handle(
        _completionNotesMeta,
        completionNotes.isAcceptableOrUnknown(
          data['completion_notes']!,
          _completionNotesMeta,
        ),
      );
    }
    if (data.containsKey('actual_distance_miles')) {
      context.handle(
        _actualDistanceMilesMeta,
        actualDistanceMiles.isAcceptableOrUnknown(
          data['actual_distance_miles']!,
          _actualDistanceMilesMeta,
        ),
      );
    }
    if (data.containsKey('actual_duration_minutes')) {
      context.handle(
        _actualDurationMinutesMeta,
        actualDurationMinutes.isAcceptableOrUnknown(
          data['actual_duration_minutes']!,
          _actualDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('nutrition_plan_data')) {
      context.handle(
        _nutritionPlanDataMeta,
        nutritionPlanData.isAcceptableOrUnknown(
          data['nutrition_plan_data']!,
          _nutritionPlanDataMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Activity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Activity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      scheduledDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_date_time'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      distanceMiles: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_miles'],
      ),
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      ),
      paceTargetMinutesPerMile: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pace_target_minutes_per_mile'],
      ),
      intensityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intensity_level'],
      ),
      cyclingSpeedMph: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cycling_speed_mph'],
      ),
      cyclingTerrain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycling_terrain'],
      ),
      cyclingIndoorOutdoor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycling_indoor_outdoor'],
      ),
      cyclingElevationGainFt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycling_elevation_gain_ft'],
      ),
      cyclingSessionGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycling_session_goal'],
      ),
      swimmingPacePer100mSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}swimming_pace_per_100m_seconds'],
      ),
      swimmingPoolOrOpenWater: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swimming_pool_or_open_water'],
      ),
      swimmingWaterTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}swimming_water_temp_c'],
      ),
      intensityTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intensity_target'],
      ),
      timeBeforeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_before_minutes'],
      ),
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_days_before'],
      ),
      reminderTimeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time_of_day'],
      ),
      reminderRecurring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_recurring'],
      )!,
      needsUpload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_upload'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      completionRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_rating'],
      ),
      completionNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_notes'],
      ),
      actualDistanceMiles: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}actual_distance_miles'],
      ),
      actualDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_duration_minutes'],
      ),
      nutritionPlanData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nutrition_plan_data'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ActivitiesTableTable createAlias(String alias) {
    return $ActivitiesTableTable(attachedDatabase, alias);
  }
}

class Activity extends DataClass implements Insertable<Activity> {
  final int id;
  final String userId;
  final String activityType;
  final String title;
  final DateTime scheduledDateTime;
  final String status;
  final double? distanceMiles;
  final int? durationMinutes;
  final double? paceTargetMinutesPerMile;
  final String? intensityLevel;
  final double? cyclingSpeedMph;
  final String? cyclingTerrain;
  final String? cyclingIndoorOutdoor;
  final int? cyclingElevationGainFt;
  final String? cyclingSessionGoal;
  final int? swimmingPacePer100mSeconds;
  final String? swimmingPoolOrOpenWater;
  final double? swimmingWaterTempC;
  final String? intensityTarget;
  final int? timeBeforeMinutes;
  final bool reminderEnabled;
  final int? reminderDaysBefore;
  final String? reminderTimeOfDay;
  final bool reminderRecurring;
  final bool? needsUpload;
  final DateTime? localUpdatedAt;
  final DateTime? completedAt;
  final int? completionRating;
  final String? completionNotes;
  final double? actualDistanceMiles;
  final int? actualDurationMinutes;
  final String? nutritionPlanData;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Activity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.title,
    required this.scheduledDateTime,
    required this.status,
    this.distanceMiles,
    this.durationMinutes,
    this.paceTargetMinutesPerMile,
    this.intensityLevel,
    this.cyclingSpeedMph,
    this.cyclingTerrain,
    this.cyclingIndoorOutdoor,
    this.cyclingElevationGainFt,
    this.cyclingSessionGoal,
    this.swimmingPacePer100mSeconds,
    this.swimmingPoolOrOpenWater,
    this.swimmingWaterTempC,
    this.intensityTarget,
    this.timeBeforeMinutes,
    required this.reminderEnabled,
    this.reminderDaysBefore,
    this.reminderTimeOfDay,
    required this.reminderRecurring,
    this.needsUpload,
    this.localUpdatedAt,
    this.completedAt,
    this.completionRating,
    this.completionNotes,
    this.actualDistanceMiles,
    this.actualDurationMinutes,
    this.nutritionPlanData,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['activity_type'] = Variable<String>(activityType);
    map['title'] = Variable<String>(title);
    map['scheduled_date_time'] = Variable<DateTime>(scheduledDateTime);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || distanceMiles != null) {
      map['distance_miles'] = Variable<double>(distanceMiles);
    }
    if (!nullToAbsent || durationMinutes != null) {
      map['duration_minutes'] = Variable<int>(durationMinutes);
    }
    if (!nullToAbsent || paceTargetMinutesPerMile != null) {
      map['pace_target_minutes_per_mile'] = Variable<double>(
        paceTargetMinutesPerMile,
      );
    }
    if (!nullToAbsent || intensityLevel != null) {
      map['intensity_level'] = Variable<String>(intensityLevel);
    }
    if (!nullToAbsent || cyclingSpeedMph != null) {
      map['cycling_speed_mph'] = Variable<double>(cyclingSpeedMph);
    }
    if (!nullToAbsent || cyclingTerrain != null) {
      map['cycling_terrain'] = Variable<String>(cyclingTerrain);
    }
    if (!nullToAbsent || cyclingIndoorOutdoor != null) {
      map['cycling_indoor_outdoor'] = Variable<String>(cyclingIndoorOutdoor);
    }
    if (!nullToAbsent || cyclingElevationGainFt != null) {
      map['cycling_elevation_gain_ft'] = Variable<int>(cyclingElevationGainFt);
    }
    if (!nullToAbsent || cyclingSessionGoal != null) {
      map['cycling_session_goal'] = Variable<String>(cyclingSessionGoal);
    }
    if (!nullToAbsent || swimmingPacePer100mSeconds != null) {
      map['swimming_pace_per_100m_seconds'] = Variable<int>(
        swimmingPacePer100mSeconds,
      );
    }
    if (!nullToAbsent || swimmingPoolOrOpenWater != null) {
      map['swimming_pool_or_open_water'] = Variable<String>(
        swimmingPoolOrOpenWater,
      );
    }
    if (!nullToAbsent || swimmingWaterTempC != null) {
      map['swimming_water_temp_c'] = Variable<double>(swimmingWaterTempC);
    }
    if (!nullToAbsent || intensityTarget != null) {
      map['intensity_target'] = Variable<String>(intensityTarget);
    }
    if (!nullToAbsent || timeBeforeMinutes != null) {
      map['time_before_minutes'] = Variable<int>(timeBeforeMinutes);
    }
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    if (!nullToAbsent || reminderDaysBefore != null) {
      map['reminder_days_before'] = Variable<int>(reminderDaysBefore);
    }
    if (!nullToAbsent || reminderTimeOfDay != null) {
      map['reminder_time_of_day'] = Variable<String>(reminderTimeOfDay);
    }
    map['reminder_recurring'] = Variable<bool>(reminderRecurring);
    if (!nullToAbsent || needsUpload != null) {
      map['needs_upload'] = Variable<bool>(needsUpload);
    }
    if (!nullToAbsent || localUpdatedAt != null) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || completionRating != null) {
      map['completion_rating'] = Variable<int>(completionRating);
    }
    if (!nullToAbsent || completionNotes != null) {
      map['completion_notes'] = Variable<String>(completionNotes);
    }
    if (!nullToAbsent || actualDistanceMiles != null) {
      map['actual_distance_miles'] = Variable<double>(actualDistanceMiles);
    }
    if (!nullToAbsent || actualDurationMinutes != null) {
      map['actual_duration_minutes'] = Variable<int>(actualDurationMinutes);
    }
    if (!nullToAbsent || nutritionPlanData != null) {
      map['nutrition_plan_data'] = Variable<String>(nutritionPlanData);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ActivitiesTableCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      activityType: Value(activityType),
      title: Value(title),
      scheduledDateTime: Value(scheduledDateTime),
      status: Value(status),
      distanceMiles: distanceMiles == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMiles),
      durationMinutes: durationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMinutes),
      paceTargetMinutesPerMile: paceTargetMinutesPerMile == null && nullToAbsent
          ? const Value.absent()
          : Value(paceTargetMinutesPerMile),
      intensityLevel: intensityLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(intensityLevel),
      cyclingSpeedMph: cyclingSpeedMph == null && nullToAbsent
          ? const Value.absent()
          : Value(cyclingSpeedMph),
      cyclingTerrain: cyclingTerrain == null && nullToAbsent
          ? const Value.absent()
          : Value(cyclingTerrain),
      cyclingIndoorOutdoor: cyclingIndoorOutdoor == null && nullToAbsent
          ? const Value.absent()
          : Value(cyclingIndoorOutdoor),
      cyclingElevationGainFt: cyclingElevationGainFt == null && nullToAbsent
          ? const Value.absent()
          : Value(cyclingElevationGainFt),
      cyclingSessionGoal: cyclingSessionGoal == null && nullToAbsent
          ? const Value.absent()
          : Value(cyclingSessionGoal),
      swimmingPacePer100mSeconds:
          swimmingPacePer100mSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(swimmingPacePer100mSeconds),
      swimmingPoolOrOpenWater: swimmingPoolOrOpenWater == null && nullToAbsent
          ? const Value.absent()
          : Value(swimmingPoolOrOpenWater),
      swimmingWaterTempC: swimmingWaterTempC == null && nullToAbsent
          ? const Value.absent()
          : Value(swimmingWaterTempC),
      intensityTarget: intensityTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(intensityTarget),
      timeBeforeMinutes: timeBeforeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(timeBeforeMinutes),
      reminderEnabled: Value(reminderEnabled),
      reminderDaysBefore: reminderDaysBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderDaysBefore),
      reminderTimeOfDay: reminderTimeOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTimeOfDay),
      reminderRecurring: Value(reminderRecurring),
      needsUpload: needsUpload == null && nullToAbsent
          ? const Value.absent()
          : Value(needsUpload),
      localUpdatedAt: localUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(localUpdatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      completionRating: completionRating == null && nullToAbsent
          ? const Value.absent()
          : Value(completionRating),
      completionNotes: completionNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(completionNotes),
      actualDistanceMiles: actualDistanceMiles == null && nullToAbsent
          ? const Value.absent()
          : Value(actualDistanceMiles),
      actualDurationMinutes: actualDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualDurationMinutes),
      nutritionPlanData: nutritionPlanData == null && nullToAbsent
          ? const Value.absent()
          : Value(nutritionPlanData),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Activity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Activity(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      activityType: serializer.fromJson<String>(json['activityType']),
      title: serializer.fromJson<String>(json['title']),
      scheduledDateTime: serializer.fromJson<DateTime>(
        json['scheduledDateTime'],
      ),
      status: serializer.fromJson<String>(json['status']),
      distanceMiles: serializer.fromJson<double?>(json['distanceMiles']),
      durationMinutes: serializer.fromJson<int?>(json['durationMinutes']),
      paceTargetMinutesPerMile: serializer.fromJson<double?>(
        json['paceTargetMinutesPerMile'],
      ),
      intensityLevel: serializer.fromJson<String?>(json['intensityLevel']),
      cyclingSpeedMph: serializer.fromJson<double?>(json['cyclingSpeedMph']),
      cyclingTerrain: serializer.fromJson<String?>(json['cyclingTerrain']),
      cyclingIndoorOutdoor: serializer.fromJson<String?>(
        json['cyclingIndoorOutdoor'],
      ),
      cyclingElevationGainFt: serializer.fromJson<int?>(
        json['cyclingElevationGainFt'],
      ),
      cyclingSessionGoal: serializer.fromJson<String?>(
        json['cyclingSessionGoal'],
      ),
      swimmingPacePer100mSeconds: serializer.fromJson<int?>(
        json['swimmingPacePer100mSeconds'],
      ),
      swimmingPoolOrOpenWater: serializer.fromJson<String?>(
        json['swimmingPoolOrOpenWater'],
      ),
      swimmingWaterTempC: serializer.fromJson<double?>(
        json['swimmingWaterTempC'],
      ),
      intensityTarget: serializer.fromJson<String?>(json['intensityTarget']),
      timeBeforeMinutes: serializer.fromJson<int?>(json['timeBeforeMinutes']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderDaysBefore: serializer.fromJson<int?>(json['reminderDaysBefore']),
      reminderTimeOfDay: serializer.fromJson<String?>(
        json['reminderTimeOfDay'],
      ),
      reminderRecurring: serializer.fromJson<bool>(json['reminderRecurring']),
      needsUpload: serializer.fromJson<bool?>(json['needsUpload']),
      localUpdatedAt: serializer.fromJson<DateTime?>(json['localUpdatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      completionRating: serializer.fromJson<int?>(json['completionRating']),
      completionNotes: serializer.fromJson<String?>(json['completionNotes']),
      actualDistanceMiles: serializer.fromJson<double?>(
        json['actualDistanceMiles'],
      ),
      actualDurationMinutes: serializer.fromJson<int?>(
        json['actualDurationMinutes'],
      ),
      nutritionPlanData: serializer.fromJson<String?>(
        json['nutritionPlanData'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'activityType': serializer.toJson<String>(activityType),
      'title': serializer.toJson<String>(title),
      'scheduledDateTime': serializer.toJson<DateTime>(scheduledDateTime),
      'status': serializer.toJson<String>(status),
      'distanceMiles': serializer.toJson<double?>(distanceMiles),
      'durationMinutes': serializer.toJson<int?>(durationMinutes),
      'paceTargetMinutesPerMile': serializer.toJson<double?>(
        paceTargetMinutesPerMile,
      ),
      'intensityLevel': serializer.toJson<String?>(intensityLevel),
      'cyclingSpeedMph': serializer.toJson<double?>(cyclingSpeedMph),
      'cyclingTerrain': serializer.toJson<String?>(cyclingTerrain),
      'cyclingIndoorOutdoor': serializer.toJson<String?>(cyclingIndoorOutdoor),
      'cyclingElevationGainFt': serializer.toJson<int?>(cyclingElevationGainFt),
      'cyclingSessionGoal': serializer.toJson<String?>(cyclingSessionGoal),
      'swimmingPacePer100mSeconds': serializer.toJson<int?>(
        swimmingPacePer100mSeconds,
      ),
      'swimmingPoolOrOpenWater': serializer.toJson<String?>(
        swimmingPoolOrOpenWater,
      ),
      'swimmingWaterTempC': serializer.toJson<double?>(swimmingWaterTempC),
      'intensityTarget': serializer.toJson<String?>(intensityTarget),
      'timeBeforeMinutes': serializer.toJson<int?>(timeBeforeMinutes),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderDaysBefore': serializer.toJson<int?>(reminderDaysBefore),
      'reminderTimeOfDay': serializer.toJson<String?>(reminderTimeOfDay),
      'reminderRecurring': serializer.toJson<bool>(reminderRecurring),
      'needsUpload': serializer.toJson<bool?>(needsUpload),
      'localUpdatedAt': serializer.toJson<DateTime?>(localUpdatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'completionRating': serializer.toJson<int?>(completionRating),
      'completionNotes': serializer.toJson<String?>(completionNotes),
      'actualDistanceMiles': serializer.toJson<double?>(actualDistanceMiles),
      'actualDurationMinutes': serializer.toJson<int?>(actualDurationMinutes),
      'nutritionPlanData': serializer.toJson<String?>(nutritionPlanData),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Activity copyWith({
    int? id,
    String? userId,
    String? activityType,
    String? title,
    DateTime? scheduledDateTime,
    String? status,
    Value<double?> distanceMiles = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<double?> paceTargetMinutesPerMile = const Value.absent(),
    Value<String?> intensityLevel = const Value.absent(),
    Value<double?> cyclingSpeedMph = const Value.absent(),
    Value<String?> cyclingTerrain = const Value.absent(),
    Value<String?> cyclingIndoorOutdoor = const Value.absent(),
    Value<int?> cyclingElevationGainFt = const Value.absent(),
    Value<String?> cyclingSessionGoal = const Value.absent(),
    Value<int?> swimmingPacePer100mSeconds = const Value.absent(),
    Value<String?> swimmingPoolOrOpenWater = const Value.absent(),
    Value<double?> swimmingWaterTempC = const Value.absent(),
    Value<String?> intensityTarget = const Value.absent(),
    Value<int?> timeBeforeMinutes = const Value.absent(),
    bool? reminderEnabled,
    Value<int?> reminderDaysBefore = const Value.absent(),
    Value<String?> reminderTimeOfDay = const Value.absent(),
    bool? reminderRecurring,
    Value<bool?> needsUpload = const Value.absent(),
    Value<DateTime?> localUpdatedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<int?> completionRating = const Value.absent(),
    Value<String?> completionNotes = const Value.absent(),
    Value<double?> actualDistanceMiles = const Value.absent(),
    Value<int?> actualDurationMinutes = const Value.absent(),
    Value<String?> nutritionPlanData = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Activity(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    activityType: activityType ?? this.activityType,
    title: title ?? this.title,
    scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
    status: status ?? this.status,
    distanceMiles: distanceMiles.present
        ? distanceMiles.value
        : this.distanceMiles,
    durationMinutes: durationMinutes.present
        ? durationMinutes.value
        : this.durationMinutes,
    paceTargetMinutesPerMile: paceTargetMinutesPerMile.present
        ? paceTargetMinutesPerMile.value
        : this.paceTargetMinutesPerMile,
    intensityLevel: intensityLevel.present
        ? intensityLevel.value
        : this.intensityLevel,
    cyclingSpeedMph: cyclingSpeedMph.present
        ? cyclingSpeedMph.value
        : this.cyclingSpeedMph,
    cyclingTerrain: cyclingTerrain.present
        ? cyclingTerrain.value
        : this.cyclingTerrain,
    cyclingIndoorOutdoor: cyclingIndoorOutdoor.present
        ? cyclingIndoorOutdoor.value
        : this.cyclingIndoorOutdoor,
    cyclingElevationGainFt: cyclingElevationGainFt.present
        ? cyclingElevationGainFt.value
        : this.cyclingElevationGainFt,
    cyclingSessionGoal: cyclingSessionGoal.present
        ? cyclingSessionGoal.value
        : this.cyclingSessionGoal,
    swimmingPacePer100mSeconds: swimmingPacePer100mSeconds.present
        ? swimmingPacePer100mSeconds.value
        : this.swimmingPacePer100mSeconds,
    swimmingPoolOrOpenWater: swimmingPoolOrOpenWater.present
        ? swimmingPoolOrOpenWater.value
        : this.swimmingPoolOrOpenWater,
    swimmingWaterTempC: swimmingWaterTempC.present
        ? swimmingWaterTempC.value
        : this.swimmingWaterTempC,
    intensityTarget: intensityTarget.present
        ? intensityTarget.value
        : this.intensityTarget,
    timeBeforeMinutes: timeBeforeMinutes.present
        ? timeBeforeMinutes.value
        : this.timeBeforeMinutes,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderDaysBefore: reminderDaysBefore.present
        ? reminderDaysBefore.value
        : this.reminderDaysBefore,
    reminderTimeOfDay: reminderTimeOfDay.present
        ? reminderTimeOfDay.value
        : this.reminderTimeOfDay,
    reminderRecurring: reminderRecurring ?? this.reminderRecurring,
    needsUpload: needsUpload.present ? needsUpload.value : this.needsUpload,
    localUpdatedAt: localUpdatedAt.present
        ? localUpdatedAt.value
        : this.localUpdatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    completionRating: completionRating.present
        ? completionRating.value
        : this.completionRating,
    completionNotes: completionNotes.present
        ? completionNotes.value
        : this.completionNotes,
    actualDistanceMiles: actualDistanceMiles.present
        ? actualDistanceMiles.value
        : this.actualDistanceMiles,
    actualDurationMinutes: actualDurationMinutes.present
        ? actualDurationMinutes.value
        : this.actualDurationMinutes,
    nutritionPlanData: nutritionPlanData.present
        ? nutritionPlanData.value
        : this.nutritionPlanData,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Activity copyWithCompanion(ActivitiesTableCompanion data) {
    return Activity(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      title: data.title.present ? data.title.value : this.title,
      scheduledDateTime: data.scheduledDateTime.present
          ? data.scheduledDateTime.value
          : this.scheduledDateTime,
      status: data.status.present ? data.status.value : this.status,
      distanceMiles: data.distanceMiles.present
          ? data.distanceMiles.value
          : this.distanceMiles,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      paceTargetMinutesPerMile: data.paceTargetMinutesPerMile.present
          ? data.paceTargetMinutesPerMile.value
          : this.paceTargetMinutesPerMile,
      intensityLevel: data.intensityLevel.present
          ? data.intensityLevel.value
          : this.intensityLevel,
      cyclingSpeedMph: data.cyclingSpeedMph.present
          ? data.cyclingSpeedMph.value
          : this.cyclingSpeedMph,
      cyclingTerrain: data.cyclingTerrain.present
          ? data.cyclingTerrain.value
          : this.cyclingTerrain,
      cyclingIndoorOutdoor: data.cyclingIndoorOutdoor.present
          ? data.cyclingIndoorOutdoor.value
          : this.cyclingIndoorOutdoor,
      cyclingElevationGainFt: data.cyclingElevationGainFt.present
          ? data.cyclingElevationGainFt.value
          : this.cyclingElevationGainFt,
      cyclingSessionGoal: data.cyclingSessionGoal.present
          ? data.cyclingSessionGoal.value
          : this.cyclingSessionGoal,
      swimmingPacePer100mSeconds: data.swimmingPacePer100mSeconds.present
          ? data.swimmingPacePer100mSeconds.value
          : this.swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: data.swimmingPoolOrOpenWater.present
          ? data.swimmingPoolOrOpenWater.value
          : this.swimmingPoolOrOpenWater,
      swimmingWaterTempC: data.swimmingWaterTempC.present
          ? data.swimmingWaterTempC.value
          : this.swimmingWaterTempC,
      intensityTarget: data.intensityTarget.present
          ? data.intensityTarget.value
          : this.intensityTarget,
      timeBeforeMinutes: data.timeBeforeMinutes.present
          ? data.timeBeforeMinutes.value
          : this.timeBeforeMinutes,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderDaysBefore: data.reminderDaysBefore.present
          ? data.reminderDaysBefore.value
          : this.reminderDaysBefore,
      reminderTimeOfDay: data.reminderTimeOfDay.present
          ? data.reminderTimeOfDay.value
          : this.reminderTimeOfDay,
      reminderRecurring: data.reminderRecurring.present
          ? data.reminderRecurring.value
          : this.reminderRecurring,
      needsUpload: data.needsUpload.present
          ? data.needsUpload.value
          : this.needsUpload,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completionRating: data.completionRating.present
          ? data.completionRating.value
          : this.completionRating,
      completionNotes: data.completionNotes.present
          ? data.completionNotes.value
          : this.completionNotes,
      actualDistanceMiles: data.actualDistanceMiles.present
          ? data.actualDistanceMiles.value
          : this.actualDistanceMiles,
      actualDurationMinutes: data.actualDurationMinutes.present
          ? data.actualDurationMinutes.value
          : this.actualDurationMinutes,
      nutritionPlanData: data.nutritionPlanData.present
          ? data.nutritionPlanData.value
          : this.nutritionPlanData,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Activity(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('activityType: $activityType, ')
          ..write('title: $title, ')
          ..write('scheduledDateTime: $scheduledDateTime, ')
          ..write('status: $status, ')
          ..write('distanceMiles: $distanceMiles, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('paceTargetMinutesPerMile: $paceTargetMinutesPerMile, ')
          ..write('intensityLevel: $intensityLevel, ')
          ..write('cyclingSpeedMph: $cyclingSpeedMph, ')
          ..write('cyclingTerrain: $cyclingTerrain, ')
          ..write('cyclingIndoorOutdoor: $cyclingIndoorOutdoor, ')
          ..write('cyclingElevationGainFt: $cyclingElevationGainFt, ')
          ..write('cyclingSessionGoal: $cyclingSessionGoal, ')
          ..write('swimmingPacePer100mSeconds: $swimmingPacePer100mSeconds, ')
          ..write('swimmingPoolOrOpenWater: $swimmingPoolOrOpenWater, ')
          ..write('swimmingWaterTempC: $swimmingWaterTempC, ')
          ..write('intensityTarget: $intensityTarget, ')
          ..write('timeBeforeMinutes: $timeBeforeMinutes, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderDaysBefore: $reminderDaysBefore, ')
          ..write('reminderTimeOfDay: $reminderTimeOfDay, ')
          ..write('reminderRecurring: $reminderRecurring, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('completionRating: $completionRating, ')
          ..write('completionNotes: $completionNotes, ')
          ..write('actualDistanceMiles: $actualDistanceMiles, ')
          ..write('actualDurationMinutes: $actualDurationMinutes, ')
          ..write('nutritionPlanData: $nutritionPlanData, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    userId,
    activityType,
    title,
    scheduledDateTime,
    status,
    distanceMiles,
    durationMinutes,
    paceTargetMinutesPerMile,
    intensityLevel,
    cyclingSpeedMph,
    cyclingTerrain,
    cyclingIndoorOutdoor,
    cyclingElevationGainFt,
    cyclingSessionGoal,
    swimmingPacePer100mSeconds,
    swimmingPoolOrOpenWater,
    swimmingWaterTempC,
    intensityTarget,
    timeBeforeMinutes,
    reminderEnabled,
    reminderDaysBefore,
    reminderTimeOfDay,
    reminderRecurring,
    needsUpload,
    localUpdatedAt,
    completedAt,
    completionRating,
    completionNotes,
    actualDistanceMiles,
    actualDurationMinutes,
    nutritionPlanData,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Activity &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.activityType == this.activityType &&
          other.title == this.title &&
          other.scheduledDateTime == this.scheduledDateTime &&
          other.status == this.status &&
          other.distanceMiles == this.distanceMiles &&
          other.durationMinutes == this.durationMinutes &&
          other.paceTargetMinutesPerMile == this.paceTargetMinutesPerMile &&
          other.intensityLevel == this.intensityLevel &&
          other.cyclingSpeedMph == this.cyclingSpeedMph &&
          other.cyclingTerrain == this.cyclingTerrain &&
          other.cyclingIndoorOutdoor == this.cyclingIndoorOutdoor &&
          other.cyclingElevationGainFt == this.cyclingElevationGainFt &&
          other.cyclingSessionGoal == this.cyclingSessionGoal &&
          other.swimmingPacePer100mSeconds == this.swimmingPacePer100mSeconds &&
          other.swimmingPoolOrOpenWater == this.swimmingPoolOrOpenWater &&
          other.swimmingWaterTempC == this.swimmingWaterTempC &&
          other.intensityTarget == this.intensityTarget &&
          other.timeBeforeMinutes == this.timeBeforeMinutes &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderDaysBefore == this.reminderDaysBefore &&
          other.reminderTimeOfDay == this.reminderTimeOfDay &&
          other.reminderRecurring == this.reminderRecurring &&
          other.needsUpload == this.needsUpload &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.completedAt == this.completedAt &&
          other.completionRating == this.completionRating &&
          other.completionNotes == this.completionNotes &&
          other.actualDistanceMiles == this.actualDistanceMiles &&
          other.actualDurationMinutes == this.actualDurationMinutes &&
          other.nutritionPlanData == this.nutritionPlanData &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ActivitiesTableCompanion extends UpdateCompanion<Activity> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> activityType;
  final Value<String> title;
  final Value<DateTime> scheduledDateTime;
  final Value<String> status;
  final Value<double?> distanceMiles;
  final Value<int?> durationMinutes;
  final Value<double?> paceTargetMinutesPerMile;
  final Value<String?> intensityLevel;
  final Value<double?> cyclingSpeedMph;
  final Value<String?> cyclingTerrain;
  final Value<String?> cyclingIndoorOutdoor;
  final Value<int?> cyclingElevationGainFt;
  final Value<String?> cyclingSessionGoal;
  final Value<int?> swimmingPacePer100mSeconds;
  final Value<String?> swimmingPoolOrOpenWater;
  final Value<double?> swimmingWaterTempC;
  final Value<String?> intensityTarget;
  final Value<int?> timeBeforeMinutes;
  final Value<bool> reminderEnabled;
  final Value<int?> reminderDaysBefore;
  final Value<String?> reminderTimeOfDay;
  final Value<bool> reminderRecurring;
  final Value<bool?> needsUpload;
  final Value<DateTime?> localUpdatedAt;
  final Value<DateTime?> completedAt;
  final Value<int?> completionRating;
  final Value<String?> completionNotes;
  final Value<double?> actualDistanceMiles;
  final Value<int?> actualDurationMinutes;
  final Value<String?> nutritionPlanData;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const ActivitiesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.activityType = const Value.absent(),
    this.title = const Value.absent(),
    this.scheduledDateTime = const Value.absent(),
    this.status = const Value.absent(),
    this.distanceMiles = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.paceTargetMinutesPerMile = const Value.absent(),
    this.intensityLevel = const Value.absent(),
    this.cyclingSpeedMph = const Value.absent(),
    this.cyclingTerrain = const Value.absent(),
    this.cyclingIndoorOutdoor = const Value.absent(),
    this.cyclingElevationGainFt = const Value.absent(),
    this.cyclingSessionGoal = const Value.absent(),
    this.swimmingPacePer100mSeconds = const Value.absent(),
    this.swimmingPoolOrOpenWater = const Value.absent(),
    this.swimmingWaterTempC = const Value.absent(),
    this.intensityTarget = const Value.absent(),
    this.timeBeforeMinutes = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderDaysBefore = const Value.absent(),
    this.reminderTimeOfDay = const Value.absent(),
    this.reminderRecurring = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completionRating = const Value.absent(),
    this.completionNotes = const Value.absent(),
    this.actualDistanceMiles = const Value.absent(),
    this.actualDurationMinutes = const Value.absent(),
    this.nutritionPlanData = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  ActivitiesTableCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String activityType,
    required String title,
    required DateTime scheduledDateTime,
    this.status = const Value.absent(),
    this.distanceMiles = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.paceTargetMinutesPerMile = const Value.absent(),
    this.intensityLevel = const Value.absent(),
    this.cyclingSpeedMph = const Value.absent(),
    this.cyclingTerrain = const Value.absent(),
    this.cyclingIndoorOutdoor = const Value.absent(),
    this.cyclingElevationGainFt = const Value.absent(),
    this.cyclingSessionGoal = const Value.absent(),
    this.swimmingPacePer100mSeconds = const Value.absent(),
    this.swimmingPoolOrOpenWater = const Value.absent(),
    this.swimmingWaterTempC = const Value.absent(),
    this.intensityTarget = const Value.absent(),
    this.timeBeforeMinutes = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderDaysBefore = const Value.absent(),
    this.reminderTimeOfDay = const Value.absent(),
    this.reminderRecurring = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completionRating = const Value.absent(),
    this.completionNotes = const Value.absent(),
    this.actualDistanceMiles = const Value.absent(),
    this.actualDurationMinutes = const Value.absent(),
    this.nutritionPlanData = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  }) : userId = Value(userId),
       activityType = Value(activityType),
       title = Value(title),
       scheduledDateTime = Value(scheduledDateTime),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Activity> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? activityType,
    Expression<String>? title,
    Expression<DateTime>? scheduledDateTime,
    Expression<String>? status,
    Expression<double>? distanceMiles,
    Expression<int>? durationMinutes,
    Expression<double>? paceTargetMinutesPerMile,
    Expression<String>? intensityLevel,
    Expression<double>? cyclingSpeedMph,
    Expression<String>? cyclingTerrain,
    Expression<String>? cyclingIndoorOutdoor,
    Expression<int>? cyclingElevationGainFt,
    Expression<String>? cyclingSessionGoal,
    Expression<int>? swimmingPacePer100mSeconds,
    Expression<String>? swimmingPoolOrOpenWater,
    Expression<double>? swimmingWaterTempC,
    Expression<String>? intensityTarget,
    Expression<int>? timeBeforeMinutes,
    Expression<bool>? reminderEnabled,
    Expression<int>? reminderDaysBefore,
    Expression<String>? reminderTimeOfDay,
    Expression<bool>? reminderRecurring,
    Expression<bool>? needsUpload,
    Expression<DateTime>? localUpdatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? completionRating,
    Expression<String>? completionNotes,
    Expression<double>? actualDistanceMiles,
    Expression<int>? actualDurationMinutes,
    Expression<String>? nutritionPlanData,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (activityType != null) 'activity_type': activityType,
      if (title != null) 'title': title,
      if (scheduledDateTime != null) 'scheduled_date_time': scheduledDateTime,
      if (status != null) 'status': status,
      if (distanceMiles != null) 'distance_miles': distanceMiles,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (paceTargetMinutesPerMile != null)
        'pace_target_minutes_per_mile': paceTargetMinutesPerMile,
      if (intensityLevel != null) 'intensity_level': intensityLevel,
      if (cyclingSpeedMph != null) 'cycling_speed_mph': cyclingSpeedMph,
      if (cyclingTerrain != null) 'cycling_terrain': cyclingTerrain,
      if (cyclingIndoorOutdoor != null)
        'cycling_indoor_outdoor': cyclingIndoorOutdoor,
      if (cyclingElevationGainFt != null)
        'cycling_elevation_gain_ft': cyclingElevationGainFt,
      if (cyclingSessionGoal != null)
        'cycling_session_goal': cyclingSessionGoal,
      if (swimmingPacePer100mSeconds != null)
        'swimming_pace_per_100m_seconds': swimmingPacePer100mSeconds,
      if (swimmingPoolOrOpenWater != null)
        'swimming_pool_or_open_water': swimmingPoolOrOpenWater,
      if (swimmingWaterTempC != null)
        'swimming_water_temp_c': swimmingWaterTempC,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (timeBeforeMinutes != null) 'time_before_minutes': timeBeforeMinutes,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderDaysBefore != null)
        'reminder_days_before': reminderDaysBefore,
      if (reminderTimeOfDay != null) 'reminder_time_of_day': reminderTimeOfDay,
      if (reminderRecurring != null) 'reminder_recurring': reminderRecurring,
      if (needsUpload != null) 'needs_upload': needsUpload,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (completionRating != null) 'completion_rating': completionRating,
      if (completionNotes != null) 'completion_notes': completionNotes,
      if (actualDistanceMiles != null)
        'actual_distance_miles': actualDistanceMiles,
      if (actualDurationMinutes != null)
        'actual_duration_minutes': actualDurationMinutes,
      if (nutritionPlanData != null) 'nutrition_plan_data': nutritionPlanData,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  ActivitiesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? userId,
    Value<String>? activityType,
    Value<String>? title,
    Value<DateTime>? scheduledDateTime,
    Value<String>? status,
    Value<double?>? distanceMiles,
    Value<int?>? durationMinutes,
    Value<double?>? paceTargetMinutesPerMile,
    Value<String?>? intensityLevel,
    Value<double?>? cyclingSpeedMph,
    Value<String?>? cyclingTerrain,
    Value<String?>? cyclingIndoorOutdoor,
    Value<int?>? cyclingElevationGainFt,
    Value<String?>? cyclingSessionGoal,
    Value<int?>? swimmingPacePer100mSeconds,
    Value<String?>? swimmingPoolOrOpenWater,
    Value<double?>? swimmingWaterTempC,
    Value<String?>? intensityTarget,
    Value<int?>? timeBeforeMinutes,
    Value<bool>? reminderEnabled,
    Value<int?>? reminderDaysBefore,
    Value<String?>? reminderTimeOfDay,
    Value<bool>? reminderRecurring,
    Value<bool?>? needsUpload,
    Value<DateTime?>? localUpdatedAt,
    Value<DateTime?>? completedAt,
    Value<int?>? completionRating,
    Value<String?>? completionNotes,
    Value<double?>? actualDistanceMiles,
    Value<int?>? actualDurationMinutes,
    Value<String?>? nutritionPlanData,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return ActivitiesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      status: status ?? this.status,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      paceTargetMinutesPerMile:
          paceTargetMinutesPerMile ?? this.paceTargetMinutesPerMile,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      cyclingSpeedMph: cyclingSpeedMph ?? this.cyclingSpeedMph,
      cyclingTerrain: cyclingTerrain ?? this.cyclingTerrain,
      cyclingIndoorOutdoor: cyclingIndoorOutdoor ?? this.cyclingIndoorOutdoor,
      cyclingElevationGainFt:
          cyclingElevationGainFt ?? this.cyclingElevationGainFt,
      cyclingSessionGoal: cyclingSessionGoal ?? this.cyclingSessionGoal,
      swimmingPacePer100mSeconds:
          swimmingPacePer100mSeconds ?? this.swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater:
          swimmingPoolOrOpenWater ?? this.swimmingPoolOrOpenWater,
      swimmingWaterTempC: swimmingWaterTempC ?? this.swimmingWaterTempC,
      intensityTarget: intensityTarget ?? this.intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes ?? this.timeBeforeMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderTimeOfDay: reminderTimeOfDay ?? this.reminderTimeOfDay,
      reminderRecurring: reminderRecurring ?? this.reminderRecurring,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      completedAt: completedAt ?? this.completedAt,
      completionRating: completionRating ?? this.completionRating,
      completionNotes: completionNotes ?? this.completionNotes,
      actualDistanceMiles: actualDistanceMiles ?? this.actualDistanceMiles,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      nutritionPlanData: nutritionPlanData ?? this.nutritionPlanData,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (scheduledDateTime.present) {
      map['scheduled_date_time'] = Variable<DateTime>(scheduledDateTime.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (distanceMiles.present) {
      map['distance_miles'] = Variable<double>(distanceMiles.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (paceTargetMinutesPerMile.present) {
      map['pace_target_minutes_per_mile'] = Variable<double>(
        paceTargetMinutesPerMile.value,
      );
    }
    if (intensityLevel.present) {
      map['intensity_level'] = Variable<String>(intensityLevel.value);
    }
    if (cyclingSpeedMph.present) {
      map['cycling_speed_mph'] = Variable<double>(cyclingSpeedMph.value);
    }
    if (cyclingTerrain.present) {
      map['cycling_terrain'] = Variable<String>(cyclingTerrain.value);
    }
    if (cyclingIndoorOutdoor.present) {
      map['cycling_indoor_outdoor'] = Variable<String>(
        cyclingIndoorOutdoor.value,
      );
    }
    if (cyclingElevationGainFt.present) {
      map['cycling_elevation_gain_ft'] = Variable<int>(
        cyclingElevationGainFt.value,
      );
    }
    if (cyclingSessionGoal.present) {
      map['cycling_session_goal'] = Variable<String>(cyclingSessionGoal.value);
    }
    if (swimmingPacePer100mSeconds.present) {
      map['swimming_pace_per_100m_seconds'] = Variable<int>(
        swimmingPacePer100mSeconds.value,
      );
    }
    if (swimmingPoolOrOpenWater.present) {
      map['swimming_pool_or_open_water'] = Variable<String>(
        swimmingPoolOrOpenWater.value,
      );
    }
    if (swimmingWaterTempC.present) {
      map['swimming_water_temp_c'] = Variable<double>(swimmingWaterTempC.value);
    }
    if (intensityTarget.present) {
      map['intensity_target'] = Variable<String>(intensityTarget.value);
    }
    if (timeBeforeMinutes.present) {
      map['time_before_minutes'] = Variable<int>(timeBeforeMinutes.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderDaysBefore.present) {
      map['reminder_days_before'] = Variable<int>(reminderDaysBefore.value);
    }
    if (reminderTimeOfDay.present) {
      map['reminder_time_of_day'] = Variable<String>(reminderTimeOfDay.value);
    }
    if (reminderRecurring.present) {
      map['reminder_recurring'] = Variable<bool>(reminderRecurring.value);
    }
    if (needsUpload.present) {
      map['needs_upload'] = Variable<bool>(needsUpload.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completionRating.present) {
      map['completion_rating'] = Variable<int>(completionRating.value);
    }
    if (completionNotes.present) {
      map['completion_notes'] = Variable<String>(completionNotes.value);
    }
    if (actualDistanceMiles.present) {
      map['actual_distance_miles'] = Variable<double>(
        actualDistanceMiles.value,
      );
    }
    if (actualDurationMinutes.present) {
      map['actual_duration_minutes'] = Variable<int>(
        actualDurationMinutes.value,
      );
    }
    if (nutritionPlanData.present) {
      map['nutrition_plan_data'] = Variable<String>(nutritionPlanData.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('activityType: $activityType, ')
          ..write('title: $title, ')
          ..write('scheduledDateTime: $scheduledDateTime, ')
          ..write('status: $status, ')
          ..write('distanceMiles: $distanceMiles, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('paceTargetMinutesPerMile: $paceTargetMinutesPerMile, ')
          ..write('intensityLevel: $intensityLevel, ')
          ..write('cyclingSpeedMph: $cyclingSpeedMph, ')
          ..write('cyclingTerrain: $cyclingTerrain, ')
          ..write('cyclingIndoorOutdoor: $cyclingIndoorOutdoor, ')
          ..write('cyclingElevationGainFt: $cyclingElevationGainFt, ')
          ..write('cyclingSessionGoal: $cyclingSessionGoal, ')
          ..write('swimmingPacePer100mSeconds: $swimmingPacePer100mSeconds, ')
          ..write('swimmingPoolOrOpenWater: $swimmingPoolOrOpenWater, ')
          ..write('swimmingWaterTempC: $swimmingWaterTempC, ')
          ..write('intensityTarget: $intensityTarget, ')
          ..write('timeBeforeMinutes: $timeBeforeMinutes, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderDaysBefore: $reminderDaysBefore, ')
          ..write('reminderTimeOfDay: $reminderTimeOfDay, ')
          ..write('reminderRecurring: $reminderRecurring, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('completionRating: $completionRating, ')
          ..write('completionNotes: $completionNotes, ')
          ..write('actualDistanceMiles: $actualDistanceMiles, ')
          ..write('actualDurationMinutes: $actualDurationMinutes, ')
          ..write('nutritionPlanData: $nutritionPlanData, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $EventsTableTable extends EventsTable
    with TableInfo<$EventsTableTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventSubtypeMeta = const VerificationMeta(
    'eventSubtype',
  );
  @override
  late final GeneratedColumn<String> eventSubtype = GeneratedColumn<String>(
    'event_subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventNameMeta = const VerificationMeta(
    'eventName',
  );
  @override
  late final GeneratedColumn<String> eventName = GeneratedColumn<String>(
    'event_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registrationUrlMeta = const VerificationMeta(
    'registrationUrl',
  );
  @override
  late final GeneratedColumn<String> registrationUrl = GeneratedColumn<String>(
    'registration_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalTimeMinutesMeta = const VerificationMeta(
    'goalTimeMinutes',
  );
  @override
  late final GeneratedColumn<int> goalTimeMinutes = GeneratedColumn<int>(
    'goal_time_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalPaceMinutesPerMileMeta =
      const VerificationMeta('goalPaceMinutesPerMile');
  @override
  late final GeneratedColumn<double> goalPaceMinutesPerMile =
      GeneratedColumn<double>(
        'goal_pace_minutes_per_mile',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _predictedFinishTimeMinutesMeta =
      const VerificationMeta('predictedFinishTimeMinutes');
  @override
  late final GeneratedColumn<int> predictedFinishTimeMinutes =
      GeneratedColumn<int>(
        'predicted_finish_time_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hasCarbLoadingMeta = const VerificationMeta(
    'hasCarbLoading',
  );
  @override
  late final GeneratedColumn<bool> hasCarbLoading = GeneratedColumn<bool>(
    'has_carb_loading',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_carb_loading" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _carbLoadingDaysMeta = const VerificationMeta(
    'carbLoadingDays',
  );
  @override
  late final GeneratedColumn<int> carbLoadingDays = GeneratedColumn<int>(
    'carb_loading_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbLoadingStartDateMeta =
      const VerificationMeta('carbLoadingStartDate');
  @override
  late final GeneratedColumn<DateTime> carbLoadingStartDate =
      GeneratedColumn<DateTime>(
        'carb_loading_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hasNutritionPlanMeta = const VerificationMeta(
    'hasNutritionPlan',
  );
  @override
  late final GeneratedColumn<bool> hasNutritionPlan = GeneratedColumn<bool>(
    'has_nutrition_plan',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_nutrition_plan" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bibNumberMeta = const VerificationMeta(
    'bibNumber',
  );
  @override
  late final GeneratedColumn<String> bibNumber = GeneratedColumn<String>(
    'bib_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waveStartTimeMeta = const VerificationMeta(
    'waveStartTime',
  );
  @override
  late final GeneratedColumn<String> waveStartTime = GeneratedColumn<String>(
    'wave_start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packetPickupInfoMeta = const VerificationMeta(
    'packetPickupInfo',
  );
  @override
  late final GeneratedColumn<String> packetPickupInfo = GeneratedColumn<String>(
    'packet_pickup_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualFinishTimeMinutesMeta =
      const VerificationMeta('actualFinishTimeMinutes');
  @override
  late final GeneratedColumn<int> actualFinishTimeMinutes =
      GeneratedColumn<int>(
        'actual_finish_time_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalPlacementMeta = const VerificationMeta(
    'finalPlacement',
  );
  @override
  late final GeneratedColumn<int> finalPlacement = GeneratedColumn<int>(
    'final_placement',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageGroupPlacementMeta = const VerificationMeta(
    'ageGroupPlacement',
  );
  @override
  late final GeneratedColumn<int> ageGroupPlacement = GeneratedColumn<int>(
    'age_group_placement',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _needsUploadMeta = const VerificationMeta(
    'needsUpload',
  );
  @override
  late final GeneratedColumn<bool> needsUpload = GeneratedColumn<bool>(
    'needs_upload',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_upload" IN (0, 1))',
    ),
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    userId,
    eventType,
    eventSubtype,
    eventName,
    location,
    registrationUrl,
    eventDate,
    startTime,
    goalTimeMinutes,
    goalPaceMinutesPerMile,
    predictedFinishTimeMinutes,
    hasCarbLoading,
    carbLoadingDays,
    carbLoadingStartDate,
    hasNutritionPlan,
    bibNumber,
    waveStartTime,
    packetPickupInfo,
    actualFinishTimeMinutes,
    finalPlacement,
    ageGroupPlacement,
    createdAt,
    updatedAt,
    needsUpload,
    localUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('event_subtype')) {
      context.handle(
        _eventSubtypeMeta,
        eventSubtype.isAcceptableOrUnknown(
          data['event_subtype']!,
          _eventSubtypeMeta,
        ),
      );
    }
    if (data.containsKey('event_name')) {
      context.handle(
        _eventNameMeta,
        eventName.isAcceptableOrUnknown(data['event_name']!, _eventNameMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('registration_url')) {
      context.handle(
        _registrationUrlMeta,
        registrationUrl.isAcceptableOrUnknown(
          data['registration_url']!,
          _registrationUrlMeta,
        ),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('goal_time_minutes')) {
      context.handle(
        _goalTimeMinutesMeta,
        goalTimeMinutes.isAcceptableOrUnknown(
          data['goal_time_minutes']!,
          _goalTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('goal_pace_minutes_per_mile')) {
      context.handle(
        _goalPaceMinutesPerMileMeta,
        goalPaceMinutesPerMile.isAcceptableOrUnknown(
          data['goal_pace_minutes_per_mile']!,
          _goalPaceMinutesPerMileMeta,
        ),
      );
    }
    if (data.containsKey('predicted_finish_time_minutes')) {
      context.handle(
        _predictedFinishTimeMinutesMeta,
        predictedFinishTimeMinutes.isAcceptableOrUnknown(
          data['predicted_finish_time_minutes']!,
          _predictedFinishTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('has_carb_loading')) {
      context.handle(
        _hasCarbLoadingMeta,
        hasCarbLoading.isAcceptableOrUnknown(
          data['has_carb_loading']!,
          _hasCarbLoadingMeta,
        ),
      );
    }
    if (data.containsKey('carb_loading_days')) {
      context.handle(
        _carbLoadingDaysMeta,
        carbLoadingDays.isAcceptableOrUnknown(
          data['carb_loading_days']!,
          _carbLoadingDaysMeta,
        ),
      );
    }
    if (data.containsKey('carb_loading_start_date')) {
      context.handle(
        _carbLoadingStartDateMeta,
        carbLoadingStartDate.isAcceptableOrUnknown(
          data['carb_loading_start_date']!,
          _carbLoadingStartDateMeta,
        ),
      );
    }
    if (data.containsKey('has_nutrition_plan')) {
      context.handle(
        _hasNutritionPlanMeta,
        hasNutritionPlan.isAcceptableOrUnknown(
          data['has_nutrition_plan']!,
          _hasNutritionPlanMeta,
        ),
      );
    }
    if (data.containsKey('bib_number')) {
      context.handle(
        _bibNumberMeta,
        bibNumber.isAcceptableOrUnknown(data['bib_number']!, _bibNumberMeta),
      );
    }
    if (data.containsKey('wave_start_time')) {
      context.handle(
        _waveStartTimeMeta,
        waveStartTime.isAcceptableOrUnknown(
          data['wave_start_time']!,
          _waveStartTimeMeta,
        ),
      );
    }
    if (data.containsKey('packet_pickup_info')) {
      context.handle(
        _packetPickupInfoMeta,
        packetPickupInfo.isAcceptableOrUnknown(
          data['packet_pickup_info']!,
          _packetPickupInfoMeta,
        ),
      );
    }
    if (data.containsKey('actual_finish_time_minutes')) {
      context.handle(
        _actualFinishTimeMinutesMeta,
        actualFinishTimeMinutes.isAcceptableOrUnknown(
          data['actual_finish_time_minutes']!,
          _actualFinishTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('final_placement')) {
      context.handle(
        _finalPlacementMeta,
        finalPlacement.isAcceptableOrUnknown(
          data['final_placement']!,
          _finalPlacementMeta,
        ),
      );
    }
    if (data.containsKey('age_group_placement')) {
      context.handle(
        _ageGroupPlacementMeta,
        ageGroupPlacement.isAcceptableOrUnknown(
          data['age_group_placement']!,
          _ageGroupPlacementMeta,
        ),
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
    if (data.containsKey('needs_upload')) {
      context.handle(
        _needsUploadMeta,
        needsUpload.isAcceptableOrUnknown(
          data['needs_upload']!,
          _needsUploadMeta,
        ),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      eventSubtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_subtype'],
      ),
      eventName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_name'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      registrationUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration_url'],
      ),
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      ),
      goalTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_time_minutes'],
      ),
      goalPaceMinutesPerMile: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}goal_pace_minutes_per_mile'],
      ),
      predictedFinishTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}predicted_finish_time_minutes'],
      ),
      hasCarbLoading: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_carb_loading'],
      )!,
      carbLoadingDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carb_loading_days'],
      ),
      carbLoadingStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}carb_loading_start_date'],
      ),
      hasNutritionPlan: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_nutrition_plan'],
      )!,
      bibNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bib_number'],
      ),
      waveStartTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wave_start_time'],
      ),
      packetPickupInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}packet_pickup_info'],
      ),
      actualFinishTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_finish_time_minutes'],
      ),
      finalPlacement: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}final_placement'],
      ),
      ageGroupPlacement: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_group_placement'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      needsUpload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_upload'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      ),
    );
  }

  @override
  $EventsTableTable createAlias(String alias) {
    return $EventsTableTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  final int id;
  final int? activityId;
  final String userId;
  final String eventType;
  final String? eventSubtype;
  final String? eventName;
  final String? location;
  final String? registrationUrl;
  final DateTime? eventDate;
  final String? startTime;
  final int? goalTimeMinutes;
  final double? goalPaceMinutesPerMile;
  final int? predictedFinishTimeMinutes;
  final bool hasCarbLoading;
  final int? carbLoadingDays;
  final DateTime? carbLoadingStartDate;
  final bool hasNutritionPlan;
  final String? bibNumber;
  final String? waveStartTime;
  final String? packetPickupInfo;
  final int? actualFinishTimeMinutes;
  final int? finalPlacement;
  final int? ageGroupPlacement;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? needsUpload;
  final DateTime? localUpdatedAt;
  const Event({
    required this.id,
    this.activityId,
    required this.userId,
    required this.eventType,
    this.eventSubtype,
    this.eventName,
    this.location,
    this.registrationUrl,
    this.eventDate,
    this.startTime,
    this.goalTimeMinutes,
    this.goalPaceMinutesPerMile,
    this.predictedFinishTimeMinutes,
    required this.hasCarbLoading,
    this.carbLoadingDays,
    this.carbLoadingStartDate,
    required this.hasNutritionPlan,
    this.bibNumber,
    this.waveStartTime,
    this.packetPickupInfo,
    this.actualFinishTimeMinutes,
    this.finalPlacement,
    this.ageGroupPlacement,
    required this.createdAt,
    required this.updatedAt,
    this.needsUpload,
    this.localUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<int>(activityId);
    }
    map['user_id'] = Variable<String>(userId);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || eventSubtype != null) {
      map['event_subtype'] = Variable<String>(eventSubtype);
    }
    if (!nullToAbsent || eventName != null) {
      map['event_name'] = Variable<String>(eventName);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || registrationUrl != null) {
      map['registration_url'] = Variable<String>(registrationUrl);
    }
    if (!nullToAbsent || eventDate != null) {
      map['event_date'] = Variable<DateTime>(eventDate);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || goalTimeMinutes != null) {
      map['goal_time_minutes'] = Variable<int>(goalTimeMinutes);
    }
    if (!nullToAbsent || goalPaceMinutesPerMile != null) {
      map['goal_pace_minutes_per_mile'] = Variable<double>(
        goalPaceMinutesPerMile,
      );
    }
    if (!nullToAbsent || predictedFinishTimeMinutes != null) {
      map['predicted_finish_time_minutes'] = Variable<int>(
        predictedFinishTimeMinutes,
      );
    }
    map['has_carb_loading'] = Variable<bool>(hasCarbLoading);
    if (!nullToAbsent || carbLoadingDays != null) {
      map['carb_loading_days'] = Variable<int>(carbLoadingDays);
    }
    if (!nullToAbsent || carbLoadingStartDate != null) {
      map['carb_loading_start_date'] = Variable<DateTime>(carbLoadingStartDate);
    }
    map['has_nutrition_plan'] = Variable<bool>(hasNutritionPlan);
    if (!nullToAbsent || bibNumber != null) {
      map['bib_number'] = Variable<String>(bibNumber);
    }
    if (!nullToAbsent || waveStartTime != null) {
      map['wave_start_time'] = Variable<String>(waveStartTime);
    }
    if (!nullToAbsent || packetPickupInfo != null) {
      map['packet_pickup_info'] = Variable<String>(packetPickupInfo);
    }
    if (!nullToAbsent || actualFinishTimeMinutes != null) {
      map['actual_finish_time_minutes'] = Variable<int>(
        actualFinishTimeMinutes,
      );
    }
    if (!nullToAbsent || finalPlacement != null) {
      map['final_placement'] = Variable<int>(finalPlacement);
    }
    if (!nullToAbsent || ageGroupPlacement != null) {
      map['age_group_placement'] = Variable<int>(ageGroupPlacement);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || needsUpload != null) {
      map['needs_upload'] = Variable<bool>(needsUpload);
    }
    if (!nullToAbsent || localUpdatedAt != null) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    }
    return map;
  }

  EventsTableCompanion toCompanion(bool nullToAbsent) {
    return EventsTableCompanion(
      id: Value(id),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      userId: Value(userId),
      eventType: Value(eventType),
      eventSubtype: eventSubtype == null && nullToAbsent
          ? const Value.absent()
          : Value(eventSubtype),
      eventName: eventName == null && nullToAbsent
          ? const Value.absent()
          : Value(eventName),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      registrationUrl: registrationUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(registrationUrl),
      eventDate: eventDate == null && nullToAbsent
          ? const Value.absent()
          : Value(eventDate),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      goalTimeMinutes: goalTimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(goalTimeMinutes),
      goalPaceMinutesPerMile: goalPaceMinutesPerMile == null && nullToAbsent
          ? const Value.absent()
          : Value(goalPaceMinutesPerMile),
      predictedFinishTimeMinutes:
          predictedFinishTimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(predictedFinishTimeMinutes),
      hasCarbLoading: Value(hasCarbLoading),
      carbLoadingDays: carbLoadingDays == null && nullToAbsent
          ? const Value.absent()
          : Value(carbLoadingDays),
      carbLoadingStartDate: carbLoadingStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(carbLoadingStartDate),
      hasNutritionPlan: Value(hasNutritionPlan),
      bibNumber: bibNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(bibNumber),
      waveStartTime: waveStartTime == null && nullToAbsent
          ? const Value.absent()
          : Value(waveStartTime),
      packetPickupInfo: packetPickupInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(packetPickupInfo),
      actualFinishTimeMinutes: actualFinishTimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualFinishTimeMinutes),
      finalPlacement: finalPlacement == null && nullToAbsent
          ? const Value.absent()
          : Value(finalPlacement),
      ageGroupPlacement: ageGroupPlacement == null && nullToAbsent
          ? const Value.absent()
          : Value(ageGroupPlacement),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      needsUpload: needsUpload == null && nullToAbsent
          ? const Value.absent()
          : Value(needsUpload),
      localUpdatedAt: localUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(localUpdatedAt),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<int>(json['id']),
      activityId: serializer.fromJson<int?>(json['activityId']),
      userId: serializer.fromJson<String>(json['userId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      eventSubtype: serializer.fromJson<String?>(json['eventSubtype']),
      eventName: serializer.fromJson<String?>(json['eventName']),
      location: serializer.fromJson<String?>(json['location']),
      registrationUrl: serializer.fromJson<String?>(json['registrationUrl']),
      eventDate: serializer.fromJson<DateTime?>(json['eventDate']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      goalTimeMinutes: serializer.fromJson<int?>(json['goalTimeMinutes']),
      goalPaceMinutesPerMile: serializer.fromJson<double?>(
        json['goalPaceMinutesPerMile'],
      ),
      predictedFinishTimeMinutes: serializer.fromJson<int?>(
        json['predictedFinishTimeMinutes'],
      ),
      hasCarbLoading: serializer.fromJson<bool>(json['hasCarbLoading']),
      carbLoadingDays: serializer.fromJson<int?>(json['carbLoadingDays']),
      carbLoadingStartDate: serializer.fromJson<DateTime?>(
        json['carbLoadingStartDate'],
      ),
      hasNutritionPlan: serializer.fromJson<bool>(json['hasNutritionPlan']),
      bibNumber: serializer.fromJson<String?>(json['bibNumber']),
      waveStartTime: serializer.fromJson<String?>(json['waveStartTime']),
      packetPickupInfo: serializer.fromJson<String?>(json['packetPickupInfo']),
      actualFinishTimeMinutes: serializer.fromJson<int?>(
        json['actualFinishTimeMinutes'],
      ),
      finalPlacement: serializer.fromJson<int?>(json['finalPlacement']),
      ageGroupPlacement: serializer.fromJson<int?>(json['ageGroupPlacement']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      needsUpload: serializer.fromJson<bool?>(json['needsUpload']),
      localUpdatedAt: serializer.fromJson<DateTime?>(json['localUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activityId': serializer.toJson<int?>(activityId),
      'userId': serializer.toJson<String>(userId),
      'eventType': serializer.toJson<String>(eventType),
      'eventSubtype': serializer.toJson<String?>(eventSubtype),
      'eventName': serializer.toJson<String?>(eventName),
      'location': serializer.toJson<String?>(location),
      'registrationUrl': serializer.toJson<String?>(registrationUrl),
      'eventDate': serializer.toJson<DateTime?>(eventDate),
      'startTime': serializer.toJson<String?>(startTime),
      'goalTimeMinutes': serializer.toJson<int?>(goalTimeMinutes),
      'goalPaceMinutesPerMile': serializer.toJson<double?>(
        goalPaceMinutesPerMile,
      ),
      'predictedFinishTimeMinutes': serializer.toJson<int?>(
        predictedFinishTimeMinutes,
      ),
      'hasCarbLoading': serializer.toJson<bool>(hasCarbLoading),
      'carbLoadingDays': serializer.toJson<int?>(carbLoadingDays),
      'carbLoadingStartDate': serializer.toJson<DateTime?>(
        carbLoadingStartDate,
      ),
      'hasNutritionPlan': serializer.toJson<bool>(hasNutritionPlan),
      'bibNumber': serializer.toJson<String?>(bibNumber),
      'waveStartTime': serializer.toJson<String?>(waveStartTime),
      'packetPickupInfo': serializer.toJson<String?>(packetPickupInfo),
      'actualFinishTimeMinutes': serializer.toJson<int?>(
        actualFinishTimeMinutes,
      ),
      'finalPlacement': serializer.toJson<int?>(finalPlacement),
      'ageGroupPlacement': serializer.toJson<int?>(ageGroupPlacement),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'needsUpload': serializer.toJson<bool?>(needsUpload),
      'localUpdatedAt': serializer.toJson<DateTime?>(localUpdatedAt),
    };
  }

  Event copyWith({
    int? id,
    Value<int?> activityId = const Value.absent(),
    String? userId,
    String? eventType,
    Value<String?> eventSubtype = const Value.absent(),
    Value<String?> eventName = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> registrationUrl = const Value.absent(),
    Value<DateTime?> eventDate = const Value.absent(),
    Value<String?> startTime = const Value.absent(),
    Value<int?> goalTimeMinutes = const Value.absent(),
    Value<double?> goalPaceMinutesPerMile = const Value.absent(),
    Value<int?> predictedFinishTimeMinutes = const Value.absent(),
    bool? hasCarbLoading,
    Value<int?> carbLoadingDays = const Value.absent(),
    Value<DateTime?> carbLoadingStartDate = const Value.absent(),
    bool? hasNutritionPlan,
    Value<String?> bibNumber = const Value.absent(),
    Value<String?> waveStartTime = const Value.absent(),
    Value<String?> packetPickupInfo = const Value.absent(),
    Value<int?> actualFinishTimeMinutes = const Value.absent(),
    Value<int?> finalPlacement = const Value.absent(),
    Value<int?> ageGroupPlacement = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<bool?> needsUpload = const Value.absent(),
    Value<DateTime?> localUpdatedAt = const Value.absent(),
  }) => Event(
    id: id ?? this.id,
    activityId: activityId.present ? activityId.value : this.activityId,
    userId: userId ?? this.userId,
    eventType: eventType ?? this.eventType,
    eventSubtype: eventSubtype.present ? eventSubtype.value : this.eventSubtype,
    eventName: eventName.present ? eventName.value : this.eventName,
    location: location.present ? location.value : this.location,
    registrationUrl: registrationUrl.present
        ? registrationUrl.value
        : this.registrationUrl,
    eventDate: eventDate.present ? eventDate.value : this.eventDate,
    startTime: startTime.present ? startTime.value : this.startTime,
    goalTimeMinutes: goalTimeMinutes.present
        ? goalTimeMinutes.value
        : this.goalTimeMinutes,
    goalPaceMinutesPerMile: goalPaceMinutesPerMile.present
        ? goalPaceMinutesPerMile.value
        : this.goalPaceMinutesPerMile,
    predictedFinishTimeMinutes: predictedFinishTimeMinutes.present
        ? predictedFinishTimeMinutes.value
        : this.predictedFinishTimeMinutes,
    hasCarbLoading: hasCarbLoading ?? this.hasCarbLoading,
    carbLoadingDays: carbLoadingDays.present
        ? carbLoadingDays.value
        : this.carbLoadingDays,
    carbLoadingStartDate: carbLoadingStartDate.present
        ? carbLoadingStartDate.value
        : this.carbLoadingStartDate,
    hasNutritionPlan: hasNutritionPlan ?? this.hasNutritionPlan,
    bibNumber: bibNumber.present ? bibNumber.value : this.bibNumber,
    waveStartTime: waveStartTime.present
        ? waveStartTime.value
        : this.waveStartTime,
    packetPickupInfo: packetPickupInfo.present
        ? packetPickupInfo.value
        : this.packetPickupInfo,
    actualFinishTimeMinutes: actualFinishTimeMinutes.present
        ? actualFinishTimeMinutes.value
        : this.actualFinishTimeMinutes,
    finalPlacement: finalPlacement.present
        ? finalPlacement.value
        : this.finalPlacement,
    ageGroupPlacement: ageGroupPlacement.present
        ? ageGroupPlacement.value
        : this.ageGroupPlacement,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    needsUpload: needsUpload.present ? needsUpload.value : this.needsUpload,
    localUpdatedAt: localUpdatedAt.present
        ? localUpdatedAt.value
        : this.localUpdatedAt,
  );
  Event copyWithCompanion(EventsTableCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      userId: data.userId.present ? data.userId.value : this.userId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      eventSubtype: data.eventSubtype.present
          ? data.eventSubtype.value
          : this.eventSubtype,
      eventName: data.eventName.present ? data.eventName.value : this.eventName,
      location: data.location.present ? data.location.value : this.location,
      registrationUrl: data.registrationUrl.present
          ? data.registrationUrl.value
          : this.registrationUrl,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      goalTimeMinutes: data.goalTimeMinutes.present
          ? data.goalTimeMinutes.value
          : this.goalTimeMinutes,
      goalPaceMinutesPerMile: data.goalPaceMinutesPerMile.present
          ? data.goalPaceMinutesPerMile.value
          : this.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes: data.predictedFinishTimeMinutes.present
          ? data.predictedFinishTimeMinutes.value
          : this.predictedFinishTimeMinutes,
      hasCarbLoading: data.hasCarbLoading.present
          ? data.hasCarbLoading.value
          : this.hasCarbLoading,
      carbLoadingDays: data.carbLoadingDays.present
          ? data.carbLoadingDays.value
          : this.carbLoadingDays,
      carbLoadingStartDate: data.carbLoadingStartDate.present
          ? data.carbLoadingStartDate.value
          : this.carbLoadingStartDate,
      hasNutritionPlan: data.hasNutritionPlan.present
          ? data.hasNutritionPlan.value
          : this.hasNutritionPlan,
      bibNumber: data.bibNumber.present ? data.bibNumber.value : this.bibNumber,
      waveStartTime: data.waveStartTime.present
          ? data.waveStartTime.value
          : this.waveStartTime,
      packetPickupInfo: data.packetPickupInfo.present
          ? data.packetPickupInfo.value
          : this.packetPickupInfo,
      actualFinishTimeMinutes: data.actualFinishTimeMinutes.present
          ? data.actualFinishTimeMinutes.value
          : this.actualFinishTimeMinutes,
      finalPlacement: data.finalPlacement.present
          ? data.finalPlacement.value
          : this.finalPlacement,
      ageGroupPlacement: data.ageGroupPlacement.present
          ? data.ageGroupPlacement.value
          : this.ageGroupPlacement,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      needsUpload: data.needsUpload.present
          ? data.needsUpload.value
          : this.needsUpload,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('userId: $userId, ')
          ..write('eventType: $eventType, ')
          ..write('eventSubtype: $eventSubtype, ')
          ..write('eventName: $eventName, ')
          ..write('location: $location, ')
          ..write('registrationUrl: $registrationUrl, ')
          ..write('eventDate: $eventDate, ')
          ..write('startTime: $startTime, ')
          ..write('goalTimeMinutes: $goalTimeMinutes, ')
          ..write('goalPaceMinutesPerMile: $goalPaceMinutesPerMile, ')
          ..write('predictedFinishTimeMinutes: $predictedFinishTimeMinutes, ')
          ..write('hasCarbLoading: $hasCarbLoading, ')
          ..write('carbLoadingDays: $carbLoadingDays, ')
          ..write('carbLoadingStartDate: $carbLoadingStartDate, ')
          ..write('hasNutritionPlan: $hasNutritionPlan, ')
          ..write('bibNumber: $bibNumber, ')
          ..write('waveStartTime: $waveStartTime, ')
          ..write('packetPickupInfo: $packetPickupInfo, ')
          ..write('actualFinishTimeMinutes: $actualFinishTimeMinutes, ')
          ..write('finalPlacement: $finalPlacement, ')
          ..write('ageGroupPlacement: $ageGroupPlacement, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    activityId,
    userId,
    eventType,
    eventSubtype,
    eventName,
    location,
    registrationUrl,
    eventDate,
    startTime,
    goalTimeMinutes,
    goalPaceMinutesPerMile,
    predictedFinishTimeMinutes,
    hasCarbLoading,
    carbLoadingDays,
    carbLoadingStartDate,
    hasNutritionPlan,
    bibNumber,
    waveStartTime,
    packetPickupInfo,
    actualFinishTimeMinutes,
    finalPlacement,
    ageGroupPlacement,
    createdAt,
    updatedAt,
    needsUpload,
    localUpdatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.userId == this.userId &&
          other.eventType == this.eventType &&
          other.eventSubtype == this.eventSubtype &&
          other.eventName == this.eventName &&
          other.location == this.location &&
          other.registrationUrl == this.registrationUrl &&
          other.eventDate == this.eventDate &&
          other.startTime == this.startTime &&
          other.goalTimeMinutes == this.goalTimeMinutes &&
          other.goalPaceMinutesPerMile == this.goalPaceMinutesPerMile &&
          other.predictedFinishTimeMinutes == this.predictedFinishTimeMinutes &&
          other.hasCarbLoading == this.hasCarbLoading &&
          other.carbLoadingDays == this.carbLoadingDays &&
          other.carbLoadingStartDate == this.carbLoadingStartDate &&
          other.hasNutritionPlan == this.hasNutritionPlan &&
          other.bibNumber == this.bibNumber &&
          other.waveStartTime == this.waveStartTime &&
          other.packetPickupInfo == this.packetPickupInfo &&
          other.actualFinishTimeMinutes == this.actualFinishTimeMinutes &&
          other.finalPlacement == this.finalPlacement &&
          other.ageGroupPlacement == this.ageGroupPlacement &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.needsUpload == this.needsUpload &&
          other.localUpdatedAt == this.localUpdatedAt);
}

class EventsTableCompanion extends UpdateCompanion<Event> {
  final Value<int> id;
  final Value<int?> activityId;
  final Value<String> userId;
  final Value<String> eventType;
  final Value<String?> eventSubtype;
  final Value<String?> eventName;
  final Value<String?> location;
  final Value<String?> registrationUrl;
  final Value<DateTime?> eventDate;
  final Value<String?> startTime;
  final Value<int?> goalTimeMinutes;
  final Value<double?> goalPaceMinutesPerMile;
  final Value<int?> predictedFinishTimeMinutes;
  final Value<bool> hasCarbLoading;
  final Value<int?> carbLoadingDays;
  final Value<DateTime?> carbLoadingStartDate;
  final Value<bool> hasNutritionPlan;
  final Value<String?> bibNumber;
  final Value<String?> waveStartTime;
  final Value<String?> packetPickupInfo;
  final Value<int?> actualFinishTimeMinutes;
  final Value<int?> finalPlacement;
  final Value<int?> ageGroupPlacement;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool?> needsUpload;
  final Value<DateTime?> localUpdatedAt;
  const EventsTableCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.userId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.eventSubtype = const Value.absent(),
    this.eventName = const Value.absent(),
    this.location = const Value.absent(),
    this.registrationUrl = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.goalTimeMinutes = const Value.absent(),
    this.goalPaceMinutesPerMile = const Value.absent(),
    this.predictedFinishTimeMinutes = const Value.absent(),
    this.hasCarbLoading = const Value.absent(),
    this.carbLoadingDays = const Value.absent(),
    this.carbLoadingStartDate = const Value.absent(),
    this.hasNutritionPlan = const Value.absent(),
    this.bibNumber = const Value.absent(),
    this.waveStartTime = const Value.absent(),
    this.packetPickupInfo = const Value.absent(),
    this.actualFinishTimeMinutes = const Value.absent(),
    this.finalPlacement = const Value.absent(),
    this.ageGroupPlacement = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
  });
  EventsTableCompanion.insert({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    required String userId,
    required String eventType,
    this.eventSubtype = const Value.absent(),
    this.eventName = const Value.absent(),
    this.location = const Value.absent(),
    this.registrationUrl = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.goalTimeMinutes = const Value.absent(),
    this.goalPaceMinutesPerMile = const Value.absent(),
    this.predictedFinishTimeMinutes = const Value.absent(),
    this.hasCarbLoading = const Value.absent(),
    this.carbLoadingDays = const Value.absent(),
    this.carbLoadingStartDate = const Value.absent(),
    this.hasNutritionPlan = const Value.absent(),
    this.bibNumber = const Value.absent(),
    this.waveStartTime = const Value.absent(),
    this.packetPickupInfo = const Value.absent(),
    this.actualFinishTimeMinutes = const Value.absent(),
    this.finalPlacement = const Value.absent(),
    this.ageGroupPlacement = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
  }) : userId = Value(userId),
       eventType = Value(eventType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Event> custom({
    Expression<int>? id,
    Expression<int>? activityId,
    Expression<String>? userId,
    Expression<String>? eventType,
    Expression<String>? eventSubtype,
    Expression<String>? eventName,
    Expression<String>? location,
    Expression<String>? registrationUrl,
    Expression<DateTime>? eventDate,
    Expression<String>? startTime,
    Expression<int>? goalTimeMinutes,
    Expression<double>? goalPaceMinutesPerMile,
    Expression<int>? predictedFinishTimeMinutes,
    Expression<bool>? hasCarbLoading,
    Expression<int>? carbLoadingDays,
    Expression<DateTime>? carbLoadingStartDate,
    Expression<bool>? hasNutritionPlan,
    Expression<String>? bibNumber,
    Expression<String>? waveStartTime,
    Expression<String>? packetPickupInfo,
    Expression<int>? actualFinishTimeMinutes,
    Expression<int>? finalPlacement,
    Expression<int>? ageGroupPlacement,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? needsUpload,
    Expression<DateTime>? localUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (userId != null) 'user_id': userId,
      if (eventType != null) 'event_type': eventType,
      if (eventSubtype != null) 'event_subtype': eventSubtype,
      if (eventName != null) 'event_name': eventName,
      if (location != null) 'location': location,
      if (registrationUrl != null) 'registration_url': registrationUrl,
      if (eventDate != null) 'event_date': eventDate,
      if (startTime != null) 'start_time': startTime,
      if (goalTimeMinutes != null) 'goal_time_minutes': goalTimeMinutes,
      if (goalPaceMinutesPerMile != null)
        'goal_pace_minutes_per_mile': goalPaceMinutesPerMile,
      if (predictedFinishTimeMinutes != null)
        'predicted_finish_time_minutes': predictedFinishTimeMinutes,
      if (hasCarbLoading != null) 'has_carb_loading': hasCarbLoading,
      if (carbLoadingDays != null) 'carb_loading_days': carbLoadingDays,
      if (carbLoadingStartDate != null)
        'carb_loading_start_date': carbLoadingStartDate,
      if (hasNutritionPlan != null) 'has_nutrition_plan': hasNutritionPlan,
      if (bibNumber != null) 'bib_number': bibNumber,
      if (waveStartTime != null) 'wave_start_time': waveStartTime,
      if (packetPickupInfo != null) 'packet_pickup_info': packetPickupInfo,
      if (actualFinishTimeMinutes != null)
        'actual_finish_time_minutes': actualFinishTimeMinutes,
      if (finalPlacement != null) 'final_placement': finalPlacement,
      if (ageGroupPlacement != null) 'age_group_placement': ageGroupPlacement,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (needsUpload != null) 'needs_upload': needsUpload,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
    });
  }

  EventsTableCompanion copyWith({
    Value<int>? id,
    Value<int?>? activityId,
    Value<String>? userId,
    Value<String>? eventType,
    Value<String?>? eventSubtype,
    Value<String?>? eventName,
    Value<String?>? location,
    Value<String?>? registrationUrl,
    Value<DateTime?>? eventDate,
    Value<String?>? startTime,
    Value<int?>? goalTimeMinutes,
    Value<double?>? goalPaceMinutesPerMile,
    Value<int?>? predictedFinishTimeMinutes,
    Value<bool>? hasCarbLoading,
    Value<int?>? carbLoadingDays,
    Value<DateTime?>? carbLoadingStartDate,
    Value<bool>? hasNutritionPlan,
    Value<String?>? bibNumber,
    Value<String?>? waveStartTime,
    Value<String?>? packetPickupInfo,
    Value<int?>? actualFinishTimeMinutes,
    Value<int?>? finalPlacement,
    Value<int?>? ageGroupPlacement,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool?>? needsUpload,
    Value<DateTime?>? localUpdatedAt,
  }) {
    return EventsTableCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      eventSubtype: eventSubtype ?? this.eventSubtype,
      eventName: eventName ?? this.eventName,
      location: location ?? this.location,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      goalTimeMinutes: goalTimeMinutes ?? this.goalTimeMinutes,
      goalPaceMinutesPerMile:
          goalPaceMinutesPerMile ?? this.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes:
          predictedFinishTimeMinutes ?? this.predictedFinishTimeMinutes,
      hasCarbLoading: hasCarbLoading ?? this.hasCarbLoading,
      carbLoadingDays: carbLoadingDays ?? this.carbLoadingDays,
      carbLoadingStartDate: carbLoadingStartDate ?? this.carbLoadingStartDate,
      hasNutritionPlan: hasNutritionPlan ?? this.hasNutritionPlan,
      bibNumber: bibNumber ?? this.bibNumber,
      waveStartTime: waveStartTime ?? this.waveStartTime,
      packetPickupInfo: packetPickupInfo ?? this.packetPickupInfo,
      actualFinishTimeMinutes:
          actualFinishTimeMinutes ?? this.actualFinishTimeMinutes,
      finalPlacement: finalPlacement ?? this.finalPlacement,
      ageGroupPlacement: ageGroupPlacement ?? this.ageGroupPlacement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (eventSubtype.present) {
      map['event_subtype'] = Variable<String>(eventSubtype.value);
    }
    if (eventName.present) {
      map['event_name'] = Variable<String>(eventName.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (registrationUrl.present) {
      map['registration_url'] = Variable<String>(registrationUrl.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (goalTimeMinutes.present) {
      map['goal_time_minutes'] = Variable<int>(goalTimeMinutes.value);
    }
    if (goalPaceMinutesPerMile.present) {
      map['goal_pace_minutes_per_mile'] = Variable<double>(
        goalPaceMinutesPerMile.value,
      );
    }
    if (predictedFinishTimeMinutes.present) {
      map['predicted_finish_time_minutes'] = Variable<int>(
        predictedFinishTimeMinutes.value,
      );
    }
    if (hasCarbLoading.present) {
      map['has_carb_loading'] = Variable<bool>(hasCarbLoading.value);
    }
    if (carbLoadingDays.present) {
      map['carb_loading_days'] = Variable<int>(carbLoadingDays.value);
    }
    if (carbLoadingStartDate.present) {
      map['carb_loading_start_date'] = Variable<DateTime>(
        carbLoadingStartDate.value,
      );
    }
    if (hasNutritionPlan.present) {
      map['has_nutrition_plan'] = Variable<bool>(hasNutritionPlan.value);
    }
    if (bibNumber.present) {
      map['bib_number'] = Variable<String>(bibNumber.value);
    }
    if (waveStartTime.present) {
      map['wave_start_time'] = Variable<String>(waveStartTime.value);
    }
    if (packetPickupInfo.present) {
      map['packet_pickup_info'] = Variable<String>(packetPickupInfo.value);
    }
    if (actualFinishTimeMinutes.present) {
      map['actual_finish_time_minutes'] = Variable<int>(
        actualFinishTimeMinutes.value,
      );
    }
    if (finalPlacement.present) {
      map['final_placement'] = Variable<int>(finalPlacement.value);
    }
    if (ageGroupPlacement.present) {
      map['age_group_placement'] = Variable<int>(ageGroupPlacement.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (needsUpload.present) {
      map['needs_upload'] = Variable<bool>(needsUpload.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsTableCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('userId: $userId, ')
          ..write('eventType: $eventType, ')
          ..write('eventSubtype: $eventSubtype, ')
          ..write('eventName: $eventName, ')
          ..write('location: $location, ')
          ..write('registrationUrl: $registrationUrl, ')
          ..write('eventDate: $eventDate, ')
          ..write('startTime: $startTime, ')
          ..write('goalTimeMinutes: $goalTimeMinutes, ')
          ..write('goalPaceMinutesPerMile: $goalPaceMinutesPerMile, ')
          ..write('predictedFinishTimeMinutes: $predictedFinishTimeMinutes, ')
          ..write('hasCarbLoading: $hasCarbLoading, ')
          ..write('carbLoadingDays: $carbLoadingDays, ')
          ..write('carbLoadingStartDate: $carbLoadingStartDate, ')
          ..write('hasNutritionPlan: $hasNutritionPlan, ')
          ..write('bibNumber: $bibNumber, ')
          ..write('waveStartTime: $waveStartTime, ')
          ..write('packetPickupInfo: $packetPickupInfo, ')
          ..write('actualFinishTimeMinutes: $actualFinishTimeMinutes, ')
          ..write('finalPlacement: $finalPlacement, ')
          ..write('ageGroupPlacement: $ageGroupPlacement, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingPlansTableTable extends CarbLoadingPlansTable
    with TableInfo<$CarbLoadingPlansTableTable, CarbLoadingPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingPlansTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalDaysMeta = const VerificationMeta(
    'totalDays',
  );
  @override
  late final GeneratedColumn<int> totalDays = GeneratedColumn<int>(
    'total_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyCarbTargetGramsMeta =
      const VerificationMeta('dailyCarbTargetGrams');
  @override
  late final GeneratedColumn<int> dailyCarbTargetGrams = GeneratedColumn<int>(
    'daily_carb_target_grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyCalorieTargetMeta =
      const VerificationMeta('dailyCalorieTarget');
  @override
  late final GeneratedColumn<int> dailyCalorieTarget = GeneratedColumn<int>(
    'daily_calorie_target',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('v1.0'),
  );
  static const VerificationMeta _adherenceScoreMeta = const VerificationMeta(
    'adherenceScore',
  );
  @override
  late final GeneratedColumn<double> adherenceScore = GeneratedColumn<double>(
    'adherence_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needsUploadMeta = const VerificationMeta(
    'needsUpload',
  );
  @override
  late final GeneratedColumn<bool> needsUpload = GeneratedColumn<bool>(
    'needs_upload',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_upload" IN (0, 1))',
    ),
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    userId,
    totalDays,
    startDate,
    endDate,
    dailyCarbTargetGrams,
    dailyCalorieTarget,
    generatedAt,
    algorithmVersion,
    adherenceScore,
    completedAt,
    needsUpload,
    localUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarbLoadingPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('total_days')) {
      context.handle(
        _totalDaysMeta,
        totalDays.isAcceptableOrUnknown(data['total_days']!, _totalDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_totalDaysMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('daily_carb_target_grams')) {
      context.handle(
        _dailyCarbTargetGramsMeta,
        dailyCarbTargetGrams.isAcceptableOrUnknown(
          data['daily_carb_target_grams']!,
          _dailyCarbTargetGramsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyCarbTargetGramsMeta);
    }
    if (data.containsKey('daily_calorie_target')) {
      context.handle(
        _dailyCalorieTargetMeta,
        dailyCalorieTarget.isAcceptableOrUnknown(
          data['daily_calorie_target']!,
          _dailyCalorieTargetMeta,
        ),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('adherence_score')) {
      context.handle(
        _adherenceScoreMeta,
        adherenceScore.isAcceptableOrUnknown(
          data['adherence_score']!,
          _adherenceScoreMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('needs_upload')) {
      context.handle(
        _needsUploadMeta,
        needsUpload.isAcceptableOrUnknown(
          data['needs_upload']!,
          _needsUploadMeta,
        ),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarbLoadingPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      totalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_days'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      dailyCarbTargetGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_carb_target_grams'],
      )!,
      dailyCalorieTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_calorie_target'],
      ),
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      )!,
      adherenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}adherence_score'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      needsUpload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_upload'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      ),
    );
  }

  @override
  $CarbLoadingPlansTableTable createAlias(String alias) {
    return $CarbLoadingPlansTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingPlan extends DataClass implements Insertable<CarbLoadingPlan> {
  final int id;
  final int? eventId;
  final String userId;
  final int totalDays;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyCarbTargetGrams;
  final int? dailyCalorieTarget;
  final DateTime generatedAt;
  final String algorithmVersion;
  final double? adherenceScore;
  final DateTime? completedAt;
  final bool? needsUpload;
  final DateTime? localUpdatedAt;
  const CarbLoadingPlan({
    required this.id,
    this.eventId,
    required this.userId,
    required this.totalDays,
    required this.startDate,
    required this.endDate,
    required this.dailyCarbTargetGrams,
    this.dailyCalorieTarget,
    required this.generatedAt,
    required this.algorithmVersion,
    this.adherenceScore,
    this.completedAt,
    this.needsUpload,
    this.localUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<int>(eventId);
    }
    map['user_id'] = Variable<String>(userId);
    map['total_days'] = Variable<int>(totalDays);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['daily_carb_target_grams'] = Variable<int>(dailyCarbTargetGrams);
    if (!nullToAbsent || dailyCalorieTarget != null) {
      map['daily_calorie_target'] = Variable<int>(dailyCalorieTarget);
    }
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['algorithm_version'] = Variable<String>(algorithmVersion);
    if (!nullToAbsent || adherenceScore != null) {
      map['adherence_score'] = Variable<double>(adherenceScore);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || needsUpload != null) {
      map['needs_upload'] = Variable<bool>(needsUpload);
    }
    if (!nullToAbsent || localUpdatedAt != null) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    }
    return map;
  }

  CarbLoadingPlansTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingPlansTableCompanion(
      id: Value(id),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      userId: Value(userId),
      totalDays: Value(totalDays),
      startDate: Value(startDate),
      endDate: Value(endDate),
      dailyCarbTargetGrams: Value(dailyCarbTargetGrams),
      dailyCalorieTarget: dailyCalorieTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyCalorieTarget),
      generatedAt: Value(generatedAt),
      algorithmVersion: Value(algorithmVersion),
      adherenceScore: adherenceScore == null && nullToAbsent
          ? const Value.absent()
          : Value(adherenceScore),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      needsUpload: needsUpload == null && nullToAbsent
          ? const Value.absent()
          : Value(needsUpload),
      localUpdatedAt: localUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(localUpdatedAt),
    );
  }

  factory CarbLoadingPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingPlan(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int?>(json['eventId']),
      userId: serializer.fromJson<String>(json['userId']),
      totalDays: serializer.fromJson<int>(json['totalDays']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      dailyCarbTargetGrams: serializer.fromJson<int>(
        json['dailyCarbTargetGrams'],
      ),
      dailyCalorieTarget: serializer.fromJson<int?>(json['dailyCalorieTarget']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      algorithmVersion: serializer.fromJson<String>(json['algorithmVersion']),
      adherenceScore: serializer.fromJson<double?>(json['adherenceScore']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      needsUpload: serializer.fromJson<bool?>(json['needsUpload']),
      localUpdatedAt: serializer.fromJson<DateTime?>(json['localUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int?>(eventId),
      'userId': serializer.toJson<String>(userId),
      'totalDays': serializer.toJson<int>(totalDays),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'dailyCarbTargetGrams': serializer.toJson<int>(dailyCarbTargetGrams),
      'dailyCalorieTarget': serializer.toJson<int?>(dailyCalorieTarget),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'algorithmVersion': serializer.toJson<String>(algorithmVersion),
      'adherenceScore': serializer.toJson<double?>(adherenceScore),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'needsUpload': serializer.toJson<bool?>(needsUpload),
      'localUpdatedAt': serializer.toJson<DateTime?>(localUpdatedAt),
    };
  }

  CarbLoadingPlan copyWith({
    int? id,
    Value<int?> eventId = const Value.absent(),
    String? userId,
    int? totalDays,
    DateTime? startDate,
    DateTime? endDate,
    int? dailyCarbTargetGrams,
    Value<int?> dailyCalorieTarget = const Value.absent(),
    DateTime? generatedAt,
    String? algorithmVersion,
    Value<double?> adherenceScore = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<bool?> needsUpload = const Value.absent(),
    Value<DateTime?> localUpdatedAt = const Value.absent(),
  }) => CarbLoadingPlan(
    id: id ?? this.id,
    eventId: eventId.present ? eventId.value : this.eventId,
    userId: userId ?? this.userId,
    totalDays: totalDays ?? this.totalDays,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    dailyCarbTargetGrams: dailyCarbTargetGrams ?? this.dailyCarbTargetGrams,
    dailyCalorieTarget: dailyCalorieTarget.present
        ? dailyCalorieTarget.value
        : this.dailyCalorieTarget,
    generatedAt: generatedAt ?? this.generatedAt,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
    adherenceScore: adherenceScore.present
        ? adherenceScore.value
        : this.adherenceScore,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    needsUpload: needsUpload.present ? needsUpload.value : this.needsUpload,
    localUpdatedAt: localUpdatedAt.present
        ? localUpdatedAt.value
        : this.localUpdatedAt,
  );
  CarbLoadingPlan copyWithCompanion(CarbLoadingPlansTableCompanion data) {
    return CarbLoadingPlan(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      userId: data.userId.present ? data.userId.value : this.userId,
      totalDays: data.totalDays.present ? data.totalDays.value : this.totalDays,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      dailyCarbTargetGrams: data.dailyCarbTargetGrams.present
          ? data.dailyCarbTargetGrams.value
          : this.dailyCarbTargetGrams,
      dailyCalorieTarget: data.dailyCalorieTarget.present
          ? data.dailyCalorieTarget.value
          : this.dailyCalorieTarget,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      adherenceScore: data.adherenceScore.present
          ? data.adherenceScore.value
          : this.adherenceScore,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      needsUpload: data.needsUpload.present
          ? data.needsUpload.value
          : this.needsUpload,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingPlan(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('totalDays: $totalDays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('dailyCarbTargetGrams: $dailyCarbTargetGrams, ')
          ..write('dailyCalorieTarget: $dailyCalorieTarget, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('adherenceScore: $adherenceScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    userId,
    totalDays,
    startDate,
    endDate,
    dailyCarbTargetGrams,
    dailyCalorieTarget,
    generatedAt,
    algorithmVersion,
    adherenceScore,
    completedAt,
    needsUpload,
    localUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingPlan &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.userId == this.userId &&
          other.totalDays == this.totalDays &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.dailyCarbTargetGrams == this.dailyCarbTargetGrams &&
          other.dailyCalorieTarget == this.dailyCalorieTarget &&
          other.generatedAt == this.generatedAt &&
          other.algorithmVersion == this.algorithmVersion &&
          other.adherenceScore == this.adherenceScore &&
          other.completedAt == this.completedAt &&
          other.needsUpload == this.needsUpload &&
          other.localUpdatedAt == this.localUpdatedAt);
}

class CarbLoadingPlansTableCompanion extends UpdateCompanion<CarbLoadingPlan> {
  final Value<int> id;
  final Value<int?> eventId;
  final Value<String> userId;
  final Value<int> totalDays;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<int> dailyCarbTargetGrams;
  final Value<int?> dailyCalorieTarget;
  final Value<DateTime> generatedAt;
  final Value<String> algorithmVersion;
  final Value<double?> adherenceScore;
  final Value<DateTime?> completedAt;
  final Value<bool?> needsUpload;
  final Value<DateTime?> localUpdatedAt;
  const CarbLoadingPlansTableCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.userId = const Value.absent(),
    this.totalDays = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.dailyCarbTargetGrams = const Value.absent(),
    this.dailyCalorieTarget = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.adherenceScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
  });
  CarbLoadingPlansTableCompanion.insert({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    required String userId,
    required int totalDays,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyCarbTargetGrams,
    this.dailyCalorieTarget = const Value.absent(),
    required DateTime generatedAt,
    this.algorithmVersion = const Value.absent(),
    this.adherenceScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
  }) : userId = Value(userId),
       totalDays = Value(totalDays),
       startDate = Value(startDate),
       endDate = Value(endDate),
       dailyCarbTargetGrams = Value(dailyCarbTargetGrams),
       generatedAt = Value(generatedAt);
  static Insertable<CarbLoadingPlan> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<String>? userId,
    Expression<int>? totalDays,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? dailyCarbTargetGrams,
    Expression<int>? dailyCalorieTarget,
    Expression<DateTime>? generatedAt,
    Expression<String>? algorithmVersion,
    Expression<double>? adherenceScore,
    Expression<DateTime>? completedAt,
    Expression<bool>? needsUpload,
    Expression<DateTime>? localUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (userId != null) 'user_id': userId,
      if (totalDays != null) 'total_days': totalDays,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (dailyCarbTargetGrams != null)
        'daily_carb_target_grams': dailyCarbTargetGrams,
      if (dailyCalorieTarget != null)
        'daily_calorie_target': dailyCalorieTarget,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (adherenceScore != null) 'adherence_score': adherenceScore,
      if (completedAt != null) 'completed_at': completedAt,
      if (needsUpload != null) 'needs_upload': needsUpload,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
    });
  }

  CarbLoadingPlansTableCompanion copyWith({
    Value<int>? id,
    Value<int?>? eventId,
    Value<String>? userId,
    Value<int>? totalDays,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<int>? dailyCarbTargetGrams,
    Value<int?>? dailyCalorieTarget,
    Value<DateTime>? generatedAt,
    Value<String>? algorithmVersion,
    Value<double?>? adherenceScore,
    Value<DateTime?>? completedAt,
    Value<bool?>? needsUpload,
    Value<DateTime?>? localUpdatedAt,
  }) {
    return CarbLoadingPlansTableCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      totalDays: totalDays ?? this.totalDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dailyCarbTargetGrams: dailyCarbTargetGrams ?? this.dailyCarbTargetGrams,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      generatedAt: generatedAt ?? this.generatedAt,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      adherenceScore: adherenceScore ?? this.adherenceScore,
      completedAt: completedAt ?? this.completedAt,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (totalDays.present) {
      map['total_days'] = Variable<int>(totalDays.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (dailyCarbTargetGrams.present) {
      map['daily_carb_target_grams'] = Variable<int>(
        dailyCarbTargetGrams.value,
      );
    }
    if (dailyCalorieTarget.present) {
      map['daily_calorie_target'] = Variable<int>(dailyCalorieTarget.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (adherenceScore.present) {
      map['adherence_score'] = Variable<double>(adherenceScore.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (needsUpload.present) {
      map['needs_upload'] = Variable<bool>(needsUpload.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingPlansTableCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('totalDays: $totalDays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('dailyCarbTargetGrams: $dailyCarbTargetGrams, ')
          ..write('dailyCalorieTarget: $dailyCalorieTarget, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('adherenceScore: $adherenceScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingDaysTableTable extends CarbLoadingDaysTable
    with TableInfo<$CarbLoadingDaysTableTable, CarbLoadingDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingDaysTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _carbLoadingPlanIdMeta = const VerificationMeta(
    'carbLoadingPlanId',
  );
  @override
  late final GeneratedColumn<int> carbLoadingPlanId = GeneratedColumn<int>(
    'carb_loading_plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planDateMeta = const VerificationMeta(
    'planDate',
  );
  @override
  late final GeneratedColumn<DateTime> planDate = GeneratedColumn<DateTime>(
    'plan_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayNumberMeta = const VerificationMeta(
    'dayNumber',
  );
  @override
  late final GeneratedColumn<int> dayNumber = GeneratedColumn<int>(
    'day_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbTargetGramsMeta = const VerificationMeta(
    'carbTargetGrams',
  );
  @override
  late final GeneratedColumn<int> carbTargetGrams = GeneratedColumn<int>(
    'carb_target_grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbProtocolGPerKgMeta =
      const VerificationMeta('carbProtocolGPerKg');
  @override
  late final GeneratedColumn<double> carbProtocolGPerKg =
      GeneratedColumn<double>(
        'carb_protocol_g_per_kg',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _calorieTargetMeta = const VerificationMeta(
    'calorieTarget',
  );
  @override
  late final GeneratedColumn<int> calorieTarget = GeneratedColumn<int>(
    'calorie_target',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mealCountMeta = const VerificationMeta(
    'mealCount',
  );
  @override
  late final GeneratedColumn<int> mealCount = GeneratedColumn<int>(
    'meal_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(6),
  );
  static const VerificationMeta _breakfastPercentMeta = const VerificationMeta(
    'breakfastPercent',
  );
  @override
  late final GeneratedColumn<double> breakfastPercent = GeneratedColumn<double>(
    'breakfast_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.25),
  );
  static const VerificationMeta _morningSnackPercentMeta =
      const VerificationMeta('morningSnackPercent');
  @override
  late final GeneratedColumn<double> morningSnackPercent =
      GeneratedColumn<double>(
        'morning_snack_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.10),
      );
  static const VerificationMeta _lunchPercentMeta = const VerificationMeta(
    'lunchPercent',
  );
  @override
  late final GeneratedColumn<double> lunchPercent = GeneratedColumn<double>(
    'lunch_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.25),
  );
  static const VerificationMeta _afternoonSnackPercentMeta =
      const VerificationMeta('afternoonSnackPercent');
  @override
  late final GeneratedColumn<double> afternoonSnackPercent =
      GeneratedColumn<double>(
        'afternoon_snack_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.15),
      );
  static const VerificationMeta _dinnerPercentMeta = const VerificationMeta(
    'dinnerPercent',
  );
  @override
  late final GeneratedColumn<double> dinnerPercent = GeneratedColumn<double>(
    'dinner_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.20),
  );
  static const VerificationMeta _eveningSnackPercentMeta =
      const VerificationMeta('eveningSnackPercent');
  @override
  late final GeneratedColumn<double> eveningSnackPercent =
      GeneratedColumn<double>(
        'evening_snack_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.05),
      );
  static const VerificationMeta _loggedCarbsGramsMeta = const VerificationMeta(
    'loggedCarbsGrams',
  );
  @override
  late final GeneratedColumn<int> loggedCarbsGrams = GeneratedColumn<int>(
    'logged_carbs_grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _loggedCaloriesMeta = const VerificationMeta(
    'loggedCalories',
  );
  @override
  late final GeneratedColumn<int> loggedCalories = GeneratedColumn<int>(
    'logged_calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsUploadMeta = const VerificationMeta(
    'needsUpload',
  );
  @override
  late final GeneratedColumn<bool> needsUpload = GeneratedColumn<bool>(
    'needs_upload',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_upload" IN (0, 1))',
    ),
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    carbLoadingPlanId,
    planDate,
    dayNumber,
    carbTargetGrams,
    carbProtocolGPerKg,
    calorieTarget,
    mealCount,
    breakfastPercent,
    morningSnackPercent,
    lunchPercent,
    afternoonSnackPercent,
    dinnerPercent,
    eveningSnackPercent,
    loggedCarbsGrams,
    loggedCalories,
    completed,
    needsUpload,
    localUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarbLoadingDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('carb_loading_plan_id')) {
      context.handle(
        _carbLoadingPlanIdMeta,
        carbLoadingPlanId.isAcceptableOrUnknown(
          data['carb_loading_plan_id']!,
          _carbLoadingPlanIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbLoadingPlanIdMeta);
    }
    if (data.containsKey('plan_date')) {
      context.handle(
        _planDateMeta,
        planDate.isAcceptableOrUnknown(data['plan_date']!, _planDateMeta),
      );
    } else if (isInserting) {
      context.missing(_planDateMeta);
    }
    if (data.containsKey('day_number')) {
      context.handle(
        _dayNumberMeta,
        dayNumber.isAcceptableOrUnknown(data['day_number']!, _dayNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_dayNumberMeta);
    }
    if (data.containsKey('carb_target_grams')) {
      context.handle(
        _carbTargetGramsMeta,
        carbTargetGrams.isAcceptableOrUnknown(
          data['carb_target_grams']!,
          _carbTargetGramsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbTargetGramsMeta);
    }
    if (data.containsKey('carb_protocol_g_per_kg')) {
      context.handle(
        _carbProtocolGPerKgMeta,
        carbProtocolGPerKg.isAcceptableOrUnknown(
          data['carb_protocol_g_per_kg']!,
          _carbProtocolGPerKgMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbProtocolGPerKgMeta);
    }
    if (data.containsKey('calorie_target')) {
      context.handle(
        _calorieTargetMeta,
        calorieTarget.isAcceptableOrUnknown(
          data['calorie_target']!,
          _calorieTargetMeta,
        ),
      );
    }
    if (data.containsKey('meal_count')) {
      context.handle(
        _mealCountMeta,
        mealCount.isAcceptableOrUnknown(data['meal_count']!, _mealCountMeta),
      );
    }
    if (data.containsKey('breakfast_percent')) {
      context.handle(
        _breakfastPercentMeta,
        breakfastPercent.isAcceptableOrUnknown(
          data['breakfast_percent']!,
          _breakfastPercentMeta,
        ),
      );
    }
    if (data.containsKey('morning_snack_percent')) {
      context.handle(
        _morningSnackPercentMeta,
        morningSnackPercent.isAcceptableOrUnknown(
          data['morning_snack_percent']!,
          _morningSnackPercentMeta,
        ),
      );
    }
    if (data.containsKey('lunch_percent')) {
      context.handle(
        _lunchPercentMeta,
        lunchPercent.isAcceptableOrUnknown(
          data['lunch_percent']!,
          _lunchPercentMeta,
        ),
      );
    }
    if (data.containsKey('afternoon_snack_percent')) {
      context.handle(
        _afternoonSnackPercentMeta,
        afternoonSnackPercent.isAcceptableOrUnknown(
          data['afternoon_snack_percent']!,
          _afternoonSnackPercentMeta,
        ),
      );
    }
    if (data.containsKey('dinner_percent')) {
      context.handle(
        _dinnerPercentMeta,
        dinnerPercent.isAcceptableOrUnknown(
          data['dinner_percent']!,
          _dinnerPercentMeta,
        ),
      );
    }
    if (data.containsKey('evening_snack_percent')) {
      context.handle(
        _eveningSnackPercentMeta,
        eveningSnackPercent.isAcceptableOrUnknown(
          data['evening_snack_percent']!,
          _eveningSnackPercentMeta,
        ),
      );
    }
    if (data.containsKey('logged_carbs_grams')) {
      context.handle(
        _loggedCarbsGramsMeta,
        loggedCarbsGrams.isAcceptableOrUnknown(
          data['logged_carbs_grams']!,
          _loggedCarbsGramsMeta,
        ),
      );
    }
    if (data.containsKey('logged_calories')) {
      context.handle(
        _loggedCaloriesMeta,
        loggedCalories.isAcceptableOrUnknown(
          data['logged_calories']!,
          _loggedCaloriesMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('needs_upload')) {
      context.handle(
        _needsUploadMeta,
        needsUpload.isAcceptableOrUnknown(
          data['needs_upload']!,
          _needsUploadMeta,
        ),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {carbLoadingPlanId, planDate},
  ];
  @override
  CarbLoadingDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingDay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      carbLoadingPlanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carb_loading_plan_id'],
      )!,
      planDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}plan_date'],
      )!,
      dayNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_number'],
      )!,
      carbTargetGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carb_target_grams'],
      )!,
      carbProtocolGPerKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carb_protocol_g_per_kg'],
      )!,
      calorieTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calorie_target'],
      ),
      mealCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_count'],
      )!,
      breakfastPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}breakfast_percent'],
      )!,
      morningSnackPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}morning_snack_percent'],
      )!,
      lunchPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lunch_percent'],
      )!,
      afternoonSnackPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}afternoon_snack_percent'],
      )!,
      dinnerPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dinner_percent'],
      )!,
      eveningSnackPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}evening_snack_percent'],
      )!,
      loggedCarbsGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}logged_carbs_grams'],
      )!,
      loggedCalories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}logged_calories'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      needsUpload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_upload'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      ),
    );
  }

  @override
  $CarbLoadingDaysTableTable createAlias(String alias) {
    return $CarbLoadingDaysTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingDay extends DataClass implements Insertable<CarbLoadingDay> {
  final int id;
  final int carbLoadingPlanId;
  final DateTime planDate;
  final int dayNumber;
  final int carbTargetGrams;
  final double carbProtocolGPerKg;
  final int? calorieTarget;
  final int mealCount;
  final double breakfastPercent;
  final double morningSnackPercent;
  final double lunchPercent;
  final double afternoonSnackPercent;
  final double dinnerPercent;
  final double eveningSnackPercent;
  final int loggedCarbsGrams;
  final int loggedCalories;
  final bool completed;
  final bool? needsUpload;
  final DateTime? localUpdatedAt;
  const CarbLoadingDay({
    required this.id,
    required this.carbLoadingPlanId,
    required this.planDate,
    required this.dayNumber,
    required this.carbTargetGrams,
    required this.carbProtocolGPerKg,
    this.calorieTarget,
    required this.mealCount,
    required this.breakfastPercent,
    required this.morningSnackPercent,
    required this.lunchPercent,
    required this.afternoonSnackPercent,
    required this.dinnerPercent,
    required this.eveningSnackPercent,
    required this.loggedCarbsGrams,
    required this.loggedCalories,
    required this.completed,
    this.needsUpload,
    this.localUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['carb_loading_plan_id'] = Variable<int>(carbLoadingPlanId);
    map['plan_date'] = Variable<DateTime>(planDate);
    map['day_number'] = Variable<int>(dayNumber);
    map['carb_target_grams'] = Variable<int>(carbTargetGrams);
    map['carb_protocol_g_per_kg'] = Variable<double>(carbProtocolGPerKg);
    if (!nullToAbsent || calorieTarget != null) {
      map['calorie_target'] = Variable<int>(calorieTarget);
    }
    map['meal_count'] = Variable<int>(mealCount);
    map['breakfast_percent'] = Variable<double>(breakfastPercent);
    map['morning_snack_percent'] = Variable<double>(morningSnackPercent);
    map['lunch_percent'] = Variable<double>(lunchPercent);
    map['afternoon_snack_percent'] = Variable<double>(afternoonSnackPercent);
    map['dinner_percent'] = Variable<double>(dinnerPercent);
    map['evening_snack_percent'] = Variable<double>(eveningSnackPercent);
    map['logged_carbs_grams'] = Variable<int>(loggedCarbsGrams);
    map['logged_calories'] = Variable<int>(loggedCalories);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || needsUpload != null) {
      map['needs_upload'] = Variable<bool>(needsUpload);
    }
    if (!nullToAbsent || localUpdatedAt != null) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    }
    return map;
  }

  CarbLoadingDaysTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingDaysTableCompanion(
      id: Value(id),
      carbLoadingPlanId: Value(carbLoadingPlanId),
      planDate: Value(planDate),
      dayNumber: Value(dayNumber),
      carbTargetGrams: Value(carbTargetGrams),
      carbProtocolGPerKg: Value(carbProtocolGPerKg),
      calorieTarget: calorieTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(calorieTarget),
      mealCount: Value(mealCount),
      breakfastPercent: Value(breakfastPercent),
      morningSnackPercent: Value(morningSnackPercent),
      lunchPercent: Value(lunchPercent),
      afternoonSnackPercent: Value(afternoonSnackPercent),
      dinnerPercent: Value(dinnerPercent),
      eveningSnackPercent: Value(eveningSnackPercent),
      loggedCarbsGrams: Value(loggedCarbsGrams),
      loggedCalories: Value(loggedCalories),
      completed: Value(completed),
      needsUpload: needsUpload == null && nullToAbsent
          ? const Value.absent()
          : Value(needsUpload),
      localUpdatedAt: localUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(localUpdatedAt),
    );
  }

  factory CarbLoadingDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingDay(
      id: serializer.fromJson<int>(json['id']),
      carbLoadingPlanId: serializer.fromJson<int>(json['carbLoadingPlanId']),
      planDate: serializer.fromJson<DateTime>(json['planDate']),
      dayNumber: serializer.fromJson<int>(json['dayNumber']),
      carbTargetGrams: serializer.fromJson<int>(json['carbTargetGrams']),
      carbProtocolGPerKg: serializer.fromJson<double>(
        json['carbProtocolGPerKg'],
      ),
      calorieTarget: serializer.fromJson<int?>(json['calorieTarget']),
      mealCount: serializer.fromJson<int>(json['mealCount']),
      breakfastPercent: serializer.fromJson<double>(json['breakfastPercent']),
      morningSnackPercent: serializer.fromJson<double>(
        json['morningSnackPercent'],
      ),
      lunchPercent: serializer.fromJson<double>(json['lunchPercent']),
      afternoonSnackPercent: serializer.fromJson<double>(
        json['afternoonSnackPercent'],
      ),
      dinnerPercent: serializer.fromJson<double>(json['dinnerPercent']),
      eveningSnackPercent: serializer.fromJson<double>(
        json['eveningSnackPercent'],
      ),
      loggedCarbsGrams: serializer.fromJson<int>(json['loggedCarbsGrams']),
      loggedCalories: serializer.fromJson<int>(json['loggedCalories']),
      completed: serializer.fromJson<bool>(json['completed']),
      needsUpload: serializer.fromJson<bool?>(json['needsUpload']),
      localUpdatedAt: serializer.fromJson<DateTime?>(json['localUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'carbLoadingPlanId': serializer.toJson<int>(carbLoadingPlanId),
      'planDate': serializer.toJson<DateTime>(planDate),
      'dayNumber': serializer.toJson<int>(dayNumber),
      'carbTargetGrams': serializer.toJson<int>(carbTargetGrams),
      'carbProtocolGPerKg': serializer.toJson<double>(carbProtocolGPerKg),
      'calorieTarget': serializer.toJson<int?>(calorieTarget),
      'mealCount': serializer.toJson<int>(mealCount),
      'breakfastPercent': serializer.toJson<double>(breakfastPercent),
      'morningSnackPercent': serializer.toJson<double>(morningSnackPercent),
      'lunchPercent': serializer.toJson<double>(lunchPercent),
      'afternoonSnackPercent': serializer.toJson<double>(afternoonSnackPercent),
      'dinnerPercent': serializer.toJson<double>(dinnerPercent),
      'eveningSnackPercent': serializer.toJson<double>(eveningSnackPercent),
      'loggedCarbsGrams': serializer.toJson<int>(loggedCarbsGrams),
      'loggedCalories': serializer.toJson<int>(loggedCalories),
      'completed': serializer.toJson<bool>(completed),
      'needsUpload': serializer.toJson<bool?>(needsUpload),
      'localUpdatedAt': serializer.toJson<DateTime?>(localUpdatedAt),
    };
  }

  CarbLoadingDay copyWith({
    int? id,
    int? carbLoadingPlanId,
    DateTime? planDate,
    int? dayNumber,
    int? carbTargetGrams,
    double? carbProtocolGPerKg,
    Value<int?> calorieTarget = const Value.absent(),
    int? mealCount,
    double? breakfastPercent,
    double? morningSnackPercent,
    double? lunchPercent,
    double? afternoonSnackPercent,
    double? dinnerPercent,
    double? eveningSnackPercent,
    int? loggedCarbsGrams,
    int? loggedCalories,
    bool? completed,
    Value<bool?> needsUpload = const Value.absent(),
    Value<DateTime?> localUpdatedAt = const Value.absent(),
  }) => CarbLoadingDay(
    id: id ?? this.id,
    carbLoadingPlanId: carbLoadingPlanId ?? this.carbLoadingPlanId,
    planDate: planDate ?? this.planDate,
    dayNumber: dayNumber ?? this.dayNumber,
    carbTargetGrams: carbTargetGrams ?? this.carbTargetGrams,
    carbProtocolGPerKg: carbProtocolGPerKg ?? this.carbProtocolGPerKg,
    calorieTarget: calorieTarget.present
        ? calorieTarget.value
        : this.calorieTarget,
    mealCount: mealCount ?? this.mealCount,
    breakfastPercent: breakfastPercent ?? this.breakfastPercent,
    morningSnackPercent: morningSnackPercent ?? this.morningSnackPercent,
    lunchPercent: lunchPercent ?? this.lunchPercent,
    afternoonSnackPercent: afternoonSnackPercent ?? this.afternoonSnackPercent,
    dinnerPercent: dinnerPercent ?? this.dinnerPercent,
    eveningSnackPercent: eveningSnackPercent ?? this.eveningSnackPercent,
    loggedCarbsGrams: loggedCarbsGrams ?? this.loggedCarbsGrams,
    loggedCalories: loggedCalories ?? this.loggedCalories,
    completed: completed ?? this.completed,
    needsUpload: needsUpload.present ? needsUpload.value : this.needsUpload,
    localUpdatedAt: localUpdatedAt.present
        ? localUpdatedAt.value
        : this.localUpdatedAt,
  );
  CarbLoadingDay copyWithCompanion(CarbLoadingDaysTableCompanion data) {
    return CarbLoadingDay(
      id: data.id.present ? data.id.value : this.id,
      carbLoadingPlanId: data.carbLoadingPlanId.present
          ? data.carbLoadingPlanId.value
          : this.carbLoadingPlanId,
      planDate: data.planDate.present ? data.planDate.value : this.planDate,
      dayNumber: data.dayNumber.present ? data.dayNumber.value : this.dayNumber,
      carbTargetGrams: data.carbTargetGrams.present
          ? data.carbTargetGrams.value
          : this.carbTargetGrams,
      carbProtocolGPerKg: data.carbProtocolGPerKg.present
          ? data.carbProtocolGPerKg.value
          : this.carbProtocolGPerKg,
      calorieTarget: data.calorieTarget.present
          ? data.calorieTarget.value
          : this.calorieTarget,
      mealCount: data.mealCount.present ? data.mealCount.value : this.mealCount,
      breakfastPercent: data.breakfastPercent.present
          ? data.breakfastPercent.value
          : this.breakfastPercent,
      morningSnackPercent: data.morningSnackPercent.present
          ? data.morningSnackPercent.value
          : this.morningSnackPercent,
      lunchPercent: data.lunchPercent.present
          ? data.lunchPercent.value
          : this.lunchPercent,
      afternoonSnackPercent: data.afternoonSnackPercent.present
          ? data.afternoonSnackPercent.value
          : this.afternoonSnackPercent,
      dinnerPercent: data.dinnerPercent.present
          ? data.dinnerPercent.value
          : this.dinnerPercent,
      eveningSnackPercent: data.eveningSnackPercent.present
          ? data.eveningSnackPercent.value
          : this.eveningSnackPercent,
      loggedCarbsGrams: data.loggedCarbsGrams.present
          ? data.loggedCarbsGrams.value
          : this.loggedCarbsGrams,
      loggedCalories: data.loggedCalories.present
          ? data.loggedCalories.value
          : this.loggedCalories,
      completed: data.completed.present ? data.completed.value : this.completed,
      needsUpload: data.needsUpload.present
          ? data.needsUpload.value
          : this.needsUpload,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingDay(')
          ..write('id: $id, ')
          ..write('carbLoadingPlanId: $carbLoadingPlanId, ')
          ..write('planDate: $planDate, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('carbTargetGrams: $carbTargetGrams, ')
          ..write('carbProtocolGPerKg: $carbProtocolGPerKg, ')
          ..write('calorieTarget: $calorieTarget, ')
          ..write('mealCount: $mealCount, ')
          ..write('breakfastPercent: $breakfastPercent, ')
          ..write('morningSnackPercent: $morningSnackPercent, ')
          ..write('lunchPercent: $lunchPercent, ')
          ..write('afternoonSnackPercent: $afternoonSnackPercent, ')
          ..write('dinnerPercent: $dinnerPercent, ')
          ..write('eveningSnackPercent: $eveningSnackPercent, ')
          ..write('loggedCarbsGrams: $loggedCarbsGrams, ')
          ..write('loggedCalories: $loggedCalories, ')
          ..write('completed: $completed, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    carbLoadingPlanId,
    planDate,
    dayNumber,
    carbTargetGrams,
    carbProtocolGPerKg,
    calorieTarget,
    mealCount,
    breakfastPercent,
    morningSnackPercent,
    lunchPercent,
    afternoonSnackPercent,
    dinnerPercent,
    eveningSnackPercent,
    loggedCarbsGrams,
    loggedCalories,
    completed,
    needsUpload,
    localUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingDay &&
          other.id == this.id &&
          other.carbLoadingPlanId == this.carbLoadingPlanId &&
          other.planDate == this.planDate &&
          other.dayNumber == this.dayNumber &&
          other.carbTargetGrams == this.carbTargetGrams &&
          other.carbProtocolGPerKg == this.carbProtocolGPerKg &&
          other.calorieTarget == this.calorieTarget &&
          other.mealCount == this.mealCount &&
          other.breakfastPercent == this.breakfastPercent &&
          other.morningSnackPercent == this.morningSnackPercent &&
          other.lunchPercent == this.lunchPercent &&
          other.afternoonSnackPercent == this.afternoonSnackPercent &&
          other.dinnerPercent == this.dinnerPercent &&
          other.eveningSnackPercent == this.eveningSnackPercent &&
          other.loggedCarbsGrams == this.loggedCarbsGrams &&
          other.loggedCalories == this.loggedCalories &&
          other.completed == this.completed &&
          other.needsUpload == this.needsUpload &&
          other.localUpdatedAt == this.localUpdatedAt);
}

class CarbLoadingDaysTableCompanion extends UpdateCompanion<CarbLoadingDay> {
  final Value<int> id;
  final Value<int> carbLoadingPlanId;
  final Value<DateTime> planDate;
  final Value<int> dayNumber;
  final Value<int> carbTargetGrams;
  final Value<double> carbProtocolGPerKg;
  final Value<int?> calorieTarget;
  final Value<int> mealCount;
  final Value<double> breakfastPercent;
  final Value<double> morningSnackPercent;
  final Value<double> lunchPercent;
  final Value<double> afternoonSnackPercent;
  final Value<double> dinnerPercent;
  final Value<double> eveningSnackPercent;
  final Value<int> loggedCarbsGrams;
  final Value<int> loggedCalories;
  final Value<bool> completed;
  final Value<bool?> needsUpload;
  final Value<DateTime?> localUpdatedAt;
  const CarbLoadingDaysTableCompanion({
    this.id = const Value.absent(),
    this.carbLoadingPlanId = const Value.absent(),
    this.planDate = const Value.absent(),
    this.dayNumber = const Value.absent(),
    this.carbTargetGrams = const Value.absent(),
    this.carbProtocolGPerKg = const Value.absent(),
    this.calorieTarget = const Value.absent(),
    this.mealCount = const Value.absent(),
    this.breakfastPercent = const Value.absent(),
    this.morningSnackPercent = const Value.absent(),
    this.lunchPercent = const Value.absent(),
    this.afternoonSnackPercent = const Value.absent(),
    this.dinnerPercent = const Value.absent(),
    this.eveningSnackPercent = const Value.absent(),
    this.loggedCarbsGrams = const Value.absent(),
    this.loggedCalories = const Value.absent(),
    this.completed = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
  });
  CarbLoadingDaysTableCompanion.insert({
    this.id = const Value.absent(),
    required int carbLoadingPlanId,
    required DateTime planDate,
    required int dayNumber,
    required int carbTargetGrams,
    required double carbProtocolGPerKg,
    this.calorieTarget = const Value.absent(),
    this.mealCount = const Value.absent(),
    this.breakfastPercent = const Value.absent(),
    this.morningSnackPercent = const Value.absent(),
    this.lunchPercent = const Value.absent(),
    this.afternoonSnackPercent = const Value.absent(),
    this.dinnerPercent = const Value.absent(),
    this.eveningSnackPercent = const Value.absent(),
    this.loggedCarbsGrams = const Value.absent(),
    this.loggedCalories = const Value.absent(),
    this.completed = const Value.absent(),
    this.needsUpload = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
  }) : carbLoadingPlanId = Value(carbLoadingPlanId),
       planDate = Value(planDate),
       dayNumber = Value(dayNumber),
       carbTargetGrams = Value(carbTargetGrams),
       carbProtocolGPerKg = Value(carbProtocolGPerKg);
  static Insertable<CarbLoadingDay> custom({
    Expression<int>? id,
    Expression<int>? carbLoadingPlanId,
    Expression<DateTime>? planDate,
    Expression<int>? dayNumber,
    Expression<int>? carbTargetGrams,
    Expression<double>? carbProtocolGPerKg,
    Expression<int>? calorieTarget,
    Expression<int>? mealCount,
    Expression<double>? breakfastPercent,
    Expression<double>? morningSnackPercent,
    Expression<double>? lunchPercent,
    Expression<double>? afternoonSnackPercent,
    Expression<double>? dinnerPercent,
    Expression<double>? eveningSnackPercent,
    Expression<int>? loggedCarbsGrams,
    Expression<int>? loggedCalories,
    Expression<bool>? completed,
    Expression<bool>? needsUpload,
    Expression<DateTime>? localUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (carbLoadingPlanId != null) 'carb_loading_plan_id': carbLoadingPlanId,
      if (planDate != null) 'plan_date': planDate,
      if (dayNumber != null) 'day_number': dayNumber,
      if (carbTargetGrams != null) 'carb_target_grams': carbTargetGrams,
      if (carbProtocolGPerKg != null)
        'carb_protocol_g_per_kg': carbProtocolGPerKg,
      if (calorieTarget != null) 'calorie_target': calorieTarget,
      if (mealCount != null) 'meal_count': mealCount,
      if (breakfastPercent != null) 'breakfast_percent': breakfastPercent,
      if (morningSnackPercent != null)
        'morning_snack_percent': morningSnackPercent,
      if (lunchPercent != null) 'lunch_percent': lunchPercent,
      if (afternoonSnackPercent != null)
        'afternoon_snack_percent': afternoonSnackPercent,
      if (dinnerPercent != null) 'dinner_percent': dinnerPercent,
      if (eveningSnackPercent != null)
        'evening_snack_percent': eveningSnackPercent,
      if (loggedCarbsGrams != null) 'logged_carbs_grams': loggedCarbsGrams,
      if (loggedCalories != null) 'logged_calories': loggedCalories,
      if (completed != null) 'completed': completed,
      if (needsUpload != null) 'needs_upload': needsUpload,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
    });
  }

  CarbLoadingDaysTableCompanion copyWith({
    Value<int>? id,
    Value<int>? carbLoadingPlanId,
    Value<DateTime>? planDate,
    Value<int>? dayNumber,
    Value<int>? carbTargetGrams,
    Value<double>? carbProtocolGPerKg,
    Value<int?>? calorieTarget,
    Value<int>? mealCount,
    Value<double>? breakfastPercent,
    Value<double>? morningSnackPercent,
    Value<double>? lunchPercent,
    Value<double>? afternoonSnackPercent,
    Value<double>? dinnerPercent,
    Value<double>? eveningSnackPercent,
    Value<int>? loggedCarbsGrams,
    Value<int>? loggedCalories,
    Value<bool>? completed,
    Value<bool?>? needsUpload,
    Value<DateTime?>? localUpdatedAt,
  }) {
    return CarbLoadingDaysTableCompanion(
      id: id ?? this.id,
      carbLoadingPlanId: carbLoadingPlanId ?? this.carbLoadingPlanId,
      planDate: planDate ?? this.planDate,
      dayNumber: dayNumber ?? this.dayNumber,
      carbTargetGrams: carbTargetGrams ?? this.carbTargetGrams,
      carbProtocolGPerKg: carbProtocolGPerKg ?? this.carbProtocolGPerKg,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      mealCount: mealCount ?? this.mealCount,
      breakfastPercent: breakfastPercent ?? this.breakfastPercent,
      morningSnackPercent: morningSnackPercent ?? this.morningSnackPercent,
      lunchPercent: lunchPercent ?? this.lunchPercent,
      afternoonSnackPercent:
          afternoonSnackPercent ?? this.afternoonSnackPercent,
      dinnerPercent: dinnerPercent ?? this.dinnerPercent,
      eveningSnackPercent: eveningSnackPercent ?? this.eveningSnackPercent,
      loggedCarbsGrams: loggedCarbsGrams ?? this.loggedCarbsGrams,
      loggedCalories: loggedCalories ?? this.loggedCalories,
      completed: completed ?? this.completed,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (carbLoadingPlanId.present) {
      map['carb_loading_plan_id'] = Variable<int>(carbLoadingPlanId.value);
    }
    if (planDate.present) {
      map['plan_date'] = Variable<DateTime>(planDate.value);
    }
    if (dayNumber.present) {
      map['day_number'] = Variable<int>(dayNumber.value);
    }
    if (carbTargetGrams.present) {
      map['carb_target_grams'] = Variable<int>(carbTargetGrams.value);
    }
    if (carbProtocolGPerKg.present) {
      map['carb_protocol_g_per_kg'] = Variable<double>(
        carbProtocolGPerKg.value,
      );
    }
    if (calorieTarget.present) {
      map['calorie_target'] = Variable<int>(calorieTarget.value);
    }
    if (mealCount.present) {
      map['meal_count'] = Variable<int>(mealCount.value);
    }
    if (breakfastPercent.present) {
      map['breakfast_percent'] = Variable<double>(breakfastPercent.value);
    }
    if (morningSnackPercent.present) {
      map['morning_snack_percent'] = Variable<double>(
        morningSnackPercent.value,
      );
    }
    if (lunchPercent.present) {
      map['lunch_percent'] = Variable<double>(lunchPercent.value);
    }
    if (afternoonSnackPercent.present) {
      map['afternoon_snack_percent'] = Variable<double>(
        afternoonSnackPercent.value,
      );
    }
    if (dinnerPercent.present) {
      map['dinner_percent'] = Variable<double>(dinnerPercent.value);
    }
    if (eveningSnackPercent.present) {
      map['evening_snack_percent'] = Variable<double>(
        eveningSnackPercent.value,
      );
    }
    if (loggedCarbsGrams.present) {
      map['logged_carbs_grams'] = Variable<int>(loggedCarbsGrams.value);
    }
    if (loggedCalories.present) {
      map['logged_calories'] = Variable<int>(loggedCalories.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (needsUpload.present) {
      map['needs_upload'] = Variable<bool>(needsUpload.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingDaysTableCompanion(')
          ..write('id: $id, ')
          ..write('carbLoadingPlanId: $carbLoadingPlanId, ')
          ..write('planDate: $planDate, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('carbTargetGrams: $carbTargetGrams, ')
          ..write('carbProtocolGPerKg: $carbProtocolGPerKg, ')
          ..write('calorieTarget: $calorieTarget, ')
          ..write('mealCount: $mealCount, ')
          ..write('breakfastPercent: $breakfastPercent, ')
          ..write('morningSnackPercent: $morningSnackPercent, ')
          ..write('lunchPercent: $lunchPercent, ')
          ..write('afternoonSnackPercent: $afternoonSnackPercent, ')
          ..write('dinnerPercent: $dinnerPercent, ')
          ..write('eveningSnackPercent: $eveningSnackPercent, ')
          ..write('loggedCarbsGrams: $loggedCarbsGrams, ')
          ..write('loggedCalories: $loggedCalories, ')
          ..write('completed: $completed, ')
          ..write('needsUpload: $needsUpload, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingFoodsTableTable extends CarbLoadingFoodsTable
    with TableInfo<$CarbLoadingFoodsTableTable, CarbLoadingFood> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingFoodsTableTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNamePluralMeta = const VerificationMeta(
    'displayNamePlural',
  );
  @override
  late final GeneratedColumn<String> displayNamePlural =
      GeneratedColumn<String>(
        'display_name_plural',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _carbsPerServingMeta = const VerificationMeta(
    'carbsPerServing',
  );
  @override
  late final GeneratedColumn<double> carbsPerServing = GeneratedColumn<double>(
    'carbs_per_serving',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageAddressMeta = const VerificationMeta(
    'imageAddress',
  );
  @override
  late final GeneratedColumn<String> imageAddress = GeneratedColumn<String>(
    'image_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _mealTypesMeta = const VerificationMeta(
    'mealTypes',
  );
  @override
  late final GeneratedColumn<String> mealTypes = GeneratedColumn<String>(
    'meal_types',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    displayName,
    displayNamePlural,
    carbsPerServing,
    imageAddress,
    isDefault,
    mealTypes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarbLoadingFood> instance, {
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('display_name_plural')) {
      context.handle(
        _displayNamePluralMeta,
        displayNamePlural.isAcceptableOrUnknown(
          data['display_name_plural']!,
          _displayNamePluralMeta,
        ),
      );
    }
    if (data.containsKey('carbs_per_serving')) {
      context.handle(
        _carbsPerServingMeta,
        carbsPerServing.isAcceptableOrUnknown(
          data['carbs_per_serving']!,
          _carbsPerServingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbsPerServingMeta);
    }
    if (data.containsKey('image_address')) {
      context.handle(
        _imageAddressMeta,
        imageAddress.isAcceptableOrUnknown(
          data['image_address']!,
          _imageAddressMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('meal_types')) {
      context.handle(
        _mealTypesMeta,
        mealTypes.isAcceptableOrUnknown(data['meal_types']!, _mealTypesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarbLoadingFood map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingFood(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      displayNamePlural: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_plural'],
      ),
      carbsPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per_serving'],
      )!,
      imageAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_address'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      mealTypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_types'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CarbLoadingFoodsTableTable createAlias(String alias) {
    return $CarbLoadingFoodsTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingFood extends DataClass implements Insertable<CarbLoadingFood> {
  final String id;
  final String name;
  final String displayName;
  final String? displayNamePlural;
  final double carbsPerServing;
  final String? imageAddress;
  final bool isDefault;

  /// Meal types: array of meal_type_enum values (e.g., ['breakfast', 'lunch', 'dinner'])
  final String? mealTypes;
  final DateTime createdAt;
  const CarbLoadingFood({
    required this.id,
    required this.name,
    required this.displayName,
    this.displayNamePlural,
    required this.carbsPerServing,
    this.imageAddress,
    required this.isDefault,
    this.mealTypes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || displayNamePlural != null) {
      map['display_name_plural'] = Variable<String>(displayNamePlural);
    }
    map['carbs_per_serving'] = Variable<double>(carbsPerServing);
    if (!nullToAbsent || imageAddress != null) {
      map['image_address'] = Variable<String>(imageAddress);
    }
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || mealTypes != null) {
      map['meal_types'] = Variable<String>(mealTypes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CarbLoadingFoodsTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingFoodsTableCompanion(
      id: Value(id),
      name: Value(name),
      displayName: Value(displayName),
      displayNamePlural: displayNamePlural == null && nullToAbsent
          ? const Value.absent()
          : Value(displayNamePlural),
      carbsPerServing: Value(carbsPerServing),
      imageAddress: imageAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAddress),
      isDefault: Value(isDefault),
      mealTypes: mealTypes == null && nullToAbsent
          ? const Value.absent()
          : Value(mealTypes),
      createdAt: Value(createdAt),
    );
  }

  factory CarbLoadingFood.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingFood(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String>(json['displayName']),
      displayNamePlural: serializer.fromJson<String?>(
        json['displayNamePlural'],
      ),
      carbsPerServing: serializer.fromJson<double>(json['carbsPerServing']),
      imageAddress: serializer.fromJson<String?>(json['imageAddress']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      mealTypes: serializer.fromJson<String?>(json['mealTypes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String>(displayName),
      'displayNamePlural': serializer.toJson<String?>(displayNamePlural),
      'carbsPerServing': serializer.toJson<double>(carbsPerServing),
      'imageAddress': serializer.toJson<String?>(imageAddress),
      'isDefault': serializer.toJson<bool>(isDefault),
      'mealTypes': serializer.toJson<String?>(mealTypes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CarbLoadingFood copyWith({
    String? id,
    String? name,
    String? displayName,
    Value<String?> displayNamePlural = const Value.absent(),
    double? carbsPerServing,
    Value<String?> imageAddress = const Value.absent(),
    bool? isDefault,
    Value<String?> mealTypes = const Value.absent(),
    DateTime? createdAt,
  }) => CarbLoadingFood(
    id: id ?? this.id,
    name: name ?? this.name,
    displayName: displayName ?? this.displayName,
    displayNamePlural: displayNamePlural.present
        ? displayNamePlural.value
        : this.displayNamePlural,
    carbsPerServing: carbsPerServing ?? this.carbsPerServing,
    imageAddress: imageAddress.present ? imageAddress.value : this.imageAddress,
    isDefault: isDefault ?? this.isDefault,
    mealTypes: mealTypes.present ? mealTypes.value : this.mealTypes,
    createdAt: createdAt ?? this.createdAt,
  );
  CarbLoadingFood copyWithCompanion(CarbLoadingFoodsTableCompanion data) {
    return CarbLoadingFood(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      displayNamePlural: data.displayNamePlural.present
          ? data.displayNamePlural.value
          : this.displayNamePlural,
      carbsPerServing: data.carbsPerServing.present
          ? data.carbsPerServing.value
          : this.carbsPerServing,
      imageAddress: data.imageAddress.present
          ? data.imageAddress.value
          : this.imageAddress,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      mealTypes: data.mealTypes.present ? data.mealTypes.value : this.mealTypes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingFood(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('isDefault: $isDefault, ')
          ..write('mealTypes: $mealTypes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    displayName,
    displayNamePlural,
    carbsPerServing,
    imageAddress,
    isDefault,
    mealTypes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingFood &&
          other.id == this.id &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.displayNamePlural == this.displayNamePlural &&
          other.carbsPerServing == this.carbsPerServing &&
          other.imageAddress == this.imageAddress &&
          other.isDefault == this.isDefault &&
          other.mealTypes == this.mealTypes &&
          other.createdAt == this.createdAt);
}

class CarbLoadingFoodsTableCompanion extends UpdateCompanion<CarbLoadingFood> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> displayName;
  final Value<String?> displayNamePlural;
  final Value<double> carbsPerServing;
  final Value<String?> imageAddress;
  final Value<bool> isDefault;
  final Value<String?> mealTypes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CarbLoadingFoodsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.displayNamePlural = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.imageAddress = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.mealTypes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarbLoadingFoodsTableCompanion.insert({
    required String id,
    required String name,
    required String displayName,
    this.displayNamePlural = const Value.absent(),
    required double carbsPerServing,
    this.imageAddress = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.mealTypes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       displayName = Value(displayName),
       carbsPerServing = Value(carbsPerServing);
  static Insertable<CarbLoadingFood> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? displayNamePlural,
    Expression<double>? carbsPerServing,
    Expression<String>? imageAddress,
    Expression<bool>? isDefault,
    Expression<String>? mealTypes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (displayNamePlural != null) 'display_name_plural': displayNamePlural,
      if (carbsPerServing != null) 'carbs_per_serving': carbsPerServing,
      if (imageAddress != null) 'image_address': imageAddress,
      if (isDefault != null) 'is_default': isDefault,
      if (mealTypes != null) 'meal_types': mealTypes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarbLoadingFoodsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? displayName,
    Value<String?>? displayNamePlural,
    Value<double>? carbsPerServing,
    Value<String?>? imageAddress,
    Value<bool>? isDefault,
    Value<String?>? mealTypes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CarbLoadingFoodsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      imageAddress: imageAddress ?? this.imageAddress,
      isDefault: isDefault ?? this.isDefault,
      mealTypes: mealTypes ?? this.mealTypes,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (displayNamePlural.present) {
      map['display_name_plural'] = Variable<String>(displayNamePlural.value);
    }
    if (carbsPerServing.present) {
      map['carbs_per_serving'] = Variable<double>(carbsPerServing.value);
    }
    if (imageAddress.present) {
      map['image_address'] = Variable<String>(imageAddress.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (mealTypes.present) {
      map['meal_types'] = Variable<String>(mealTypes.value);
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
    return (StringBuffer('CarbLoadingFoodsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('isDefault: $isDefault, ')
          ..write('mealTypes: $mealTypes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingUserFoodsTableTable extends CarbLoadingUserFoodsTable
    with TableInfo<$CarbLoadingUserFoodsTableTable, CarbLoadingUserFood> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingUserFoodsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientFoodIdMeta = const VerificationMeta(
    'clientFoodId',
  );
  @override
  late final GeneratedColumn<String> clientFoodId = GeneratedColumn<String>(
    'client_food_id',
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNamePluralMeta = const VerificationMeta(
    'displayNamePlural',
  );
  @override
  late final GeneratedColumn<String> displayNamePlural =
      GeneratedColumn<String>(
        'display_name_plural',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _carbsPerServingMeta = const VerificationMeta(
    'carbsPerServing',
  );
  @override
  late final GeneratedColumn<double> carbsPerServing = GeneratedColumn<double>(
    'carbs_per_serving',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageAddressMeta = const VerificationMeta(
    'imageAddress',
  );
  @override
  late final GeneratedColumn<String> imageAddress = GeneratedColumn<String>(
    'image_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceFoodIdMeta = const VerificationMeta(
    'sourceFoodId',
  );
  @override
  late final GeneratedColumn<String> sourceFoodId = GeneratedColumn<String>(
    'source_food_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUserFoodIdMeta = const VerificationMeta(
    'sourceUserFoodId',
  );
  @override
  late final GeneratedColumn<String> sourceUserFoodId = GeneratedColumn<String>(
    'source_user_food_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mealTypesMeta = const VerificationMeta(
    'mealTypes',
  );
  @override
  late final GeneratedColumn<String> mealTypes = GeneratedColumn<String>(
    'meal_types',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    deviceId,
    userId,
    clientFoodId,
    name,
    displayName,
    displayNamePlural,
    carbsPerServing,
    imageAddress,
    barcode,
    sourceFoodId,
    sourceUserFoodId,
    mealTypes,
    isDeleted,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_user_foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarbLoadingUserFood> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('client_food_id')) {
      context.handle(
        _clientFoodIdMeta,
        clientFoodId.isAcceptableOrUnknown(
          data['client_food_id']!,
          _clientFoodIdMeta,
        ),
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('display_name_plural')) {
      context.handle(
        _displayNamePluralMeta,
        displayNamePlural.isAcceptableOrUnknown(
          data['display_name_plural']!,
          _displayNamePluralMeta,
        ),
      );
    }
    if (data.containsKey('carbs_per_serving')) {
      context.handle(
        _carbsPerServingMeta,
        carbsPerServing.isAcceptableOrUnknown(
          data['carbs_per_serving']!,
          _carbsPerServingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbsPerServingMeta);
    }
    if (data.containsKey('image_address')) {
      context.handle(
        _imageAddressMeta,
        imageAddress.isAcceptableOrUnknown(
          data['image_address']!,
          _imageAddressMeta,
        ),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('source_food_id')) {
      context.handle(
        _sourceFoodIdMeta,
        sourceFoodId.isAcceptableOrUnknown(
          data['source_food_id']!,
          _sourceFoodIdMeta,
        ),
      );
    }
    if (data.containsKey('source_user_food_id')) {
      context.handle(
        _sourceUserFoodIdMeta,
        sourceUserFoodId.isAcceptableOrUnknown(
          data['source_user_food_id']!,
          _sourceUserFoodIdMeta,
        ),
      );
    }
    if (data.containsKey('meal_types')) {
      context.handle(
        _mealTypesMeta,
        mealTypes.isAcceptableOrUnknown(data['meal_types']!, _mealTypesMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarbLoadingUserFood map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingUserFood(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      clientFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_food_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      displayNamePlural: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_plural'],
      ),
      carbsPerServing: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per_serving'],
      )!,
      imageAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_address'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      sourceFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_food_id'],
      ),
      sourceUserFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_user_food_id'],
      ),
      mealTypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_types'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
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
  $CarbLoadingUserFoodsTableTable createAlias(String alias) {
    return $CarbLoadingUserFoodsTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingUserFood extends DataClass
    implements Insertable<CarbLoadingUserFood> {
  final String id;
  final String deviceId;
  final String userId;
  final String? clientFoodId;
  final String name;
  final String displayName;
  final String? displayNamePlural;
  final double carbsPerServing;
  final String? imageAddress;
  final String? barcode;
  final String? sourceFoodId;
  final String? sourceUserFoodId;

  /// Meal types: array of meal_type_enum values (e.g., ['breakfast', 'lunch', 'dinner'])
  final String? mealTypes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CarbLoadingUserFood({
    required this.id,
    required this.deviceId,
    required this.userId,
    this.clientFoodId,
    required this.name,
    required this.displayName,
    this.displayNamePlural,
    required this.carbsPerServing,
    this.imageAddress,
    this.barcode,
    this.sourceFoodId,
    this.sourceUserFoodId,
    this.mealTypes,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || clientFoodId != null) {
      map['client_food_id'] = Variable<String>(clientFoodId);
    }
    map['name'] = Variable<String>(name);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || displayNamePlural != null) {
      map['display_name_plural'] = Variable<String>(displayNamePlural);
    }
    map['carbs_per_serving'] = Variable<double>(carbsPerServing);
    if (!nullToAbsent || imageAddress != null) {
      map['image_address'] = Variable<String>(imageAddress);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    if (!nullToAbsent || sourceFoodId != null) {
      map['source_food_id'] = Variable<String>(sourceFoodId);
    }
    if (!nullToAbsent || sourceUserFoodId != null) {
      map['source_user_food_id'] = Variable<String>(sourceUserFoodId);
    }
    if (!nullToAbsent || mealTypes != null) {
      map['meal_types'] = Variable<String>(mealTypes);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CarbLoadingUserFoodsTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingUserFoodsTableCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      userId: Value(userId),
      clientFoodId: clientFoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientFoodId),
      name: Value(name),
      displayName: Value(displayName),
      displayNamePlural: displayNamePlural == null && nullToAbsent
          ? const Value.absent()
          : Value(displayNamePlural),
      carbsPerServing: Value(carbsPerServing),
      imageAddress: imageAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAddress),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      sourceFoodId: sourceFoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFoodId),
      sourceUserFoodId: sourceUserFoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUserFoodId),
      mealTypes: mealTypes == null && nullToAbsent
          ? const Value.absent()
          : Value(mealTypes),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CarbLoadingUserFood.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingUserFood(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      clientFoodId: serializer.fromJson<String?>(json['clientFoodId']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String>(json['displayName']),
      displayNamePlural: serializer.fromJson<String?>(
        json['displayNamePlural'],
      ),
      carbsPerServing: serializer.fromJson<double>(json['carbsPerServing']),
      imageAddress: serializer.fromJson<String?>(json['imageAddress']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      sourceFoodId: serializer.fromJson<String?>(json['sourceFoodId']),
      sourceUserFoodId: serializer.fromJson<String?>(json['sourceUserFoodId']),
      mealTypes: serializer.fromJson<String?>(json['mealTypes']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
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
      'userId': serializer.toJson<String>(userId),
      'clientFoodId': serializer.toJson<String?>(clientFoodId),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String>(displayName),
      'displayNamePlural': serializer.toJson<String?>(displayNamePlural),
      'carbsPerServing': serializer.toJson<double>(carbsPerServing),
      'imageAddress': serializer.toJson<String?>(imageAddress),
      'barcode': serializer.toJson<String?>(barcode),
      'sourceFoodId': serializer.toJson<String?>(sourceFoodId),
      'sourceUserFoodId': serializer.toJson<String?>(sourceUserFoodId),
      'mealTypes': serializer.toJson<String?>(mealTypes),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CarbLoadingUserFood copyWith({
    String? id,
    String? deviceId,
    String? userId,
    Value<String?> clientFoodId = const Value.absent(),
    String? name,
    String? displayName,
    Value<String?> displayNamePlural = const Value.absent(),
    double? carbsPerServing,
    Value<String?> imageAddress = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    Value<String?> sourceFoodId = const Value.absent(),
    Value<String?> sourceUserFoodId = const Value.absent(),
    Value<String?> mealTypes = const Value.absent(),
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CarbLoadingUserFood(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    userId: userId ?? this.userId,
    clientFoodId: clientFoodId.present ? clientFoodId.value : this.clientFoodId,
    name: name ?? this.name,
    displayName: displayName ?? this.displayName,
    displayNamePlural: displayNamePlural.present
        ? displayNamePlural.value
        : this.displayNamePlural,
    carbsPerServing: carbsPerServing ?? this.carbsPerServing,
    imageAddress: imageAddress.present ? imageAddress.value : this.imageAddress,
    barcode: barcode.present ? barcode.value : this.barcode,
    sourceFoodId: sourceFoodId.present ? sourceFoodId.value : this.sourceFoodId,
    sourceUserFoodId: sourceUserFoodId.present
        ? sourceUserFoodId.value
        : this.sourceUserFoodId,
    mealTypes: mealTypes.present ? mealTypes.value : this.mealTypes,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CarbLoadingUserFood copyWithCompanion(
    CarbLoadingUserFoodsTableCompanion data,
  ) {
    return CarbLoadingUserFood(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      clientFoodId: data.clientFoodId.present
          ? data.clientFoodId.value
          : this.clientFoodId,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      displayNamePlural: data.displayNamePlural.present
          ? data.displayNamePlural.value
          : this.displayNamePlural,
      carbsPerServing: data.carbsPerServing.present
          ? data.carbsPerServing.value
          : this.carbsPerServing,
      imageAddress: data.imageAddress.present
          ? data.imageAddress.value
          : this.imageAddress,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      sourceFoodId: data.sourceFoodId.present
          ? data.sourceFoodId.value
          : this.sourceFoodId,
      sourceUserFoodId: data.sourceUserFoodId.present
          ? data.sourceUserFoodId.value
          : this.sourceUserFoodId,
      mealTypes: data.mealTypes.present ? data.mealTypes.value : this.mealTypes,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingUserFood(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('clientFoodId: $clientFoodId, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('barcode: $barcode, ')
          ..write('sourceFoodId: $sourceFoodId, ')
          ..write('sourceUserFoodId: $sourceUserFoodId, ')
          ..write('mealTypes: $mealTypes, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    userId,
    clientFoodId,
    name,
    displayName,
    displayNamePlural,
    carbsPerServing,
    imageAddress,
    barcode,
    sourceFoodId,
    sourceUserFoodId,
    mealTypes,
    isDeleted,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingUserFood &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.clientFoodId == this.clientFoodId &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.displayNamePlural == this.displayNamePlural &&
          other.carbsPerServing == this.carbsPerServing &&
          other.imageAddress == this.imageAddress &&
          other.barcode == this.barcode &&
          other.sourceFoodId == this.sourceFoodId &&
          other.sourceUserFoodId == this.sourceUserFoodId &&
          other.mealTypes == this.mealTypes &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CarbLoadingUserFoodsTableCompanion
    extends UpdateCompanion<CarbLoadingUserFood> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<String?> clientFoodId;
  final Value<String> name;
  final Value<String> displayName;
  final Value<String?> displayNamePlural;
  final Value<double> carbsPerServing;
  final Value<String?> imageAddress;
  final Value<String?> barcode;
  final Value<String?> sourceFoodId;
  final Value<String?> sourceUserFoodId;
  final Value<String?> mealTypes;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CarbLoadingUserFoodsTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.clientFoodId = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.displayNamePlural = const Value.absent(),
    this.carbsPerServing = const Value.absent(),
    this.imageAddress = const Value.absent(),
    this.barcode = const Value.absent(),
    this.sourceFoodId = const Value.absent(),
    this.sourceUserFoodId = const Value.absent(),
    this.mealTypes = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarbLoadingUserFoodsTableCompanion.insert({
    required String id,
    required String deviceId,
    required String userId,
    this.clientFoodId = const Value.absent(),
    required String name,
    required String displayName,
    this.displayNamePlural = const Value.absent(),
    required double carbsPerServing,
    this.imageAddress = const Value.absent(),
    this.barcode = const Value.absent(),
    this.sourceFoodId = const Value.absent(),
    this.sourceUserFoodId = const Value.absent(),
    this.mealTypes = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       userId = Value(userId),
       name = Value(name),
       displayName = Value(displayName),
       carbsPerServing = Value(carbsPerServing);
  static Insertable<CarbLoadingUserFood> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<String>? clientFoodId,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? displayNamePlural,
    Expression<double>? carbsPerServing,
    Expression<String>? imageAddress,
    Expression<String>? barcode,
    Expression<String>? sourceFoodId,
    Expression<String>? sourceUserFoodId,
    Expression<String>? mealTypes,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (clientFoodId != null) 'client_food_id': clientFoodId,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (displayNamePlural != null) 'display_name_plural': displayNamePlural,
      if (carbsPerServing != null) 'carbs_per_serving': carbsPerServing,
      if (imageAddress != null) 'image_address': imageAddress,
      if (barcode != null) 'barcode': barcode,
      if (sourceFoodId != null) 'source_food_id': sourceFoodId,
      if (sourceUserFoodId != null) 'source_user_food_id': sourceUserFoodId,
      if (mealTypes != null) 'meal_types': mealTypes,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarbLoadingUserFoodsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? userId,
    Value<String?>? clientFoodId,
    Value<String>? name,
    Value<String>? displayName,
    Value<String?>? displayNamePlural,
    Value<double>? carbsPerServing,
    Value<String?>? imageAddress,
    Value<String?>? barcode,
    Value<String?>? sourceFoodId,
    Value<String?>? sourceUserFoodId,
    Value<String?>? mealTypes,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CarbLoadingUserFoodsTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      clientFoodId: clientFoodId ?? this.clientFoodId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      displayNamePlural: displayNamePlural ?? this.displayNamePlural,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      imageAddress: imageAddress ?? this.imageAddress,
      barcode: barcode ?? this.barcode,
      sourceFoodId: sourceFoodId ?? this.sourceFoodId,
      sourceUserFoodId: sourceUserFoodId ?? this.sourceUserFoodId,
      mealTypes: mealTypes ?? this.mealTypes,
      isDeleted: isDeleted ?? this.isDeleted,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (clientFoodId.present) {
      map['client_food_id'] = Variable<String>(clientFoodId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (displayNamePlural.present) {
      map['display_name_plural'] = Variable<String>(displayNamePlural.value);
    }
    if (carbsPerServing.present) {
      map['carbs_per_serving'] = Variable<double>(carbsPerServing.value);
    }
    if (imageAddress.present) {
      map['image_address'] = Variable<String>(imageAddress.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (sourceFoodId.present) {
      map['source_food_id'] = Variable<String>(sourceFoodId.value);
    }
    if (sourceUserFoodId.present) {
      map['source_user_food_id'] = Variable<String>(sourceUserFoodId.value);
    }
    if (mealTypes.present) {
      map['meal_types'] = Variable<String>(mealTypes.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
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
    return (StringBuffer('CarbLoadingUserFoodsTableCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('clientFoodId: $clientFoodId, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('displayNamePlural: $displayNamePlural, ')
          ..write('carbsPerServing: $carbsPerServing, ')
          ..write('imageAddress: $imageAddress, ')
          ..write('barcode: $barcode, ')
          ..write('sourceFoodId: $sourceFoodId, ')
          ..write('sourceUserFoodId: $sourceUserFoodId, ')
          ..write('mealTypes: $mealTypes, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarbLoadingDayMealsTableTable extends CarbLoadingDayMealsTable
    with TableInfo<$CarbLoadingDayMealsTableTable, CarbLoadingDayMeal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbLoadingDayMealsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _carbLoadingDayIdMeta = const VerificationMeta(
    'carbLoadingDayId',
  );
  @override
  late final GeneratedColumn<int> carbLoadingDayId = GeneratedColumn<int>(
    'carb_loading_day_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeIdMeta = const VerificationMeta(
    'mealTypeId',
  );
  @override
  late final GeneratedColumn<int> mealTypeId = GeneratedColumn<int>(
    'meal_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbLoadingFoodIdMeta = const VerificationMeta(
    'carbLoadingFoodId',
  );
  @override
  late final GeneratedColumn<String> carbLoadingFoodId =
      GeneratedColumn<String>(
        'carb_loading_food_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _carbLoadingUserFoodIdMeta =
      const VerificationMeta('carbLoadingUserFoodId');
  @override
  late final GeneratedColumn<String> carbLoadingUserFoodId =
      GeneratedColumn<String>(
        'carb_loading_user_food_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _foodDisplayNameMeta = const VerificationMeta(
    'foodDisplayName',
  );
  @override
  late final GeneratedColumn<String> foodDisplayName = GeneratedColumn<String>(
    'food_display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _carbsConsumedMeta = const VerificationMeta(
    'carbsConsumed',
  );
  @override
  late final GeneratedColumn<double> carbsConsumed = GeneratedColumn<double>(
    'carbs_consumed',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
    carbLoadingDayId,
    mealTypeId,
    carbLoadingFoodId,
    carbLoadingUserFoodId,
    foodDisplayName,
    quantity,
    carbsConsumed,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_loading_day_meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarbLoadingDayMeal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('carb_loading_day_id')) {
      context.handle(
        _carbLoadingDayIdMeta,
        carbLoadingDayId.isAcceptableOrUnknown(
          data['carb_loading_day_id']!,
          _carbLoadingDayIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbLoadingDayIdMeta);
    }
    if (data.containsKey('meal_type_id')) {
      context.handle(
        _mealTypeIdMeta,
        mealTypeId.isAcceptableOrUnknown(
          data['meal_type_id']!,
          _mealTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mealTypeIdMeta);
    }
    if (data.containsKey('carb_loading_food_id')) {
      context.handle(
        _carbLoadingFoodIdMeta,
        carbLoadingFoodId.isAcceptableOrUnknown(
          data['carb_loading_food_id']!,
          _carbLoadingFoodIdMeta,
        ),
      );
    }
    if (data.containsKey('carb_loading_user_food_id')) {
      context.handle(
        _carbLoadingUserFoodIdMeta,
        carbLoadingUserFoodId.isAcceptableOrUnknown(
          data['carb_loading_user_food_id']!,
          _carbLoadingUserFoodIdMeta,
        ),
      );
    }
    if (data.containsKey('food_display_name')) {
      context.handle(
        _foodDisplayNameMeta,
        foodDisplayName.isAcceptableOrUnknown(
          data['food_display_name']!,
          _foodDisplayNameMeta,
        ),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('carbs_consumed')) {
      context.handle(
        _carbsConsumedMeta,
        carbsConsumed.isAcceptableOrUnknown(
          data['carbs_consumed']!,
          _carbsConsumedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbsConsumedMeta);
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
  CarbLoadingDayMeal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbLoadingDayMeal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      carbLoadingDayId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carb_loading_day_id'],
      )!,
      mealTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_type_id'],
      )!,
      carbLoadingFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}carb_loading_food_id'],
      ),
      carbLoadingUserFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}carb_loading_user_food_id'],
      ),
      foodDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_display_name'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      carbsConsumed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_consumed'],
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
  $CarbLoadingDayMealsTableTable createAlias(String alias) {
    return $CarbLoadingDayMealsTableTable(attachedDatabase, alias);
  }
}

class CarbLoadingDayMeal extends DataClass
    implements Insertable<CarbLoadingDayMeal> {
  final int id;
  final int carbLoadingDayId;
  final int mealTypeId;
  final String? carbLoadingFoodId;
  final String? carbLoadingUserFoodId;
  final String? foodDisplayName;
  final int quantity;
  final double carbsConsumed;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CarbLoadingDayMeal({
    required this.id,
    required this.carbLoadingDayId,
    required this.mealTypeId,
    this.carbLoadingFoodId,
    this.carbLoadingUserFoodId,
    this.foodDisplayName,
    required this.quantity,
    required this.carbsConsumed,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['carb_loading_day_id'] = Variable<int>(carbLoadingDayId);
    map['meal_type_id'] = Variable<int>(mealTypeId);
    if (!nullToAbsent || carbLoadingFoodId != null) {
      map['carb_loading_food_id'] = Variable<String>(carbLoadingFoodId);
    }
    if (!nullToAbsent || carbLoadingUserFoodId != null) {
      map['carb_loading_user_food_id'] = Variable<String>(
        carbLoadingUserFoodId,
      );
    }
    if (!nullToAbsent || foodDisplayName != null) {
      map['food_display_name'] = Variable<String>(foodDisplayName);
    }
    map['quantity'] = Variable<int>(quantity);
    map['carbs_consumed'] = Variable<double>(carbsConsumed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CarbLoadingDayMealsTableCompanion toCompanion(bool nullToAbsent) {
    return CarbLoadingDayMealsTableCompanion(
      id: Value(id),
      carbLoadingDayId: Value(carbLoadingDayId),
      mealTypeId: Value(mealTypeId),
      carbLoadingFoodId: carbLoadingFoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(carbLoadingFoodId),
      carbLoadingUserFoodId: carbLoadingUserFoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(carbLoadingUserFoodId),
      foodDisplayName: foodDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(foodDisplayName),
      quantity: Value(quantity),
      carbsConsumed: Value(carbsConsumed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CarbLoadingDayMeal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbLoadingDayMeal(
      id: serializer.fromJson<int>(json['id']),
      carbLoadingDayId: serializer.fromJson<int>(json['carbLoadingDayId']),
      mealTypeId: serializer.fromJson<int>(json['mealTypeId']),
      carbLoadingFoodId: serializer.fromJson<String?>(
        json['carbLoadingFoodId'],
      ),
      carbLoadingUserFoodId: serializer.fromJson<String?>(
        json['carbLoadingUserFoodId'],
      ),
      foodDisplayName: serializer.fromJson<String?>(json['foodDisplayName']),
      quantity: serializer.fromJson<int>(json['quantity']),
      carbsConsumed: serializer.fromJson<double>(json['carbsConsumed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'carbLoadingDayId': serializer.toJson<int>(carbLoadingDayId),
      'mealTypeId': serializer.toJson<int>(mealTypeId),
      'carbLoadingFoodId': serializer.toJson<String?>(carbLoadingFoodId),
      'carbLoadingUserFoodId': serializer.toJson<String?>(
        carbLoadingUserFoodId,
      ),
      'foodDisplayName': serializer.toJson<String?>(foodDisplayName),
      'quantity': serializer.toJson<int>(quantity),
      'carbsConsumed': serializer.toJson<double>(carbsConsumed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CarbLoadingDayMeal copyWith({
    int? id,
    int? carbLoadingDayId,
    int? mealTypeId,
    Value<String?> carbLoadingFoodId = const Value.absent(),
    Value<String?> carbLoadingUserFoodId = const Value.absent(),
    Value<String?> foodDisplayName = const Value.absent(),
    int? quantity,
    double? carbsConsumed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CarbLoadingDayMeal(
    id: id ?? this.id,
    carbLoadingDayId: carbLoadingDayId ?? this.carbLoadingDayId,
    mealTypeId: mealTypeId ?? this.mealTypeId,
    carbLoadingFoodId: carbLoadingFoodId.present
        ? carbLoadingFoodId.value
        : this.carbLoadingFoodId,
    carbLoadingUserFoodId: carbLoadingUserFoodId.present
        ? carbLoadingUserFoodId.value
        : this.carbLoadingUserFoodId,
    foodDisplayName: foodDisplayName.present
        ? foodDisplayName.value
        : this.foodDisplayName,
    quantity: quantity ?? this.quantity,
    carbsConsumed: carbsConsumed ?? this.carbsConsumed,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CarbLoadingDayMeal copyWithCompanion(CarbLoadingDayMealsTableCompanion data) {
    return CarbLoadingDayMeal(
      id: data.id.present ? data.id.value : this.id,
      carbLoadingDayId: data.carbLoadingDayId.present
          ? data.carbLoadingDayId.value
          : this.carbLoadingDayId,
      mealTypeId: data.mealTypeId.present
          ? data.mealTypeId.value
          : this.mealTypeId,
      carbLoadingFoodId: data.carbLoadingFoodId.present
          ? data.carbLoadingFoodId.value
          : this.carbLoadingFoodId,
      carbLoadingUserFoodId: data.carbLoadingUserFoodId.present
          ? data.carbLoadingUserFoodId.value
          : this.carbLoadingUserFoodId,
      foodDisplayName: data.foodDisplayName.present
          ? data.foodDisplayName.value
          : this.foodDisplayName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      carbsConsumed: data.carbsConsumed.present
          ? data.carbsConsumed.value
          : this.carbsConsumed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingDayMeal(')
          ..write('id: $id, ')
          ..write('carbLoadingDayId: $carbLoadingDayId, ')
          ..write('mealTypeId: $mealTypeId, ')
          ..write('carbLoadingFoodId: $carbLoadingFoodId, ')
          ..write('carbLoadingUserFoodId: $carbLoadingUserFoodId, ')
          ..write('foodDisplayName: $foodDisplayName, ')
          ..write('quantity: $quantity, ')
          ..write('carbsConsumed: $carbsConsumed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    carbLoadingDayId,
    mealTypeId,
    carbLoadingFoodId,
    carbLoadingUserFoodId,
    foodDisplayName,
    quantity,
    carbsConsumed,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbLoadingDayMeal &&
          other.id == this.id &&
          other.carbLoadingDayId == this.carbLoadingDayId &&
          other.mealTypeId == this.mealTypeId &&
          other.carbLoadingFoodId == this.carbLoadingFoodId &&
          other.carbLoadingUserFoodId == this.carbLoadingUserFoodId &&
          other.foodDisplayName == this.foodDisplayName &&
          other.quantity == this.quantity &&
          other.carbsConsumed == this.carbsConsumed &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CarbLoadingDayMealsTableCompanion
    extends UpdateCompanion<CarbLoadingDayMeal> {
  final Value<int> id;
  final Value<int> carbLoadingDayId;
  final Value<int> mealTypeId;
  final Value<String?> carbLoadingFoodId;
  final Value<String?> carbLoadingUserFoodId;
  final Value<String?> foodDisplayName;
  final Value<int> quantity;
  final Value<double> carbsConsumed;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CarbLoadingDayMealsTableCompanion({
    this.id = const Value.absent(),
    this.carbLoadingDayId = const Value.absent(),
    this.mealTypeId = const Value.absent(),
    this.carbLoadingFoodId = const Value.absent(),
    this.carbLoadingUserFoodId = const Value.absent(),
    this.foodDisplayName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.carbsConsumed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CarbLoadingDayMealsTableCompanion.insert({
    this.id = const Value.absent(),
    required int carbLoadingDayId,
    required int mealTypeId,
    this.carbLoadingFoodId = const Value.absent(),
    this.carbLoadingUserFoodId = const Value.absent(),
    this.foodDisplayName = const Value.absent(),
    this.quantity = const Value.absent(),
    required double carbsConsumed,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : carbLoadingDayId = Value(carbLoadingDayId),
       mealTypeId = Value(mealTypeId),
       carbsConsumed = Value(carbsConsumed);
  static Insertable<CarbLoadingDayMeal> custom({
    Expression<int>? id,
    Expression<int>? carbLoadingDayId,
    Expression<int>? mealTypeId,
    Expression<String>? carbLoadingFoodId,
    Expression<String>? carbLoadingUserFoodId,
    Expression<String>? foodDisplayName,
    Expression<int>? quantity,
    Expression<double>? carbsConsumed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (carbLoadingDayId != null) 'carb_loading_day_id': carbLoadingDayId,
      if (mealTypeId != null) 'meal_type_id': mealTypeId,
      if (carbLoadingFoodId != null) 'carb_loading_food_id': carbLoadingFoodId,
      if (carbLoadingUserFoodId != null)
        'carb_loading_user_food_id': carbLoadingUserFoodId,
      if (foodDisplayName != null) 'food_display_name': foodDisplayName,
      if (quantity != null) 'quantity': quantity,
      if (carbsConsumed != null) 'carbs_consumed': carbsConsumed,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CarbLoadingDayMealsTableCompanion copyWith({
    Value<int>? id,
    Value<int>? carbLoadingDayId,
    Value<int>? mealTypeId,
    Value<String?>? carbLoadingFoodId,
    Value<String?>? carbLoadingUserFoodId,
    Value<String?>? foodDisplayName,
    Value<int>? quantity,
    Value<double>? carbsConsumed,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CarbLoadingDayMealsTableCompanion(
      id: id ?? this.id,
      carbLoadingDayId: carbLoadingDayId ?? this.carbLoadingDayId,
      mealTypeId: mealTypeId ?? this.mealTypeId,
      carbLoadingFoodId: carbLoadingFoodId ?? this.carbLoadingFoodId,
      carbLoadingUserFoodId:
          carbLoadingUserFoodId ?? this.carbLoadingUserFoodId,
      foodDisplayName: foodDisplayName ?? this.foodDisplayName,
      quantity: quantity ?? this.quantity,
      carbsConsumed: carbsConsumed ?? this.carbsConsumed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (carbLoadingDayId.present) {
      map['carb_loading_day_id'] = Variable<int>(carbLoadingDayId.value);
    }
    if (mealTypeId.present) {
      map['meal_type_id'] = Variable<int>(mealTypeId.value);
    }
    if (carbLoadingFoodId.present) {
      map['carb_loading_food_id'] = Variable<String>(carbLoadingFoodId.value);
    }
    if (carbLoadingUserFoodId.present) {
      map['carb_loading_user_food_id'] = Variable<String>(
        carbLoadingUserFoodId.value,
      );
    }
    if (foodDisplayName.present) {
      map['food_display_name'] = Variable<String>(foodDisplayName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (carbsConsumed.present) {
      map['carbs_consumed'] = Variable<double>(carbsConsumed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbLoadingDayMealsTableCompanion(')
          ..write('id: $id, ')
          ..write('carbLoadingDayId: $carbLoadingDayId, ')
          ..write('mealTypeId: $mealTypeId, ')
          ..write('carbLoadingFoodId: $carbLoadingFoodId, ')
          ..write('carbLoadingUserFoodId: $carbLoadingUserFoodId, ')
          ..write('foodDisplayName: $foodDisplayName, ')
          ..write('quantity: $quantity, ')
          ..write('carbsConsumed: $carbsConsumed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WeatherForecastsTableTable extends WeatherForecastsTable
    with TableInfo<$WeatherForecastsTableTable, WeatherForecastData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeatherForecastsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _forecastDateMeta = const VerificationMeta(
    'forecastDate',
  );
  @override
  late final GeneratedColumn<DateTime> forecastDate = GeneratedColumn<DateTime>(
    'forecast_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temperatureCMeta = const VerificationMeta(
    'temperatureC',
  );
  @override
  late final GeneratedColumn<double> temperatureC = GeneratedColumn<double>(
    'temperature_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _humidityPctMeta = const VerificationMeta(
    'humidityPct',
  );
  @override
  late final GeneratedColumn<int> humidityPct = GeneratedColumn<int>(
    'humidity_pct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _forecastAvailableMeta = const VerificationMeta(
    'forecastAvailable',
  );
  @override
  late final GeneratedColumn<bool> forecastAvailable = GeneratedColumn<bool>(
    'forecast_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("forecast_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conditionsMeta = const VerificationMeta(
    'conditions',
  );
  @override
  late final GeneratedColumn<String> conditions = GeneratedColumn<String>(
    'conditions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _windSpeedKmhMeta = const VerificationMeta(
    'windSpeedKmh',
  );
  @override
  late final GeneratedColumn<int> windSpeedKmh = GeneratedColumn<int>(
    'wind_speed_kmh',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _precipitationMmMeta = const VerificationMeta(
    'precipitationMm',
  );
  @override
  late final GeneratedColumn<double> precipitationMm = GeneratedColumn<double>(
    'precipitation_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    latitude,
    longitude,
    forecastDate,
    temperatureC,
    humidityPct,
    forecastAvailable,
    source,
    conditions,
    windSpeedKmh,
    precipitationMm,
    fetchedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weather_forecasts_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeatherForecastData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('forecast_date')) {
      context.handle(
        _forecastDateMeta,
        forecastDate.isAcceptableOrUnknown(
          data['forecast_date']!,
          _forecastDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_forecastDateMeta);
    }
    if (data.containsKey('temperature_c')) {
      context.handle(
        _temperatureCMeta,
        temperatureC.isAcceptableOrUnknown(
          data['temperature_c']!,
          _temperatureCMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_temperatureCMeta);
    }
    if (data.containsKey('humidity_pct')) {
      context.handle(
        _humidityPctMeta,
        humidityPct.isAcceptableOrUnknown(
          data['humidity_pct']!,
          _humidityPctMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_humidityPctMeta);
    }
    if (data.containsKey('forecast_available')) {
      context.handle(
        _forecastAvailableMeta,
        forecastAvailable.isAcceptableOrUnknown(
          data['forecast_available']!,
          _forecastAvailableMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('conditions')) {
      context.handle(
        _conditionsMeta,
        conditions.isAcceptableOrUnknown(data['conditions']!, _conditionsMeta),
      );
    }
    if (data.containsKey('wind_speed_kmh')) {
      context.handle(
        _windSpeedKmhMeta,
        windSpeedKmh.isAcceptableOrUnknown(
          data['wind_speed_kmh']!,
          _windSpeedKmhMeta,
        ),
      );
    }
    if (data.containsKey('precipitation_mm')) {
      context.handle(
        _precipitationMmMeta,
        precipitationMm.isAcceptableOrUnknown(
          data['precipitation_mm']!,
          _precipitationMmMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeatherForecastData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeatherForecastData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      forecastDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}forecast_date'],
      )!,
      temperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature_c'],
      )!,
      humidityPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}humidity_pct'],
      )!,
      forecastAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}forecast_available'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      conditions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conditions'],
      ),
      windSpeedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wind_speed_kmh'],
      ),
      precipitationMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precipitation_mm'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $WeatherForecastsTableTable createAlias(String alias) {
    return $WeatherForecastsTableTable(attachedDatabase, alias);
  }
}

class WeatherForecastData extends DataClass
    implements Insertable<WeatherForecastData> {
  final int id;
  final double latitude;
  final double longitude;
  final DateTime forecastDate;
  final double temperatureC;
  final int humidityPct;
  final bool forecastAvailable;
  final String source;
  final String? conditions;
  final int? windSpeedKmh;
  final double? precipitationMm;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  const WeatherForecastData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.forecastDate,
    required this.temperatureC,
    required this.humidityPct,
    required this.forecastAvailable,
    required this.source,
    this.conditions,
    this.windSpeedKmh,
    this.precipitationMm,
    required this.fetchedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['forecast_date'] = Variable<DateTime>(forecastDate);
    map['temperature_c'] = Variable<double>(temperatureC);
    map['humidity_pct'] = Variable<int>(humidityPct);
    map['forecast_available'] = Variable<bool>(forecastAvailable);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || conditions != null) {
      map['conditions'] = Variable<String>(conditions);
    }
    if (!nullToAbsent || windSpeedKmh != null) {
      map['wind_speed_kmh'] = Variable<int>(windSpeedKmh);
    }
    if (!nullToAbsent || precipitationMm != null) {
      map['precipitation_mm'] = Variable<double>(precipitationMm);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  WeatherForecastsTableCompanion toCompanion(bool nullToAbsent) {
    return WeatherForecastsTableCompanion(
      id: Value(id),
      latitude: Value(latitude),
      longitude: Value(longitude),
      forecastDate: Value(forecastDate),
      temperatureC: Value(temperatureC),
      humidityPct: Value(humidityPct),
      forecastAvailable: Value(forecastAvailable),
      source: Value(source),
      conditions: conditions == null && nullToAbsent
          ? const Value.absent()
          : Value(conditions),
      windSpeedKmh: windSpeedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(windSpeedKmh),
      precipitationMm: precipitationMm == null && nullToAbsent
          ? const Value.absent()
          : Value(precipitationMm),
      fetchedAt: Value(fetchedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory WeatherForecastData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeatherForecastData(
      id: serializer.fromJson<int>(json['id']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      forecastDate: serializer.fromJson<DateTime>(json['forecastDate']),
      temperatureC: serializer.fromJson<double>(json['temperatureC']),
      humidityPct: serializer.fromJson<int>(json['humidityPct']),
      forecastAvailable: serializer.fromJson<bool>(json['forecastAvailable']),
      source: serializer.fromJson<String>(json['source']),
      conditions: serializer.fromJson<String?>(json['conditions']),
      windSpeedKmh: serializer.fromJson<int?>(json['windSpeedKmh']),
      precipitationMm: serializer.fromJson<double?>(json['precipitationMm']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'forecastDate': serializer.toJson<DateTime>(forecastDate),
      'temperatureC': serializer.toJson<double>(temperatureC),
      'humidityPct': serializer.toJson<int>(humidityPct),
      'forecastAvailable': serializer.toJson<bool>(forecastAvailable),
      'source': serializer.toJson<String>(source),
      'conditions': serializer.toJson<String?>(conditions),
      'windSpeedKmh': serializer.toJson<int?>(windSpeedKmh),
      'precipitationMm': serializer.toJson<double?>(precipitationMm),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  WeatherForecastData copyWith({
    int? id,
    double? latitude,
    double? longitude,
    DateTime? forecastDate,
    double? temperatureC,
    int? humidityPct,
    bool? forecastAvailable,
    String? source,
    Value<String?> conditions = const Value.absent(),
    Value<int?> windSpeedKmh = const Value.absent(),
    Value<double?> precipitationMm = const Value.absent(),
    DateTime? fetchedAt,
    DateTime? expiresAt,
  }) => WeatherForecastData(
    id: id ?? this.id,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    forecastDate: forecastDate ?? this.forecastDate,
    temperatureC: temperatureC ?? this.temperatureC,
    humidityPct: humidityPct ?? this.humidityPct,
    forecastAvailable: forecastAvailable ?? this.forecastAvailable,
    source: source ?? this.source,
    conditions: conditions.present ? conditions.value : this.conditions,
    windSpeedKmh: windSpeedKmh.present ? windSpeedKmh.value : this.windSpeedKmh,
    precipitationMm: precipitationMm.present
        ? precipitationMm.value
        : this.precipitationMm,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  WeatherForecastData copyWithCompanion(WeatherForecastsTableCompanion data) {
    return WeatherForecastData(
      id: data.id.present ? data.id.value : this.id,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      forecastDate: data.forecastDate.present
          ? data.forecastDate.value
          : this.forecastDate,
      temperatureC: data.temperatureC.present
          ? data.temperatureC.value
          : this.temperatureC,
      humidityPct: data.humidityPct.present
          ? data.humidityPct.value
          : this.humidityPct,
      forecastAvailable: data.forecastAvailable.present
          ? data.forecastAvailable.value
          : this.forecastAvailable,
      source: data.source.present ? data.source.value : this.source,
      conditions: data.conditions.present
          ? data.conditions.value
          : this.conditions,
      windSpeedKmh: data.windSpeedKmh.present
          ? data.windSpeedKmh.value
          : this.windSpeedKmh,
      precipitationMm: data.precipitationMm.present
          ? data.precipitationMm.value
          : this.precipitationMm,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeatherForecastData(')
          ..write('id: $id, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('forecastDate: $forecastDate, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('humidityPct: $humidityPct, ')
          ..write('forecastAvailable: $forecastAvailable, ')
          ..write('source: $source, ')
          ..write('conditions: $conditions, ')
          ..write('windSpeedKmh: $windSpeedKmh, ')
          ..write('precipitationMm: $precipitationMm, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    latitude,
    longitude,
    forecastDate,
    temperatureC,
    humidityPct,
    forecastAvailable,
    source,
    conditions,
    windSpeedKmh,
    precipitationMm,
    fetchedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeatherForecastData &&
          other.id == this.id &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.forecastDate == this.forecastDate &&
          other.temperatureC == this.temperatureC &&
          other.humidityPct == this.humidityPct &&
          other.forecastAvailable == this.forecastAvailable &&
          other.source == this.source &&
          other.conditions == this.conditions &&
          other.windSpeedKmh == this.windSpeedKmh &&
          other.precipitationMm == this.precipitationMm &&
          other.fetchedAt == this.fetchedAt &&
          other.expiresAt == this.expiresAt);
}

class WeatherForecastsTableCompanion
    extends UpdateCompanion<WeatherForecastData> {
  final Value<int> id;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<DateTime> forecastDate;
  final Value<double> temperatureC;
  final Value<int> humidityPct;
  final Value<bool> forecastAvailable;
  final Value<String> source;
  final Value<String?> conditions;
  final Value<int?> windSpeedKmh;
  final Value<double?> precipitationMm;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> expiresAt;
  const WeatherForecastsTableCompanion({
    this.id = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.forecastDate = const Value.absent(),
    this.temperatureC = const Value.absent(),
    this.humidityPct = const Value.absent(),
    this.forecastAvailable = const Value.absent(),
    this.source = const Value.absent(),
    this.conditions = const Value.absent(),
    this.windSpeedKmh = const Value.absent(),
    this.precipitationMm = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  WeatherForecastsTableCompanion.insert({
    this.id = const Value.absent(),
    required double latitude,
    required double longitude,
    required DateTime forecastDate,
    required double temperatureC,
    required int humidityPct,
    this.forecastAvailable = const Value.absent(),
    required String source,
    this.conditions = const Value.absent(),
    this.windSpeedKmh = const Value.absent(),
    this.precipitationMm = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    required DateTime expiresAt,
  }) : latitude = Value(latitude),
       longitude = Value(longitude),
       forecastDate = Value(forecastDate),
       temperatureC = Value(temperatureC),
       humidityPct = Value(humidityPct),
       source = Value(source),
       expiresAt = Value(expiresAt);
  static Insertable<WeatherForecastData> custom({
    Expression<int>? id,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? forecastDate,
    Expression<double>? temperatureC,
    Expression<int>? humidityPct,
    Expression<bool>? forecastAvailable,
    Expression<String>? source,
    Expression<String>? conditions,
    Expression<int>? windSpeedKmh,
    Expression<double>? precipitationMm,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (forecastDate != null) 'forecast_date': forecastDate,
      if (temperatureC != null) 'temperature_c': temperatureC,
      if (humidityPct != null) 'humidity_pct': humidityPct,
      if (forecastAvailable != null) 'forecast_available': forecastAvailable,
      if (source != null) 'source': source,
      if (conditions != null) 'conditions': conditions,
      if (windSpeedKmh != null) 'wind_speed_kmh': windSpeedKmh,
      if (precipitationMm != null) 'precipitation_mm': precipitationMm,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  WeatherForecastsTableCompanion copyWith({
    Value<int>? id,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<DateTime>? forecastDate,
    Value<double>? temperatureC,
    Value<int>? humidityPct,
    Value<bool>? forecastAvailable,
    Value<String>? source,
    Value<String?>? conditions,
    Value<int?>? windSpeedKmh,
    Value<double?>? precipitationMm,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? expiresAt,
  }) {
    return WeatherForecastsTableCompanion(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      forecastDate: forecastDate ?? this.forecastDate,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      forecastAvailable: forecastAvailable ?? this.forecastAvailable,
      source: source ?? this.source,
      conditions: conditions ?? this.conditions,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      precipitationMm: precipitationMm ?? this.precipitationMm,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (forecastDate.present) {
      map['forecast_date'] = Variable<DateTime>(forecastDate.value);
    }
    if (temperatureC.present) {
      map['temperature_c'] = Variable<double>(temperatureC.value);
    }
    if (humidityPct.present) {
      map['humidity_pct'] = Variable<int>(humidityPct.value);
    }
    if (forecastAvailable.present) {
      map['forecast_available'] = Variable<bool>(forecastAvailable.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (conditions.present) {
      map['conditions'] = Variable<String>(conditions.value);
    }
    if (windSpeedKmh.present) {
      map['wind_speed_kmh'] = Variable<int>(windSpeedKmh.value);
    }
    if (precipitationMm.present) {
      map['precipitation_mm'] = Variable<double>(precipitationMm.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeatherForecastsTableCompanion(')
          ..write('id: $id, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('forecastDate: $forecastDate, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('humidityPct: $humidityPct, ')
          ..write('forecastAvailable: $forecastAvailable, ')
          ..write('source: $source, ')
          ..write('conditions: $conditions, ')
          ..write('windSpeedKmh: $windSpeedKmh, ')
          ..write('precipitationMm: $precipitationMm, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $FeatureSurveyResponsesTableTable extends FeatureSurveyResponsesTable
    with
        TableInfo<
          $FeatureSurveyResponsesTableTable,
          FeatureSurveyResponseEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeatureSurveyResponsesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedFeaturesMeta = const VerificationMeta(
    'selectedFeatures',
  );
  @override
  late final GeneratedColumn<String> selectedFeatures = GeneratedColumn<String>(
    'selected_features',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _votedAtMeta = const VerificationMeta(
    'votedAt',
  );
  @override
  late final GeneratedColumn<DateTime> votedAt = GeneratedColumn<DateTime>(
    'voted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, selectedFeatures, votedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feature_survey_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeatureSurveyResponseEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('selected_features')) {
      context.handle(
        _selectedFeaturesMeta,
        selectedFeatures.isAcceptableOrUnknown(
          data['selected_features']!,
          _selectedFeaturesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedFeaturesMeta);
    }
    if (data.containsKey('voted_at')) {
      context.handle(
        _votedAtMeta,
        votedAt.isAcceptableOrUnknown(data['voted_at']!, _votedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_votedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeatureSurveyResponseEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeatureSurveyResponseEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      selectedFeatures: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_features'],
      )!,
      votedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}voted_at'],
      )!,
    );
  }

  @override
  $FeatureSurveyResponsesTableTable createAlias(String alias) {
    return $FeatureSurveyResponsesTableTable(attachedDatabase, alias);
  }
}

class FeatureSurveyResponseEntry extends DataClass
    implements Insertable<FeatureSurveyResponseEntry> {
  /// Primary key - BIGSERIAL
  final int id;

  /// User ID (UUID) - references users.id
  final String userId;

  /// JSON array of selected feature IDs (exactly 3)
  /// Example: ["shopping_list", "coach_sharing", "recipes"]
  final String selectedFeatures;

  /// Timestamp of when the vote was cast
  final DateTime votedAt;
  const FeatureSurveyResponseEntry({
    required this.id,
    required this.userId,
    required this.selectedFeatures,
    required this.votedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['selected_features'] = Variable<String>(selectedFeatures);
    map['voted_at'] = Variable<DateTime>(votedAt);
    return map;
  }

  FeatureSurveyResponsesTableCompanion toCompanion(bool nullToAbsent) {
    return FeatureSurveyResponsesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      selectedFeatures: Value(selectedFeatures),
      votedAt: Value(votedAt),
    );
  }

  factory FeatureSurveyResponseEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeatureSurveyResponseEntry(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      selectedFeatures: serializer.fromJson<String>(json['selectedFeatures']),
      votedAt: serializer.fromJson<DateTime>(json['votedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'selectedFeatures': serializer.toJson<String>(selectedFeatures),
      'votedAt': serializer.toJson<DateTime>(votedAt),
    };
  }

  FeatureSurveyResponseEntry copyWith({
    int? id,
    String? userId,
    String? selectedFeatures,
    DateTime? votedAt,
  }) => FeatureSurveyResponseEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    selectedFeatures: selectedFeatures ?? this.selectedFeatures,
    votedAt: votedAt ?? this.votedAt,
  );
  FeatureSurveyResponseEntry copyWithCompanion(
    FeatureSurveyResponsesTableCompanion data,
  ) {
    return FeatureSurveyResponseEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      selectedFeatures: data.selectedFeatures.present
          ? data.selectedFeatures.value
          : this.selectedFeatures,
      votedAt: data.votedAt.present ? data.votedAt.value : this.votedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeatureSurveyResponseEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('selectedFeatures: $selectedFeatures, ')
          ..write('votedAt: $votedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, selectedFeatures, votedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureSurveyResponseEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.selectedFeatures == this.selectedFeatures &&
          other.votedAt == this.votedAt);
}

class FeatureSurveyResponsesTableCompanion
    extends UpdateCompanion<FeatureSurveyResponseEntry> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> selectedFeatures;
  final Value<DateTime> votedAt;
  const FeatureSurveyResponsesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.selectedFeatures = const Value.absent(),
    this.votedAt = const Value.absent(),
  });
  FeatureSurveyResponsesTableCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String selectedFeatures,
    required DateTime votedAt,
  }) : userId = Value(userId),
       selectedFeatures = Value(selectedFeatures),
       votedAt = Value(votedAt);
  static Insertable<FeatureSurveyResponseEntry> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? selectedFeatures,
    Expression<DateTime>? votedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (selectedFeatures != null) 'selected_features': selectedFeatures,
      if (votedAt != null) 'voted_at': votedAt,
    });
  }

  FeatureSurveyResponsesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? userId,
    Value<String>? selectedFeatures,
    Value<DateTime>? votedAt,
  }) {
    return FeatureSurveyResponsesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      selectedFeatures: selectedFeatures ?? this.selectedFeatures,
      votedAt: votedAt ?? this.votedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (selectedFeatures.present) {
      map['selected_features'] = Variable<String>(selectedFeatures.value);
    }
    if (votedAt.present) {
      map['voted_at'] = Variable<DateTime>(votedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeatureSurveyResponsesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('selectedFeatures: $selectedFeatures, ')
          ..write('votedAt: $votedAt')
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
  late final $FeedbackTableTable feedbackTable = $FeedbackTableTable(this);
  late final $FoodsTableTable foodsTable = $FoodsTableTable(this);
  late final $UserFoodsTableTable userFoodsTable = $UserFoodsTableTable(this);
  late final $AppContentTableTable appContentTable = $AppContentTableTable(
    this,
  );
  late final $EdgeFunctionsTableTable edgeFunctionsTable =
      $EdgeFunctionsTableTable(this);
  late final $ActivitiesTableTable activitiesTable = $ActivitiesTableTable(
    this,
  );
  late final $EventsTableTable eventsTable = $EventsTableTable(this);
  late final $CarbLoadingPlansTableTable carbLoadingPlansTable =
      $CarbLoadingPlansTableTable(this);
  late final $CarbLoadingDaysTableTable carbLoadingDaysTable =
      $CarbLoadingDaysTableTable(this);
  late final $CarbLoadingFoodsTableTable carbLoadingFoodsTable =
      $CarbLoadingFoodsTableTable(this);
  late final $CarbLoadingUserFoodsTableTable carbLoadingUserFoodsTable =
      $CarbLoadingUserFoodsTableTable(this);
  late final $CarbLoadingDayMealsTableTable carbLoadingDayMealsTable =
      $CarbLoadingDayMealsTableTable(this);
  late final $WeatherForecastsTableTable weatherForecastsTable =
      $WeatherForecastsTableTable(this);
  late final $FeatureSurveyResponsesTableTable featureSurveyResponsesTable =
      $FeatureSurveyResponsesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfilesTable,
    foodPreferencesTable,
    feedbackTable,
    foodsTable,
    userFoodsTable,
    appContentTable,
    edgeFunctionsTable,
    activitiesTable,
    eventsTable,
    carbLoadingPlansTable,
    carbLoadingDaysTable,
    carbLoadingFoodsTable,
    carbLoadingUserFoodsTable,
    carbLoadingDayMealsTable,
    weatherForecastsTable,
    featureSurveyResponsesTable,
  ];
}

typedef $$UserProfilesTableTableCreateCompanionBuilder =
    UserProfilesTableCompanion Function({
      required String id,
      required String deviceId,
      Value<String?> authUserId,
      Value<String> authProvider,
      Value<bool> isAnonymous,
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
      Value<String> calendarWeekStart,
      Value<String> defaultActivityTime,
      Value<String> defaultActivityDay,
      Value<bool> autoGenerateNutrition,
      Value<bool> completionReminders,
      Value<String?> senderName,
      Value<int> rowid,
    });
typedef $$UserProfilesTableTableUpdateCompanionBuilder =
    UserProfilesTableCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<String?> authUserId,
      Value<String> authProvider,
      Value<bool> isAnonymous,
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
      Value<String> calendarWeekStart,
      Value<String> defaultActivityTime,
      Value<String> defaultActivityDay,
      Value<bool> autoGenerateNutrition,
      Value<bool> completionReminders,
      Value<String?> senderName,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authUserId => $composableBuilder(
    column: $table.authUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authProvider => $composableBuilder(
    column: $table.authProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAnonymous => $composableBuilder(
    column: $table.isAnonymous,
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

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthday => $composableBuilder(
    column: $table.birthday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightFeet => $composableBuilder(
    column: $table.heightFeet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightInches => $composableBuilder(
    column: $table.heightInches,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightPounds => $composableBuilder(
    column: $table.weightPounds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get runsWithWaterBottle => $composableBuilder(
    column: $table.runsWithWaterBottle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>,
    Map<String, dynamic>,
    String
  >
  get foodPreferences => $composableBuilder(
    column: $table.foodPreferences,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get preferredDistanceUnit => $composableBuilder(
    column: $table.preferredDistanceUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredPaceUnit => $composableBuilder(
    column: $table.preferredPaceUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gutTrainingLevel => $composableBuilder(
    column: $table.gutTrainingLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastActiveAt => $composableBuilder(
    column: $table.lastActiveAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultReminderDay => $composableBuilder(
    column: $table.defaultReminderDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultReminderHour => $composableBuilder(
    column: $table.defaultReminderHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultReminderMinute => $composableBuilder(
    column: $table.defaultReminderMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get defaultReminderRecurring => $composableBuilder(
    column: $table.defaultReminderRecurring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tempPlanData => $composableBuilder(
    column: $table.tempPlanData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get swipeHintShown => $composableBuilder(
    column: $table.swipeHintShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarWeekStart => $composableBuilder(
    column: $table.calendarWeekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultActivityTime => $composableBuilder(
    column: $table.defaultActivityTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultActivityDay => $composableBuilder(
    column: $table.defaultActivityDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoGenerateNutrition => $composableBuilder(
    column: $table.autoGenerateNutrition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completionReminders => $composableBuilder(
    column: $table.completionReminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authUserId => $composableBuilder(
    column: $table.authUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authProvider => $composableBuilder(
    column: $table.authProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAnonymous => $composableBuilder(
    column: $table.isAnonymous,
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

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthday => $composableBuilder(
    column: $table.birthday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightFeet => $composableBuilder(
    column: $table.heightFeet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightInches => $composableBuilder(
    column: $table.heightInches,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightPounds => $composableBuilder(
    column: $table.weightPounds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get runsWithWaterBottle => $composableBuilder(
    column: $table.runsWithWaterBottle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodPreferences => $composableBuilder(
    column: $table.foodPreferences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredDistanceUnit => $composableBuilder(
    column: $table.preferredDistanceUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredPaceUnit => $composableBuilder(
    column: $table.preferredPaceUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gutTrainingLevel => $composableBuilder(
    column: $table.gutTrainingLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastActiveAt => $composableBuilder(
    column: $table.lastActiveAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultReminderDay => $composableBuilder(
    column: $table.defaultReminderDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultReminderHour => $composableBuilder(
    column: $table.defaultReminderHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultReminderMinute => $composableBuilder(
    column: $table.defaultReminderMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get defaultReminderRecurring => $composableBuilder(
    column: $table.defaultReminderRecurring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tempPlanData => $composableBuilder(
    column: $table.tempPlanData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get swipeHintShown => $composableBuilder(
    column: $table.swipeHintShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarWeekStart => $composableBuilder(
    column: $table.calendarWeekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultActivityTime => $composableBuilder(
    column: $table.defaultActivityTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultActivityDay => $composableBuilder(
    column: $table.defaultActivityDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoGenerateNutrition => $composableBuilder(
    column: $table.autoGenerateNutrition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completionReminders => $composableBuilder(
    column: $table.completionReminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get authUserId => $composableBuilder(
    column: $table.authUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authProvider => $composableBuilder(
    column: $table.authProvider,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAnonymous => $composableBuilder(
    column: $table.isAnonymous,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<DateTime> get birthday =>
      $composableBuilder(column: $table.birthday, builder: (column) => column);

  GeneratedColumn<int> get heightFeet => $composableBuilder(
    column: $table.heightFeet,
    builder: (column) => column,
  );

  GeneratedColumn<int> get heightInches => $composableBuilder(
    column: $table.heightInches,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightPounds => $composableBuilder(
    column: $table.weightPounds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get runsWithWaterBottle => $composableBuilder(
    column: $table.runsWithWaterBottle,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  get foodPreferences => $composableBuilder(
    column: $table.foodPreferences,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredDistanceUnit => $composableBuilder(
    column: $table.preferredDistanceUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredPaceUnit => $composableBuilder(
    column: $table.preferredPaceUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gutTrainingLevel => $composableBuilder(
    column: $table.gutTrainingLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastActiveAt => $composableBuilder(
    column: $table.lastActiveAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultReminderDay => $composableBuilder(
    column: $table.defaultReminderDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultReminderHour => $composableBuilder(
    column: $table.defaultReminderHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultReminderMinute => $composableBuilder(
    column: $table.defaultReminderMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get defaultReminderRecurring => $composableBuilder(
    column: $table.defaultReminderRecurring,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tempPlanData => $composableBuilder(
    column: $table.tempPlanData,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get swipeHintShown => $composableBuilder(
    column: $table.swipeHintShown,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarWeekStart => $composableBuilder(
    column: $table.calendarWeekStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultActivityTime => $composableBuilder(
    column: $table.defaultActivityTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultActivityDay => $composableBuilder(
    column: $table.defaultActivityDay,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoGenerateNutrition => $composableBuilder(
    column: $table.autoGenerateNutrition,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completionReminders => $composableBuilder(
    column: $table.completionReminders,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<
              _$AppDatabase,
              $UserProfilesTableTable,
              UserProfileEntry
            >,
          ),
          UserProfileEntry,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableTableManager(
    _$AppDatabase db,
    $UserProfilesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String?> authUserId = const Value.absent(),
                Value<String> authProvider = const Value.absent(),
                Value<bool> isAnonymous = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<DateTime?> birthday = const Value.absent(),
                Value<int?> heightFeet = const Value.absent(),
                Value<int?> heightInches = const Value.absent(),
                Value<double?> weightPounds = const Value.absent(),
                Value<bool> runsWithWaterBottle = const Value.absent(),
                Value<Map<String, dynamic>> foodPreferences =
                    const Value.absent(),
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
                Value<String> calendarWeekStart = const Value.absent(),
                Value<String> defaultActivityTime = const Value.absent(),
                Value<String> defaultActivityDay = const Value.absent(),
                Value<bool> autoGenerateNutrition = const Value.absent(),
                Value<bool> completionReminders = const Value.absent(),
                Value<String?> senderName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesTableCompanion(
                id: id,
                deviceId: deviceId,
                authUserId: authUserId,
                authProvider: authProvider,
                isAnonymous: isAnonymous,
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
                calendarWeekStart: calendarWeekStart,
                defaultActivityTime: defaultActivityTime,
                defaultActivityDay: defaultActivityDay,
                autoGenerateNutrition: autoGenerateNutrition,
                completionReminders: completionReminders,
                senderName: senderName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                Value<String?> authUserId = const Value.absent(),
                Value<String> authProvider = const Value.absent(),
                Value<bool> isAnonymous = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<DateTime?> birthday = const Value.absent(),
                Value<int?> heightFeet = const Value.absent(),
                Value<int?> heightInches = const Value.absent(),
                Value<double?> weightPounds = const Value.absent(),
                Value<bool> runsWithWaterBottle = const Value.absent(),
                Value<Map<String, dynamic>> foodPreferences =
                    const Value.absent(),
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
                Value<String> calendarWeekStart = const Value.absent(),
                Value<String> defaultActivityTime = const Value.absent(),
                Value<String> defaultActivityDay = const Value.absent(),
                Value<bool> autoGenerateNutrition = const Value.absent(),
                Value<bool> completionReminders = const Value.absent(),
                Value<String?> senderName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesTableCompanion.insert(
                id: id,
                deviceId: deviceId,
                authUserId: authUserId,
                authProvider: authProvider,
                isAnonymous: isAnonymous,
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
                calendarWeekStart: calendarWeekStart,
                defaultActivityTime: defaultActivityTime,
                defaultActivityDay: defaultActivityDay,
                autoGenerateNutrition: autoGenerateNutrition,
                completionReminders: completionReminders,
                senderName: senderName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<
          _$AppDatabase,
          $UserProfilesTableTable,
          UserProfileEntry
        >,
      ),
      UserProfileEntry,
      PrefetchHooks Function()
    >;
typedef $$FoodPreferencesTableTableCreateCompanionBuilder =
    FoodPreferencesTableCompanion Function({
      required String id,
      required String userId,
      required String foodName,
      required String preference,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$FoodPreferencesTableTableUpdateCompanionBuilder =
    FoodPreferencesTableCompanion Function({
      Value<String> id,
      Value<String> userId,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preference => $composableBuilder(
    column: $table.preference,
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preference => $composableBuilder(
    column: $table.preference,
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<String> get preference => $composableBuilder(
    column: $table.preference,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FoodPreferencesTableTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<
              _$AppDatabase,
              $FoodPreferencesTableTable,
              FoodPreferenceEntry
            >,
          ),
          FoodPreferenceEntry,
          PrefetchHooks Function()
        > {
  $$FoodPreferencesTableTableTableManager(
    _$AppDatabase db,
    $FoodPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FoodPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<String> preference = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodPreferencesTableCompanion(
                id: id,
                userId: userId,
                foodName: foodName,
                preference: preference,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String foodName,
                required String preference,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodPreferencesTableCompanion.insert(
                id: id,
                userId: userId,
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
        ),
      );
}

typedef $$FoodPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<
          _$AppDatabase,
          $FoodPreferencesTableTable,
          FoodPreferenceEntry
        >,
      ),
      FoodPreferenceEntry,
      PrefetchHooks Function()
    >;
typedef $$FeedbackTableTableCreateCompanionBuilder =
    FeedbackTableCompanion Function({
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
typedef $$FeedbackTableTableUpdateCompanionBuilder =
    FeedbackTableCompanion Function({
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get satisfactionLevel => $composableBuilder(
    column: $table.satisfactionLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get satisfactionEmoji => $composableBuilder(
    column: $table.satisfactionEmoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get satisfactionLabel => $composableBuilder(
    column: $table.satisfactionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appFeedback => $composableBuilder(
    column: $table.appFeedback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestions => $composableBuilder(
    column: $table.suggestions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planName => $composableBuilder(
    column: $table.planName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidenceLevel => $composableBuilder(
    column: $table.confidenceLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidenceLabel => $composableBuilder(
    column: $table.confidenceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reuseIntent => $composableBuilder(
    column: $table.reuseIntent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderRequested => $composableBuilder(
    column: $table.reminderRequested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missedReasons => $composableBuilder(
    column: $table.missedReasons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missedOther => $composableBuilder(
    column: $table.missedOther,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderDayOfWeek => $composableBuilder(
    column: $table.reminderDayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderRecurring => $composableBuilder(
    column: $table.reminderRecurring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get satisfactionLevel => $composableBuilder(
    column: $table.satisfactionLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get satisfactionEmoji => $composableBuilder(
    column: $table.satisfactionEmoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get satisfactionLabel => $composableBuilder(
    column: $table.satisfactionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appFeedback => $composableBuilder(
    column: $table.appFeedback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestions => $composableBuilder(
    column: $table.suggestions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planName => $composableBuilder(
    column: $table.planName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidenceLevel => $composableBuilder(
    column: $table.confidenceLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidenceLabel => $composableBuilder(
    column: $table.confidenceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reuseIntent => $composableBuilder(
    column: $table.reuseIntent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderRequested => $composableBuilder(
    column: $table.reminderRequested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missedReasons => $composableBuilder(
    column: $table.missedReasons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missedOther => $composableBuilder(
    column: $table.missedOther,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderDayOfWeek => $composableBuilder(
    column: $table.reminderDayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderRecurring => $composableBuilder(
    column: $table.reminderRecurring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.satisfactionLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get satisfactionEmoji => $composableBuilder(
    column: $table.satisfactionEmoji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get satisfactionLabel => $composableBuilder(
    column: $table.satisfactionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appFeedback => $composableBuilder(
    column: $table.appFeedback,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestions => $composableBuilder(
    column: $table.suggestions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get planName =>
      $composableBuilder(column: $table.planName, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get confidenceLevel => $composableBuilder(
    column: $table.confidenceLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidenceLabel => $composableBuilder(
    column: $table.confidenceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reuseIntent => $composableBuilder(
    column: $table.reuseIntent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderRequested => $composableBuilder(
    column: $table.reminderRequested,
    builder: (column) => column,
  );

  GeneratedColumn<String> get missedReasons => $composableBuilder(
    column: $table.missedReasons,
    builder: (column) => column,
  );

  GeneratedColumn<String> get missedOther => $composableBuilder(
    column: $table.missedOther,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderDayOfWeek => $composableBuilder(
    column: $table.reminderDayOfWeek,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderRecurring => $composableBuilder(
    column: $table.reminderRecurring,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FeedbackTableTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<_$AppDatabase, $FeedbackTableTable, FeedbackEntry>,
          ),
          FeedbackEntry,
          PrefetchHooks Function()
        > {
  $$FeedbackTableTableTableManager(_$AppDatabase db, $FeedbackTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedbackTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedbackTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedbackTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
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
              }) => FeedbackTableCompanion(
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
          createCompanionCallback:
              ({
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
              }) => FeedbackTableCompanion.insert(
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
        ),
      );
}

typedef $$FeedbackTableTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<_$AppDatabase, $FeedbackTableTable, FeedbackEntry>,
      ),
      FeedbackEntry,
      PrefetchHooks Function()
    >;
typedef $$FoodsTableTableCreateCompanionBuilder =
    FoodsTableCompanion Function({
      required String id,
      Value<String?> name,
      Value<String?> imageAddress,
      Value<DateTime> createdAt,
      Value<double?> servingAmount,
      Value<int?> maxServingsBefore,
      Value<int?> maxServingsDuring,
      Value<int?> maxServingsAfter,
      Value<String?> categories,
      Value<String?> activityTypes,
      Value<int?> sodiumMg,
      Value<int?> caffeineMg,
      Value<int?> potassiumMg,
      Value<double?> fatPerServing,
      Value<double?> carbsPerServing,
      Value<double?> proteinPerServing,
      Value<int?> caloriesPerServing,
      Value<double?> fluidMlPerServing,
      Value<bool> showInPreferences,
      Value<bool> isElectrolyte,
      Value<bool> toExcludeFromSolver,
      Value<bool> isEssential,
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
      Value<String?> productTypeId,
      Value<String?> purchaseUrl,
      Value<String?> affiliateSource,
      Value<int?> preferencePriority,
      Value<int> rowid,
    });
typedef $$FoodsTableTableUpdateCompanionBuilder =
    FoodsTableCompanion Function({
      Value<String> id,
      Value<String?> name,
      Value<String?> imageAddress,
      Value<DateTime> createdAt,
      Value<double?> servingAmount,
      Value<int?> maxServingsBefore,
      Value<int?> maxServingsDuring,
      Value<int?> maxServingsAfter,
      Value<String?> categories,
      Value<String?> activityTypes,
      Value<int?> sodiumMg,
      Value<int?> caffeineMg,
      Value<int?> potassiumMg,
      Value<double?> fatPerServing,
      Value<double?> carbsPerServing,
      Value<double?> proteinPerServing,
      Value<int?> caloriesPerServing,
      Value<double?> fluidMlPerServing,
      Value<bool> showInPreferences,
      Value<bool> isElectrolyte,
      Value<bool> toExcludeFromSolver,
      Value<bool> isEssential,
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
      Value<String?> productTypeId,
      Value<String?> purchaseUrl,
      Value<String?> affiliateSource,
      Value<int?> preferencePriority,
      Value<int> rowid,
    });

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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingAmount => $composableBuilder(
    column: $table.servingAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxServingsBefore => $composableBuilder(
    column: $table.maxServingsBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxServingsDuring => $composableBuilder(
    column: $table.maxServingsDuring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxServingsAfter => $composableBuilder(
    column: $table.maxServingsAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityTypes => $composableBuilder(
    column: $table.activityTypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get caffeineMg => $composableBuilder(
    column: $table.caffeineMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get potassiumMg => $composableBuilder(
    column: $table.potassiumMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatPerServing => $composableBuilder(
    column: $table.fatPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinPerServing => $composableBuilder(
    column: $table.proteinPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get caloriesPerServing => $composableBuilder(
    column: $table.caloriesPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fluidMlPerServing => $composableBuilder(
    column: $table.fluidMlPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showInPreferences => $composableBuilder(
    column: $table.showInPreferences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isElectrolyte => $composableBuilder(
    column: $table.isElectrolyte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toExcludeFromSolver => $composableBuilder(
    column: $table.toExcludeFromSolver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEssential => $composableBuilder(
    column: $table.isEssential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingDescription => $composableBuilder(
    column: $table.servingDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nutritionalInfo => $composableBuilder(
    column: $table.nutritionalInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingUnitPlural => $composableBuilder(
    column: $table.servingUnitPlural,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingQualifier => $composableBuilder(
    column: $table.servingQualifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purchaseUrl => $composableBuilder(
    column: $table.purchaseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get affiliateSource => $composableBuilder(
    column: $table.affiliateSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preferencePriority => $composableBuilder(
    column: $table.preferencePriority,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingAmount => $composableBuilder(
    column: $table.servingAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxServingsBefore => $composableBuilder(
    column: $table.maxServingsBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxServingsDuring => $composableBuilder(
    column: $table.maxServingsDuring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxServingsAfter => $composableBuilder(
    column: $table.maxServingsAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityTypes => $composableBuilder(
    column: $table.activityTypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get caffeineMg => $composableBuilder(
    column: $table.caffeineMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get potassiumMg => $composableBuilder(
    column: $table.potassiumMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatPerServing => $composableBuilder(
    column: $table.fatPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinPerServing => $composableBuilder(
    column: $table.proteinPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get caloriesPerServing => $composableBuilder(
    column: $table.caloriesPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fluidMlPerServing => $composableBuilder(
    column: $table.fluidMlPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showInPreferences => $composableBuilder(
    column: $table.showInPreferences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isElectrolyte => $composableBuilder(
    column: $table.isElectrolyte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toExcludeFromSolver => $composableBuilder(
    column: $table.toExcludeFromSolver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEssential => $composableBuilder(
    column: $table.isEssential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingDescription => $composableBuilder(
    column: $table.servingDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nutritionalInfo => $composableBuilder(
    column: $table.nutritionalInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingUnitPlural => $composableBuilder(
    column: $table.servingUnitPlural,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingQualifier => $composableBuilder(
    column: $table.servingQualifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purchaseUrl => $composableBuilder(
    column: $table.purchaseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get affiliateSource => $composableBuilder(
    column: $table.affiliateSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preferencePriority => $composableBuilder(
    column: $table.preferencePriority,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.imageAddress,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<double> get servingAmount => $composableBuilder(
    column: $table.servingAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxServingsBefore => $composableBuilder(
    column: $table.maxServingsBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxServingsDuring => $composableBuilder(
    column: $table.maxServingsDuring,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxServingsAfter => $composableBuilder(
    column: $table.maxServingsAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityTypes => $composableBuilder(
    column: $table.activityTypes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);

  GeneratedColumn<int> get caffeineMg => $composableBuilder(
    column: $table.caffeineMg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get potassiumMg => $composableBuilder(
    column: $table.potassiumMg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatPerServing => $composableBuilder(
    column: $table.fatPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<double> get proteinPerServing => $composableBuilder(
    column: $table.proteinPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<int> get caloriesPerServing => $composableBuilder(
    column: $table.caloriesPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fluidMlPerServing => $composableBuilder(
    column: $table.fluidMlPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showInPreferences => $composableBuilder(
    column: $table.showInPreferences,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isElectrolyte => $composableBuilder(
    column: $table.isElectrolyte,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get toExcludeFromSolver => $composableBuilder(
    column: $table.toExcludeFromSolver,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEssential => $composableBuilder(
    column: $table.isEssential,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingDescription => $composableBuilder(
    column: $table.servingDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nutritionalInfo => $composableBuilder(
    column: $table.nutritionalInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingUnitPlural => $composableBuilder(
    column: $table.servingUnitPlural,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingQualifier => $composableBuilder(
    column: $table.servingQualifier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purchaseUrl => $composableBuilder(
    column: $table.purchaseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get affiliateSource => $composableBuilder(
    column: $table.affiliateSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get preferencePriority => $composableBuilder(
    column: $table.preferencePriority,
    builder: (column) => column,
  );
}

class $$FoodsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodsTableTable,
          FoodEntry,
          $$FoodsTableTableFilterComposer,
          $$FoodsTableTableOrderingComposer,
          $$FoodsTableTableAnnotationComposer,
          $$FoodsTableTableCreateCompanionBuilder,
          $$FoodsTableTableUpdateCompanionBuilder,
          (
            FoodEntry,
            BaseReferences<_$AppDatabase, $FoodsTableTable, FoodEntry>,
          ),
          FoodEntry,
          PrefetchHooks Function()
        > {
  $$FoodsTableTableTableManager(_$AppDatabase db, $FoodsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> imageAddress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double?> servingAmount = const Value.absent(),
                Value<int?> maxServingsBefore = const Value.absent(),
                Value<int?> maxServingsDuring = const Value.absent(),
                Value<int?> maxServingsAfter = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> activityTypes = const Value.absent(),
                Value<int?> sodiumMg = const Value.absent(),
                Value<int?> caffeineMg = const Value.absent(),
                Value<int?> potassiumMg = const Value.absent(),
                Value<double?> fatPerServing = const Value.absent(),
                Value<double?> carbsPerServing = const Value.absent(),
                Value<double?> proteinPerServing = const Value.absent(),
                Value<int?> caloriesPerServing = const Value.absent(),
                Value<double?> fluidMlPerServing = const Value.absent(),
                Value<bool> showInPreferences = const Value.absent(),
                Value<bool> isElectrolyte = const Value.absent(),
                Value<bool> toExcludeFromSolver = const Value.absent(),
                Value<bool> isEssential = const Value.absent(),
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
                Value<String?> productTypeId = const Value.absent(),
                Value<String?> purchaseUrl = const Value.absent(),
                Value<String?> affiliateSource = const Value.absent(),
                Value<int?> preferencePriority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodsTableCompanion(
                id: id,
                name: name,
                imageAddress: imageAddress,
                createdAt: createdAt,
                servingAmount: servingAmount,
                maxServingsBefore: maxServingsBefore,
                maxServingsDuring: maxServingsDuring,
                maxServingsAfter: maxServingsAfter,
                categories: categories,
                activityTypes: activityTypes,
                sodiumMg: sodiumMg,
                caffeineMg: caffeineMg,
                potassiumMg: potassiumMg,
                fatPerServing: fatPerServing,
                carbsPerServing: carbsPerServing,
                proteinPerServing: proteinPerServing,
                caloriesPerServing: caloriesPerServing,
                fluidMlPerServing: fluidMlPerServing,
                showInPreferences: showInPreferences,
                isElectrolyte: isElectrolyte,
                toExcludeFromSolver: toExcludeFromSolver,
                isEssential: isEssential,
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
                productTypeId: productTypeId,
                purchaseUrl: purchaseUrl,
                affiliateSource: affiliateSource,
                preferencePriority: preferencePriority,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                Value<String?> imageAddress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double?> servingAmount = const Value.absent(),
                Value<int?> maxServingsBefore = const Value.absent(),
                Value<int?> maxServingsDuring = const Value.absent(),
                Value<int?> maxServingsAfter = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> activityTypes = const Value.absent(),
                Value<int?> sodiumMg = const Value.absent(),
                Value<int?> caffeineMg = const Value.absent(),
                Value<int?> potassiumMg = const Value.absent(),
                Value<double?> fatPerServing = const Value.absent(),
                Value<double?> carbsPerServing = const Value.absent(),
                Value<double?> proteinPerServing = const Value.absent(),
                Value<int?> caloriesPerServing = const Value.absent(),
                Value<double?> fluidMlPerServing = const Value.absent(),
                Value<bool> showInPreferences = const Value.absent(),
                Value<bool> isElectrolyte = const Value.absent(),
                Value<bool> toExcludeFromSolver = const Value.absent(),
                Value<bool> isEssential = const Value.absent(),
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
                Value<String?> productTypeId = const Value.absent(),
                Value<String?> purchaseUrl = const Value.absent(),
                Value<String?> affiliateSource = const Value.absent(),
                Value<int?> preferencePriority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodsTableCompanion.insert(
                id: id,
                name: name,
                imageAddress: imageAddress,
                createdAt: createdAt,
                servingAmount: servingAmount,
                maxServingsBefore: maxServingsBefore,
                maxServingsDuring: maxServingsDuring,
                maxServingsAfter: maxServingsAfter,
                categories: categories,
                activityTypes: activityTypes,
                sodiumMg: sodiumMg,
                caffeineMg: caffeineMg,
                potassiumMg: potassiumMg,
                fatPerServing: fatPerServing,
                carbsPerServing: carbsPerServing,
                proteinPerServing: proteinPerServing,
                caloriesPerServing: caloriesPerServing,
                fluidMlPerServing: fluidMlPerServing,
                showInPreferences: showInPreferences,
                isElectrolyte: isElectrolyte,
                toExcludeFromSolver: toExcludeFromSolver,
                isEssential: isEssential,
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
                productTypeId: productTypeId,
                purchaseUrl: purchaseUrl,
                affiliateSource: affiliateSource,
                preferencePriority: preferencePriority,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoodsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodsTableTable,
      FoodEntry,
      $$FoodsTableTableFilterComposer,
      $$FoodsTableTableOrderingComposer,
      $$FoodsTableTableAnnotationComposer,
      $$FoodsTableTableCreateCompanionBuilder,
      $$FoodsTableTableUpdateCompanionBuilder,
      (FoodEntry, BaseReferences<_$AppDatabase, $FoodsTableTable, FoodEntry>),
      FoodEntry,
      PrefetchHooks Function()
    >;
typedef $$UserFoodsTableTableCreateCompanionBuilder =
    UserFoodsTableCompanion Function({
      required String id,
      required String deviceId,
      required String userId,
      Value<String?> clientFoodId,
      Value<String?> barcode,
      required String name,
      Value<String?> displayName,
      Value<String?> displayNamePlural,
      Value<String?> description,
      Value<String?> imageAddress,
      Value<double?> servingAmount,
      Value<String?> servingUnit,
      Value<int?> caloriesPerServing,
      Value<double?> carbsPerServing,
      Value<double?> proteinPerServing,
      Value<double?> fatPerServing,
      Value<int?> sodiumMg,
      Value<double?> fluidMlPerServing,
      Value<String?> productTypeId,
      Value<String?> categories,
      Value<String?> activityTypes,
      Value<bool> isElectrolyte,
      Value<bool> toExcludeFromSolver,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> clientUpdatedAt,
      Value<int> rowid,
    });
typedef $$UserFoodsTableTableUpdateCompanionBuilder =
    UserFoodsTableCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<String> userId,
      Value<String?> clientFoodId,
      Value<String?> barcode,
      Value<String> name,
      Value<String?> displayName,
      Value<String?> displayNamePlural,
      Value<String?> description,
      Value<String?> imageAddress,
      Value<double?> servingAmount,
      Value<String?> servingUnit,
      Value<int?> caloriesPerServing,
      Value<double?> carbsPerServing,
      Value<double?> proteinPerServing,
      Value<double?> fatPerServing,
      Value<int?> sodiumMg,
      Value<double?> fluidMlPerServing,
      Value<String?> productTypeId,
      Value<String?> categories,
      Value<String?> activityTypes,
      Value<bool> isElectrolyte,
      Value<bool> toExcludeFromSolver,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> clientUpdatedAt,
      Value<int> rowid,
    });

class $$UserFoodsTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserFoodsTableTable> {
  $$UserFoodsTableTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientFoodId => $composableBuilder(
    column: $table.clientFoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingAmount => $composableBuilder(
    column: $table.servingAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get caloriesPerServing => $composableBuilder(
    column: $table.caloriesPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinPerServing => $composableBuilder(
    column: $table.proteinPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatPerServing => $composableBuilder(
    column: $table.fatPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fluidMlPerServing => $composableBuilder(
    column: $table.fluidMlPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityTypes => $composableBuilder(
    column: $table.activityTypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isElectrolyte => $composableBuilder(
    column: $table.isElectrolyte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toExcludeFromSolver => $composableBuilder(
    column: $table.toExcludeFromSolver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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

  ColumnFilters<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserFoodsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserFoodsTableTable> {
  $$UserFoodsTableTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientFoodId => $composableBuilder(
    column: $table.clientFoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingAmount => $composableBuilder(
    column: $table.servingAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get caloriesPerServing => $composableBuilder(
    column: $table.caloriesPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinPerServing => $composableBuilder(
    column: $table.proteinPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatPerServing => $composableBuilder(
    column: $table.fatPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fluidMlPerServing => $composableBuilder(
    column: $table.fluidMlPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityTypes => $composableBuilder(
    column: $table.activityTypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isElectrolyte => $composableBuilder(
    column: $table.isElectrolyte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toExcludeFromSolver => $composableBuilder(
    column: $table.toExcludeFromSolver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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

  ColumnOrderings<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserFoodsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserFoodsTableTable> {
  $$UserFoodsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get clientFoodId => $composableBuilder(
    column: $table.clientFoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => column,
  );

  GeneratedColumn<double> get servingAmount => $composableBuilder(
    column: $table.servingAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get caloriesPerServing => $composableBuilder(
    column: $table.caloriesPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<double> get proteinPerServing => $composableBuilder(
    column: $table.proteinPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatPerServing => $composableBuilder(
    column: $table.fatPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);

  GeneratedColumn<double> get fluidMlPerServing => $composableBuilder(
    column: $table.fluidMlPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityTypes => $composableBuilder(
    column: $table.activityTypes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isElectrolyte => $composableBuilder(
    column: $table.isElectrolyte,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get toExcludeFromSolver => $composableBuilder(
    column: $table.toExcludeFromSolver,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );
}

class $$UserFoodsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserFoodsTableTable,
          UserFood,
          $$UserFoodsTableTableFilterComposer,
          $$UserFoodsTableTableOrderingComposer,
          $$UserFoodsTableTableAnnotationComposer,
          $$UserFoodsTableTableCreateCompanionBuilder,
          $$UserFoodsTableTableUpdateCompanionBuilder,
          (
            UserFood,
            BaseReferences<_$AppDatabase, $UserFoodsTableTable, UserFood>,
          ),
          UserFood,
          PrefetchHooks Function()
        > {
  $$UserFoodsTableTableTableManager(
    _$AppDatabase db,
    $UserFoodsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserFoodsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserFoodsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserFoodsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> clientFoodId = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> displayNamePlural = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> imageAddress = const Value.absent(),
                Value<double?> servingAmount = const Value.absent(),
                Value<String?> servingUnit = const Value.absent(),
                Value<int?> caloriesPerServing = const Value.absent(),
                Value<double?> carbsPerServing = const Value.absent(),
                Value<double?> proteinPerServing = const Value.absent(),
                Value<double?> fatPerServing = const Value.absent(),
                Value<int?> sodiumMg = const Value.absent(),
                Value<double?> fluidMlPerServing = const Value.absent(),
                Value<String?> productTypeId = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> activityTypes = const Value.absent(),
                Value<bool> isElectrolyte = const Value.absent(),
                Value<bool> toExcludeFromSolver = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> clientUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserFoodsTableCompanion(
                id: id,
                deviceId: deviceId,
                userId: userId,
                clientFoodId: clientFoodId,
                barcode: barcode,
                name: name,
                displayName: displayName,
                displayNamePlural: displayNamePlural,
                description: description,
                imageAddress: imageAddress,
                servingAmount: servingAmount,
                servingUnit: servingUnit,
                caloriesPerServing: caloriesPerServing,
                carbsPerServing: carbsPerServing,
                proteinPerServing: proteinPerServing,
                fatPerServing: fatPerServing,
                sodiumMg: sodiumMg,
                fluidMlPerServing: fluidMlPerServing,
                productTypeId: productTypeId,
                categories: categories,
                activityTypes: activityTypes,
                isElectrolyte: isElectrolyte,
                toExcludeFromSolver: toExcludeFromSolver,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                clientUpdatedAt: clientUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String userId,
                Value<String?> clientFoodId = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                required String name,
                Value<String?> displayName = const Value.absent(),
                Value<String?> displayNamePlural = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> imageAddress = const Value.absent(),
                Value<double?> servingAmount = const Value.absent(),
                Value<String?> servingUnit = const Value.absent(),
                Value<int?> caloriesPerServing = const Value.absent(),
                Value<double?> carbsPerServing = const Value.absent(),
                Value<double?> proteinPerServing = const Value.absent(),
                Value<double?> fatPerServing = const Value.absent(),
                Value<int?> sodiumMg = const Value.absent(),
                Value<double?> fluidMlPerServing = const Value.absent(),
                Value<String?> productTypeId = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> activityTypes = const Value.absent(),
                Value<bool> isElectrolyte = const Value.absent(),
                Value<bool> toExcludeFromSolver = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> clientUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserFoodsTableCompanion.insert(
                id: id,
                deviceId: deviceId,
                userId: userId,
                clientFoodId: clientFoodId,
                barcode: barcode,
                name: name,
                displayName: displayName,
                displayNamePlural: displayNamePlural,
                description: description,
                imageAddress: imageAddress,
                servingAmount: servingAmount,
                servingUnit: servingUnit,
                caloriesPerServing: caloriesPerServing,
                carbsPerServing: carbsPerServing,
                proteinPerServing: proteinPerServing,
                fatPerServing: fatPerServing,
                sodiumMg: sodiumMg,
                fluidMlPerServing: fluidMlPerServing,
                productTypeId: productTypeId,
                categories: categories,
                activityTypes: activityTypes,
                isElectrolyte: isElectrolyte,
                toExcludeFromSolver: toExcludeFromSolver,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                clientUpdatedAt: clientUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserFoodsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserFoodsTableTable,
      UserFood,
      $$UserFoodsTableTableFilterComposer,
      $$UserFoodsTableTableOrderingComposer,
      $$UserFoodsTableTableAnnotationComposer,
      $$UserFoodsTableTableCreateCompanionBuilder,
      $$UserFoodsTableTableUpdateCompanionBuilder,
      (UserFood, BaseReferences<_$AppDatabase, $UserFoodsTableTable, UserFood>),
      UserFood,
      PrefetchHooks Function()
    >;
typedef $$AppContentTableTableCreateCompanionBuilder =
    AppContentTableCompanion Function({
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
typedef $$AppContentTableTableUpdateCompanionBuilder =
    AppContentTableCompanion Function({
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCached => $composableBuilder(
    column: $table.isCached,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCached => $composableBuilder(
    column: $table.isCached,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.environment,
    builder: (column) => column,
  );

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
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCached =>
      $composableBuilder(column: $table.isCached, builder: (column) => column);
}

class $$AppContentTableTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<
              _$AppDatabase,
              $AppContentTableTable,
              AppContentEntry
            >,
          ),
          AppContentEntry,
          PrefetchHooks Function()
        > {
  $$AppContentTableTableTableManager(
    _$AppDatabase db,
    $AppContentTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppContentTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppContentTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppContentTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
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
              }) => AppContentTableCompanion(
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
          createCompanionCallback:
              ({
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
              }) => AppContentTableCompanion.insert(
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
        ),
      );
}

typedef $$AppContentTableTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<_$AppDatabase, $AppContentTableTable, AppContentEntry>,
      ),
      AppContentEntry,
      PrefetchHooks Function()
    >;
typedef $$EdgeFunctionsTableTableCreateCompanionBuilder =
    EdgeFunctionsTableCompanion Function({
      required String id,
      required String name,
      required String code,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$EdgeFunctionsTableTableUpdateCompanionBuilder =
    EdgeFunctionsTableCompanion Function({
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
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

class $$EdgeFunctionsTableTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<
              _$AppDatabase,
              $EdgeFunctionsTableTable,
              EdgeFunctionEntry
            >,
          ),
          EdgeFunctionEntry,
          PrefetchHooks Function()
        > {
  $$EdgeFunctionsTableTableTableManager(
    _$AppDatabase db,
    $EdgeFunctionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EdgeFunctionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EdgeFunctionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EdgeFunctionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EdgeFunctionsTableCompanion(
                id: id,
                name: name,
                code: code,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String code,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EdgeFunctionsTableCompanion.insert(
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
        ),
      );
}

typedef $$EdgeFunctionsTableTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<
          _$AppDatabase,
          $EdgeFunctionsTableTable,
          EdgeFunctionEntry
        >,
      ),
      EdgeFunctionEntry,
      PrefetchHooks Function()
    >;
typedef $$ActivitiesTableTableCreateCompanionBuilder =
    ActivitiesTableCompanion Function({
      Value<int> id,
      required String userId,
      required String activityType,
      required String title,
      required DateTime scheduledDateTime,
      Value<String> status,
      Value<double?> distanceMiles,
      Value<int?> durationMinutes,
      Value<double?> paceTargetMinutesPerMile,
      Value<String?> intensityLevel,
      Value<double?> cyclingSpeedMph,
      Value<String?> cyclingTerrain,
      Value<String?> cyclingIndoorOutdoor,
      Value<int?> cyclingElevationGainFt,
      Value<String?> cyclingSessionGoal,
      Value<int?> swimmingPacePer100mSeconds,
      Value<String?> swimmingPoolOrOpenWater,
      Value<double?> swimmingWaterTempC,
      Value<String?> intensityTarget,
      Value<int?> timeBeforeMinutes,
      Value<bool> reminderEnabled,
      Value<int?> reminderDaysBefore,
      Value<String?> reminderTimeOfDay,
      Value<bool> reminderRecurring,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
      Value<DateTime?> completedAt,
      Value<int?> completionRating,
      Value<String?> completionNotes,
      Value<double?> actualDistanceMiles,
      Value<int?> actualDurationMinutes,
      Value<String?> nutritionPlanData,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$ActivitiesTableTableUpdateCompanionBuilder =
    ActivitiesTableCompanion Function({
      Value<int> id,
      Value<String> userId,
      Value<String> activityType,
      Value<String> title,
      Value<DateTime> scheduledDateTime,
      Value<String> status,
      Value<double?> distanceMiles,
      Value<int?> durationMinutes,
      Value<double?> paceTargetMinutesPerMile,
      Value<String?> intensityLevel,
      Value<double?> cyclingSpeedMph,
      Value<String?> cyclingTerrain,
      Value<String?> cyclingIndoorOutdoor,
      Value<int?> cyclingElevationGainFt,
      Value<String?> cyclingSessionGoal,
      Value<int?> swimmingPacePer100mSeconds,
      Value<String?> swimmingPoolOrOpenWater,
      Value<double?> swimmingWaterTempC,
      Value<String?> intensityTarget,
      Value<int?> timeBeforeMinutes,
      Value<bool> reminderEnabled,
      Value<int?> reminderDaysBefore,
      Value<String?> reminderTimeOfDay,
      Value<bool> reminderRecurring,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
      Value<DateTime?> completedAt,
      Value<int?> completionRating,
      Value<String?> completionNotes,
      Value<double?> actualDistanceMiles,
      Value<int?> actualDurationMinutes,
      Value<String?> nutritionPlanData,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });

class $$ActivitiesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ActivitiesTableTable> {
  $$ActivitiesTableTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledDateTime => $composableBuilder(
    column: $table.scheduledDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMiles => $composableBuilder(
    column: $table.distanceMiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get paceTargetMinutesPerMile => $composableBuilder(
    column: $table.paceTargetMinutesPerMile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intensityLevel => $composableBuilder(
    column: $table.intensityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cyclingSpeedMph => $composableBuilder(
    column: $table.cyclingSpeedMph,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cyclingTerrain => $composableBuilder(
    column: $table.cyclingTerrain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cyclingIndoorOutdoor => $composableBuilder(
    column: $table.cyclingIndoorOutdoor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cyclingElevationGainFt => $composableBuilder(
    column: $table.cyclingElevationGainFt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cyclingSessionGoal => $composableBuilder(
    column: $table.cyclingSessionGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get swimmingPacePer100mSeconds => $composableBuilder(
    column: $table.swimmingPacePer100mSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swimmingPoolOrOpenWater => $composableBuilder(
    column: $table.swimmingPoolOrOpenWater,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get swimmingWaterTempC => $composableBuilder(
    column: $table.swimmingWaterTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intensityTarget => $composableBuilder(
    column: $table.intensityTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeBeforeMinutes => $composableBuilder(
    column: $table.timeBeforeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderDaysBefore => $composableBuilder(
    column: $table.reminderDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTimeOfDay => $composableBuilder(
    column: $table.reminderTimeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderRecurring => $composableBuilder(
    column: $table.reminderRecurring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionRating => $composableBuilder(
    column: $table.completionRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completionNotes => $composableBuilder(
    column: $table.completionNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get actualDistanceMiles => $composableBuilder(
    column: $table.actualDistanceMiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualDurationMinutes => $composableBuilder(
    column: $table.actualDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nutritionPlanData => $composableBuilder(
    column: $table.nutritionPlanData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitiesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivitiesTableTable> {
  $$ActivitiesTableTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledDateTime => $composableBuilder(
    column: $table.scheduledDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMiles => $composableBuilder(
    column: $table.distanceMiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get paceTargetMinutesPerMile => $composableBuilder(
    column: $table.paceTargetMinutesPerMile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intensityLevel => $composableBuilder(
    column: $table.intensityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cyclingSpeedMph => $composableBuilder(
    column: $table.cyclingSpeedMph,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cyclingTerrain => $composableBuilder(
    column: $table.cyclingTerrain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cyclingIndoorOutdoor => $composableBuilder(
    column: $table.cyclingIndoorOutdoor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cyclingElevationGainFt => $composableBuilder(
    column: $table.cyclingElevationGainFt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cyclingSessionGoal => $composableBuilder(
    column: $table.cyclingSessionGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get swimmingPacePer100mSeconds => $composableBuilder(
    column: $table.swimmingPacePer100mSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swimmingPoolOrOpenWater => $composableBuilder(
    column: $table.swimmingPoolOrOpenWater,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get swimmingWaterTempC => $composableBuilder(
    column: $table.swimmingWaterTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intensityTarget => $composableBuilder(
    column: $table.intensityTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeBeforeMinutes => $composableBuilder(
    column: $table.timeBeforeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderDaysBefore => $composableBuilder(
    column: $table.reminderDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTimeOfDay => $composableBuilder(
    column: $table.reminderTimeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderRecurring => $composableBuilder(
    column: $table.reminderRecurring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionRating => $composableBuilder(
    column: $table.completionRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completionNotes => $composableBuilder(
    column: $table.completionNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get actualDistanceMiles => $composableBuilder(
    column: $table.actualDistanceMiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualDurationMinutes => $composableBuilder(
    column: $table.actualDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nutritionPlanData => $composableBuilder(
    column: $table.nutritionPlanData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivitiesTableTable> {
  $$ActivitiesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledDateTime => $composableBuilder(
    column: $table.scheduledDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get distanceMiles => $composableBuilder(
    column: $table.distanceMiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get paceTargetMinutesPerMile => $composableBuilder(
    column: $table.paceTargetMinutesPerMile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intensityLevel => $composableBuilder(
    column: $table.intensityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cyclingSpeedMph => $composableBuilder(
    column: $table.cyclingSpeedMph,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cyclingTerrain => $composableBuilder(
    column: $table.cyclingTerrain,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cyclingIndoorOutdoor => $composableBuilder(
    column: $table.cyclingIndoorOutdoor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cyclingElevationGainFt => $composableBuilder(
    column: $table.cyclingElevationGainFt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cyclingSessionGoal => $composableBuilder(
    column: $table.cyclingSessionGoal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get swimmingPacePer100mSeconds => $composableBuilder(
    column: $table.swimmingPacePer100mSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get swimmingPoolOrOpenWater => $composableBuilder(
    column: $table.swimmingPoolOrOpenWater,
    builder: (column) => column,
  );

  GeneratedColumn<double> get swimmingWaterTempC => $composableBuilder(
    column: $table.swimmingWaterTempC,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intensityTarget => $composableBuilder(
    column: $table.intensityTarget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeBeforeMinutes => $composableBuilder(
    column: $table.timeBeforeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderDaysBefore => $composableBuilder(
    column: $table.reminderDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTimeOfDay => $composableBuilder(
    column: $table.reminderTimeOfDay,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderRecurring => $composableBuilder(
    column: $table.reminderRecurring,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionRating => $composableBuilder(
    column: $table.completionRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completionNotes => $composableBuilder(
    column: $table.completionNotes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get actualDistanceMiles => $composableBuilder(
    column: $table.actualDistanceMiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualDurationMinutes => $composableBuilder(
    column: $table.actualDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nutritionPlanData => $composableBuilder(
    column: $table.nutritionPlanData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ActivitiesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivitiesTableTable,
          Activity,
          $$ActivitiesTableTableFilterComposer,
          $$ActivitiesTableTableOrderingComposer,
          $$ActivitiesTableTableAnnotationComposer,
          $$ActivitiesTableTableCreateCompanionBuilder,
          $$ActivitiesTableTableUpdateCompanionBuilder,
          (
            Activity,
            BaseReferences<_$AppDatabase, $ActivitiesTableTable, Activity>,
          ),
          Activity,
          PrefetchHooks Function()
        > {
  $$ActivitiesTableTableTableManager(
    _$AppDatabase db,
    $ActivitiesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> activityType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> scheduledDateTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> distanceMiles = const Value.absent(),
                Value<int?> durationMinutes = const Value.absent(),
                Value<double?> paceTargetMinutesPerMile = const Value.absent(),
                Value<String?> intensityLevel = const Value.absent(),
                Value<double?> cyclingSpeedMph = const Value.absent(),
                Value<String?> cyclingTerrain = const Value.absent(),
                Value<String?> cyclingIndoorOutdoor = const Value.absent(),
                Value<int?> cyclingElevationGainFt = const Value.absent(),
                Value<String?> cyclingSessionGoal = const Value.absent(),
                Value<int?> swimmingPacePer100mSeconds = const Value.absent(),
                Value<String?> swimmingPoolOrOpenWater = const Value.absent(),
                Value<double?> swimmingWaterTempC = const Value.absent(),
                Value<String?> intensityTarget = const Value.absent(),
                Value<int?> timeBeforeMinutes = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int?> reminderDaysBefore = const Value.absent(),
                Value<String?> reminderTimeOfDay = const Value.absent(),
                Value<bool> reminderRecurring = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int?> completionRating = const Value.absent(),
                Value<String?> completionNotes = const Value.absent(),
                Value<double?> actualDistanceMiles = const Value.absent(),
                Value<int?> actualDurationMinutes = const Value.absent(),
                Value<String?> nutritionPlanData = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => ActivitiesTableCompanion(
                id: id,
                userId: userId,
                activityType: activityType,
                title: title,
                scheduledDateTime: scheduledDateTime,
                status: status,
                distanceMiles: distanceMiles,
                durationMinutes: durationMinutes,
                paceTargetMinutesPerMile: paceTargetMinutesPerMile,
                intensityLevel: intensityLevel,
                cyclingSpeedMph: cyclingSpeedMph,
                cyclingTerrain: cyclingTerrain,
                cyclingIndoorOutdoor: cyclingIndoorOutdoor,
                cyclingElevationGainFt: cyclingElevationGainFt,
                cyclingSessionGoal: cyclingSessionGoal,
                swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
                swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
                swimmingWaterTempC: swimmingWaterTempC,
                intensityTarget: intensityTarget,
                timeBeforeMinutes: timeBeforeMinutes,
                reminderEnabled: reminderEnabled,
                reminderDaysBefore: reminderDaysBefore,
                reminderTimeOfDay: reminderTimeOfDay,
                reminderRecurring: reminderRecurring,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
                completedAt: completedAt,
                completionRating: completionRating,
                completionNotes: completionNotes,
                actualDistanceMiles: actualDistanceMiles,
                actualDurationMinutes: actualDurationMinutes,
                nutritionPlanData: nutritionPlanData,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String userId,
                required String activityType,
                required String title,
                required DateTime scheduledDateTime,
                Value<String> status = const Value.absent(),
                Value<double?> distanceMiles = const Value.absent(),
                Value<int?> durationMinutes = const Value.absent(),
                Value<double?> paceTargetMinutesPerMile = const Value.absent(),
                Value<String?> intensityLevel = const Value.absent(),
                Value<double?> cyclingSpeedMph = const Value.absent(),
                Value<String?> cyclingTerrain = const Value.absent(),
                Value<String?> cyclingIndoorOutdoor = const Value.absent(),
                Value<int?> cyclingElevationGainFt = const Value.absent(),
                Value<String?> cyclingSessionGoal = const Value.absent(),
                Value<int?> swimmingPacePer100mSeconds = const Value.absent(),
                Value<String?> swimmingPoolOrOpenWater = const Value.absent(),
                Value<double?> swimmingWaterTempC = const Value.absent(),
                Value<String?> intensityTarget = const Value.absent(),
                Value<int?> timeBeforeMinutes = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int?> reminderDaysBefore = const Value.absent(),
                Value<String?> reminderTimeOfDay = const Value.absent(),
                Value<bool> reminderRecurring = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int?> completionRating = const Value.absent(),
                Value<String?> completionNotes = const Value.absent(),
                Value<double?> actualDistanceMiles = const Value.absent(),
                Value<int?> actualDurationMinutes = const Value.absent(),
                Value<String?> nutritionPlanData = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => ActivitiesTableCompanion.insert(
                id: id,
                userId: userId,
                activityType: activityType,
                title: title,
                scheduledDateTime: scheduledDateTime,
                status: status,
                distanceMiles: distanceMiles,
                durationMinutes: durationMinutes,
                paceTargetMinutesPerMile: paceTargetMinutesPerMile,
                intensityLevel: intensityLevel,
                cyclingSpeedMph: cyclingSpeedMph,
                cyclingTerrain: cyclingTerrain,
                cyclingIndoorOutdoor: cyclingIndoorOutdoor,
                cyclingElevationGainFt: cyclingElevationGainFt,
                cyclingSessionGoal: cyclingSessionGoal,
                swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
                swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
                swimmingWaterTempC: swimmingWaterTempC,
                intensityTarget: intensityTarget,
                timeBeforeMinutes: timeBeforeMinutes,
                reminderEnabled: reminderEnabled,
                reminderDaysBefore: reminderDaysBefore,
                reminderTimeOfDay: reminderTimeOfDay,
                reminderRecurring: reminderRecurring,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
                completedAt: completedAt,
                completionRating: completionRating,
                completionNotes: completionNotes,
                actualDistanceMiles: actualDistanceMiles,
                actualDurationMinutes: actualDurationMinutes,
                nutritionPlanData: nutritionPlanData,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitiesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivitiesTableTable,
      Activity,
      $$ActivitiesTableTableFilterComposer,
      $$ActivitiesTableTableOrderingComposer,
      $$ActivitiesTableTableAnnotationComposer,
      $$ActivitiesTableTableCreateCompanionBuilder,
      $$ActivitiesTableTableUpdateCompanionBuilder,
      (
        Activity,
        BaseReferences<_$AppDatabase, $ActivitiesTableTable, Activity>,
      ),
      Activity,
      PrefetchHooks Function()
    >;
typedef $$EventsTableTableCreateCompanionBuilder =
    EventsTableCompanion Function({
      Value<int> id,
      Value<int?> activityId,
      required String userId,
      required String eventType,
      Value<String?> eventSubtype,
      Value<String?> eventName,
      Value<String?> location,
      Value<String?> registrationUrl,
      Value<DateTime?> eventDate,
      Value<String?> startTime,
      Value<int?> goalTimeMinutes,
      Value<double?> goalPaceMinutesPerMile,
      Value<int?> predictedFinishTimeMinutes,
      Value<bool> hasCarbLoading,
      Value<int?> carbLoadingDays,
      Value<DateTime?> carbLoadingStartDate,
      Value<bool> hasNutritionPlan,
      Value<String?> bibNumber,
      Value<String?> waveStartTime,
      Value<String?> packetPickupInfo,
      Value<int?> actualFinishTimeMinutes,
      Value<int?> finalPlacement,
      Value<int?> ageGroupPlacement,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
    });
typedef $$EventsTableTableUpdateCompanionBuilder =
    EventsTableCompanion Function({
      Value<int> id,
      Value<int?> activityId,
      Value<String> userId,
      Value<String> eventType,
      Value<String?> eventSubtype,
      Value<String?> eventName,
      Value<String?> location,
      Value<String?> registrationUrl,
      Value<DateTime?> eventDate,
      Value<String?> startTime,
      Value<int?> goalTimeMinutes,
      Value<double?> goalPaceMinutesPerMile,
      Value<int?> predictedFinishTimeMinutes,
      Value<bool> hasCarbLoading,
      Value<int?> carbLoadingDays,
      Value<DateTime?> carbLoadingStartDate,
      Value<bool> hasNutritionPlan,
      Value<String?> bibNumber,
      Value<String?> waveStartTime,
      Value<String?> packetPickupInfo,
      Value<int?> actualFinishTimeMinutes,
      Value<int?> finalPlacement,
      Value<int?> ageGroupPlacement,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
    });

class $$EventsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTableTable> {
  $$EventsTableTableFilterComposer({
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

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventSubtype => $composableBuilder(
    column: $table.eventSubtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrationUrl => $composableBuilder(
    column: $table.registrationUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalTimeMinutes => $composableBuilder(
    column: $table.goalTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goalPaceMinutesPerMile => $composableBuilder(
    column: $table.goalPaceMinutesPerMile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get predictedFinishTimeMinutes => $composableBuilder(
    column: $table.predictedFinishTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasCarbLoading => $composableBuilder(
    column: $table.hasCarbLoading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbLoadingDays => $composableBuilder(
    column: $table.carbLoadingDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get carbLoadingStartDate => $composableBuilder(
    column: $table.carbLoadingStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasNutritionPlan => $composableBuilder(
    column: $table.hasNutritionPlan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bibNumber => $composableBuilder(
    column: $table.bibNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waveStartTime => $composableBuilder(
    column: $table.waveStartTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packetPickupInfo => $composableBuilder(
    column: $table.packetPickupInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualFinishTimeMinutes => $composableBuilder(
    column: $table.actualFinishTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalPlacement => $composableBuilder(
    column: $table.finalPlacement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageGroupPlacement => $composableBuilder(
    column: $table.ageGroupPlacement,
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

  ColumnFilters<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTableTable> {
  $$EventsTableTableOrderingComposer({
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

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventSubtype => $composableBuilder(
    column: $table.eventSubtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrationUrl => $composableBuilder(
    column: $table.registrationUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalTimeMinutes => $composableBuilder(
    column: $table.goalTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goalPaceMinutesPerMile => $composableBuilder(
    column: $table.goalPaceMinutesPerMile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get predictedFinishTimeMinutes => $composableBuilder(
    column: $table.predictedFinishTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasCarbLoading => $composableBuilder(
    column: $table.hasCarbLoading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbLoadingDays => $composableBuilder(
    column: $table.carbLoadingDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get carbLoadingStartDate => $composableBuilder(
    column: $table.carbLoadingStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasNutritionPlan => $composableBuilder(
    column: $table.hasNutritionPlan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bibNumber => $composableBuilder(
    column: $table.bibNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waveStartTime => $composableBuilder(
    column: $table.waveStartTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packetPickupInfo => $composableBuilder(
    column: $table.packetPickupInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualFinishTimeMinutes => $composableBuilder(
    column: $table.actualFinishTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalPlacement => $composableBuilder(
    column: $table.finalPlacement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageGroupPlacement => $composableBuilder(
    column: $table.ageGroupPlacement,
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

  ColumnOrderings<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTableTable> {
  $$EventsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get eventSubtype => $composableBuilder(
    column: $table.eventSubtype,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventName =>
      $composableBuilder(column: $table.eventName, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get registrationUrl => $composableBuilder(
    column: $table.registrationUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<int> get goalTimeMinutes => $composableBuilder(
    column: $table.goalTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get goalPaceMinutesPerMile => $composableBuilder(
    column: $table.goalPaceMinutesPerMile,
    builder: (column) => column,
  );

  GeneratedColumn<int> get predictedFinishTimeMinutes => $composableBuilder(
    column: $table.predictedFinishTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasCarbLoading => $composableBuilder(
    column: $table.hasCarbLoading,
    builder: (column) => column,
  );

  GeneratedColumn<int> get carbLoadingDays => $composableBuilder(
    column: $table.carbLoadingDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get carbLoadingStartDate => $composableBuilder(
    column: $table.carbLoadingStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasNutritionPlan => $composableBuilder(
    column: $table.hasNutritionPlan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bibNumber =>
      $composableBuilder(column: $table.bibNumber, builder: (column) => column);

  GeneratedColumn<String> get waveStartTime => $composableBuilder(
    column: $table.waveStartTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packetPickupInfo => $composableBuilder(
    column: $table.packetPickupInfo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualFinishTimeMinutes => $composableBuilder(
    column: $table.actualFinishTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get finalPlacement => $composableBuilder(
    column: $table.finalPlacement,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ageGroupPlacement => $composableBuilder(
    column: $table.ageGroupPlacement,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );
}

class $$EventsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTableTable,
          Event,
          $$EventsTableTableFilterComposer,
          $$EventsTableTableOrderingComposer,
          $$EventsTableTableAnnotationComposer,
          $$EventsTableTableCreateCompanionBuilder,
          $$EventsTableTableUpdateCompanionBuilder,
          (Event, BaseReferences<_$AppDatabase, $EventsTableTable, Event>),
          Event,
          PrefetchHooks Function()
        > {
  $$EventsTableTableTableManager(_$AppDatabase db, $EventsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> activityId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> eventSubtype = const Value.absent(),
                Value<String?> eventName = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> registrationUrl = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<int?> goalTimeMinutes = const Value.absent(),
                Value<double?> goalPaceMinutesPerMile = const Value.absent(),
                Value<int?> predictedFinishTimeMinutes = const Value.absent(),
                Value<bool> hasCarbLoading = const Value.absent(),
                Value<int?> carbLoadingDays = const Value.absent(),
                Value<DateTime?> carbLoadingStartDate = const Value.absent(),
                Value<bool> hasNutritionPlan = const Value.absent(),
                Value<String?> bibNumber = const Value.absent(),
                Value<String?> waveStartTime = const Value.absent(),
                Value<String?> packetPickupInfo = const Value.absent(),
                Value<int?> actualFinishTimeMinutes = const Value.absent(),
                Value<int?> finalPlacement = const Value.absent(),
                Value<int?> ageGroupPlacement = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
              }) => EventsTableCompanion(
                id: id,
                activityId: activityId,
                userId: userId,
                eventType: eventType,
                eventSubtype: eventSubtype,
                eventName: eventName,
                location: location,
                registrationUrl: registrationUrl,
                eventDate: eventDate,
                startTime: startTime,
                goalTimeMinutes: goalTimeMinutes,
                goalPaceMinutesPerMile: goalPaceMinutesPerMile,
                predictedFinishTimeMinutes: predictedFinishTimeMinutes,
                hasCarbLoading: hasCarbLoading,
                carbLoadingDays: carbLoadingDays,
                carbLoadingStartDate: carbLoadingStartDate,
                hasNutritionPlan: hasNutritionPlan,
                bibNumber: bibNumber,
                waveStartTime: waveStartTime,
                packetPickupInfo: packetPickupInfo,
                actualFinishTimeMinutes: actualFinishTimeMinutes,
                finalPlacement: finalPlacement,
                ageGroupPlacement: ageGroupPlacement,
                createdAt: createdAt,
                updatedAt: updatedAt,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> activityId = const Value.absent(),
                required String userId,
                required String eventType,
                Value<String?> eventSubtype = const Value.absent(),
                Value<String?> eventName = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> registrationUrl = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<int?> goalTimeMinutes = const Value.absent(),
                Value<double?> goalPaceMinutesPerMile = const Value.absent(),
                Value<int?> predictedFinishTimeMinutes = const Value.absent(),
                Value<bool> hasCarbLoading = const Value.absent(),
                Value<int?> carbLoadingDays = const Value.absent(),
                Value<DateTime?> carbLoadingStartDate = const Value.absent(),
                Value<bool> hasNutritionPlan = const Value.absent(),
                Value<String?> bibNumber = const Value.absent(),
                Value<String?> waveStartTime = const Value.absent(),
                Value<String?> packetPickupInfo = const Value.absent(),
                Value<int?> actualFinishTimeMinutes = const Value.absent(),
                Value<int?> finalPlacement = const Value.absent(),
                Value<int?> ageGroupPlacement = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
              }) => EventsTableCompanion.insert(
                id: id,
                activityId: activityId,
                userId: userId,
                eventType: eventType,
                eventSubtype: eventSubtype,
                eventName: eventName,
                location: location,
                registrationUrl: registrationUrl,
                eventDate: eventDate,
                startTime: startTime,
                goalTimeMinutes: goalTimeMinutes,
                goalPaceMinutesPerMile: goalPaceMinutesPerMile,
                predictedFinishTimeMinutes: predictedFinishTimeMinutes,
                hasCarbLoading: hasCarbLoading,
                carbLoadingDays: carbLoadingDays,
                carbLoadingStartDate: carbLoadingStartDate,
                hasNutritionPlan: hasNutritionPlan,
                bibNumber: bibNumber,
                waveStartTime: waveStartTime,
                packetPickupInfo: packetPickupInfo,
                actualFinishTimeMinutes: actualFinishTimeMinutes,
                finalPlacement: finalPlacement,
                ageGroupPlacement: ageGroupPlacement,
                createdAt: createdAt,
                updatedAt: updatedAt,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTableTable,
      Event,
      $$EventsTableTableFilterComposer,
      $$EventsTableTableOrderingComposer,
      $$EventsTableTableAnnotationComposer,
      $$EventsTableTableCreateCompanionBuilder,
      $$EventsTableTableUpdateCompanionBuilder,
      (Event, BaseReferences<_$AppDatabase, $EventsTableTable, Event>),
      Event,
      PrefetchHooks Function()
    >;
typedef $$CarbLoadingPlansTableTableCreateCompanionBuilder =
    CarbLoadingPlansTableCompanion Function({
      Value<int> id,
      Value<int?> eventId,
      required String userId,
      required int totalDays,
      required DateTime startDate,
      required DateTime endDate,
      required int dailyCarbTargetGrams,
      Value<int?> dailyCalorieTarget,
      required DateTime generatedAt,
      Value<String> algorithmVersion,
      Value<double?> adherenceScore,
      Value<DateTime?> completedAt,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
    });
typedef $$CarbLoadingPlansTableTableUpdateCompanionBuilder =
    CarbLoadingPlansTableCompanion Function({
      Value<int> id,
      Value<int?> eventId,
      Value<String> userId,
      Value<int> totalDays,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<int> dailyCarbTargetGrams,
      Value<int?> dailyCalorieTarget,
      Value<DateTime> generatedAt,
      Value<String> algorithmVersion,
      Value<double?> adherenceScore,
      Value<DateTime?> completedAt,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
    });

class $$CarbLoadingPlansTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingPlansTableTable> {
  $$CarbLoadingPlansTableTableFilterComposer({
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

  ColumnFilters<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDays => $composableBuilder(
    column: $table.totalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyCarbTargetGrams => $composableBuilder(
    column: $table.dailyCarbTargetGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyCalorieTarget => $composableBuilder(
    column: $table.dailyCalorieTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get adherenceScore => $composableBuilder(
    column: $table.adherenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CarbLoadingPlansTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingPlansTableTable> {
  $$CarbLoadingPlansTableTableOrderingComposer({
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

  ColumnOrderings<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDays => $composableBuilder(
    column: $table.totalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyCarbTargetGrams => $composableBuilder(
    column: $table.dailyCarbTargetGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyCalorieTarget => $composableBuilder(
    column: $table.dailyCalorieTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get adherenceScore => $composableBuilder(
    column: $table.adherenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CarbLoadingPlansTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingPlansTableTable> {
  $$CarbLoadingPlansTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get totalDays =>
      $composableBuilder(column: $table.totalDays, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get dailyCarbTargetGrams => $composableBuilder(
    column: $table.dailyCarbTargetGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyCalorieTarget => $composableBuilder(
    column: $table.dailyCalorieTarget,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get adherenceScore => $composableBuilder(
    column: $table.adherenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );
}

class $$CarbLoadingPlansTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarbLoadingPlansTableTable,
          CarbLoadingPlan,
          $$CarbLoadingPlansTableTableFilterComposer,
          $$CarbLoadingPlansTableTableOrderingComposer,
          $$CarbLoadingPlansTableTableAnnotationComposer,
          $$CarbLoadingPlansTableTableCreateCompanionBuilder,
          $$CarbLoadingPlansTableTableUpdateCompanionBuilder,
          (
            CarbLoadingPlan,
            BaseReferences<
              _$AppDatabase,
              $CarbLoadingPlansTableTable,
              CarbLoadingPlan
            >,
          ),
          CarbLoadingPlan,
          PrefetchHooks Function()
        > {
  $$CarbLoadingPlansTableTableTableManager(
    _$AppDatabase db,
    $CarbLoadingPlansTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingPlansTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CarbLoadingPlansTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CarbLoadingPlansTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> totalDays = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<int> dailyCarbTargetGrams = const Value.absent(),
                Value<int?> dailyCalorieTarget = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<String> algorithmVersion = const Value.absent(),
                Value<double?> adherenceScore = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
              }) => CarbLoadingPlansTableCompanion(
                id: id,
                eventId: eventId,
                userId: userId,
                totalDays: totalDays,
                startDate: startDate,
                endDate: endDate,
                dailyCarbTargetGrams: dailyCarbTargetGrams,
                dailyCalorieTarget: dailyCalorieTarget,
                generatedAt: generatedAt,
                algorithmVersion: algorithmVersion,
                adherenceScore: adherenceScore,
                completedAt: completedAt,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
                required String userId,
                required int totalDays,
                required DateTime startDate,
                required DateTime endDate,
                required int dailyCarbTargetGrams,
                Value<int?> dailyCalorieTarget = const Value.absent(),
                required DateTime generatedAt,
                Value<String> algorithmVersion = const Value.absent(),
                Value<double?> adherenceScore = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
              }) => CarbLoadingPlansTableCompanion.insert(
                id: id,
                eventId: eventId,
                userId: userId,
                totalDays: totalDays,
                startDate: startDate,
                endDate: endDate,
                dailyCarbTargetGrams: dailyCarbTargetGrams,
                dailyCalorieTarget: dailyCalorieTarget,
                generatedAt: generatedAt,
                algorithmVersion: algorithmVersion,
                adherenceScore: adherenceScore,
                completedAt: completedAt,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarbLoadingPlansTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarbLoadingPlansTableTable,
      CarbLoadingPlan,
      $$CarbLoadingPlansTableTableFilterComposer,
      $$CarbLoadingPlansTableTableOrderingComposer,
      $$CarbLoadingPlansTableTableAnnotationComposer,
      $$CarbLoadingPlansTableTableCreateCompanionBuilder,
      $$CarbLoadingPlansTableTableUpdateCompanionBuilder,
      (
        CarbLoadingPlan,
        BaseReferences<
          _$AppDatabase,
          $CarbLoadingPlansTableTable,
          CarbLoadingPlan
        >,
      ),
      CarbLoadingPlan,
      PrefetchHooks Function()
    >;
typedef $$CarbLoadingDaysTableTableCreateCompanionBuilder =
    CarbLoadingDaysTableCompanion Function({
      Value<int> id,
      required int carbLoadingPlanId,
      required DateTime planDate,
      required int dayNumber,
      required int carbTargetGrams,
      required double carbProtocolGPerKg,
      Value<int?> calorieTarget,
      Value<int> mealCount,
      Value<double> breakfastPercent,
      Value<double> morningSnackPercent,
      Value<double> lunchPercent,
      Value<double> afternoonSnackPercent,
      Value<double> dinnerPercent,
      Value<double> eveningSnackPercent,
      Value<int> loggedCarbsGrams,
      Value<int> loggedCalories,
      Value<bool> completed,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
    });
typedef $$CarbLoadingDaysTableTableUpdateCompanionBuilder =
    CarbLoadingDaysTableCompanion Function({
      Value<int> id,
      Value<int> carbLoadingPlanId,
      Value<DateTime> planDate,
      Value<int> dayNumber,
      Value<int> carbTargetGrams,
      Value<double> carbProtocolGPerKg,
      Value<int?> calorieTarget,
      Value<int> mealCount,
      Value<double> breakfastPercent,
      Value<double> morningSnackPercent,
      Value<double> lunchPercent,
      Value<double> afternoonSnackPercent,
      Value<double> dinnerPercent,
      Value<double> eveningSnackPercent,
      Value<int> loggedCarbsGrams,
      Value<int> loggedCalories,
      Value<bool> completed,
      Value<bool?> needsUpload,
      Value<DateTime?> localUpdatedAt,
    });

class $$CarbLoadingDaysTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingDaysTableTable> {
  $$CarbLoadingDaysTableTableFilterComposer({
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

  ColumnFilters<int> get carbLoadingPlanId => $composableBuilder(
    column: $table.carbLoadingPlanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get planDate => $composableBuilder(
    column: $table.planDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayNumber => $composableBuilder(
    column: $table.dayNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbTargetGrams => $composableBuilder(
    column: $table.carbTargetGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbProtocolGPerKg => $composableBuilder(
    column: $table.carbProtocolGPerKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calorieTarget => $composableBuilder(
    column: $table.calorieTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mealCount => $composableBuilder(
    column: $table.mealCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get breakfastPercent => $composableBuilder(
    column: $table.breakfastPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get morningSnackPercent => $composableBuilder(
    column: $table.morningSnackPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lunchPercent => $composableBuilder(
    column: $table.lunchPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get afternoonSnackPercent => $composableBuilder(
    column: $table.afternoonSnackPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dinnerPercent => $composableBuilder(
    column: $table.dinnerPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get eveningSnackPercent => $composableBuilder(
    column: $table.eveningSnackPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loggedCarbsGrams => $composableBuilder(
    column: $table.loggedCarbsGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loggedCalories => $composableBuilder(
    column: $table.loggedCalories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CarbLoadingDaysTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingDaysTableTable> {
  $$CarbLoadingDaysTableTableOrderingComposer({
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

  ColumnOrderings<int> get carbLoadingPlanId => $composableBuilder(
    column: $table.carbLoadingPlanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get planDate => $composableBuilder(
    column: $table.planDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayNumber => $composableBuilder(
    column: $table.dayNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbTargetGrams => $composableBuilder(
    column: $table.carbTargetGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbProtocolGPerKg => $composableBuilder(
    column: $table.carbProtocolGPerKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calorieTarget => $composableBuilder(
    column: $table.calorieTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mealCount => $composableBuilder(
    column: $table.mealCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get breakfastPercent => $composableBuilder(
    column: $table.breakfastPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get morningSnackPercent => $composableBuilder(
    column: $table.morningSnackPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lunchPercent => $composableBuilder(
    column: $table.lunchPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get afternoonSnackPercent => $composableBuilder(
    column: $table.afternoonSnackPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dinnerPercent => $composableBuilder(
    column: $table.dinnerPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get eveningSnackPercent => $composableBuilder(
    column: $table.eveningSnackPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loggedCarbsGrams => $composableBuilder(
    column: $table.loggedCarbsGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loggedCalories => $composableBuilder(
    column: $table.loggedCalories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CarbLoadingDaysTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingDaysTableTable> {
  $$CarbLoadingDaysTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get carbLoadingPlanId => $composableBuilder(
    column: $table.carbLoadingPlanId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get planDate =>
      $composableBuilder(column: $table.planDate, builder: (column) => column);

  GeneratedColumn<int> get dayNumber =>
      $composableBuilder(column: $table.dayNumber, builder: (column) => column);

  GeneratedColumn<int> get carbTargetGrams => $composableBuilder(
    column: $table.carbTargetGrams,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbProtocolGPerKg => $composableBuilder(
    column: $table.carbProtocolGPerKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calorieTarget => $composableBuilder(
    column: $table.calorieTarget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mealCount =>
      $composableBuilder(column: $table.mealCount, builder: (column) => column);

  GeneratedColumn<double> get breakfastPercent => $composableBuilder(
    column: $table.breakfastPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get morningSnackPercent => $composableBuilder(
    column: $table.morningSnackPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lunchPercent => $composableBuilder(
    column: $table.lunchPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get afternoonSnackPercent => $composableBuilder(
    column: $table.afternoonSnackPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dinnerPercent => $composableBuilder(
    column: $table.dinnerPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get eveningSnackPercent => $composableBuilder(
    column: $table.eveningSnackPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loggedCarbsGrams => $composableBuilder(
    column: $table.loggedCarbsGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loggedCalories => $composableBuilder(
    column: $table.loggedCalories,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<bool> get needsUpload => $composableBuilder(
    column: $table.needsUpload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );
}

class $$CarbLoadingDaysTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarbLoadingDaysTableTable,
          CarbLoadingDay,
          $$CarbLoadingDaysTableTableFilterComposer,
          $$CarbLoadingDaysTableTableOrderingComposer,
          $$CarbLoadingDaysTableTableAnnotationComposer,
          $$CarbLoadingDaysTableTableCreateCompanionBuilder,
          $$CarbLoadingDaysTableTableUpdateCompanionBuilder,
          (
            CarbLoadingDay,
            BaseReferences<
              _$AppDatabase,
              $CarbLoadingDaysTableTable,
              CarbLoadingDay
            >,
          ),
          CarbLoadingDay,
          PrefetchHooks Function()
        > {
  $$CarbLoadingDaysTableTableTableManager(
    _$AppDatabase db,
    $CarbLoadingDaysTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingDaysTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarbLoadingDaysTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CarbLoadingDaysTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> carbLoadingPlanId = const Value.absent(),
                Value<DateTime> planDate = const Value.absent(),
                Value<int> dayNumber = const Value.absent(),
                Value<int> carbTargetGrams = const Value.absent(),
                Value<double> carbProtocolGPerKg = const Value.absent(),
                Value<int?> calorieTarget = const Value.absent(),
                Value<int> mealCount = const Value.absent(),
                Value<double> breakfastPercent = const Value.absent(),
                Value<double> morningSnackPercent = const Value.absent(),
                Value<double> lunchPercent = const Value.absent(),
                Value<double> afternoonSnackPercent = const Value.absent(),
                Value<double> dinnerPercent = const Value.absent(),
                Value<double> eveningSnackPercent = const Value.absent(),
                Value<int> loggedCarbsGrams = const Value.absent(),
                Value<int> loggedCalories = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
              }) => CarbLoadingDaysTableCompanion(
                id: id,
                carbLoadingPlanId: carbLoadingPlanId,
                planDate: planDate,
                dayNumber: dayNumber,
                carbTargetGrams: carbTargetGrams,
                carbProtocolGPerKg: carbProtocolGPerKg,
                calorieTarget: calorieTarget,
                mealCount: mealCount,
                breakfastPercent: breakfastPercent,
                morningSnackPercent: morningSnackPercent,
                lunchPercent: lunchPercent,
                afternoonSnackPercent: afternoonSnackPercent,
                dinnerPercent: dinnerPercent,
                eveningSnackPercent: eveningSnackPercent,
                loggedCarbsGrams: loggedCarbsGrams,
                loggedCalories: loggedCalories,
                completed: completed,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int carbLoadingPlanId,
                required DateTime planDate,
                required int dayNumber,
                required int carbTargetGrams,
                required double carbProtocolGPerKg,
                Value<int?> calorieTarget = const Value.absent(),
                Value<int> mealCount = const Value.absent(),
                Value<double> breakfastPercent = const Value.absent(),
                Value<double> morningSnackPercent = const Value.absent(),
                Value<double> lunchPercent = const Value.absent(),
                Value<double> afternoonSnackPercent = const Value.absent(),
                Value<double> dinnerPercent = const Value.absent(),
                Value<double> eveningSnackPercent = const Value.absent(),
                Value<int> loggedCarbsGrams = const Value.absent(),
                Value<int> loggedCalories = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool?> needsUpload = const Value.absent(),
                Value<DateTime?> localUpdatedAt = const Value.absent(),
              }) => CarbLoadingDaysTableCompanion.insert(
                id: id,
                carbLoadingPlanId: carbLoadingPlanId,
                planDate: planDate,
                dayNumber: dayNumber,
                carbTargetGrams: carbTargetGrams,
                carbProtocolGPerKg: carbProtocolGPerKg,
                calorieTarget: calorieTarget,
                mealCount: mealCount,
                breakfastPercent: breakfastPercent,
                morningSnackPercent: morningSnackPercent,
                lunchPercent: lunchPercent,
                afternoonSnackPercent: afternoonSnackPercent,
                dinnerPercent: dinnerPercent,
                eveningSnackPercent: eveningSnackPercent,
                loggedCarbsGrams: loggedCarbsGrams,
                loggedCalories: loggedCalories,
                completed: completed,
                needsUpload: needsUpload,
                localUpdatedAt: localUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarbLoadingDaysTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarbLoadingDaysTableTable,
      CarbLoadingDay,
      $$CarbLoadingDaysTableTableFilterComposer,
      $$CarbLoadingDaysTableTableOrderingComposer,
      $$CarbLoadingDaysTableTableAnnotationComposer,
      $$CarbLoadingDaysTableTableCreateCompanionBuilder,
      $$CarbLoadingDaysTableTableUpdateCompanionBuilder,
      (
        CarbLoadingDay,
        BaseReferences<
          _$AppDatabase,
          $CarbLoadingDaysTableTable,
          CarbLoadingDay
        >,
      ),
      CarbLoadingDay,
      PrefetchHooks Function()
    >;
typedef $$CarbLoadingFoodsTableTableCreateCompanionBuilder =
    CarbLoadingFoodsTableCompanion Function({
      required String id,
      required String name,
      required String displayName,
      Value<String?> displayNamePlural,
      required double carbsPerServing,
      Value<String?> imageAddress,
      Value<bool> isDefault,
      Value<String?> mealTypes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$CarbLoadingFoodsTableTableUpdateCompanionBuilder =
    CarbLoadingFoodsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> displayName,
      Value<String?> displayNamePlural,
      Value<double> carbsPerServing,
      Value<String?> imageAddress,
      Value<bool> isDefault,
      Value<String?> mealTypes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CarbLoadingFoodsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingFoodsTableTable> {
  $$CarbLoadingFoodsTableTableFilterComposer({
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

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealTypes => $composableBuilder(
    column: $table.mealTypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CarbLoadingFoodsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingFoodsTableTable> {
  $$CarbLoadingFoodsTableTableOrderingComposer({
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

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealTypes => $composableBuilder(
    column: $table.mealTypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CarbLoadingFoodsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingFoodsTableTable> {
  $$CarbLoadingFoodsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get mealTypes =>
      $composableBuilder(column: $table.mealTypes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CarbLoadingFoodsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarbLoadingFoodsTableTable,
          CarbLoadingFood,
          $$CarbLoadingFoodsTableTableFilterComposer,
          $$CarbLoadingFoodsTableTableOrderingComposer,
          $$CarbLoadingFoodsTableTableAnnotationComposer,
          $$CarbLoadingFoodsTableTableCreateCompanionBuilder,
          $$CarbLoadingFoodsTableTableUpdateCompanionBuilder,
          (
            CarbLoadingFood,
            BaseReferences<
              _$AppDatabase,
              $CarbLoadingFoodsTableTable,
              CarbLoadingFood
            >,
          ),
          CarbLoadingFood,
          PrefetchHooks Function()
        > {
  $$CarbLoadingFoodsTableTableTableManager(
    _$AppDatabase db,
    $CarbLoadingFoodsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingFoodsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CarbLoadingFoodsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CarbLoadingFoodsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> displayNamePlural = const Value.absent(),
                Value<double> carbsPerServing = const Value.absent(),
                Value<String?> imageAddress = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> mealTypes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarbLoadingFoodsTableCompanion(
                id: id,
                name: name,
                displayName: displayName,
                displayNamePlural: displayNamePlural,
                carbsPerServing: carbsPerServing,
                imageAddress: imageAddress,
                isDefault: isDefault,
                mealTypes: mealTypes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String displayName,
                Value<String?> displayNamePlural = const Value.absent(),
                required double carbsPerServing,
                Value<String?> imageAddress = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> mealTypes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarbLoadingFoodsTableCompanion.insert(
                id: id,
                name: name,
                displayName: displayName,
                displayNamePlural: displayNamePlural,
                carbsPerServing: carbsPerServing,
                imageAddress: imageAddress,
                isDefault: isDefault,
                mealTypes: mealTypes,
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

typedef $$CarbLoadingFoodsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarbLoadingFoodsTableTable,
      CarbLoadingFood,
      $$CarbLoadingFoodsTableTableFilterComposer,
      $$CarbLoadingFoodsTableTableOrderingComposer,
      $$CarbLoadingFoodsTableTableAnnotationComposer,
      $$CarbLoadingFoodsTableTableCreateCompanionBuilder,
      $$CarbLoadingFoodsTableTableUpdateCompanionBuilder,
      (
        CarbLoadingFood,
        BaseReferences<
          _$AppDatabase,
          $CarbLoadingFoodsTableTable,
          CarbLoadingFood
        >,
      ),
      CarbLoadingFood,
      PrefetchHooks Function()
    >;
typedef $$CarbLoadingUserFoodsTableTableCreateCompanionBuilder =
    CarbLoadingUserFoodsTableCompanion Function({
      required String id,
      required String deviceId,
      required String userId,
      Value<String?> clientFoodId,
      required String name,
      required String displayName,
      Value<String?> displayNamePlural,
      required double carbsPerServing,
      Value<String?> imageAddress,
      Value<String?> barcode,
      Value<String?> sourceFoodId,
      Value<String?> sourceUserFoodId,
      Value<String?> mealTypes,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CarbLoadingUserFoodsTableTableUpdateCompanionBuilder =
    CarbLoadingUserFoodsTableCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<String> userId,
      Value<String?> clientFoodId,
      Value<String> name,
      Value<String> displayName,
      Value<String?> displayNamePlural,
      Value<double> carbsPerServing,
      Value<String?> imageAddress,
      Value<String?> barcode,
      Value<String?> sourceFoodId,
      Value<String?> sourceUserFoodId,
      Value<String?> mealTypes,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CarbLoadingUserFoodsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingUserFoodsTableTable> {
  $$CarbLoadingUserFoodsTableTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientFoodId => $composableBuilder(
    column: $table.clientFoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFoodId => $composableBuilder(
    column: $table.sourceFoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUserFoodId => $composableBuilder(
    column: $table.sourceUserFoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealTypes => $composableBuilder(
    column: $table.mealTypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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
}

class $$CarbLoadingUserFoodsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingUserFoodsTableTable> {
  $$CarbLoadingUserFoodsTableTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientFoodId => $composableBuilder(
    column: $table.clientFoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFoodId => $composableBuilder(
    column: $table.sourceFoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUserFoodId => $composableBuilder(
    column: $table.sourceUserFoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealTypes => $composableBuilder(
    column: $table.mealTypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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
}

class $$CarbLoadingUserFoodsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingUserFoodsTableTable> {
  $$CarbLoadingUserFoodsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get clientFoodId => $composableBuilder(
    column: $table.clientFoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayNamePlural => $composableBuilder(
    column: $table.displayNamePlural,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPerServing => $composableBuilder(
    column: $table.carbsPerServing,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageAddress => $composableBuilder(
    column: $table.imageAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get sourceFoodId => $composableBuilder(
    column: $table.sourceFoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUserFoodId => $composableBuilder(
    column: $table.sourceUserFoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mealTypes =>
      $composableBuilder(column: $table.mealTypes, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CarbLoadingUserFoodsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarbLoadingUserFoodsTableTable,
          CarbLoadingUserFood,
          $$CarbLoadingUserFoodsTableTableFilterComposer,
          $$CarbLoadingUserFoodsTableTableOrderingComposer,
          $$CarbLoadingUserFoodsTableTableAnnotationComposer,
          $$CarbLoadingUserFoodsTableTableCreateCompanionBuilder,
          $$CarbLoadingUserFoodsTableTableUpdateCompanionBuilder,
          (
            CarbLoadingUserFood,
            BaseReferences<
              _$AppDatabase,
              $CarbLoadingUserFoodsTableTable,
              CarbLoadingUserFood
            >,
          ),
          CarbLoadingUserFood,
          PrefetchHooks Function()
        > {
  $$CarbLoadingUserFoodsTableTableTableManager(
    _$AppDatabase db,
    $CarbLoadingUserFoodsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingUserFoodsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CarbLoadingUserFoodsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CarbLoadingUserFoodsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> clientFoodId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> displayNamePlural = const Value.absent(),
                Value<double> carbsPerServing = const Value.absent(),
                Value<String?> imageAddress = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String?> sourceFoodId = const Value.absent(),
                Value<String?> sourceUserFoodId = const Value.absent(),
                Value<String?> mealTypes = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarbLoadingUserFoodsTableCompanion(
                id: id,
                deviceId: deviceId,
                userId: userId,
                clientFoodId: clientFoodId,
                name: name,
                displayName: displayName,
                displayNamePlural: displayNamePlural,
                carbsPerServing: carbsPerServing,
                imageAddress: imageAddress,
                barcode: barcode,
                sourceFoodId: sourceFoodId,
                sourceUserFoodId: sourceUserFoodId,
                mealTypes: mealTypes,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String userId,
                Value<String?> clientFoodId = const Value.absent(),
                required String name,
                required String displayName,
                Value<String?> displayNamePlural = const Value.absent(),
                required double carbsPerServing,
                Value<String?> imageAddress = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String?> sourceFoodId = const Value.absent(),
                Value<String?> sourceUserFoodId = const Value.absent(),
                Value<String?> mealTypes = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarbLoadingUserFoodsTableCompanion.insert(
                id: id,
                deviceId: deviceId,
                userId: userId,
                clientFoodId: clientFoodId,
                name: name,
                displayName: displayName,
                displayNamePlural: displayNamePlural,
                carbsPerServing: carbsPerServing,
                imageAddress: imageAddress,
                barcode: barcode,
                sourceFoodId: sourceFoodId,
                sourceUserFoodId: sourceUserFoodId,
                mealTypes: mealTypes,
                isDeleted: isDeleted,
                createdAt: createdAt,
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

typedef $$CarbLoadingUserFoodsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarbLoadingUserFoodsTableTable,
      CarbLoadingUserFood,
      $$CarbLoadingUserFoodsTableTableFilterComposer,
      $$CarbLoadingUserFoodsTableTableOrderingComposer,
      $$CarbLoadingUserFoodsTableTableAnnotationComposer,
      $$CarbLoadingUserFoodsTableTableCreateCompanionBuilder,
      $$CarbLoadingUserFoodsTableTableUpdateCompanionBuilder,
      (
        CarbLoadingUserFood,
        BaseReferences<
          _$AppDatabase,
          $CarbLoadingUserFoodsTableTable,
          CarbLoadingUserFood
        >,
      ),
      CarbLoadingUserFood,
      PrefetchHooks Function()
    >;
typedef $$CarbLoadingDayMealsTableTableCreateCompanionBuilder =
    CarbLoadingDayMealsTableCompanion Function({
      Value<int> id,
      required int carbLoadingDayId,
      required int mealTypeId,
      Value<String?> carbLoadingFoodId,
      Value<String?> carbLoadingUserFoodId,
      Value<String?> foodDisplayName,
      Value<int> quantity,
      required double carbsConsumed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$CarbLoadingDayMealsTableTableUpdateCompanionBuilder =
    CarbLoadingDayMealsTableCompanion Function({
      Value<int> id,
      Value<int> carbLoadingDayId,
      Value<int> mealTypeId,
      Value<String?> carbLoadingFoodId,
      Value<String?> carbLoadingUserFoodId,
      Value<String?> foodDisplayName,
      Value<int> quantity,
      Value<double> carbsConsumed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$CarbLoadingDayMealsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CarbLoadingDayMealsTableTable> {
  $$CarbLoadingDayMealsTableTableFilterComposer({
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

  ColumnFilters<int> get carbLoadingDayId => $composableBuilder(
    column: $table.carbLoadingDayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mealTypeId => $composableBuilder(
    column: $table.mealTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carbLoadingFoodId => $composableBuilder(
    column: $table.carbLoadingFoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carbLoadingUserFoodId => $composableBuilder(
    column: $table.carbLoadingUserFoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodDisplayName => $composableBuilder(
    column: $table.foodDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsConsumed => $composableBuilder(
    column: $table.carbsConsumed,
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
}

class $$CarbLoadingDayMealsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbLoadingDayMealsTableTable> {
  $$CarbLoadingDayMealsTableTableOrderingComposer({
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

  ColumnOrderings<int> get carbLoadingDayId => $composableBuilder(
    column: $table.carbLoadingDayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mealTypeId => $composableBuilder(
    column: $table.mealTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carbLoadingFoodId => $composableBuilder(
    column: $table.carbLoadingFoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carbLoadingUserFoodId => $composableBuilder(
    column: $table.carbLoadingUserFoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodDisplayName => $composableBuilder(
    column: $table.foodDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsConsumed => $composableBuilder(
    column: $table.carbsConsumed,
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
}

class $$CarbLoadingDayMealsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbLoadingDayMealsTableTable> {
  $$CarbLoadingDayMealsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get carbLoadingDayId => $composableBuilder(
    column: $table.carbLoadingDayId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mealTypeId => $composableBuilder(
    column: $table.mealTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get carbLoadingFoodId => $composableBuilder(
    column: $table.carbLoadingFoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get carbLoadingUserFoodId => $composableBuilder(
    column: $table.carbLoadingUserFoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foodDisplayName => $composableBuilder(
    column: $table.foodDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get carbsConsumed => $composableBuilder(
    column: $table.carbsConsumed,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CarbLoadingDayMealsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarbLoadingDayMealsTableTable,
          CarbLoadingDayMeal,
          $$CarbLoadingDayMealsTableTableFilterComposer,
          $$CarbLoadingDayMealsTableTableOrderingComposer,
          $$CarbLoadingDayMealsTableTableAnnotationComposer,
          $$CarbLoadingDayMealsTableTableCreateCompanionBuilder,
          $$CarbLoadingDayMealsTableTableUpdateCompanionBuilder,
          (
            CarbLoadingDayMeal,
            BaseReferences<
              _$AppDatabase,
              $CarbLoadingDayMealsTableTable,
              CarbLoadingDayMeal
            >,
          ),
          CarbLoadingDayMeal,
          PrefetchHooks Function()
        > {
  $$CarbLoadingDayMealsTableTableTableManager(
    _$AppDatabase db,
    $CarbLoadingDayMealsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbLoadingDayMealsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CarbLoadingDayMealsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CarbLoadingDayMealsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> carbLoadingDayId = const Value.absent(),
                Value<int> mealTypeId = const Value.absent(),
                Value<String?> carbLoadingFoodId = const Value.absent(),
                Value<String?> carbLoadingUserFoodId = const Value.absent(),
                Value<String?> foodDisplayName = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double> carbsConsumed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CarbLoadingDayMealsTableCompanion(
                id: id,
                carbLoadingDayId: carbLoadingDayId,
                mealTypeId: mealTypeId,
                carbLoadingFoodId: carbLoadingFoodId,
                carbLoadingUserFoodId: carbLoadingUserFoodId,
                foodDisplayName: foodDisplayName,
                quantity: quantity,
                carbsConsumed: carbsConsumed,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int carbLoadingDayId,
                required int mealTypeId,
                Value<String?> carbLoadingFoodId = const Value.absent(),
                Value<String?> carbLoadingUserFoodId = const Value.absent(),
                Value<String?> foodDisplayName = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                required double carbsConsumed,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CarbLoadingDayMealsTableCompanion.insert(
                id: id,
                carbLoadingDayId: carbLoadingDayId,
                mealTypeId: mealTypeId,
                carbLoadingFoodId: carbLoadingFoodId,
                carbLoadingUserFoodId: carbLoadingUserFoodId,
                foodDisplayName: foodDisplayName,
                quantity: quantity,
                carbsConsumed: carbsConsumed,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarbLoadingDayMealsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarbLoadingDayMealsTableTable,
      CarbLoadingDayMeal,
      $$CarbLoadingDayMealsTableTableFilterComposer,
      $$CarbLoadingDayMealsTableTableOrderingComposer,
      $$CarbLoadingDayMealsTableTableAnnotationComposer,
      $$CarbLoadingDayMealsTableTableCreateCompanionBuilder,
      $$CarbLoadingDayMealsTableTableUpdateCompanionBuilder,
      (
        CarbLoadingDayMeal,
        BaseReferences<
          _$AppDatabase,
          $CarbLoadingDayMealsTableTable,
          CarbLoadingDayMeal
        >,
      ),
      CarbLoadingDayMeal,
      PrefetchHooks Function()
    >;
typedef $$WeatherForecastsTableTableCreateCompanionBuilder =
    WeatherForecastsTableCompanion Function({
      Value<int> id,
      required double latitude,
      required double longitude,
      required DateTime forecastDate,
      required double temperatureC,
      required int humidityPct,
      Value<bool> forecastAvailable,
      required String source,
      Value<String?> conditions,
      Value<int?> windSpeedKmh,
      Value<double?> precipitationMm,
      Value<DateTime> fetchedAt,
      required DateTime expiresAt,
    });
typedef $$WeatherForecastsTableTableUpdateCompanionBuilder =
    WeatherForecastsTableCompanion Function({
      Value<int> id,
      Value<double> latitude,
      Value<double> longitude,
      Value<DateTime> forecastDate,
      Value<double> temperatureC,
      Value<int> humidityPct,
      Value<bool> forecastAvailable,
      Value<String> source,
      Value<String?> conditions,
      Value<int?> windSpeedKmh,
      Value<double?> precipitationMm,
      Value<DateTime> fetchedAt,
      Value<DateTime> expiresAt,
    });

class $$WeatherForecastsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WeatherForecastsTableTable> {
  $$WeatherForecastsTableTableFilterComposer({
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

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get forecastDate => $composableBuilder(
    column: $table.forecastDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get forecastAvailable => $composableBuilder(
    column: $table.forecastAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windSpeedKmh => $composableBuilder(
    column: $table.windSpeedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeatherForecastsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WeatherForecastsTableTable> {
  $$WeatherForecastsTableTableOrderingComposer({
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

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get forecastDate => $composableBuilder(
    column: $table.forecastDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get forecastAvailable => $composableBuilder(
    column: $table.forecastAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windSpeedKmh => $composableBuilder(
    column: $table.windSpeedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeatherForecastsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeatherForecastsTableTable> {
  $$WeatherForecastsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get forecastDate => $composableBuilder(
    column: $table.forecastDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => column,
  );

  GeneratedColumn<int> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get forecastAvailable => $composableBuilder(
    column: $table.forecastAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windSpeedKmh => $composableBuilder(
    column: $table.windSpeedKmh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$WeatherForecastsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeatherForecastsTableTable,
          WeatherForecastData,
          $$WeatherForecastsTableTableFilterComposer,
          $$WeatherForecastsTableTableOrderingComposer,
          $$WeatherForecastsTableTableAnnotationComposer,
          $$WeatherForecastsTableTableCreateCompanionBuilder,
          $$WeatherForecastsTableTableUpdateCompanionBuilder,
          (
            WeatherForecastData,
            BaseReferences<
              _$AppDatabase,
              $WeatherForecastsTableTable,
              WeatherForecastData
            >,
          ),
          WeatherForecastData,
          PrefetchHooks Function()
        > {
  $$WeatherForecastsTableTableTableManager(
    _$AppDatabase db,
    $WeatherForecastsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeatherForecastsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WeatherForecastsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WeatherForecastsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<DateTime> forecastDate = const Value.absent(),
                Value<double> temperatureC = const Value.absent(),
                Value<int> humidityPct = const Value.absent(),
                Value<bool> forecastAvailable = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> conditions = const Value.absent(),
                Value<int?> windSpeedKmh = const Value.absent(),
                Value<double?> precipitationMm = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
              }) => WeatherForecastsTableCompanion(
                id: id,
                latitude: latitude,
                longitude: longitude,
                forecastDate: forecastDate,
                temperatureC: temperatureC,
                humidityPct: humidityPct,
                forecastAvailable: forecastAvailable,
                source: source,
                conditions: conditions,
                windSpeedKmh: windSpeedKmh,
                precipitationMm: precipitationMm,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required double latitude,
                required double longitude,
                required DateTime forecastDate,
                required double temperatureC,
                required int humidityPct,
                Value<bool> forecastAvailable = const Value.absent(),
                required String source,
                Value<String?> conditions = const Value.absent(),
                Value<int?> windSpeedKmh = const Value.absent(),
                Value<double?> precipitationMm = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                required DateTime expiresAt,
              }) => WeatherForecastsTableCompanion.insert(
                id: id,
                latitude: latitude,
                longitude: longitude,
                forecastDate: forecastDate,
                temperatureC: temperatureC,
                humidityPct: humidityPct,
                forecastAvailable: forecastAvailable,
                source: source,
                conditions: conditions,
                windSpeedKmh: windSpeedKmh,
                precipitationMm: precipitationMm,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeatherForecastsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeatherForecastsTableTable,
      WeatherForecastData,
      $$WeatherForecastsTableTableFilterComposer,
      $$WeatherForecastsTableTableOrderingComposer,
      $$WeatherForecastsTableTableAnnotationComposer,
      $$WeatherForecastsTableTableCreateCompanionBuilder,
      $$WeatherForecastsTableTableUpdateCompanionBuilder,
      (
        WeatherForecastData,
        BaseReferences<
          _$AppDatabase,
          $WeatherForecastsTableTable,
          WeatherForecastData
        >,
      ),
      WeatherForecastData,
      PrefetchHooks Function()
    >;
typedef $$FeatureSurveyResponsesTableTableCreateCompanionBuilder =
    FeatureSurveyResponsesTableCompanion Function({
      Value<int> id,
      required String userId,
      required String selectedFeatures,
      required DateTime votedAt,
    });
typedef $$FeatureSurveyResponsesTableTableUpdateCompanionBuilder =
    FeatureSurveyResponsesTableCompanion Function({
      Value<int> id,
      Value<String> userId,
      Value<String> selectedFeatures,
      Value<DateTime> votedAt,
    });

class $$FeatureSurveyResponsesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FeatureSurveyResponsesTableTable> {
  $$FeatureSurveyResponsesTableTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedFeatures => $composableBuilder(
    column: $table.selectedFeatures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get votedAt => $composableBuilder(
    column: $table.votedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeatureSurveyResponsesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FeatureSurveyResponsesTableTable> {
  $$FeatureSurveyResponsesTableTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedFeatures => $composableBuilder(
    column: $table.selectedFeatures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get votedAt => $composableBuilder(
    column: $table.votedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeatureSurveyResponsesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeatureSurveyResponsesTableTable> {
  $$FeatureSurveyResponsesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get selectedFeatures => $composableBuilder(
    column: $table.selectedFeatures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get votedAt =>
      $composableBuilder(column: $table.votedAt, builder: (column) => column);
}

class $$FeatureSurveyResponsesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeatureSurveyResponsesTableTable,
          FeatureSurveyResponseEntry,
          $$FeatureSurveyResponsesTableTableFilterComposer,
          $$FeatureSurveyResponsesTableTableOrderingComposer,
          $$FeatureSurveyResponsesTableTableAnnotationComposer,
          $$FeatureSurveyResponsesTableTableCreateCompanionBuilder,
          $$FeatureSurveyResponsesTableTableUpdateCompanionBuilder,
          (
            FeatureSurveyResponseEntry,
            BaseReferences<
              _$AppDatabase,
              $FeatureSurveyResponsesTableTable,
              FeatureSurveyResponseEntry
            >,
          ),
          FeatureSurveyResponseEntry,
          PrefetchHooks Function()
        > {
  $$FeatureSurveyResponsesTableTableTableManager(
    _$AppDatabase db,
    $FeatureSurveyResponsesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeatureSurveyResponsesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FeatureSurveyResponsesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FeatureSurveyResponsesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> selectedFeatures = const Value.absent(),
                Value<DateTime> votedAt = const Value.absent(),
              }) => FeatureSurveyResponsesTableCompanion(
                id: id,
                userId: userId,
                selectedFeatures: selectedFeatures,
                votedAt: votedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String userId,
                required String selectedFeatures,
                required DateTime votedAt,
              }) => FeatureSurveyResponsesTableCompanion.insert(
                id: id,
                userId: userId,
                selectedFeatures: selectedFeatures,
                votedAt: votedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeatureSurveyResponsesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeatureSurveyResponsesTableTable,
      FeatureSurveyResponseEntry,
      $$FeatureSurveyResponsesTableTableFilterComposer,
      $$FeatureSurveyResponsesTableTableOrderingComposer,
      $$FeatureSurveyResponsesTableTableAnnotationComposer,
      $$FeatureSurveyResponsesTableTableCreateCompanionBuilder,
      $$FeatureSurveyResponsesTableTableUpdateCompanionBuilder,
      (
        FeatureSurveyResponseEntry,
        BaseReferences<
          _$AppDatabase,
          $FeatureSurveyResponsesTableTable,
          FeatureSurveyResponseEntry
        >,
      ),
      FeatureSurveyResponseEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableTableManager get userProfilesTable =>
      $$UserProfilesTableTableTableManager(_db, _db.userProfilesTable);
  $$FoodPreferencesTableTableTableManager get foodPreferencesTable =>
      $$FoodPreferencesTableTableTableManager(_db, _db.foodPreferencesTable);
  $$FeedbackTableTableTableManager get feedbackTable =>
      $$FeedbackTableTableTableManager(_db, _db.feedbackTable);
  $$FoodsTableTableTableManager get foodsTable =>
      $$FoodsTableTableTableManager(_db, _db.foodsTable);
  $$UserFoodsTableTableTableManager get userFoodsTable =>
      $$UserFoodsTableTableTableManager(_db, _db.userFoodsTable);
  $$AppContentTableTableTableManager get appContentTable =>
      $$AppContentTableTableTableManager(_db, _db.appContentTable);
  $$EdgeFunctionsTableTableTableManager get edgeFunctionsTable =>
      $$EdgeFunctionsTableTableTableManager(_db, _db.edgeFunctionsTable);
  $$ActivitiesTableTableTableManager get activitiesTable =>
      $$ActivitiesTableTableTableManager(_db, _db.activitiesTable);
  $$EventsTableTableTableManager get eventsTable =>
      $$EventsTableTableTableManager(_db, _db.eventsTable);
  $$CarbLoadingPlansTableTableTableManager get carbLoadingPlansTable =>
      $$CarbLoadingPlansTableTableTableManager(_db, _db.carbLoadingPlansTable);
  $$CarbLoadingDaysTableTableTableManager get carbLoadingDaysTable =>
      $$CarbLoadingDaysTableTableTableManager(_db, _db.carbLoadingDaysTable);
  $$CarbLoadingFoodsTableTableTableManager get carbLoadingFoodsTable =>
      $$CarbLoadingFoodsTableTableTableManager(_db, _db.carbLoadingFoodsTable);
  $$CarbLoadingUserFoodsTableTableTableManager get carbLoadingUserFoodsTable =>
      $$CarbLoadingUserFoodsTableTableTableManager(
        _db,
        _db.carbLoadingUserFoodsTable,
      );
  $$CarbLoadingDayMealsTableTableTableManager get carbLoadingDayMealsTable =>
      $$CarbLoadingDayMealsTableTableTableManager(
        _db,
        _db.carbLoadingDayMealsTable,
      );
  $$WeatherForecastsTableTableTableManager get weatherForecastsTable =>
      $$WeatherForecastsTableTableTableManager(_db, _db.weatherForecastsTable);
  $$FeatureSurveyResponsesTableTableTableManager
  get featureSurveyResponsesTable =>
      $$FeatureSurveyResponsesTableTableTableManager(
        _db,
        _db.featureSurveyResponsesTable,
      );
}
