// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'distance_page_gut_entry_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns

@ProviderFor(DistancePageGutEntryController)
const distancePageGutEntryControllerProvider =
    DistancePageGutEntryControllerProvider._();

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns
final class DistancePageGutEntryControllerProvider
    extends
        $AsyncNotifierProvider<
          DistancePageGutEntryController,
          DistancePageGutEntryState
        > {
  /// Controller for distance page gut entry screen
  /// FOA COMPLIANT: Contains ALL business logic, no UI concerns
  const DistancePageGutEntryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'distancePageGutEntryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$distancePageGutEntryControllerHash();

  @$internal
  @override
  DistancePageGutEntryController create() => DistancePageGutEntryController();
}

String _$distancePageGutEntryControllerHash() =>
    r'9d6ef82186c41df49a315c9acd8b7a77fa07723d';

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns

abstract class _$DistancePageGutEntryController
    extends $AsyncNotifier<DistancePageGutEntryState> {
  FutureOr<DistancePageGutEntryState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DistancePageGutEntryState>,
              DistancePageGutEntryState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DistancePageGutEntryState>,
                DistancePageGutEntryState
              >,
              AsyncValue<DistancePageGutEntryState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
