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
/// written while offline).
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
/// written while offline).
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
  /// written while offline).
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

String _$mealLogsForDateHash() => r'518ad78e738593651ff7a24b92b63fc88a902304';

/// Streams [MealLog] entries for [date] (formatted as `'yyyy-MM-dd'`) for the
/// current user.
///
/// Automatically re-emits whenever the underlying Drift table changes, so the
/// Daily Macros tab always reflects the latest local state (including entries
/// written while offline).
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
  /// written while offline).
  ///
  /// Returns an empty list when there is no authenticated user (no throws —
  /// callers handle the empty-state UI).

  MealLogsForDateProvider call(String date) =>
      MealLogsForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'mealLogsForDateProvider';
}

/// Derived provider: [ConsumedTotals] for [date], recomputed whenever the
/// underlying [mealLogsForDateProvider] stream emits.
///
/// This is the single value the Daily Macros progress bars should watch.
/// Derives directly from the same repository stream so it shares the same
/// Drift subscription lifecycle.

@ProviderFor(consumedTotalsForDate)
const consumedTotalsForDateProvider = ConsumedTotalsForDateFamily._();

/// Derived provider: [ConsumedTotals] for [date], recomputed whenever the
/// underlying [mealLogsForDateProvider] stream emits.
///
/// This is the single value the Daily Macros progress bars should watch.
/// Derives directly from the same repository stream so it shares the same
/// Drift subscription lifecycle.

final class ConsumedTotalsForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConsumedTotals>,
          ConsumedTotals,
          Stream<ConsumedTotals>
        >
    with $FutureModifier<ConsumedTotals>, $StreamProvider<ConsumedTotals> {
  /// Derived provider: [ConsumedTotals] for [date], recomputed whenever the
  /// underlying [mealLogsForDateProvider] stream emits.
  ///
  /// This is the single value the Daily Macros progress bars should watch.
  /// Derives directly from the same repository stream so it shares the same
  /// Drift subscription lifecycle.
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
    r'49a315c0a9d6d158609d6ffb0e2979e397d950e7';

/// Derived provider: [ConsumedTotals] for [date], recomputed whenever the
/// underlying [mealLogsForDateProvider] stream emits.
///
/// This is the single value the Daily Macros progress bars should watch.
/// Derives directly from the same repository stream so it shares the same
/// Drift subscription lifecycle.

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

  /// Derived provider: [ConsumedTotals] for [date], recomputed whenever the
  /// underlying [mealLogsForDateProvider] stream emits.
  ///
  /// This is the single value the Daily Macros progress bars should watch.
  /// Derives directly from the same repository stream so it shares the same
  /// Drift subscription lifecycle.

  ConsumedTotalsForDateProvider call(String date) =>
      ConsumedTotalsForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'consumedTotalsForDateProvider';
}

/// Most recent 25 distinct meal names for the current user.
///
/// Used by the "Recent" section of the meal picker. Rebuilds on invalidation
/// (not a stream — recents don't need real-time updates within a session).

@ProviderFor(recentMeals)
const recentMealsProvider = RecentMealsProvider._();

/// Most recent 25 distinct meal names for the current user.
///
/// Used by the "Recent" section of the meal picker. Rebuilds on invalidation
/// (not a stream — recents don't need real-time updates within a session).

final class RecentMealsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MealLog>>,
          List<MealLog>,
          FutureOr<List<MealLog>>
        >
    with $FutureModifier<List<MealLog>>, $FutureProvider<List<MealLog>> {
  /// Most recent 25 distinct meal names for the current user.
  ///
  /// Used by the "Recent" section of the meal picker. Rebuilds on invalidation
  /// (not a stream — recents don't need real-time updates within a session).
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
  $FutureProviderElement<List<MealLog>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MealLog>> create(Ref ref) {
    return recentMeals(ref);
  }
}

String _$recentMealsHash() => r'f507aef154d019ad74c1eb24cb6411fecc0c7c15';

/// Streams all non-deleted saved meals for the current user, ordered by
/// [SavedMeal.lastUsedAt] descending.
///
/// Used by the "My Meals" section of the meal picker.

@ProviderFor(savedMeals)
const savedMealsProvider = SavedMealsProvider._();

/// Streams all non-deleted saved meals for the current user, ordered by
/// [SavedMeal.lastUsedAt] descending.
///
/// Used by the "My Meals" section of the meal picker.

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
  /// Used by the "My Meals" section of the meal picker.
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

String _$savedMealsHash() => r'ea91e47c7a97981c83229cfa270e9ed7413f9f60';

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

String _$mealLogControllerHash() => r'f1d132930f206f7a36c85bb5df0a948df6427027';

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
