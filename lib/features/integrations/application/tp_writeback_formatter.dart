import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../nutrition_plan/domain/nutrition_plan.dart';

/// Converts a NutritionPlan into a compact text block for TP workout descriptions.
///
/// Format:
/// ```
/// ---
/// [Mealvana Fuel Plan]
/// Pre: 60g carb, 16oz water (2-3h before)
/// During: 60g/h carb, 20oz/h water
/// Post: 25g protein, 40g carb within 30min
/// [/Mealvana]
/// ```
class TpWritebackFormatter {
  static const String startDelimiter = '[Mealvana Fuel Plan]';
  static const String endDelimiter = '[/Mealvana]';

  /// Format the nutrition plan into a delimited text block for TP descriptions.
  ///
  /// [plan] The nutrition plan with sections (before/during/after).
  /// [durationMinutes] Activity duration in minutes for per-hour rate calculations.
  static String formatPlanBlock(NutritionPlan plan, {int? durationMinutes}) {
    final lines = <String>[];
    lines.add('---');
    lines.add(startDelimiter);

    // Before section
    final beforeSection = _findSection(plan, 'before');
    if (beforeSection != null) {
      lines.add(_formatBeforeLine(beforeSection));
    }

    // During section (skip if < 60 min or no carbs target)
    final duringSection = _findSection(plan, 'during');
    if (duringSection != null) {
      final effectiveDuration = durationMinutes ??
          duringSection.byHourData?.durationMinutes;
      if (effectiveDuration != null && effectiveDuration >= 60 &&
          (duringSection.carbsTarget ?? 0) > 0) {
        lines.add(_formatDuringLine(duringSection, effectiveDuration));
      }
    }

    // After section
    final afterSection = _findSection(plan, 'after');
    if (afterSection != null) {
      lines.add(_formatAfterLine(afterSection));
    }

    lines.add(endDelimiter);
    return lines.join('\n');
  }

  /// Compute a hash of the formatted block for change detection.
  static String computeHash(String block) {
    return md5.convert(utf8.encode(block)).toString();
  }

  /// Merge a Mealvana block into an existing workout description.
  /// Replaces any existing block, or appends if none exists.
  static String mergeBlockIntoDescription(String? existingDesc, String block) {
    final desc = existingDesc ?? '';
    final stripped = stripBlockFromDescription(desc);
    // Append block after existing content (with spacing)
    if (stripped.trim().isEmpty) {
      return block;
    }
    return '${stripped.trimRight()}\n\n$block';
  }

  /// Remove the Mealvana block from a description.
  static String stripBlockFromDescription(String desc) {
    // Find the "---\n[Mealvana Fuel Plan]" or just "[Mealvana Fuel Plan]" start
    final startPattern = RegExp(
      r'(\n{0,2}---\n)?\[Mealvana Fuel Plan\].*?\[/Mealvana\]',
      dotAll: true,
    );
    return desc.replaceAll(startPattern, '').trimRight();
  }

  // ─── Private helpers ───

  static PlanSection? _findSection(NutritionPlan plan, String keyword) {
    for (final section in plan.sections) {
      if (section.id.contains(keyword)) return section;
    }
    return null;
  }

  static String _formatBeforeLine(PlanSection section) {
    final parts = <String>[];
    final carbs = section.carbsTarget?.round();
    final fluidsOz = _mlToOz(section.fluidsTarget);

    if (carbs != null && carbs > 0) parts.add('${carbs}g carb');
    if (fluidsOz != null && fluidsOz > 0) parts.add('${fluidsOz}oz water');

    final timing = section.timing ?? section.subtitle;
    final timingStr = timing != null ? ' ($timing)' : '';
    return 'Pre: ${parts.join(', ')}$timingStr';
  }

  static String _formatDuringLine(PlanSection section, int durationMinutes) {
    final durationHours = durationMinutes / 60.0;
    final parts = <String>[];

    final totalCarbs = section.carbsTarget ?? 0;
    final carbsPerHour = (totalCarbs / durationHours).round();
    if (carbsPerHour > 0) parts.add('${carbsPerHour}g/h carb');

    final totalFluidsOz = _mlToOz(section.fluidsTarget);
    if (totalFluidsOz != null && totalFluidsOz > 0) {
      final fluidsPerHour = (totalFluidsOz / durationHours).round();
      if (fluidsPerHour > 0) parts.add('${fluidsPerHour}oz/h water');
    }

    return 'During: ${parts.join(', ')}';
  }

  static String _formatAfterLine(PlanSection section) {
    final parts = <String>[];
    final protein = section.proteinTarget?.round();
    final carbs = section.carbsTarget?.round();

    if (protein != null && protein > 0) parts.add('${protein}g protein');
    if (carbs != null && carbs > 0) parts.add('${carbs}g carb');

    return 'Post: ${parts.join(', ')} within 30min';
  }

  /// Convert milliliters to fluid ounces (rounded).
  static int? _mlToOz(double? ml) {
    if (ml == null || ml <= 0) return null;
    return (ml / 29.5735).round();
  }
}
