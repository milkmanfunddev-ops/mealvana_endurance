// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_coach_banner_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True when the current user has at least one non-deleted meal log created
/// in the last 14 days (local Drift query — no network required).
///
/// Used by [AiCoachBanner] to choose between baseline-tutorial copy and
/// default copy.  Degrades gracefully:
///   - loading  → false (show tutorial copy until data is available)
///   - no user  → false
///   - error    → false (never throws)

@ProviderFor(aiCoachHasBaseline)
const aiCoachHasBaselineProvider = AiCoachHasBaselineProvider._();

/// True when the current user has at least one non-deleted meal log created
/// in the last 14 days (local Drift query — no network required).
///
/// Used by [AiCoachBanner] to choose between baseline-tutorial copy and
/// default copy.  Degrades gracefully:
///   - loading  → false (show tutorial copy until data is available)
///   - no user  → false
///   - error    → false (never throws)

final class AiCoachHasBaselineProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// True when the current user has at least one non-deleted meal log created
  /// in the last 14 days (local Drift query — no network required).
  ///
  /// Used by [AiCoachBanner] to choose between baseline-tutorial copy and
  /// default copy.  Degrades gracefully:
  ///   - loading  → false (show tutorial copy until data is available)
  ///   - no user  → false
  ///   - error    → false (never throws)
  const AiCoachHasBaselineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiCoachHasBaselineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiCoachHasBaselineHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return aiCoachHasBaseline(ref);
  }
}

String _$aiCoachHasBaselineHash() =>
    r'699f0f7a2218a2411e2d6556d4e41aa78e59a9bc';
