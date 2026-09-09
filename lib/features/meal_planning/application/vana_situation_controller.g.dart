// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_situation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where Vana looks to find out what the athlete is looking at.
///
/// Screens in the table report as they come into view; the value rides the next
/// message and is never stored. Leaving a screen does NOT clear it: opening
/// Vana means leaving the screen you were asking about, and the Vana routes
/// report nothing, so the last reported screen is the right answer. A report
/// older than [vanaSituationTtl] reads as no Situation at all.
///
/// Kept alive: the screen that set it is underneath the sheet, not above it.

@ProviderFor(VanaSituationController)
const vanaSituationControllerProvider = VanaSituationControllerProvider._();

/// Where Vana looks to find out what the athlete is looking at.
///
/// Screens in the table report as they come into view; the value rides the next
/// message and is never stored. Leaving a screen does NOT clear it: opening
/// Vana means leaving the screen you were asking about, and the Vana routes
/// report nothing, so the last reported screen is the right answer. A report
/// older than [vanaSituationTtl] reads as no Situation at all.
///
/// Kept alive: the screen that set it is underneath the sheet, not above it.
final class VanaSituationControllerProvider
    extends $NotifierProvider<VanaSituationController, VanaSituation?> {
  /// Where Vana looks to find out what the athlete is looking at.
  ///
  /// Screens in the table report as they come into view; the value rides the next
  /// message and is never stored. Leaving a screen does NOT clear it: opening
  /// Vana means leaving the screen you were asking about, and the Vana routes
  /// report nothing, so the last reported screen is the right answer. A report
  /// older than [vanaSituationTtl] reads as no Situation at all.
  ///
  /// Kept alive: the screen that set it is underneath the sheet, not above it.
  const VanaSituationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaSituationControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaSituationControllerHash();

  @$internal
  @override
  VanaSituationController create() => VanaSituationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaSituation? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaSituation?>(value),
    );
  }
}

String _$vanaSituationControllerHash() =>
    r'0f53150344ae62c94d46028767690153519efa35';

/// Where Vana looks to find out what the athlete is looking at.
///
/// Screens in the table report as they come into view; the value rides the next
/// message and is never stored. Leaving a screen does NOT clear it: opening
/// Vana means leaving the screen you were asking about, and the Vana routes
/// report nothing, so the last reported screen is the right answer. A report
/// older than [vanaSituationTtl] reads as no Situation at all.
///
/// Kept alive: the screen that set it is underneath the sheet, not above it.

abstract class _$VanaSituationController extends $Notifier<VanaSituation?> {
  VanaSituation? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<VanaSituation?, VanaSituation?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VanaSituation?, VanaSituation?>,
              VanaSituation?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
