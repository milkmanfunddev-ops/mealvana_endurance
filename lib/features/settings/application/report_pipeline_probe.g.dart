// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_pipeline_probe.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reportPipelineProbe)
const reportPipelineProbeProvider = ReportPipelineProbeProvider._();

final class ReportPipelineProbeProvider
    extends
        $FunctionalProvider<
          ReportPipelineProbe,
          ReportPipelineProbe,
          ReportPipelineProbe
        >
    with $Provider<ReportPipelineProbe> {
  const ReportPipelineProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportPipelineProbeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportPipelineProbeHash();

  @$internal
  @override
  $ProviderElement<ReportPipelineProbe> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReportPipelineProbe create(Ref ref) {
    return reportPipelineProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportPipelineProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportPipelineProbe>(value),
    );
  }
}

String _$reportPipelineProbeHash() =>
    r'9c4177db523b0860de398c706e84e02040d14d87';
