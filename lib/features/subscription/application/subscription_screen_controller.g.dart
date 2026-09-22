// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_screen_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a purchase made through Upgrade
/// turns "ended" into the running plan while the screen is open.

@ProviderFor(SubscriptionScreenController)
const subscriptionScreenControllerProvider =
    SubscriptionScreenControllerProvider._();

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a purchase made through Upgrade
/// turns "ended" into the running plan while the screen is open.
final class SubscriptionScreenControllerProvider
    extends
        $AsyncNotifierProvider<
          SubscriptionScreenController,
          SubscriptionScreenState
        > {
  /// The Subscription screen in Settings (mp-495): the plan's status from the
  /// status provider (RevenueCat, mp-279), whether there is a store
  /// subscription to manage, and where Manage subscription goes.
  ///
  /// Rebuilds whenever the status does, so a purchase made through Upgrade
  /// turns "ended" into the running plan while the screen is open.
  const SubscriptionScreenControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionScreenControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionScreenControllerHash();

  @$internal
  @override
  SubscriptionScreenController create() => SubscriptionScreenController();
}

String _$subscriptionScreenControllerHash() =>
    r'd9b13d13cf967ba6fb72c4a5905db2114441cd67';

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a purchase made through Upgrade
/// turns "ended" into the running plan while the screen is open.

abstract class _$SubscriptionScreenController
    extends $AsyncNotifier<SubscriptionScreenState> {
  FutureOr<SubscriptionScreenState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SubscriptionScreenState>,
              SubscriptionScreenState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SubscriptionScreenState>,
                SubscriptionScreenState
              >,
              AsyncValue<SubscriptionScreenState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
