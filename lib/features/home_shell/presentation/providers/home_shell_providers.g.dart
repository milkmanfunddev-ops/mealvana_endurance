// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_shell_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Distinct `log_date`s carrying ≥ 1 non-deleted meal log in the inclusive
/// `'yyyy-MM-dd'` range — the tint channel's rollup (calendar-sheet.md Q2,
/// binary v1). Empty when there is no authenticated user.

@ProviderFor(homeShellLoggedDates)
const homeShellLoggedDatesProvider = HomeShellLoggedDatesFamily._();

/// Distinct `log_date`s carrying ≥ 1 non-deleted meal log in the inclusive
/// `'yyyy-MM-dd'` range — the tint channel's rollup (calendar-sheet.md Q2,
/// binary v1). Empty when there is no authenticated user.

final class HomeShellLoggedDatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// Distinct `log_date`s carrying ≥ 1 non-deleted meal log in the inclusive
  /// `'yyyy-MM-dd'` range — the tint channel's rollup (calendar-sheet.md Q2,
  /// binary v1). Empty when there is no authenticated user.
  const HomeShellLoggedDatesProvider._({
    required HomeShellLoggedDatesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'homeShellLoggedDatesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeShellLoggedDatesHash();

  @override
  String toString() {
    return r'homeShellLoggedDatesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return homeShellLoggedDates(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeShellLoggedDatesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeShellLoggedDatesHash() =>
    r'7cc73afc0dfd72f1a764d3b8ed5a482a1e8330dc';

/// Distinct `log_date`s carrying ≥ 1 non-deleted meal log in the inclusive
/// `'yyyy-MM-dd'` range — the tint channel's rollup (calendar-sheet.md Q2,
/// binary v1). Empty when there is no authenticated user.

final class HomeShellLoggedDatesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Set<String>>, (String, String)> {
  const HomeShellLoggedDatesFamily._()
    : super(
        retry: null,
        name: r'homeShellLoggedDatesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Distinct `log_date`s carrying ≥ 1 non-deleted meal log in the inclusive
  /// `'yyyy-MM-dd'` range — the tint channel's rollup (calendar-sheet.md Q2,
  /// binary v1). Empty when there is no authenticated user.

  HomeShellLoggedDatesProvider call(String startDate, String endDate) =>
      HomeShellLoggedDatesProvider._(
        argument: (startDate, endDate),
        from: this,
      );

  @override
  String toString() => r'homeShellLoggedDatesProvider';
}

/// The calendar sheet's cell data for the month starting at [month]
/// (midnight-normalized first-of-month).

@ProviderFor(homeShellCalendarMonth)
const homeShellCalendarMonthProvider = HomeShellCalendarMonthFamily._();

/// The calendar sheet's cell data for the month starting at [month]
/// (midnight-normalized first-of-month).

final class HomeShellCalendarMonthProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, KyleCalendarDayData>>,
          Map<int, KyleCalendarDayData>,
          FutureOr<Map<int, KyleCalendarDayData>>
        >
    with
        $FutureModifier<Map<int, KyleCalendarDayData>>,
        $FutureProvider<Map<int, KyleCalendarDayData>> {
  /// The calendar sheet's cell data for the month starting at [month]
  /// (midnight-normalized first-of-month).
  const HomeShellCalendarMonthProvider._({
    required HomeShellCalendarMonthFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'homeShellCalendarMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeShellCalendarMonthHash();

  @override
  String toString() {
    return r'homeShellCalendarMonthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, KyleCalendarDayData>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, KyleCalendarDayData>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return homeShellCalendarMonth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeShellCalendarMonthProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeShellCalendarMonthHash() =>
    r'daa3fbb7e393a4a5745c8128582719d0759b77a0';

/// The calendar sheet's cell data for the month starting at [month]
/// (midnight-normalized first-of-month).

final class HomeShellCalendarMonthFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<int, KyleCalendarDayData>>,
          DateTime
        > {
  const HomeShellCalendarMonthFamily._()
    : super(
        retry: null,
        name: r'homeShellCalendarMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The calendar sheet's cell data for the month starting at [month]
  /// (midnight-normalized first-of-month).

  HomeShellCalendarMonthProvider call(DateTime month) =>
      HomeShellCalendarMonthProvider._(argument: month, from: this);

  @override
  String toString() => r'homeShellCalendarMonthProvider';
}
