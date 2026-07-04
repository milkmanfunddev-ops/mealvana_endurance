// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_meal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Accumulator controller for the in-progress build-a-meal draft, scoped to
/// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
/// remaining watchers), so re-opening the sheet always starts a fresh draft.

@ProviderFor(DraftMealController)
const draftMealControllerProvider = DraftMealControllerFamily._();

/// Accumulator controller for the in-progress build-a-meal draft, scoped to
/// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
/// remaining watchers), so re-opening the sheet always starts a fresh draft.
final class DraftMealControllerProvider
    extends $NotifierProvider<DraftMealController, DraftMealState> {
  /// Accumulator controller for the in-progress build-a-meal draft, scoped to
  /// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
  /// remaining watchers), so re-opening the sheet always starts a fresh draft.
  const DraftMealControllerProvider._({
    required DraftMealControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'draftMealControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$draftMealControllerHash();

  @override
  String toString() {
    return r'draftMealControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DraftMealController create() => DraftMealController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DraftMealState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DraftMealState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DraftMealControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$draftMealControllerHash() =>
    r'1736964733a8f4443dee8643cb362461b301c791';

/// Accumulator controller for the in-progress build-a-meal draft, scoped to
/// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
/// remaining watchers), so re-opening the sheet always starts a fresh draft.

final class DraftMealControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DraftMealController,
          DraftMealState,
          DraftMealState,
          DraftMealState,
          String
        > {
  const DraftMealControllerFamily._()
    : super(
        retry: null,
        name: r'draftMealControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Accumulator controller for the in-progress build-a-meal draft, scoped to
  /// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
  /// remaining watchers), so re-opening the sheet always starts a fresh draft.

  DraftMealControllerProvider call(String logDate) =>
      DraftMealControllerProvider._(argument: logDate, from: this);

  @override
  String toString() => r'draftMealControllerProvider';
}

/// Accumulator controller for the in-progress build-a-meal draft, scoped to
/// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
/// remaining watchers), so re-opening the sheet always starts a fresh draft.

abstract class _$DraftMealController extends $Notifier<DraftMealState> {
  late final _$args = ref.$arg as String;
  String get logDate => _$args;

  DraftMealState build(String logDate);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<DraftMealState, DraftMealState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DraftMealState, DraftMealState>,
              DraftMealState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
