import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/app_external_deps.dart';

part 'diary_session.g.dart';

/// One visit to Log a Meal (the "diary"), from open to close, for the
/// `diary_closed` analytics event: how long the athlete stayed and how many
/// meals actually landed.
///
/// The session outlives the screen on purpose. Describe and photo analysis
/// close Log a Meal as Review & Log opens, before the save; the session is
/// handed off to Review & Log and closes when that screen does, so the save
/// there is counted (testing-wave 24-002). Meals are counted by
/// [MealLogController] on each successful write, whichever surface made it
/// (27-003: the Manual tab's saves were never counted).
///
/// Plain mutable fields rather than provider state: both closes run from a
/// widget's `dispose`, where changing provider state is not allowed.
class DiarySession {
  DiarySession({required AnalyticsTracker analytics, DateTime Function()? now})
    : _analytics = analytics,
      _now = now ?? DateTime.now;

  final AnalyticsTracker _analytics;
  final DateTime Function() _now;

  DateTime? _openedAt;
  String? _logDate;
  int _itemsLogged = 0;
  bool _handedOff = false;

  bool get isOpen => _openedAt != null;

  /// Log a Meal opened for [logDate]. Replaces any session still open.
  void open({required String logDate}) {
    _openedAt = _now();
    _logDate = logDate;
    _itemsLogged = 0;
    _handedOff = false;
  }

  /// [count] meals were written while the diary is open. No-op otherwise.
  void recordLogged([int count = 1]) {
    if (isOpen) _itemsLogged += count;
  }

  /// Describe or photo analysis is opening Review & Log, which will close
  /// the session instead of Log a Meal.
  void handOff() {
    if (isOpen) _handedOff = true;
  }

  /// Log a Meal is closing. Closes the session unless it was handed off.
  void closeDiary() {
    if (isOpen && !_handedOff) _close();
  }

  /// Review & Log is closing. Closes the session only if it was handed off,
  /// so a Review & Log reached from outside the diary tracks nothing.
  void closeHandOff() {
    if (isOpen && _handedOff) _close();
  }

  void _close() {
    final openedAt = _openedAt!;
    final properties = {
      'duration_sec': _now().difference(openedAt).inSeconds,
      // 0 after a long stay is the signal that the diary looked but didn't
      // land.
      'items_logged': _itemsLogged,
      'log_date': _logDate,
    };
    _openedAt = null;
    _logDate = null;
    _itemsLogged = 0;
    _handedOff = false;
    try {
      _analytics.track('diary_closed', properties: properties);
    } catch (_) {}
  }
}

/// App-lifetime: a session spans Log a Meal and Review & Log, and the meal
/// controller that counts into it is auto-dispose.
@Riverpod(keepAlive: true)
DiarySession diarySession(Ref ref) =>
    DiarySession(analytics: ref.watch(appExternalDepsProvider).analytics);
