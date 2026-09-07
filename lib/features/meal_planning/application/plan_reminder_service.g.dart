// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_reminder_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(planReminderService)
const planReminderServiceProvider = PlanReminderServiceProvider._();

final class PlanReminderServiceProvider
    extends
        $FunctionalProvider<
          PlanReminderService,
          PlanReminderService,
          PlanReminderService
        >
    with $Provider<PlanReminderService> {
  const PlanReminderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planReminderServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planReminderServiceHash();

  @$internal
  @override
  $ProviderElement<PlanReminderService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlanReminderService create(Ref ref) {
    return planReminderService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanReminderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanReminderService>(value),
    );
  }
}

String _$planReminderServiceHash() =>
    r'764fa7ac425669eeb74afdd043555f5753087b75';
