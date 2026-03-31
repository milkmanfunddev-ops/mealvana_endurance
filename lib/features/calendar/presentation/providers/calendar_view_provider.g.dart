// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_view_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Calendar view mode state provider
///
/// Manages the state of the calendar view mode (week vs month).
/// Used by both the FloatingActionButtonsBar (to toggle view) and
/// the ActivitiesListScreen (to render the appropriate calendar).
///
/// Example usage:
/// ```dart
/// // In FloatingActionButtonsBar:
/// onCalendarTap: () {
///   ref.read(calendarViewNotifierProvider.notifier).toggleView();
/// }
///
/// // In ActivitiesListScreen:
/// final calendarMode = ref.watch(calendarViewNotifierProvider);
/// if (calendarMode == CalendarViewMode.week) {
///   return CalendarWeekViewKyle(...);
/// } else {
///   return CalendarMonthViewKyle(...);
/// }
/// ```

@ProviderFor(CalendarViewNotifier)
const calendarViewProvider = CalendarViewNotifierProvider._();

/// Calendar view mode state provider
///
/// Manages the state of the calendar view mode (week vs month).
/// Used by both the FloatingActionButtonsBar (to toggle view) and
/// the ActivitiesListScreen (to render the appropriate calendar).
///
/// Example usage:
/// ```dart
/// // In FloatingActionButtonsBar:
/// onCalendarTap: () {
///   ref.read(calendarViewNotifierProvider.notifier).toggleView();
/// }
///
/// // In ActivitiesListScreen:
/// final calendarMode = ref.watch(calendarViewNotifierProvider);
/// if (calendarMode == CalendarViewMode.week) {
///   return CalendarWeekViewKyle(...);
/// } else {
///   return CalendarMonthViewKyle(...);
/// }
/// ```
final class CalendarViewNotifierProvider
    extends $NotifierProvider<CalendarViewNotifier, CalendarViewMode> {
  /// Calendar view mode state provider
  ///
  /// Manages the state of the calendar view mode (week vs month).
  /// Used by both the FloatingActionButtonsBar (to toggle view) and
  /// the ActivitiesListScreen (to render the appropriate calendar).
  ///
  /// Example usage:
  /// ```dart
  /// // In FloatingActionButtonsBar:
  /// onCalendarTap: () {
  ///   ref.read(calendarViewNotifierProvider.notifier).toggleView();
  /// }
  ///
  /// // In ActivitiesListScreen:
  /// final calendarMode = ref.watch(calendarViewNotifierProvider);
  /// if (calendarMode == CalendarViewMode.week) {
  ///   return CalendarWeekViewKyle(...);
  /// } else {
  ///   return CalendarMonthViewKyle(...);
  /// }
  /// ```
  const CalendarViewNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarViewNotifierHash();

  @$internal
  @override
  CalendarViewNotifier create() => CalendarViewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarViewMode>(value),
    );
  }
}

String _$calendarViewNotifierHash() =>
    r'904015bb1089463cbd0ae18796490cb7ada50343';

/// Calendar view mode state provider
///
/// Manages the state of the calendar view mode (week vs month).
/// Used by both the FloatingActionButtonsBar (to toggle view) and
/// the ActivitiesListScreen (to render the appropriate calendar).
///
/// Example usage:
/// ```dart
/// // In FloatingActionButtonsBar:
/// onCalendarTap: () {
///   ref.read(calendarViewNotifierProvider.notifier).toggleView();
/// }
///
/// // In ActivitiesListScreen:
/// final calendarMode = ref.watch(calendarViewNotifierProvider);
/// if (calendarMode == CalendarViewMode.week) {
///   return CalendarWeekViewKyle(...);
/// } else {
///   return CalendarMonthViewKyle(...);
/// }
/// ```

abstract class _$CalendarViewNotifier extends $Notifier<CalendarViewMode> {
  CalendarViewMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CalendarViewMode, CalendarViewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarViewMode, CalendarViewMode>,
              CalendarViewMode,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
