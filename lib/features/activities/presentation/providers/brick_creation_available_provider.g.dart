// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_creation_available_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider to check if brick creation is available for a given date
///
/// Returns true if:
/// - 2+ activities exist on the selected date
/// - Activities are of different sport types (not all the same sport)
///
/// Used to show/hide the "Create Brick" button in activities list

@ProviderFor(isBrickCreationAvailable)
const isBrickCreationAvailableProvider = IsBrickCreationAvailableFamily._();

/// Provider to check if brick creation is available for a given date
///
/// Returns true if:
/// - 2+ activities exist on the selected date
/// - Activities are of different sport types (not all the same sport)
///
/// Used to show/hide the "Create Brick" button in activities list

final class IsBrickCreationAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if brick creation is available for a given date
  ///
  /// Returns true if:
  /// - 2+ activities exist on the selected date
  /// - Activities are of different sport types (not all the same sport)
  ///
  /// Used to show/hide the "Create Brick" button in activities list
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
    r'173be7acf8527a8b10581b97b90f1d59ebcad0a2';

/// Provider to check if brick creation is available for a given date
///
/// Returns true if:
/// - 2+ activities exist on the selected date
/// - Activities are of different sport types (not all the same sport)
///
/// Used to show/hide the "Create Brick" button in activities list

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

  /// Provider to check if brick creation is available for a given date
  ///
  /// Returns true if:
  /// - 2+ activities exist on the selected date
  /// - Activities are of different sport types (not all the same sport)
  ///
  /// Used to show/hide the "Create Brick" button in activities list

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
