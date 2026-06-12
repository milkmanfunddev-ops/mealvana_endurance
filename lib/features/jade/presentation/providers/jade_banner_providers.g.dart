// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jade_banner_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True when the current user has at least one non-deleted meal log created
/// in the last 14 days (local Drift query — no network required).
///
/// Used by [JadeCoachBanner] to choose between baseline-tutorial copy and
/// default copy.  Degrades gracefully:
///   - loading  → false (show tutorial copy until data is available)
///   - no user  → false
///   - error    → false (never throws)

@ProviderFor(jadeHasBaseline)
const jadeHasBaselineProvider = JadeHasBaselineProvider._();

/// True when the current user has at least one non-deleted meal log created
/// in the last 14 days (local Drift query — no network required).
///
/// Used by [JadeCoachBanner] to choose between baseline-tutorial copy and
/// default copy.  Degrades gracefully:
///   - loading  → false (show tutorial copy until data is available)
///   - no user  → false
///   - error    → false (never throws)

final class JadeHasBaselineProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// True when the current user has at least one non-deleted meal log created
  /// in the last 14 days (local Drift query — no network required).
  ///
  /// Used by [JadeCoachBanner] to choose between baseline-tutorial copy and
  /// default copy.  Degrades gracefully:
  ///   - loading  → false (show tutorial copy until data is available)
  ///   - no user  → false
  ///   - error    → false (never throws)
  const JadeHasBaselineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jadeHasBaselineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jadeHasBaselineHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return jadeHasBaseline(ref);
  }
}

String _$jadeHasBaselineHash() => r'8dc908e0453195647726343d2a9b164e0e149484';
