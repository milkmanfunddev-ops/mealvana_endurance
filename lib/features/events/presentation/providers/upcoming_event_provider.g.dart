// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upcoming_event_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for next upcoming event from a specific date

@ProviderFor(nextUpcomingEventFromDate)
const nextUpcomingEventFromDateProvider = NextUpcomingEventFromDateFamily._();

/// Provider for next upcoming event from a specific date

final class NextUpcomingEventFromDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Event event, DateTime eventDate})?>,
          ({Event event, DateTime eventDate})?,
          FutureOr<({Event event, DateTime eventDate})?>
        >
    with
        $FutureModifier<({Event event, DateTime eventDate})?>,
        $FutureProvider<({Event event, DateTime eventDate})?> {
  /// Provider for next upcoming event from a specific date
  const NextUpcomingEventFromDateProvider._({
    required NextUpcomingEventFromDateFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'nextUpcomingEventFromDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nextUpcomingEventFromDateHash();

  @override
  String toString() {
    return r'nextUpcomingEventFromDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<({Event event, DateTime eventDate})?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Event event, DateTime eventDate})?> create(Ref ref) {
    final argument = this.argument as DateTime;
    return nextUpcomingEventFromDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NextUpcomingEventFromDateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nextUpcomingEventFromDateHash() =>
    r'dbd5954e028822653d7bd899c74cfb037d9fb14e';

/// Provider for next upcoming event from a specific date

final class NextUpcomingEventFromDateFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({Event event, DateTime eventDate})?>,
          DateTime
        > {
  const NextUpcomingEventFromDateFamily._()
    : super(
        retry: null,
        name: r'nextUpcomingEventFromDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for next upcoming event from a specific date

  NextUpcomingEventFromDateProvider call(DateTime fromDate) =>
      NextUpcomingEventFromDateProvider._(argument: fromDate, from: this);

  @override
  String toString() => r'nextUpcomingEventFromDateProvider';
}
