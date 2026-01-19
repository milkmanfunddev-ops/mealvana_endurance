// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing carb loading plans
/// Handles carb loading protocol creation, updates, and queries

@ProviderFor(CarbLoadingController)
const carbLoadingControllerProvider = CarbLoadingControllerProvider._();

/// Controller for managing carb loading plans
/// Handles carb loading protocol creation, updates, and queries
final class CarbLoadingControllerProvider
    extends $AsyncNotifierProvider<CarbLoadingController, void> {
  /// Controller for managing carb loading plans
  /// Handles carb loading protocol creation, updates, and queries
  const CarbLoadingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingControllerHash();

  @$internal
  @override
  CarbLoadingController create() => CarbLoadingController();
}

String _$carbLoadingControllerHash() =>
    r'fed895b13032c86d2d9ce263ba399b7025d3665e';

/// Controller for managing carb loading plans
/// Handles carb loading protocol creation, updates, and queries

abstract class _$CarbLoadingController extends $AsyncNotifier<void> {
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

/// Provider for getting carb loading plan for a specific event
/// Returns CarbLoadingPlan? from the database

@ProviderFor(carbLoadingPlan)
const carbLoadingPlanProvider = CarbLoadingPlanFamily._();

/// Provider for getting carb loading plan for a specific event
/// Returns CarbLoadingPlan? from the database

final class CarbLoadingPlanProvider
    extends $FunctionalProvider<AsyncValue<dynamic>, dynamic, FutureOr<dynamic>>
    with $FutureModifier<dynamic>, $FutureProvider<dynamic> {
  /// Provider for getting carb loading plan for a specific event
  /// Returns CarbLoadingPlan? from the database
  const CarbLoadingPlanProvider._({
    required CarbLoadingPlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carbLoadingPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingPlanHash();

  @override
  String toString() {
    return r'carbLoadingPlanProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<dynamic> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<dynamic> create(Ref ref) {
    final argument = this.argument as String;
    return carbLoadingPlan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbLoadingPlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbLoadingPlanHash() => r'e66e01a2070b341f6d32bf2a2bb8c5d8d9dfdd31';

/// Provider for getting carb loading plan for a specific event
/// Returns CarbLoadingPlan? from the database

final class CarbLoadingPlanFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<dynamic>, String> {
  const CarbLoadingPlanFamily._()
    : super(
        retry: null,
        name: r'carbLoadingPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting carb loading plan for a specific event
  /// Returns CarbLoadingPlan? from the database

  CarbLoadingPlanProvider call(String eventId) =>
      CarbLoadingPlanProvider._(argument: eventId, from: this);

  @override
  String toString() => r'carbLoadingPlanProvider';
}

/// Provider for getting carb loading days for a plan
/// Returns List<CarbLoadingDay> from the database

@ProviderFor(carbLoadingDaysForPlan)
const carbLoadingDaysForPlanProvider = CarbLoadingDaysForPlanFamily._();

/// Provider for getting carb loading days for a plan
/// Returns List<CarbLoadingDay> from the database

final class CarbLoadingDaysForPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<dynamic>>,
          List<dynamic>,
          FutureOr<List<dynamic>>
        >
    with $FutureModifier<List<dynamic>>, $FutureProvider<List<dynamic>> {
  /// Provider for getting carb loading days for a plan
  /// Returns List<CarbLoadingDay> from the database
  const CarbLoadingDaysForPlanProvider._({
    required CarbLoadingDaysForPlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carbLoadingDaysForPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingDaysForPlanHash();

  @override
  String toString() {
    return r'carbLoadingDaysForPlanProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<dynamic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<dynamic>> create(Ref ref) {
    final argument = this.argument as String;
    return carbLoadingDaysForPlan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbLoadingDaysForPlanProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbLoadingDaysForPlanHash() =>
    r'e147a6366a5e86db491ed8275064c546c4af4fbd';

/// Provider for getting carb loading days for a plan
/// Returns List<CarbLoadingDay> from the database

final class CarbLoadingDaysForPlanFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<dynamic>>, String> {
  const CarbLoadingDaysForPlanFamily._()
    : super(
        retry: null,
        name: r'carbLoadingDaysForPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting carb loading days for a plan
  /// Returns List<CarbLoadingDay> from the database

  CarbLoadingDaysForPlanProvider call(String planId) =>
      CarbLoadingDaysForPlanProvider._(argument: planId, from: this);

  @override
  String toString() => r'carbLoadingDaysForPlanProvider';
}

/// Provider for getting carb loading days in a date range
/// Returns List<CarbLoadingDay> from the database

@ProviderFor(carbLoadingDaysForRange)
const carbLoadingDaysForRangeProvider = CarbLoadingDaysForRangeFamily._();

/// Provider for getting carb loading days in a date range
/// Returns List<CarbLoadingDay> from the database

final class CarbLoadingDaysForRangeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<dynamic>>,
          List<dynamic>,
          FutureOr<List<dynamic>>
        >
    with $FutureModifier<List<dynamic>>, $FutureProvider<List<dynamic>> {
  /// Provider for getting carb loading days in a date range
  /// Returns List<CarbLoadingDay> from the database
  const CarbLoadingDaysForRangeProvider._({
    required CarbLoadingDaysForRangeFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'carbLoadingDaysForRangeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingDaysForRangeHash();

  @override
  String toString() {
    return r'carbLoadingDaysForRangeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<dynamic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<dynamic>> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return carbLoadingDaysForRange(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbLoadingDaysForRangeProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbLoadingDaysForRangeHash() =>
    r'ae4446c121bc4909283a672fd986f5df9101a106';

/// Provider for getting carb loading days in a date range
/// Returns List<CarbLoadingDay> from the database

final class CarbLoadingDaysForRangeFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<dynamic>>,
          (DateTime, DateTime)
        > {
  const CarbLoadingDaysForRangeFamily._()
    : super(
        retry: null,
        name: r'carbLoadingDaysForRangeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting carb loading days in a date range
  /// Returns List<CarbLoadingDay> from the database

  CarbLoadingDaysForRangeProvider call(DateTime startDate, DateTime endDate) =>
      CarbLoadingDaysForRangeProvider._(
        argument: (startDate, endDate),
        from: this,
      );

  @override
  String toString() => r'carbLoadingDaysForRangeProvider';
}
