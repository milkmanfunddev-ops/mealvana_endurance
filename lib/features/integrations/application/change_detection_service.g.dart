// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_detection_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for detecting changes between local activities and remote provider workouts
///
/// Compares local activities with remote workouts from providers (Final Surge, Training Peaks)
/// to determine what needs to be inserted, updated, or soft-deleted.
///
/// Schedule change significance criteria:
/// - Time changed by > 30 minutes
/// - Date changed (different day)
/// - Duration changed by > 15 minutes
/// - Distance changed by > 10%

@ProviderFor(changeDetectionService)
const changeDetectionServiceProvider = ChangeDetectionServiceProvider._();

/// Service for detecting changes between local activities and remote provider workouts
///
/// Compares local activities with remote workouts from providers (Final Surge, Training Peaks)
/// to determine what needs to be inserted, updated, or soft-deleted.
///
/// Schedule change significance criteria:
/// - Time changed by > 30 minutes
/// - Date changed (different day)
/// - Duration changed by > 15 minutes
/// - Distance changed by > 10%

final class ChangeDetectionServiceProvider
    extends
        $FunctionalProvider<
          ChangeDetectionService,
          ChangeDetectionService,
          ChangeDetectionService
        >
    with $Provider<ChangeDetectionService> {
  /// Service for detecting changes between local activities and remote provider workouts
  ///
  /// Compares local activities with remote workouts from providers (Final Surge, Training Peaks)
  /// to determine what needs to be inserted, updated, or soft-deleted.
  ///
  /// Schedule change significance criteria:
  /// - Time changed by > 30 minutes
  /// - Date changed (different day)
  /// - Duration changed by > 15 minutes
  /// - Distance changed by > 10%
  const ChangeDetectionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeDetectionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeDetectionServiceHash();

  @$internal
  @override
  $ProviderElement<ChangeDetectionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChangeDetectionService create(Ref ref) {
    return changeDetectionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeDetectionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeDetectionService>(value),
    );
  }
}

String _$changeDetectionServiceHash() =>
    r'37512575f10474e6862c7755f0659b9db5ed3db0';
