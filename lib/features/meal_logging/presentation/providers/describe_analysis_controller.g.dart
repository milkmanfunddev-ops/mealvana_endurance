// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'describe_analysis_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the Describe tab's last analysis for as long as Log a Meal is open
/// (testing-wave develop-2026-10 ticket 45, Finding 31-004).
///
/// `LogMealScreen` watches it, so it survives tab switches and the Review &
/// Log route pushed on top, and auto-dispose drops it when Log a Meal closes.
/// Back from Review and "Review again" re-open the stored result without a
/// second call, so seeing it again costs nothing. A changed input is a new
/// call (and a new token).

@ProviderFor(DescribeAnalysisController)
const describeAnalysisControllerProvider =
    DescribeAnalysisControllerProvider._();

/// Holds the Describe tab's last analysis for as long as Log a Meal is open
/// (testing-wave develop-2026-10 ticket 45, Finding 31-004).
///
/// `LogMealScreen` watches it, so it survives tab switches and the Review &
/// Log route pushed on top, and auto-dispose drops it when Log a Meal closes.
/// Back from Review and "Review again" re-open the stored result without a
/// second call, so seeing it again costs nothing. A changed input is a new
/// call (and a new token).
final class DescribeAnalysisControllerProvider
    extends
        $AsyncNotifierProvider<DescribeAnalysisController, DescribeAnalysis?> {
  /// Holds the Describe tab's last analysis for as long as Log a Meal is open
  /// (testing-wave develop-2026-10 ticket 45, Finding 31-004).
  ///
  /// `LogMealScreen` watches it, so it survives tab switches and the Review &
  /// Log route pushed on top, and auto-dispose drops it when Log a Meal closes.
  /// Back from Review and "Review again" re-open the stored result without a
  /// second call, so seeing it again costs nothing. A changed input is a new
  /// call (and a new token).
  const DescribeAnalysisControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'describeAnalysisControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$describeAnalysisControllerHash();

  @$internal
  @override
  DescribeAnalysisController create() => DescribeAnalysisController();
}

String _$describeAnalysisControllerHash() =>
    r'381750daee10bd1ca824364e256436a159a1bc8e';

/// Holds the Describe tab's last analysis for as long as Log a Meal is open
/// (testing-wave develop-2026-10 ticket 45, Finding 31-004).
///
/// `LogMealScreen` watches it, so it survives tab switches and the Review &
/// Log route pushed on top, and auto-dispose drops it when Log a Meal closes.
/// Back from Review and "Review again" re-open the stored result without a
/// second call, so seeing it again costs nothing. A changed input is a new
/// call (and a new token).

abstract class _$DescribeAnalysisController
    extends $AsyncNotifier<DescribeAnalysis?> {
  FutureOr<DescribeAnalysis?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<DescribeAnalysis?>, DescribeAnalysis?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DescribeAnalysis?>, DescribeAnalysis?>,
              AsyncValue<DescribeAnalysis?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
