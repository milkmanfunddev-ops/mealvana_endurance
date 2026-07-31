/// Intensity Distribution Mapper
///
/// Utility class for mapping external workout data to [IntensityDistribution].
/// Supports two approaches:
/// 1. Structured workout parsing - calculates time-weighted distributions from intervals
/// 2. Heuristic mapping - uses workout metadata (IF, TSS, keywords) for conservative estimates
///
/// Zone thresholds are based on standard training zone models:
/// - Conversational (Z1-Z2): 0-75% FTP / 0-80% MaxHR / RPE 1-4
/// - Tempo (Z3-Z4): 76-100% FTP / 81-95% MaxHR / RPE 5-7
/// - All-Out (Z5+): >100% FTP / >95% MaxHR / RPE 8-10
library;

import '../../nutrition_plan/domain/intensity_distribution.dart';

/// Represents a training intensity zone
enum IntensityZone { conversational, tempo, allOut }

/// Represents a segment of a structured workout
class WorkoutSegment {
  const WorkoutSegment({required this.durationSeconds, required this.zone});

  /// Duration of this segment in seconds
  final int durationSeconds;

  /// The intensity zone for this segment
  final IntensityZone zone;
}

/// Utility class for mapping workout data to intensity distributions
class IntensityDistributionMapper {
  const IntensityDistributionMapper._();

  // ===========================================================================
  // Zone Threshold Constants
  // ===========================================================================

  /// FTP thresholds (as decimal, e.g., 0.75 = 75%)
  static const double ftpConversationalMax = 0.75;
  static const double ftpTempoMax = 1.00;

  /// Max HR thresholds (as decimal)
  static const double hrConversationalMax = 0.80;
  static const double hrTempoMax = 0.95;

  /// RPE thresholds (1-10 scale)
  static const int rpeConversationalMax = 4;
  static const int rpeTempoMax = 7;

  // ===========================================================================
  // Heuristic Pattern Constants (Conservative Estimates)
  // ===========================================================================

  /// Easy/Recovery workout pattern: 95% conversational, 5% tempo, 0% all-out
  static const IntensityDistribution patternEasyRecovery =
      IntensityDistribution(conversationalPct: 95, tempoPct: 5, allOutPct: 0);

  /// Long Run/Endurance pattern: 80% conversational, 15% tempo, 5% all-out
  static const IntensityDistribution patternLongRun = IntensityDistribution(
    conversationalPct: 80,
    tempoPct: 15,
    allOutPct: 5,
  );

  /// Moderate/Aerobic pattern: 70% conversational, 25% tempo, 5% all-out
  static const IntensityDistribution patternModerate = IntensityDistribution(
    conversationalPct: 70,
    tempoPct: 25,
    allOutPct: 5,
  );

  /// Tempo/Threshold pattern: 30% conversational, 60% tempo, 10% all-out
  static const IntensityDistribution patternTempo = IntensityDistribution(
    conversationalPct: 30,
    tempoPct: 60,
    allOutPct: 10,
  );

  /// Intervals/Speed pattern: 40% conversational, 30% tempo, 30% all-out
  static const IntensityDistribution patternIntervals = IntensityDistribution(
    conversationalPct: 40,
    tempoPct: 30,
    allOutPct: 30,
  );

  /// Race pattern: 10% conversational, 30% tempo, 60% all-out
  static const IntensityDistribution patternRace = IntensityDistribution(
    conversationalPct: 10,
    tempoPct: 30,
    allOutPct: 60,
  );

  // ===========================================================================
  // Keyword Patterns for Heuristic Matching
  // ===========================================================================

  /// Keywords that indicate easy/recovery workouts
  static const List<String> keywordsEasyRecovery = [
    'easy',
    'recovery',
    'warm',
    'cooldown',
    'cool down',
    'shake out',
    'shakeout',
  ];

  /// Keywords that indicate long/endurance workouts
  static const List<String> keywordsLongRun = [
    'long',
    'endurance',
    'aerobic base',
  ];

  /// Keywords that indicate moderate workouts
  static const List<String> keywordsModerate = [
    'moderate',
    'aerobic',
    'steady',
    'steady state',
  ];

  /// Keywords that indicate tempo/threshold workouts
  static const List<String> keywordsTempo = [
    'tempo',
    'threshold',
    'cruise',
    'lactate',
    'lt',
    'ftp',
    'sweet spot',
    'sweetspot',
  ];

  /// Keywords that indicate intervals/speed workouts
  static const List<String> keywordsIntervals = [
    'interval',
    'speed',
    'track',
    'vo2',
    'v02',
    'vo2max',
    'hill',
    'repeat',
    'fartlek',
    'strides',
  ];

  /// Keywords that indicate race workouts
  static const List<String> keywordsRace = [
    'race',
    'competition',
    'time trial',
    'tt',
    'pr attempt',
    'goal pace',
  ];

  // ===========================================================================
  // Zone Mapping Methods
  // ===========================================================================

  /// Maps a percentage of FTP to an intensity zone
  ///
  /// - 0-75% FTP → Conversational
  /// - 76-100% FTP → Tempo
  /// - >100% FTP → All-Out
  static IntensityZone ftpToZone(double percentFtp) {
    if (percentFtp <= ftpConversationalMax) {
      return IntensityZone.conversational;
    } else if (percentFtp <= ftpTempoMax) {
      return IntensityZone.tempo;
    } else {
      return IntensityZone.allOut;
    }
  }

  /// Maps a percentage of Max HR to an intensity zone
  ///
  /// - 0-80% MaxHR → Conversational
  /// - 81-95% MaxHR → Tempo
  /// - >95% MaxHR → All-Out
  static IntensityZone maxHrToZone(double percentMaxHr) {
    if (percentMaxHr <= hrConversationalMax) {
      return IntensityZone.conversational;
    } else if (percentMaxHr <= hrTempoMax) {
      return IntensityZone.tempo;
    } else {
      return IntensityZone.allOut;
    }
  }

  /// Maps an RPE value (1-10 scale) to an intensity zone
  ///
  /// - RPE 1-4 → Conversational
  /// - RPE 5-7 → Tempo
  /// - RPE 8-10 → All-Out
  static IntensityZone rpeToZone(int rpe) {
    if (rpe <= rpeConversationalMax) {
      return IntensityZone.conversational;
    } else if (rpe <= rpeTempoMax) {
      return IntensityZone.tempo;
    } else {
      return IntensityZone.allOut;
    }
  }

  // ===========================================================================
  // Distribution Calculation Methods
  // ===========================================================================

  /// Calculates a time-weighted intensity distribution from workout segments
  ///
  /// Takes a list of [WorkoutSegment]s with duration and zone, and calculates
  /// the percentage of total time spent in each zone.
  ///
  /// Returns null if segments list is empty or total duration is zero.
  static IntensityDistribution? fromSegments(List<WorkoutSegment> segments) {
    if (segments.isEmpty) return null;

    final totalSeconds = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.durationSeconds,
    );

    if (totalSeconds <= 0) return null;

    // Accumulate time per zone
    var conversationalSeconds = 0;
    var tempoSeconds = 0;
    var allOutSeconds = 0;

    for (final segment in segments) {
      switch (segment.zone) {
        case IntensityZone.conversational:
          conversationalSeconds += segment.durationSeconds;
        case IntensityZone.tempo:
          tempoSeconds += segment.durationSeconds;
        case IntensityZone.allOut:
          allOutSeconds += segment.durationSeconds;
      }
    }

    // Calculate percentages
    var conversationalPct = ((conversationalSeconds / totalSeconds) * 100)
        .round();
    var tempoPct = ((tempoSeconds / totalSeconds) * 100).round();
    var allOutPct = ((allOutSeconds / totalSeconds) * 100).round();

    // Ensure sum equals 100 (handle rounding errors)
    final sum = conversationalPct + tempoPct + allOutPct;
    if (sum != 100) {
      // Adjust the largest component to fix rounding
      final diff = 100 - sum;
      if (conversationalPct >= tempoPct && conversationalPct >= allOutPct) {
        conversationalPct += diff;
      } else if (tempoPct >= conversationalPct && tempoPct >= allOutPct) {
        tempoPct += diff;
      } else {
        allOutPct += diff;
      }
    }

    return IntensityDistribution.validated(
      conversationalPct: conversationalPct,
      tempoPct: tempoPct,
      allOutPct: allOutPct,
    );
  }

  /// Infers intensity distribution from workout type keywords
  ///
  /// Matches the input string against known workout type keywords and returns
  /// the corresponding heuristic pattern. Keywords are case-insensitive.
  ///
  /// Priority order:
  /// 1. Race keywords (strongest signal)
  /// 2. Intervals/Speed keywords
  /// 3. Tempo/Threshold keywords
  /// 4. Moderate keywords
  /// 5. Long Run keywords
  /// 6. Easy/Recovery keywords
  ///
  /// Returns null if no keywords match.
  static IntensityDistribution? fromWorkoutType(String? keywords) {
    if (keywords == null || keywords.isEmpty) return null;

    final lower = keywords.toLowerCase();

    // Check in priority order (most specific first)
    if (_containsAny(lower, keywordsRace)) {
      return patternRace;
    }
    if (_containsAny(lower, keywordsIntervals)) {
      return patternIntervals;
    }
    if (_containsAny(lower, keywordsTempo)) {
      return patternTempo;
    }
    // Check moderate before long run - "moderate long run" should be moderate
    if (_containsAny(lower, keywordsModerate)) {
      return patternModerate;
    }
    if (_containsAny(lower, keywordsLongRun)) {
      return patternLongRun;
    }
    if (_containsAny(lower, keywordsEasyRecovery)) {
      return patternEasyRecovery;
    }

    return null;
  }

  /// Infers intensity distribution from Intensity Factor (IF)
  ///
  /// IF is a normalized intensity metric from TrainingPeaks:
  /// - IF < 0.75 → Easy/Recovery pattern
  /// - IF 0.75-0.85 → Moderate pattern
  /// - IF 0.85-0.95 → Tempo pattern
  /// - IF 0.95-1.0 → Intervals pattern
  /// - IF > 1.0 → Race pattern
  static IntensityDistribution? fromIntensityFactor(double? intensityFactor) {
    if (intensityFactor == null || intensityFactor <= 0) return null;

    if (intensityFactor > 1.0) {
      return patternRace;
    }
    if (intensityFactor >= 0.95) {
      return patternIntervals;
    }
    if (intensityFactor >= 0.85) {
      return patternTempo;
    }
    if (intensityFactor >= 0.75) {
      return patternModerate;
    }
    return patternEasyRecovery;
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Checks if the input string contains any of the keywords
  static bool _containsAny(String input, List<String> keywords) {
    for (final keyword in keywords) {
      if (input.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}
