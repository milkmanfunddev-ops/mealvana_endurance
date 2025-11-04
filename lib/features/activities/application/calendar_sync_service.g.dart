// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(calendarSyncService)
const calendarSyncServiceProvider = CalendarSyncServiceProvider._();

final class CalendarSyncServiceProvider
    extends
        $FunctionalProvider<
          CalendarSyncService,
          CalendarSyncService,
          CalendarSyncService
        >
    with $Provider<CalendarSyncService> {
  const CalendarSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarSyncServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarSyncServiceHash();

  @$internal
  @override
  $ProviderElement<CalendarSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarSyncService create(Ref ref) {
    return calendarSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarSyncService>(value),
    );
  }
}

String _$calendarSyncServiceHash() =>
    r'0192b5b847d1db72ef41542cbd70528e56dbe9b5';
