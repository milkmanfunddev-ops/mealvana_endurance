import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/logging_service.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_athlete_relationship.dart';

part 'coach_reports_controller.g.dart';

/// Summary data for a single athlete over a date range
class AthleteReportSummary {
  final CoachAthleteRelationship relationship;
  final int activitiesPlanned;
  final int activitiesCompleted;
  final int upcomingEventsCount;
  final int unreadMessagesCount;
  final DateTime? nextEventDate;
  final String? nextEventName;

  const AthleteReportSummary({
    required this.relationship,
    this.activitiesPlanned = 0,
    this.activitiesCompleted = 0,
    this.upcomingEventsCount = 0,
    this.unreadMessagesCount = 0,
    this.nextEventDate,
    this.nextEventName,
  });

  double get completionRate =>
      activitiesPlanned > 0 ? activitiesCompleted / activitiesPlanned : 0;
}

/// State for coach reports
class CoachReportsState {
  final List<AthleteReportSummary> summaries;
  final DateRange dateRange;
  final bool isLoading;
  final String? error;

  const CoachReportsState({
    this.summaries = const [],
    this.dateRange = DateRange.thisWeek,
    this.isLoading = false,
    this.error,
  });

  CoachReportsState copyWith({
    List<AthleteReportSummary>? summaries,
    DateRange? dateRange,
    bool? isLoading,
    String? error,
  }) {
    return CoachReportsState(
      summaries: summaries ?? this.summaries,
      dateRange: dateRange ?? this.dateRange,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

enum DateRange {
  thisWeek('This Week'),
  lastWeek('Last Week');

  const DateRange(this.label);
  final String label;

  DateTime get start {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday; // 1=Monday, 7=Sunday
    switch (this) {
      case DateRange.thisWeek:
        return today.subtract(Duration(days: weekday - 1));
      case DateRange.lastWeek:
        return today.subtract(Duration(days: weekday + 6));
    }
  }

  DateTime get end {
    switch (this) {
      case DateRange.thisWeek:
        return start.add(const Duration(days: 7));
      case DateRange.lastWeek:
        return start.add(const Duration(days: 7));
    }
  }
}

@riverpod
class CoachReportsController extends _$CoachReportsController {
  CoachService get _coachService => ref.read(coachServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<CoachReportsState> build() async {
    return _loadReports(DateRange.thisWeek);
  }

  Future<CoachReportsState> _loadReports(DateRange range) async {
    try {
      final athletes = await _coachService.getMyAthletes();
      final db = ref.read(appDatabaseProvider);
      final now = DateTime.now();
      final twoWeeksFromNow = now.add(const Duration(days: 14));

      final summaries = <AthleteReportSummary>[];

      for (final athlete in athletes) {
        final athleteId = athlete.athleteUserId;
        if (athleteId.isEmpty) continue;

        // Count activities in date range
        final activities = await (db.select(db.activitiesTable)
              ..where((t) =>
                  t.userId.equals(athleteId) &
                  t.deletedAt.isNull() &
                  t.scheduledDateTime
                      .isBiggerOrEqualValue(range.start) &
                  t.scheduledDateTime.isSmallerThanValue(range.end)))
            .get();

        final planned = activities.length;
        final completed = activities
            .where((a) =>
                a.completedAt != null ||
                a.status == 'completed')
            .length;

        // Count upcoming events (next 14 days)
        final events = await (db.select(db.eventsTable)
              ..where((t) =>
                  t.userId.equals(athleteId) &
                  t.eventDate.isBiggerOrEqualValue(now) &
                  t.eventDate
                      .isSmallerThanValue(twoWeeksFromNow))
              ..orderBy([(t) => OrderingTerm.asc(t.eventDate)]))
            .get();

        // Count unread messages
        final messages = await _coachService.getConversation(
          coachUserId: athlete.coachUserId,
          athleteUserId: athleteId,
        );
        final unread = messages
            .where((m) =>
                m.senderUserId == athleteId && !m.isRead)
            .length;

        summaries.add(AthleteReportSummary(
          relationship: athlete,
          activitiesPlanned: planned,
          activitiesCompleted: completed,
          upcomingEventsCount: events.length,
          unreadMessagesCount: unread,
          nextEventDate: events.isNotEmpty ? events.first.eventDate : null,
          nextEventName: events.isNotEmpty ? events.first.eventName : null,
        ));
      }

      return CoachReportsState(
        summaries: summaries,
        dateRange: range,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load reports',
        context: 'COACH_REPORTS_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      return CoachReportsState(
        dateRange: range,
        error: 'Failed to load reports: $e',
      );
    }
  }

  /// Switch date range and reload
  Future<void> setDateRange(DateRange range) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadReports(range));
  }

  /// Refresh reports
  Future<void> refresh() async {
    final currentRange = state.value?.dateRange ?? DateRange.thisWeek;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadReports(currentRange));
  }
}
