// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_creation_available_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the Brick entry point should be offered for a given day.
///
/// Brick redesign (Notion 3a7e3fdb): the Brick pill only appears when 2+
/// *adjacent* brick-eligible workouts exist. Eligibility is limited to the
/// three triathlon disciplines — a strength or foam-rolling activity must not
/// be groupable.
///
/// [activities] must arrive in the order they appear on the timeline
/// (chronological); adjacency is positional over the day's *workout*
/// sequence, so the caller's ordering is load-bearing. A meal logged between
/// two workouts does not break their adjacency — an ineligible workout
/// (strength, an existing brick) does.

@ProviderFor(isBrickCreationAvailable)
const isBrickCreationAvailableProvider = IsBrickCreationAvailableFamily._();

/// Whether the Brick entry point should be offered for a given day.
///
/// Brick redesign (Notion 3a7e3fdb): the Brick pill only appears when 2+
/// *adjacent* brick-eligible workouts exist. Eligibility is limited to the
/// three triathlon disciplines — a strength or foam-rolling activity must not
/// be groupable.
///
/// [activities] must arrive in the order they appear on the timeline
/// (chronological); adjacency is positional over the day's *workout*
/// sequence, so the caller's ordering is load-bearing. A meal logged between
/// two workouts does not break their adjacency — an ineligible workout
/// (strength, an existing brick) does.

final class IsBrickCreationAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the Brick entry point should be offered for a given day.
  ///
  /// Brick redesign (Notion 3a7e3fdb): the Brick pill only appears when 2+
  /// *adjacent* brick-eligible workouts exist. Eligibility is limited to the
  /// three triathlon disciplines — a strength or foam-rolling activity must not
  /// be groupable.
  ///
  /// [activities] must arrive in the order they appear on the timeline
  /// (chronological); adjacency is positional over the day's *workout*
  /// sequence, so the caller's ordering is load-bearing. A meal logged between
  /// two workouts does not break their adjacency — an ineligible workout
  /// (strength, an existing brick) does.
  const IsBrickCreationAvailableProvider._({
    required IsBrickCreationAvailableFamily super.from,
    required ({List<Activity> activities, DateTime selectedDate})
    super.argument,
  }) : super(
         retry: null,
         name: r'isBrickCreationAvailableProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isBrickCreationAvailableHash();

  @override
  String toString() {
    return r'isBrickCreationAvailableProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument =
        this.argument as ({List<Activity> activities, DateTime selectedDate});
    return isBrickCreationAvailable(
      ref,
      activities: argument.activities,
      selectedDate: argument.selectedDate,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsBrickCreationAvailableProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isBrickCreationAvailableHash() =>
    r'f74a159a75919501969b765aabaccd9454730bc6';

/// Whether the Brick entry point should be offered for a given day.
///
/// Brick redesign (Notion 3a7e3fdb): the Brick pill only appears when 2+
/// *adjacent* brick-eligible workouts exist. Eligibility is limited to the
/// three triathlon disciplines — a strength or foam-rolling activity must not
/// be groupable.
///
/// [activities] must arrive in the order they appear on the timeline
/// (chronological); adjacency is positional over the day's *workout*
/// sequence, so the caller's ordering is load-bearing. A meal logged between
/// two workouts does not break their adjacency — an ineligible workout
/// (strength, an existing brick) does.

final class IsBrickCreationAvailableFamily extends $Family
    with
        $FunctionalFamilyOverride<
          bool,
          ({List<Activity> activities, DateTime selectedDate})
        > {
  const IsBrickCreationAvailableFamily._()
    : super(
        retry: null,
        name: r'isBrickCreationAvailableProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether the Brick entry point should be offered for a given day.
  ///
  /// Brick redesign (Notion 3a7e3fdb): the Brick pill only appears when 2+
  /// *adjacent* brick-eligible workouts exist. Eligibility is limited to the
  /// three triathlon disciplines — a strength or foam-rolling activity must not
  /// be groupable.
  ///
  /// [activities] must arrive in the order they appear on the timeline
  /// (chronological); adjacency is positional over the day's *workout*
  /// sequence, so the caller's ordering is load-bearing. A meal logged between
  /// two workouts does not break their adjacency — an ineligible workout
  /// (strength, an existing brick) does.

  IsBrickCreationAvailableProvider call({
    required List<Activity> activities,
    required DateTime selectedDate,
  }) => IsBrickCreationAvailableProvider._(
    argument: (activities: activities, selectedDate: selectedDate),
    from: this,
  );

  @override
  String toString() => r'isBrickCreationAvailableProvider';
}
