// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_log_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application-layer service wired with both repositories.

@ProviderFor(mealLoggingService)
const mealLoggingServiceProvider = MealLoggingServiceProvider._();

/// Application-layer service wired with both repositories.

final class MealLoggingServiceProvider
    extends
        $FunctionalProvider<
          MealLoggingService,
          MealLoggingService,
          MealLoggingService
        >
    with $Provider<MealLoggingService> {
  /// Application-layer service wired with both repositories.
  const MealLoggingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealLoggingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealLoggingServiceHash();

  @$internal
  @override
  $ProviderElement<MealLoggingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MealLoggingService create(Ref ref) {
    return mealLoggingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealLoggingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealLoggingService>(value),
    );
  }
}

String _$mealLoggingServiceHash() =>
    r'1a818450cc896c13278702b10fc718505502a6e9';

/// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
/// current user.
///
/// Automatically re-emits whenever the underlying Drift table changes, so the
/// Daily Macros tab always reflects the latest local state (including entries
/// written while offline). Kicks a `meal_logs` sync in the background on
/// build (never blocks on the network): the local table answers first and
/// the server's rows re-emit through the same stream when they land.
///
/// Returns an empty list when there is no authenticated user (no throws —
/// callers handle the empty-state UI).

@ProviderFor(mealLogsForDate)
const mealLogsForDateProvider = MealLogsForDateFamily._();

/// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
/// current user.
///
/// Automatically re-emits whenever the underlying Drift table changes, so the
/// Daily Macros tab always reflects the latest local state (including entries
/// written while offline). Kicks a `meal_logs` sync in the background on
/// build (never blocks on the network): the local table answers first and
/// the server's rows re-emit through the same stream when they land.
///
/// Returns an empty list when there is no authenticated user (no throws —
/// callers handle the empty-state UI).

final class MealLogsForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MealLog>>,
          List<MealLog>,
          Stream<List<MealLog>>
        >
    with $FutureModifier<List<MealLog>>, $StreamProvider<List<MealLog>> {
  /// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
  /// current user.
  ///
  /// Automatically re-emits whenever the underlying Drift table changes, so the
  /// Daily Macros tab always reflects the latest local state (including entries
  /// written while offline). Kicks a `meal_logs` sync in the background on
  /// build (never blocks on the network): the local table answers first and
  /// the server's rows re-emit through the same stream when they land.
  ///
  /// Returns an empty list when there is no authenticated user (no throws —
  /// callers handle the empty-state UI).
  const MealLogsForDateProvider._({
    required MealLogsForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mealLogsForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mealLogsForDateHash();

  @override
  String toString() {
    return r'mealLogsForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MealLog>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MealLog>> create(Ref ref) {
    final argument = this.argument as String;
    return mealLogsForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MealLogsForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mealLogsForDateHash() => r'a3148958fd11ce1aa207ee5db8876d964d09d9c6';

/// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
/// current user.
///
/// Automatically re-emits whenever the underlying Drift table changes, so the
/// Daily Macros tab always reflects the latest local state (including entries
/// written while offline). Kicks a `meal_logs` sync in the background on
/// build (never blocks on the network): the local table answers first and
/// the server's rows re-emit through the same stream when they land.
///
/// Returns an empty list when there is no authenticated user (no throws —
/// callers handle the empty-state UI).

final class MealLogsForDateFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MealLog>>, String> {
  const MealLogsForDateFamily._()
    : super(
        retry: null,
        name: r'mealLogsForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
  /// current user.
  ///
  /// Automatically re-emits whenever the underlying Drift table changes, so the
  /// Daily Macros tab always reflects the latest local state (including entries
  /// written while offline). Kicks a `meal_logs` sync in the background on
  /// build (never blocks on the network): the local table answers first and
  /// the server's rows re-emit through the same stream when they land.
  ///
  /// Returns an empty list when there is no authenticated user (no throws —
  /// callers handle the empty-state UI).

  MealLogsForDateProvider call(String date) =>
      MealLogsForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'mealLogsForDateProvider';
}

/// Streams the day's completed activities (local calendar day of
/// `scheduledDateTime`), so their logged workout fuel can count as "eaten".
///
/// Empty when there is no authenticated user.

@ProviderFor(completedActivitiesForDate)
const completedActivitiesForDateProvider = CompletedActivitiesForDateFamily._();

/// Streams the day's completed activities (local calendar day of
/// `scheduledDateTime`), so their logged workout fuel can count as "eaten".
///
/// Empty when there is no authenticated user.

final class CompletedActivitiesForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Activity>>,
          List<Activity>,
          Stream<List<Activity>>
        >
    with $FutureModifier<List<Activity>>, $StreamProvider<List<Activity>> {
  /// Streams the day's completed activities (local calendar day of
  /// `scheduledDateTime`), so their logged workout fuel can count as "eaten".
  ///
  /// Empty when there is no authenticated user.
  const CompletedActivitiesForDateProvider._({
    required CompletedActivitiesForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'completedActivitiesForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$completedActivitiesForDateHash();

  @override
  String toString() {
    return r'completedActivitiesForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Activity>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Activity>> create(Ref ref) {
    final argument = this.argument as String;
    return completedActivitiesForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CompletedActivitiesForDateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$completedActivitiesForDateHash() =>
    r'd9576f6e278e03fb579ab168c91682c8e3fc8a53';

/// Streams the day's completed activities (local calendar day of
/// `scheduledDateTime`), so their logged workout fuel can count as "eaten".
///
/// Empty when there is no authenticated user.

final class CompletedActivitiesForDateFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Activity>>, String> {
  const CompletedActivitiesForDateFamily._()
    : super(
        retry: null,
        name: r'completedActivitiesForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the day's completed activities (local calendar day of
  /// `scheduledDateTime`), so their logged workout fuel can count as "eaten".
  ///
  /// Empty when there is no authenticated user.

  CompletedActivitiesForDateProvider call(String date) =>
      CompletedActivitiesForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'completedActivitiesForDateProvider';
}

/// Derived provider: [ConsumedTotals] for [date] — meal logs PLUS the
/// during-workout fuel logged on the day's completed activities.
///
/// This is the single value the Daily Macros progress bars (and the fuel
/// timeline's energy balance) should watch. Re-emits whenever either
/// underlying Drift stream changes.

@ProviderFor(consumedTotalsForDate)
const consumedTotalsForDateProvider = ConsumedTotalsForDateFamily._();

/// Derived provider: [ConsumedTotals] for [date] — meal logs PLUS the
/// during-workout fuel logged on the day's completed activities.
///
/// This is the single value the Daily Macros progress bars (and the fuel
/// timeline's energy balance) should watch. Re-emits whenever either
/// underlying Drift stream changes.

final class ConsumedTotalsForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConsumedTotals>,
          ConsumedTotals,
          Stream<ConsumedTotals>
        >
    with $FutureModifier<ConsumedTotals>, $StreamProvider<ConsumedTotals> {
  /// Derived provider: [ConsumedTotals] for [date] — meal logs PLUS the
  /// during-workout fuel logged on the day's completed activities.
  ///
  /// This is the single value the Daily Macros progress bars (and the fuel
  /// timeline's energy balance) should watch. Re-emits whenever either
  /// underlying Drift stream changes.
  const ConsumedTotalsForDateProvider._({
    required ConsumedTotalsForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'consumedTotalsForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$consumedTotalsForDateHash();

  @override
  String toString() {
    return r'consumedTotalsForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ConsumedTotals> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ConsumedTotals> create(Ref ref) {
    final argument = this.argument as String;
    return consumedTotalsForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConsumedTotalsForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$consumedTotalsForDateHash() =>
    r'b2f53f9e3948fbc1843299a529af17da5324c636';

/// Derived provider: [ConsumedTotals] for [date] — meal logs PLUS the
/// during-workout fuel logged on the day's completed activities.
///
/// This is the single value the Daily Macros progress bars (and the fuel
/// timeline's energy balance) should watch. Re-emits whenever either
/// underlying Drift stream changes.

final class ConsumedTotalsForDateFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ConsumedTotals>, String> {
  const ConsumedTotalsForDateFamily._()
    : super(
        retry: null,
        name: r'consumedTotalsForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Derived provider: [ConsumedTotals] for [date] — meal logs PLUS the
  /// during-workout fuel logged on the day's completed activities.
  ///
  /// This is the single value the Daily Macros progress bars (and the fuel
  /// timeline's energy balance) should watch. Re-emits whenever either
  /// underlying Drift stream changes.

  ConsumedTotalsForDateProvider call(String date) =>
      ConsumedTotalsForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'consumedTotalsForDateProvider';
}

/// Most recent 25 distinct meal names for the current user.
///
/// Used by the "Recent" section of the meal picker. Streams from Drift, so a
/// meal just logged (re-logged from Recent, or from a recipe) moves to the
/// top at once, whichever write path logged it (testing-wave 26-005: the
/// controller's invalidate was skipped whenever the auto-dispose controller
/// had been disposed mid-write, and `logRecipe` never asked).
///
/// The `meal_logs` sync is awaited before the first emission rather than
/// kicked, so a fresh sign-in shows the spinner, not an empty Recent that
/// fills in under the athlete's finger; a sync that fails answers from the
/// local table.

@ProviderFor(recentMeals)
const recentMealsProvider = RecentMealsProvider._();

/// Most recent 25 distinct meal names for the current user.
///
/// Used by the "Recent" section of the meal picker. Streams from Drift, so a
/// meal just logged (re-logged from Recent, or from a recipe) moves to the
/// top at once, whichever write path logged it (testing-wave 26-005: the
/// controller's invalidate was skipped whenever the auto-dispose controller
/// had been disposed mid-write, and `logRecipe` never asked).
///
/// The `meal_logs` sync is awaited before the first emission rather than
/// kicked, so a fresh sign-in shows the spinner, not an empty Recent that
/// fills in under the athlete's finger; a sync that fails answers from the
/// local table.

final class RecentMealsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MealLog>>,
          List<MealLog>,
          Stream<List<MealLog>>
        >
    with $FutureModifier<List<MealLog>>, $StreamProvider<List<MealLog>> {
  /// Most recent 25 distinct meal names for the current user.
  ///
  /// Used by the "Recent" section of the meal picker. Streams from Drift, so a
  /// meal just logged (re-logged from Recent, or from a recipe) moves to the
  /// top at once, whichever write path logged it (testing-wave 26-005: the
  /// controller's invalidate was skipped whenever the auto-dispose controller
  /// had been disposed mid-write, and `logRecipe` never asked).
  ///
  /// The `meal_logs` sync is awaited before the first emission rather than
  /// kicked, so a fresh sign-in shows the spinner, not an empty Recent that
  /// fills in under the athlete's finger; a sync that fails answers from the
  /// local table.
  const RecentMealsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentMealsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentMealsHash();

  @$internal
  @override
  $StreamProviderElement<List<MealLog>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MealLog>> create(Ref ref) {
    return recentMeals(ref);
  }
}

String _$recentMealsHash() => r'19e9a9b5acfe6603449fbae9cde693457dc954c8';

/// Streams all non-deleted saved meals for the current user, ordered by
/// [SavedMeal.lastUsedAt] descending.
///
/// Used by the "My Meals" section of the meal picker. Kicks a `saved_meals`
/// sync in the background on build, like [mealLogsForDate].

@ProviderFor(savedMeals)
const savedMealsProvider = SavedMealsProvider._();

/// Streams all non-deleted saved meals for the current user, ordered by
/// [SavedMeal.lastUsedAt] descending.
///
/// Used by the "My Meals" section of the meal picker. Kicks a `saved_meals`
/// sync in the background on build, like [mealLogsForDate].

final class SavedMealsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedMeal>>,
          List<SavedMeal>,
          Stream<List<SavedMeal>>
        >
    with $FutureModifier<List<SavedMeal>>, $StreamProvider<List<SavedMeal>> {
  /// Streams all non-deleted saved meals for the current user, ordered by
  /// [SavedMeal.lastUsedAt] descending.
  ///
  /// Used by the "My Meals" section of the meal picker. Kicks a `saved_meals`
  /// sync in the background on build, like [mealLogsForDate].
  const SavedMealsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedMealsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedMealsHash();

  @$internal
  @override
  $StreamProviderElement<List<SavedMeal>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedMeal>> create(Ref ref) {
    return savedMeals(ref);
  }
}

String _$savedMealsHash() => r'0bb5900c35e255748b6aa9bfe1ac127c15e4d2b0';

/// Controller for meal log mutations.
///
/// State is `AsyncValue<void>` — callers check [state] for loading/error
/// feedback after calling any action method. On success the relevant stream
/// providers update automatically (Drift stream re-emits).
///
/// Uses [AsyncValue.guard] so errors surface as [AsyncError] rather than
/// uncaught exceptions.

@ProviderFor(MealLogController)
const mealLogControllerProvider = MealLogControllerProvider._();

/// Controller for meal log mutations.
///
/// State is `AsyncValue<void>` — callers check [state] for loading/error
/// feedback after calling any action method. On success the relevant stream
/// providers update automatically (Drift stream re-emits).
///
/// Uses [AsyncValue.guard] so errors surface as [AsyncError] rather than
/// uncaught exceptions.
final class MealLogControllerProvider
    extends $AsyncNotifierProvider<MealLogController, void> {
  /// Controller for meal log mutations.
  ///
  /// State is `AsyncValue<void>` — callers check [state] for loading/error
  /// feedback after calling any action method. On success the relevant stream
  /// providers update automatically (Drift stream re-emits).
  ///
  /// Uses [AsyncValue.guard] so errors surface as [AsyncError] rather than
  /// uncaught exceptions.
  const MealLogControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealLogControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealLogControllerHash();

  @$internal
  @override
  MealLogController create() => MealLogController();
}

String _$mealLogControllerHash() => r'a64ee97fcb28d594762e2f11d7d896c1ecc3ebd1';

/// Controller for meal log mutations.
///
/// State is `AsyncValue<void>` — callers check [state] for loading/error
/// feedback after calling any action method. On success the relevant stream
/// providers update automatically (Drift stream re-emits).
///
/// Uses [AsyncValue.guard] so errors surface as [AsyncError] rather than
/// uncaught exceptions.

abstract class _$MealLogController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}

/// Generates a 1-hour signed URL for a meal photo stored in the `meal-photos`
/// bucket. Returns `null` when [photoPath] is null/empty or on any error.

@ProviderFor(mealPhotoSignedUrl)
const mealPhotoSignedUrlProvider = MealPhotoSignedUrlFamily._();

/// Generates a 1-hour signed URL for a meal photo stored in the `meal-photos`
/// bucket. Returns `null` when [photoPath] is null/empty or on any error.

final class MealPhotoSignedUrlProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Generates a 1-hour signed URL for a meal photo stored in the `meal-photos`
  /// bucket. Returns `null` when [photoPath] is null/empty or on any error.
  const MealPhotoSignedUrlProvider._({
    required MealPhotoSignedUrlFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'mealPhotoSignedUrlProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mealPhotoSignedUrlHash();

  @override
  String toString() {
    return r'mealPhotoSignedUrlProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String?;
    return mealPhotoSignedUrl(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MealPhotoSignedUrlProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mealPhotoSignedUrlHash() =>
    r'1603e0ce649a95bcc5a162c56f0597b4096a77ab';

/// Generates a 1-hour signed URL for a meal photo stored in the `meal-photos`
/// bucket. Returns `null` when [photoPath] is null/empty or on any error.

final class MealPhotoSignedUrlFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String?> {
  const MealPhotoSignedUrlFamily._()
    : super(
        retry: null,
        name: r'mealPhotoSignedUrlProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Generates a 1-hour signed URL for a meal photo stored in the `meal-photos`
  /// bucket. Returns `null` when [photoPath] is null/empty or on any error.

  MealPhotoSignedUrlProvider call(String? photoPath) =>
      MealPhotoSignedUrlProvider._(argument: photoPath, from: this);

  @override
  String toString() => r'mealPhotoSignedUrlProvider';
}
