import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';

/// Domain model for personal nutrition plan templates
class PersonalTemplate {
  const PersonalTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.activityType,
    this.originalDurationMinutes,
    this.originalDistance,
    this.originalActivityTitle,
    required this.planData,
    this.totalCarbsG,
    this.totalProteinG,
    this.totalFatG,
    this.totalSodiumMg,
    this.totalFluidsMl,
    this.totalCalories,
    this.brickSegmentOrder,
    required this.createdAt,
    required this.updatedAt,
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String activityType; // 'running'/'cycling'/'swimming'/'brick'
  final int? originalDurationMinutes;
  final double? originalDistance;
  final String? originalActivityTitle;
  final Map<String, dynamic> planData; // Full nutrition_plan_data JSON
  final int? totalCarbsG;
  final int? totalProteinG;
  final int? totalFatG;
  final int? totalSodiumMg;
  final int? totalFluidsMl;
  final int? totalCalories;
  final List<String>? brickSegmentOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? needsUpload;
  final DateTime? localUpdatedAt;

  /// Convert from Drift database entry
  factory PersonalTemplate.fromDriftEntry(PersonalTemplateEntry entry) {
    Map<String, dynamic> planData;
    try {
      planData = jsonDecode(entry.planData) as Map<String, dynamic>;
    } catch (_) {
      planData = {};
    }

    List<String>? segmentOrder;
    if (entry.brickSegmentOrder != null) {
      try {
        segmentOrder =
            (jsonDecode(entry.brickSegmentOrder!) as List).cast<String>();
      } catch (_) {
        segmentOrder = null;
      }
    }

    return PersonalTemplate(
      id: entry.id,
      userId: entry.userId,
      name: entry.name,
      activityType: entry.activityType,
      originalDurationMinutes: entry.originalDurationMinutes,
      originalDistance: entry.originalDistance,
      originalActivityTitle: entry.originalActivityTitle,
      planData: planData,
      totalCarbsG: entry.totalCarbsG,
      totalProteinG: entry.totalProteinG,
      totalFatG: entry.totalFatG,
      totalSodiumMg: entry.totalSodiumMg,
      totalFluidsMl: entry.totalFluidsMl,
      totalCalories: entry.totalCalories,
      brickSegmentOrder: segmentOrder,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      needsUpload: entry.needsUpload,
      localUpdatedAt: entry.localUpdatedAt,
    );
  }

  /// Convert to Drift companion for insert
  PersonalTemplatesTableCompanion toDriftCompanion() {
    return PersonalTemplatesTableCompanion.insert(
      id: Value(id),
      userId: userId,
      name: name,
      activityType: activityType,
      originalDurationMinutes: Value(originalDurationMinutes),
      originalDistance: Value(originalDistance),
      originalActivityTitle: Value(originalActivityTitle),
      planData: jsonEncode(planData),
      totalCarbsG: Value(totalCarbsG),
      totalProteinG: Value(totalProteinG),
      totalFatG: Value(totalFatG),
      totalSodiumMg: Value(totalSodiumMg),
      totalFluidsMl: Value(totalFluidsMl),
      totalCalories: Value(totalCalories),
      brickSegmentOrder: Value(
        brickSegmentOrder != null ? jsonEncode(brickSegmentOrder) : null,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      needsUpload: Value(needsUpload ?? false),
      localUpdatedAt: Value(localUpdatedAt ?? DateTime.now()),
    );
  }

  /// Serialize for Supabase upload
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'activity_type': activityType,
      'original_duration_minutes': originalDurationMinutes,
      'original_distance': originalDistance,
      'original_activity_title': originalActivityTitle,
      'plan_data': planData,
      'total_carbs_g': totalCarbsG,
      'total_protein_g': totalProteinG,
      'total_fat_g': totalFatG,
      'total_sodium_mg': totalSodiumMg,
      'total_fluids_ml': totalFluidsMl,
      'total_calories': totalCalories,
      'brick_segment_order': brickSegmentOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Parse from Supabase response JSON
  factory PersonalTemplate.fromSupabaseJson(Map<String, dynamic> json) {
    Map<String, dynamic> planData;
    final rawPlan = json['plan_data'];
    if (rawPlan is Map<String, dynamic>) {
      planData = rawPlan;
    } else if (rawPlan is String) {
      planData = jsonDecode(rawPlan) as Map<String, dynamic>;
    } else {
      planData = {};
    }

    List<String>? segmentOrder;
    final rawSegments = json['brick_segment_order'];
    if (rawSegments is List) {
      segmentOrder = rawSegments.cast<String>();
    }

    return PersonalTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      activityType: json['activity_type'] as String,
      originalDurationMinutes: json['original_duration_minutes'] as int?,
      originalDistance: (json['original_distance'] as num?)?.toDouble(),
      originalActivityTitle: json['original_activity_title'] as String?,
      planData: planData,
      totalCarbsG: json['total_carbs_g'] as int?,
      totalProteinG: json['total_protein_g'] as int?,
      totalFatG: json['total_fat_g'] as int?,
      totalSodiumMg: json['total_sodium_mg'] as int?,
      totalFluidsMl: json['total_fluids_ml'] as int?,
      totalCalories: json['total_calories'] as int?,
      brickSegmentOrder: segmentOrder,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Formatted duration string (e.g., "3h 00m")
  String get durationDisplay {
    if (originalDurationMinutes == null) return '';
    final hours = originalDurationMinutes! ~/ 60;
    final minutes = originalDurationMinutes! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m';
  }

  /// Quick macro summary (e.g., "245g carbs, 42g protein")
  String get macroSummaryDisplay {
    final parts = <String>[];
    if (totalCarbsG != null) parts.add('${totalCarbsG}g carbs');
    if (totalProteinG != null) parts.add('${totalProteinG}g protein');
    if (totalFatG != null) parts.add('${totalFatG}g fat');
    return parts.join(' · ');
  }

  /// Activity type display name
  String get activityTypeDisplay {
    switch (activityType) {
      case 'running':
        return 'Running';
      case 'cycling':
        return 'Cycling';
      case 'swimming':
        return 'Swimming';
      case 'brick':
        return 'Brick';
      default:
        return activityType;
    }
  }

  /// Brick segment display (e.g., "Swim → Bike → Run")
  String? get brickSegmentDisplay {
    if (brickSegmentOrder == null || brickSegmentOrder!.isEmpty) return null;
    return brickSegmentOrder!
        .map((s) {
          switch (s) {
            case 'swimming':
              return 'Swim';
            case 'cycling':
              return 'Bike';
            case 'running':
              return 'Run';
            default:
              return s;
          }
        })
        .join(' → ');
  }

  PersonalTemplate copyWith({
    String? id,
    String? userId,
    String? name,
    String? activityType,
    int? originalDurationMinutes,
    double? originalDistance,
    String? originalActivityTitle,
    Map<String, dynamic>? planData,
    int? totalCarbsG,
    int? totalProteinG,
    int? totalFatG,
    int? totalSodiumMg,
    int? totalFluidsMl,
    int? totalCalories,
    List<String>? brickSegmentOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return PersonalTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      activityType: activityType ?? this.activityType,
      originalDurationMinutes:
          originalDurationMinutes ?? this.originalDurationMinutes,
      originalDistance: originalDistance ?? this.originalDistance,
      originalActivityTitle:
          originalActivityTitle ?? this.originalActivityTitle,
      planData: planData ?? this.planData,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      totalSodiumMg: totalSodiumMg ?? this.totalSodiumMg,
      totalFluidsMl: totalFluidsMl ?? this.totalFluidsMl,
      totalCalories: totalCalories ?? this.totalCalories,
      brickSegmentOrder: brickSegmentOrder ?? this.brickSegmentOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  @override
  String toString() {
    return 'PersonalTemplate(id: $id, name: $name, activityType: $activityType)';
  }
}
