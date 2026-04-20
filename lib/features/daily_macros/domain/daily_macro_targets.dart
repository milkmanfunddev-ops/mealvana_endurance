import 'enums.dart';

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
    );
  }

  /// Convert to JSON for Supabase upsert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'target_date': '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
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
