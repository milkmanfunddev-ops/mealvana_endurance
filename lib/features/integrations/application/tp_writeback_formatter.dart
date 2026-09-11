import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../nutrition_plan/domain/nutrition_plan.dart';

/// Converts a NutritionPlan into a compact text block for TP workout descriptions.
///
/// Macro register (RULED Xuan, 2026-09-10 — TP-5 option A): Pre + During
/// ONLY — no Post line. Pre = carbs g, water oz, timing. During = carbs g/h
/// (essential), water oz/h, sodium mg/h.
///
/// Format:
/// ```
/// ---
/// [Mealvana Fuel Plan]
/// Pre: 60g carb, 16oz water (2-3h before)
/// During: 60g/h carb, 500ml/h water, 400mg/h sodium
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
      final effectiveDuration =
          durationMinutes ?? duringSection.byHourData?.durationMinutes;
      if (effectiveDuration != null &&
          effectiveDuration >= 60 &&
          (duringSection.carbsTarget ?? 0) > 0) {
        lines.add(_formatDuringLine(duringSection, effectiveDuration));
      }
    }

    // No Post line: the macro register is Pre + During ONLY (RULED Xuan,
    // 2026-09-10) — recovery guidance lives in the app, not the TP block.

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
  ///
  /// Delimiter robustness (RULED fix, handback §3): the fuel terminator
  /// `[/Mealvana]` is a PREFIX of `[/Mealvana Feedback]` — a truncated fuel
  /// block must not make this strip swallow the feedback block (athlete
  /// notes included). The negative lookahead keeps the match from ending
  /// inside the feedback terminator.
  static String stripBlockFromDescription(String desc) {
    // Find the "---\n[Mealvana Fuel Plan]" or just "[Mealvana Fuel Plan]" start
    final startPattern = RegExp(
      r'(\n{0,2}---\n)?\[Mealvana Fuel Plan\].*?\[/Mealvana\](?! Feedback)',
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

    // Water rate in ml/h — the bundle manifest's amended TP-5 register
    // ("During water ml/h") supersedes the handback's oz phrasing; the
    // ratified consent rendering's example block agrees ("500 ml/hr").
    final totalFluidsMl = section.fluidsTarget;
    if (totalFluidsMl != null && totalFluidsMl > 0) {
      final fluidsPerHour = (totalFluidsMl / durationHours).round();
      if (fluidsPerHour > 0) parts.add('${fluidsPerHour}ml/h water');
    }

    // Sodium rate (ADDED per the ruled register — absent before).
    final totalSodiumMg = section.sodiumTarget;
    if (totalSodiumMg != null && totalSodiumMg > 0) {
      final sodiumPerHour = (totalSodiumMg / durationHours).round();
      if (sodiumPerHour > 0) parts.add('${sodiumPerHour}mg/h sodium');
    }

    return 'During: ${parts.join(', ')}';
  }

  // ─── Feedback block ───

  static const String feedbackStartDelimiter = '[Mealvana Feedback]';
  static const String feedbackEndDelimiter = '[/Mealvana Feedback]';

  /// Format completion feedback into a delimited text block for TP descriptions.
  static String formatFeedbackBlock({required int rating, String? notes}) {
    final lines = <String>[];
    lines.add('---');
    lines.add(feedbackStartDelimiter);
    lines.add('Rating: $rating/5');
    if (notes != null && notes.trim().isNotEmpty) {
      lines.add('Notes: ${notes.trim()}');
    }
    lines.add(feedbackEndDelimiter);
    return lines.join('\n');
  }

  /// Merge a feedback block into an existing workout description.
  /// Replaces any existing feedback block, or appends if none exists.
  static String mergeFeedbackIntoDescription(
    String? existingDesc,
    String block,
  ) {
    final desc = existingDesc ?? '';
    final stripped = stripFeedbackFromDescription(desc);
    if (stripped.trim().isEmpty) {
      return block;
    }
    return '${stripped.trimRight()}\n\n$block';
  }

  /// Remove the feedback block from a description.
  static String stripFeedbackFromDescription(String desc) {
    final pattern = RegExp(
      r'(\n{0,2}---\n)?\[Mealvana Feedback\].*?\[/Mealvana Feedback\]',
      dotAll: true,
    );
    return desc.replaceAll(pattern, '').trimRight();
  }

  /// Convert milliliters to fluid ounces (rounded).
  static int? _mlToOz(double? ml) {
    if (ml == null || ml <= 0) return null;
    return (ml / 29.5735).round();
  }
}
