/// Activity completion domain model for calendar feature
class ActivityCompletion {
  const ActivityCompletion({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.completedAt,
    this.completionType = CompletionType.manual,
    
    // Performance data
    this.actualDistanceMiles,
    this.actualDurationMinutes,
    this.averagePaceMinutesPerMile,
    this.maxHeartRate,
    this.averageHeartRate,
    this.caloriesBurned,
    
    // User feedback
    this.effortRating,
    this.nutritionRating,
    this.overallSatisfaction,
    
    // Notes and feedback
    this.textNotes,
    this.voiceNoteId,
    this.hasVoiceRecording = false,
    
    // Conditions
    this.weatherConditions,
    this.temperatureFahrenheit,
    this.humidityPercent,
    
    // Analysis
    this.nutritionAdherenceScore,
    this.performanceVsTarget,

    // Sync tracking (offline-first architecture)
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String activityId;
  final String userId;
  final DateTime completedAt;
  final CompletionType completionType;
  
  // Performance data
  final double? actualDistanceMiles;
  final int? actualDurationMinutes;
  final double? averagePaceMinutesPerMile;
  final int? maxHeartRate;
  final int? averageHeartRate;
  final int? caloriesBurned;
  
  // User feedback
  final int? effortRating; // 1-5
  final int? nutritionRating; // 1-5
  final int? overallSatisfaction; // 1-5
  
  // Notes and feedback
  final String? textNotes;
  final String? voiceNoteId;
  final bool hasVoiceRecording;
  
  // Conditions
  final String? weatherConditions;
  final int? temperatureFahrenheit;
  final int? humidityPercent;
  
  // Analysis
  final double? nutritionAdherenceScore; // 0.0 to 1.0
  final double? performanceVsTarget;

  // Sync tracking (offline-first architecture)
  final bool? needsUpload;
  final DateTime? localUpdatedAt;

  /// Serialize completion to JSON for edge function payload
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityId': activityId,
      'userId': userId,
      'completedAt': completedAt.toIso8601String(),
      'completionType': completionType.name,
      'actualDistanceMiles': actualDistanceMiles,
      'actualDurationMinutes': actualDurationMinutes,
      'averagePaceMinutesPerMile': averagePaceMinutesPerMile,
      'maxHeartRate': maxHeartRate,
      'averageHeartRate': averageHeartRate,
      'caloriesBurned': caloriesBurned,
      'effortRating': effortRating,
      'nutritionRating': nutritionRating,
      'overallSatisfaction': overallSatisfaction,
      'textNotes': textNotes,
      'voiceNoteId': voiceNoteId,
      'hasVoiceRecording': hasVoiceRecording,
      'weatherConditions': weatherConditions,
      'temperatureFahrenheit': temperatureFahrenheit,
      'humidityPercent': humidityPercent,
      'nutritionAdherenceScore': nutritionAdherenceScore,
      'performanceVsTarget': performanceVsTarget,
    };
  }

  ActivityCompletion copyWith({
    String? id,
    String? activityId,
    String? userId,
    DateTime? completedAt,
    CompletionType? completionType,
    double? actualDistanceMiles,
    int? actualDurationMinutes,
    double? averagePaceMinutesPerMile,
    int? maxHeartRate,
    int? averageHeartRate,
    int? caloriesBurned,
    int? effortRating,
    int? nutritionRating,
    int? overallSatisfaction,
    String? textNotes,
    String? voiceNoteId,
    bool? hasVoiceRecording,
    String? weatherConditions,
    int? temperatureFahrenheit,
    int? humidityPercent,
    double? nutritionAdherenceScore,
    double? performanceVsTarget,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return ActivityCompletion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      userId: userId ?? this.userId,
      completedAt: completedAt ?? this.completedAt,
      completionType: completionType ?? this.completionType,
      actualDistanceMiles: actualDistanceMiles ?? this.actualDistanceMiles,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      averagePaceMinutesPerMile: averagePaceMinutesPerMile ?? this.averagePaceMinutesPerMile,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      effortRating: effortRating ?? this.effortRating,
      nutritionRating: nutritionRating ?? this.nutritionRating,
      overallSatisfaction: overallSatisfaction ?? this.overallSatisfaction,
      textNotes: textNotes ?? this.textNotes,
      voiceNoteId: voiceNoteId ?? this.voiceNoteId,
      hasVoiceRecording: hasVoiceRecording ?? this.hasVoiceRecording,
      weatherConditions: weatherConditions ?? this.weatherConditions,
      temperatureFahrenheit: temperatureFahrenheit ?? this.temperatureFahrenheit,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      nutritionAdherenceScore: nutritionAdherenceScore ?? this.nutritionAdherenceScore,
      performanceVsTarget: performanceVsTarget ?? this.performanceVsTarget,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityCompletion &&
        other.id == id &&
        other.activityId == activityId &&
        other.userId == userId &&
        other.completedAt == completedAt &&
        other.completionType == completionType &&
        other.actualDistanceMiles == actualDistanceMiles &&
        other.actualDurationMinutes == actualDurationMinutes &&
        other.averagePaceMinutesPerMile == averagePaceMinutesPerMile &&
        other.maxHeartRate == maxHeartRate &&
        other.averageHeartRate == averageHeartRate &&
        other.caloriesBurned == caloriesBurned &&
        other.effortRating == effortRating &&
        other.nutritionRating == nutritionRating &&
        other.overallSatisfaction == overallSatisfaction &&
        other.textNotes == textNotes &&
        other.voiceNoteId == voiceNoteId &&
        other.hasVoiceRecording == hasVoiceRecording &&
        other.weatherConditions == weatherConditions &&
        other.temperatureFahrenheit == temperatureFahrenheit &&
        other.humidityPercent == humidityPercent &&
        other.nutritionAdherenceScore == nutritionAdherenceScore &&
        other.performanceVsTarget == performanceVsTarget;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        activityId.hashCode ^
        userId.hashCode ^
        completedAt.hashCode ^
        completionType.hashCode ^
        actualDistanceMiles.hashCode ^
        actualDurationMinutes.hashCode ^
        averagePaceMinutesPerMile.hashCode ^
        maxHeartRate.hashCode ^
        averageHeartRate.hashCode ^
        caloriesBurned.hashCode ^
        effortRating.hashCode ^
        nutritionRating.hashCode ^
        overallSatisfaction.hashCode ^
        textNotes.hashCode ^
        voiceNoteId.hashCode ^
        hasVoiceRecording.hashCode ^
        weatherConditions.hashCode ^
        temperatureFahrenheit.hashCode ^
        humidityPercent.hashCode ^
        nutritionAdherenceScore.hashCode ^
        performanceVsTarget.hashCode;
  }

  @override
  String toString() {
    return 'ActivityCompletion(id: $id, activityId: $activityId, completedAt: $completedAt, completionType: $completionType)';
  }
}

/// Completion type enum
enum CompletionType {
  manual,
  automatic,
  imported,
}

/// Activity completion extensions for utility methods
extension ActivityCompletionExtensions on ActivityCompletion {
  /// Get formatted pace if available
  String? get formattedPace {
    if (averagePaceMinutesPerMile == null) return null;
    final minutes = averagePaceMinutesPerMile!.floor();
    final seconds = ((averagePaceMinutesPerMile! - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}/mi";
  }
  
  /// Get formatted duration if available
  String? get formattedDuration {
    if (actualDurationMinutes == null) return null;
    final hours = actualDurationMinutes! ~/ 60;
    final minutes = actualDurationMinutes! % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    }
    return "${minutes}m";
  }
  
  /// Get formatted distance if available
  String? get formattedDistance {
    if (actualDistanceMiles == null) return null;
    return "${actualDistanceMiles!.toStringAsFixed(1)} mi";
  }
  
  /// Check if completion has performance data
  bool get hasPerformanceData => 
      actualDistanceMiles != null || 
      actualDurationMinutes != null || 
      averagePaceMinutesPerMile != null;
  
  /// Check if completion has user feedback
  bool get hasUserFeedback => 
      effortRating != null || 
      nutritionRating != null || 
      overallSatisfaction != null ||
      (textNotes != null && textNotes!.isNotEmpty) ||
      hasVoiceRecording;
  
  /// Get average rating if available
  double? get averageRating {
    final ratings = <int?>[
      effortRating,
      nutritionRating,
      overallSatisfaction,
    ].where((r) => r != null).cast<int>().toList();
    
    if (ratings.isEmpty) return null;
    
    final sum = ratings.reduce((a, b) => a + b);
    return sum / ratings.length;
  }
  
  /// Get formatted average rating
  String? get formattedAverageRating {
    final avg = averageRating;
    if (avg == null) return null;
    return "${avg.toStringAsFixed(1)}/5.0";
  }
  
  /// Check if completion has weather data
  bool get hasWeatherData => 
      weatherConditions != null || 
      temperatureFahrenheit != null || 
      humidityPercent != null;
  
  /// Get formatted weather description
  String? get formattedWeather {
    if (!hasWeatherData) return null;
    
    final parts = <String>[];
    if (weatherConditions != null) {
      parts.add(weatherConditions!);
    }
    if (temperatureFahrenheit != null) {
      parts.add("$temperatureFahrenheit°F");
    }
    if (humidityPercent != null) {
      parts.add("$humidityPercent% humidity");
    }
    
    return parts.join(', ');
  }
}