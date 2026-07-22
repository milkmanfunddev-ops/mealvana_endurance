/// Runna ICS event → Mealvana Activity transformer.
///
/// Runna is a running app, so events default to [ActivityType.running]. The
/// only events NOT imported are clear strength/mobility/cross-training
/// sessions (matched on SUMMARY keywords — deliberately not on DESCRIPTION,
/// whose step text varies across event types and is unreliable for
/// classification); those return null and are counted as filtered by the
/// sync service. Strength import is a follow-up.
///
/// SUMMARY format (verified against Runna's feed): a leading emoji plus
/// bullet-separated segments, e.g. "🏃 Easy Run • 6mi • 50m - 55m".
/// - First segment → workout name (emoji stripped).
/// - A distance segment ("6mi", "10km", "5k") → distanceMiles.
/// - A duration segment ("50m - 55m" range → midpoint; "45 mins") → duration
///   fallback.
///
/// Duration priority:
/// 1. X-WORKOUT-ESTIMATED-DURATION (Runna's own estimate, in seconds)
/// 2. DTEND − DTSTART (timed events only)
/// 3. DURATION property
/// 4. Duration text parsed from SUMMARY (the all-day common case)
library;

import 'package:uuid/uuid.dart';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import 'runna_ics_parser.dart';

/// Result of transforming a single Runna ICS event.
class RunnaTransformResult {
  const RunnaTransformResult({
    required this.activity,
    required this.providerWorkoutId,
    required this.lastSyncedAt,
    this.workoutSubtype,
  });

  final Activity activity;
  final String providerWorkoutId;
  final DateTime lastSyncedAt;
  final String? workoutSubtype;
}

/// Transforms Runna ICS events to Mealvana Activities.
class RunnaTransformer {
  const RunnaTransformer();

  static const _uuid = Uuid();
  static const _kmToMiles = 0.621371;

  /// SUMMARY keywords that mark an event as a non-running session we skip in
  /// MVP (no nutrition mapping yet). Matched case-insensitively on the whole
  /// summary.
  static const _skipKeywords = [
    'strength',
    'mobility',
    's&c',
    'conditioning',
    'yoga',
    'pilates',
    'cross training',
    'cross-training',
    'crosstraining',
  ];

  /// Transform a single [RunnaIcsEvent] to an [Activity].
  ///
  /// Returns null for events we deliberately don't import (strength/mobility/
  /// cross-training) — the caller counts these as filtered.
  RunnaTransformResult? transform(RunnaIcsEvent event, String userId) {
    final summary = event.summary ?? '';
    final lowerSummary = summary.toLowerCase();

    if (_skipKeywords.any(lowerSummary.contains)) {
      return null;
    }

    final segments = _splitSummarySegments(summary);
    final title = _buildTitle(segments);
    final distanceMiles = _extractDistanceMiles(segments);
    final durationMinutes = _resolveDurationMinutes(event, segments);
    final workoutSubtype = _inferSubtype(lowerSummary);

    final now = DateTime.now();
    final activity = Activity(
      id: _uuid.v4(),
      userId: userId,
      activityType: ActivityType.running,
      title: title,
      scheduledDateTime: event.start,
      status: ActivityStatus.planned,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      paceTargetMinutesPerMile: _calculatePace(
        durationMinutes: durationMinutes,
        distanceMiles: distanceMiles,
      ),
      intensityLevel: _inferIntensity(workoutSubtype),
      // Step-by-step workout text from DESCRIPTION (already RFC-unescaped by
      // the parser) — same field Final Surge uses for provider descriptions.
      notes: event.description,
      workoutSubtype: workoutSubtype,
      needsUpload: true,
      syncedFromProvider: 'runna',
      providerWorkoutId: event.uid,
      providerWorkoutUrl: event.url,
      providerScheduledAt: event.start,
      lastSyncedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    return RunnaTransformResult(
      activity: activity,
      providerWorkoutId: event.uid,
      lastSyncedAt: now,
      workoutSubtype: workoutSubtype,
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY parsing
  // ---------------------------------------------------------------------------

  /// Split "🏃 Easy Run • 6mi • 50m - 55m" into trimmed segments, stripping
  /// the leading emoji (any leading non-letter/non-digit run) from the first.
  List<String> _splitSummarySegments(String summary) {
    final segments = summary
        .split(RegExp(r'[•·]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isNotEmpty) {
      segments[0] = _stripLeadingEmoji(segments[0]);
    }
    return segments;
  }

  /// Drop any leading characters that aren't letters or digits (emoji,
  /// spaces, stray bullets). "6mi Easy Run" keeps its leading digit.
  String _stripLeadingEmoji(String value) {
    return value
        .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
        .trim();
  }

  String _buildTitle(List<String> segments) {
    if (segments.isEmpty || segments.first.isEmpty) return 'Runna workout';
    return segments.first;
  }

  /// A segment that is purely a distance: "6mi", "4.5 miles", "10km", "5k".
  double? _extractDistanceMiles(List<String> segments) {
    final pattern = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(mi|mile|miles|km|k)$',
      caseSensitive: false,
    );
    for (final segment in segments) {
      final match = pattern.firstMatch(segment);
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      if (value == null || value <= 0) continue;
      final unit = match.group(2)!.toLowerCase();
      if (unit == 'km' || unit == 'k') {
        return value * _kmToMiles;
      }
      return value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Duration
  // ---------------------------------------------------------------------------

  int? _resolveDurationMinutes(RunnaIcsEvent event, List<String> segments) {
    // 1. Runna's own moving-time estimate (seconds).
    final estimated = event.estimatedDurationSeconds;
    if (estimated != null && estimated > 0) {
      return (estimated / 60).round().clamp(1, 24 * 60);
    }

    // 2. DTEND − DTSTART for timed events.
    final end = event.end;
    if (end != null) {
      final minutes = end.difference(event.start).inMinutes;
      if (minutes > 0) return minutes.clamp(1, 24 * 60);
    }

    // 3. DURATION property.
    final duration = event.duration;
    if (duration != null && duration.inMinutes > 0) {
      return duration.inMinutes.clamp(1, 24 * 60);
    }

    // 4. SUMMARY duration text — the all-day common case ("50m - 55m").
    return _extractDurationMinutesFromSegments(segments);
  }

  /// Parse duration text from SUMMARY segments:
  /// - Range "50m - 55m" / "50 min - 55 min" → midpoint
  /// - Hours "1h 10m" / "1hr"
  /// - Single "45m" / "45 mins" / "45 minutes"
  int? _extractDurationMinutesFromSegments(List<String> segments) {
    final rangePattern = RegExp(
      r'^(\d+)\s*m(?:in(?:s|utes)?)?\s*[-–]\s*(\d+)\s*m(?:in(?:s|utes)?)?$',
      caseSensitive: false,
    );
    final hoursPattern = RegExp(
      r'^(\d+)\s*h(?:r|rs|our|ours)?(?:\s*(\d+)\s*m(?:in(?:s|utes)?)?)?$',
      caseSensitive: false,
    );
    final singlePattern = RegExp(
      r'^(\d+)\s*m(?:in(?:s|utes)?)?$',
      caseSensitive: false,
    );

    for (final segment in segments) {
      final range = rangePattern.firstMatch(segment);
      if (range != null) {
        final low = int.parse(range.group(1)!);
        final high = int.parse(range.group(2)!);
        final midpoint = ((low + high) / 2).round();
        if (midpoint > 0) return midpoint;
      }

      final hours = hoursPattern.firstMatch(segment);
      if (hours != null) {
        final h = int.parse(hours.group(1)!);
        final m = int.tryParse(hours.group(2) ?? '') ?? 0;
        final total = h * 60 + m;
        if (total > 0) return total;
      }

      final single = singlePattern.firstMatch(segment);
      if (single != null) {
        final minutes = int.parse(single.group(1)!);
        if (minutes > 0) return minutes;
      }
    }

    // Last resort: "45 min" anywhere in a segment (e.g. an unbulleted
    // summary like "Tempo Run · 45 mins" already split, or free text).
    for (final segment in segments) {
      final loose = RegExp(
        r'(\d+)\s*min',
        caseSensitive: false,
      ).firstMatch(segment);
      if (loose != null) {
        final minutes = int.parse(loose.group(1)!);
        if (minutes > 0) return minutes;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Subtype / intensity / pace
  // ---------------------------------------------------------------------------

  /// Workout subtype heuristic from the SUMMARY, mirroring the labels the
  /// Final Surge path stores ("Long Run", "Tempo", "Intervals", ...).
  String? _inferSubtype(String lowerSummary) {
    if (lowerSummary.contains('race')) return 'Race';
    if (lowerSummary.contains('long run') || lowerSummary.contains('long ')) {
      return 'Long Run';
    }
    if (lowerSummary.contains('tempo')) return 'Tempo';
    if (lowerSummary.contains('threshold')) return 'Threshold';
    if (lowerSummary.contains('interval')) return 'Intervals';
    if (lowerSummary.contains('speed')) return 'Speed';
    if (lowerSummary.contains('fartlek')) return 'Fartlek';
    if (lowerSummary.contains('hill')) return 'Hills';
    if (lowerSummary.contains('progression')) return 'Progression';
    if (lowerSummary.contains('recovery')) return 'Recovery';
    if (lowerSummary.contains('easy')) return 'Easy';
    return null;
  }

  IntensityLevel _inferIntensity(String? subtype) {
    switch (subtype) {
      case 'Easy':
      case 'Recovery':
        return IntensityLevel.easy;
      case 'Race':
        return IntensityLevel.race;
      case 'Tempo':
      case 'Threshold':
      case 'Intervals':
      case 'Speed':
      case 'Fartlek':
      case 'Hills':
        return IntensityLevel.hard;
      case 'Long Run':
      case 'Progression':
        return IntensityLevel.moderate;
      default:
        return IntensityLevel.moderate;
    }
  }

  /// Derive pace from duration/distance when both are known, with the same
  /// 4–20 min/mi sanity window the Final Surge transformer uses.
  double? _calculatePace({int? durationMinutes, double? distanceMiles}) {
    if (durationMinutes == null || durationMinutes <= 0) return null;
    if (distanceMiles == null || distanceMiles <= 0) return null;
    final pace = durationMinutes / distanceMiles;
    if (pace < 4.0 || pace > 20.0) return null;
    return pace;
  }
}
