// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trial_reminder_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clock the reminder is timed against. A provider so tests can pin it;
/// the app never overrides it.

@ProviderFor(trialReminderClock)
const trialReminderClockProvider = TrialReminderClockProvider._();

/// The clock the reminder is timed against. A provider so tests can pin it;
/// the app never overrides it.

final class TrialReminderClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock the reminder is timed against. A provider so tests can pin it;
  /// the app never overrides it.
  const TrialReminderClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trialReminderClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trialReminderClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return trialReminderClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$trialReminderClockHash() =>
    r'e0cae0f64820cba10412f904431c1dec935f49ef';

@ProviderFor(trialReminderService)
const trialReminderServiceProvider = TrialReminderServiceProvider._();

final class TrialReminderServiceProvider
    extends
        $FunctionalProvider<
          TrialReminderService,
          TrialReminderService,
          TrialReminderService
        >
    with $Provider<TrialReminderService> {
  const TrialReminderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trialReminderServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trialReminderServiceHash();

  @$internal
  @override
  $ProviderElement<TrialReminderService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrialReminderService create(Ref ref) {
    return trialReminderService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrialReminderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrialReminderService>(value),
    );
  }
}

String _$trialReminderServiceHash() =>
    r'b2b503d70b09dd5741252f49b9332f252838041d';
