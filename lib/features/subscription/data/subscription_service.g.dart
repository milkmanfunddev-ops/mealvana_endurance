// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kept alive for the same reason as [revenueCatServiceProvider]: it wraps
/// the process-wide [Purchases] singleton and owns the one CustomerInfo
/// listener slot; an autoDispose instance would drop that listener with the
/// last watcher.

@ProviderFor(subscriptionService)
const subscriptionServiceProvider = SubscriptionServiceProvider._();

/// Kept alive for the same reason as [revenueCatServiceProvider]: it wraps
/// the process-wide [Purchases] singleton and owns the one CustomerInfo
/// listener slot; an autoDispose instance would drop that listener with the
/// last watcher.

final class SubscriptionServiceProvider
    extends
        $FunctionalProvider<
          SubscriptionService,
          SubscriptionService,
          SubscriptionService
        >
    with $Provider<SubscriptionService> {
  /// Kept alive for the same reason as [revenueCatServiceProvider]: it wraps
  /// the process-wide [Purchases] singleton and owns the one CustomerInfo
  /// listener slot; an autoDispose instance would drop that listener with the
  /// last watcher.
  const SubscriptionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionServiceHash();

  @$internal
  @override
  $ProviderElement<SubscriptionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionService create(Ref ref) {
    return subscriptionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionService>(value),
    );
  }
}

String _$subscriptionServiceHash() =>
    r'd9ca720981f90a17684e79f5da223e5b8605f872';
