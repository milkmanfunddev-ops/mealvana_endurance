import 'enums.dart';

/// Source attribution emitted by the calculate-daily-macros edge function.
/// Mirrors `ResolveSource` on the backend. String literals (rather than an
/// enum) so unknown values from a newer server don't crash older clients.
class MacroSources {
  final String rmr;
  final String neat;
  final String weight;
  final String bodyFat;
  final List<MacroSessionSources> sessions;

  const MacroSources({
    required this.rmr,
    required this.neat,
    required this.weight,
    required this.bodyFat,
    required this.sessions,
  });

  bool get rmrFromGarmin => rmr == 'GARMIN';
  bool get neatFromGarmin => neat == 'GARMIN';
  bool get weightFromGarmin => weight == 'GARMIN';
  bool get bodyFatFromGarmin => bodyFat == 'GARMIN';

  /// True if any input came from Garmin — used to render a single
  /// "Powered by Garmin" footer when finer-grained badges are too noisy.
  bool get anyFromGarmin =>
      rmrFromGarmin ||
      neatFromGarmin ||
      weightFromGarmin ||
      bodyFatFromGarmin ||
      sessions.any((s) => s.kcalFromGarmin || s.durationFromGarmin);

  static MacroSources? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final sessionsJson = (json['sessions'] as List?) ?? const [];
    return MacroSources(
      rmr: json['rmr']?.toString() ?? 'FORMULA',
      neat: json['neat']?.toString() ?? 'FORMULA',
      weight: json['weight']?.toString() ?? 'MANUAL',
      bodyFat: json['body_fat']?.toString() ?? 'NONE',
      sessions: sessionsJson
          .whereType<Map>()
          .map((m) => MacroSessionSources.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

/// Source attribution for a single session (one row in sessions[]).
class MacroSessionSources {
  final String sessionKcal;
  final String intensityFactor;
  final String tss;
  final String duration;

  const MacroSessionSources({
    required this.sessionKcal,
    required this.intensityFactor,
    required this.tss,
    required this.duration,
  });

  bool get kcalFromGarmin => sessionKcal == 'GARMIN';
  bool get durationFromGarmin => duration == 'GARMIN';

  factory MacroSessionSources.fromJson(Map<String, dynamic> json) {
    return MacroSessionSources(
      sessionKcal: json['session_kcal']?.toString() ?? 'FORMULA',
      intensityFactor: json['intensity_factor']?.toString() ?? 'ZONE_DIST',
      tss: json['tss']?.toString() ?? 'FORMULA',
      duration: json['duration']?.toString() ?? 'FORMULA',
    );
  }
}

/// Domain model for calculated daily macro targets
class DailyMacroTargets {
  final String id;
  final String userId;
  final DateTime targetDate;
  final double carbG;
  final double protG;
  final double fatG;
  final double tdee;
  final double rmr;
  final double sessionKcal;
  final double? neatKcal;
  final double? tefKcal;
  final String mode;
  final double? ea;
  final EaStatus? eaStatus;
  final String algorithmVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Resolved athlete weight (kg) used for this calculation. May come from
  /// Garmin (if newer than user's manual entry, per `sources.weight`).
  final double? weightKg;

  /// Resolved body fat % used for this calculation, if any.
  final double? bodyFatPct;

  /// Source attribution from the edge function. Populated only when this
  /// instance was just calculated (not persisted in cache yet) — null on
  /// cached reads. Drives Garmin badges in the macro UI.
  final MacroSources? sources;

  const DailyMacroTargets({
    required this.id,
    required this.userId,
    required this.targetDate,
    required this.carbG,
    required this.protG,
    required this.fatG,
    required this.tdee,
    required this.rmr,
    required this.sessionKcal,
    this.neatKcal,
    this.tefKcal,
    required this.mode,
    this.ea,
    this.eaStatus,
    this.algorithmVersion = 'v4',
    required this.createdAt,
    required this.updatedAt,
    this.weightKg,
    this.bodyFatPct,
    this.sources,
  });

  /// Total calories from macros
  double get totalCalories => (carbG * 4) + (protG * 4) + (fatG * 9);

  /// Whether this is a training day (has session calories)
  bool get isTrainingDay => sessionKcal > 0;

  /// Day type label for display
  String get dayTypeLabel {
    if (mode == 'race_week') return 'RACE WEEK';
    if (sessionKcal > 500) return 'TRAINING';
    if (sessionKcal > 0) return 'LIGHT TRAINING';
    return 'REST';
  }

  /// Whether an EA warning should be shown
  bool get hasEaWarning =>
      eaStatus == EaStatus.softWarning ||
      eaStatus == EaStatus.hardWarning ||
      eaStatus == EaStatus.block;

  /// Create from edge function response JSON
  factory DailyMacroTargets.fromEdgeFunctionResponse({
    required String id,
    required String userId,
    required DateTime targetDate,
    required Map<String, dynamic> json,
  }) {
    return DailyMacroTargets(
      id: id,
      userId: userId,
      targetDate: targetDate,
      carbG: (json['carb_g'] as num).toDouble(),
      protG: (json['prot_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      tdee: (json['tdee'] as num).toDouble(),
      rmr: (json['rmr'] as num).toDouble(),
      sessionKcal: (json['session_kcal'] as num).toDouble(),
      neatKcal: (json['neat_kcal'] as num?)?.toDouble(),
      tefKcal: (json['tef_kcal'] as num?)?.toDouble(),
      mode: json['mode'] as String? ?? 'prospective',
      ea: (json['ea'] as num?)?.toDouble(),
      eaStatus: EaStatus.fromDbValue(json['ea_status'] as String?),
      algorithmVersion: json['algorithm_version'] as String? ?? 'v4',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
      sources: MacroSources.fromJson(
        (json['sources'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// Convert to JSON for Supabase upsert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'target_date':
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
      'carb_g': carbG,
      'prot_g': protG,
      'fat_g': fatG,
      'tdee': tdee,
      'rmr': rmr,
      'session_kcal': sessionKcal,
      'neat_kcal': neatKcal,
      'tef_kcal': tefKcal,
      'mode': mode,
      'ea': ea,
      'ea_status': eaStatus?.dbValue,
      'algorithm_version': algorithmVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
