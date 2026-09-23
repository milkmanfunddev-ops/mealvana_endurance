import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/logging_service.dart';
import '../../data/personal_templates_repository.dart';
import '../../domain/personal_template.dart';
import '../../../activities/domain/activity.dart';
import '../../../nutrition_plan/domain/nutrition_plan.dart';

part 'personal_templates_controller.g.dart';

/// Maximum number of templates a user can save
const kMaxTemplateCount = 10;

/// Result of a save template operation
enum SaveTemplateResult { success, limitReached, error }

/// Controller for personal nutrition plan templates
@riverpod
class PersonalTemplatesController extends _$PersonalTemplatesController {
  PersonalTemplatesRepository get _repository =>
      ref.read(personalTemplatesRepositoryProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<List<PersonalTemplate>> build() async {
    final userId = await ref.read(userIdProvider.future);
    return _repository.getTemplatesForUser(userId);
  }

  /// Save a nutrition plan as a template from an activity
  Future<SaveTemplateResult> saveTemplate({
    required Activity activity,
    required NutritionPlan nutritionPlan,
    required String templateName,
  }) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      if (!ref.mounted) return SaveTemplateResult.error;

      // Check template count limit
      final count = await _repository.getTemplateCount(userId);
      if (!ref.mounted) return SaveTemplateResult.error;
      if (count >= kMaxTemplateCount) {
        return SaveTemplateResult.limitReached;
      }

      // Extract macro totals from the nutrition plan
      final macros = _extractMacroTotals(nutritionPlan);

      // Build brick segment order if applicable
      List<String>? brickSegmentOrder;
      if (activity.isBrick && activity.brickMetadata != null) {
        brickSegmentOrder = activity.brickMetadata!.segments
            .map((s) => s.sport)
            .toList();
      }

      // Determine activity type string
      final activityType = activity.isBrick
          ? 'brick'
          : activity.activityType.dbValue;

      final template = PersonalTemplate(
        id: const Uuid().v4(),
        userId: userId,
        name: templateName,
        activityType: activityType,
        originalDurationMinutes: activity.durationMinutes,
        originalDistance: activity.distanceMiles,
        originalActivityTitle: activity.title,
        planData: nutritionPlan.toJson(),
        totalCarbsG: macros['carbs'],
        totalProteinG: macros['protein'],
        totalFatG: macros['fat'],
        totalSodiumMg: macros['sodium'],
        totalFluidsMl: macros['fluids'],
        totalCalories: macros['calories'],
        brickSegmentOrder: brickSegmentOrder,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.createTemplate(template);
      if (!ref.mounted) return SaveTemplateResult.success;

      // Refresh the list
      ref.invalidateSelf();

      return SaveTemplateResult.success;
    } catch (e, stackTrace) {
      if (ref.mounted) {
        _logger.error(
          'Failed to save template',
          context: 'PERSONAL_TEMPLATES_CONTROLLER',
          error: e,
          stackTrace: stackTrace,
        );
      }
      return SaveTemplateResult.error;
    }
  }

  /// Get templates for a specific sport type
  Future<List<PersonalTemplate>> getTemplatesForSport(
    String activityType,
  ) async {
    final userId = await ref.read(userIdProvider.future);
    if (!ref.mounted) return [];
    return _repository.getTemplatesForSport(userId, activityType);
  }

  /// Get brick templates matching a specific segment order
  Future<List<PersonalTemplate>> getTemplatesForBrick(
    List<String> segmentOrder,
  ) async {
    final userId = await ref.read(userIdProvider.future);
    if (!ref.mounted) return [];
    return _repository.getTemplatesForBrick(userId, segmentOrder);
  }

  /// Rename a template
  Future<void> renameTemplate(String templateId, String newName) async {
    try {
      await _repository.updateTemplateName(templateId, newName);
      if (!ref.mounted) return;
      ref.invalidateSelf();
    } catch (e, stackTrace) {
      if (!ref.mounted) rethrow;
      _logger.error(
        'Failed to rename template',
        context: 'PERSONAL_TEMPLATES_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      if (!ref.mounted) return;
      await _repository.deleteTemplate(templateId, userId);
      if (!ref.mounted) return;
      ref.invalidateSelf();
    } catch (e, stackTrace) {
      if (!ref.mounted) rethrow;
      _logger.error(
        'Failed to delete template',
        context: 'PERSONAL_TEMPLATES_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the current template count
  Future<int> getTemplateCount() async {
    final userId = await ref.read(userIdProvider.future);
    if (!ref.mounted) return 0;
    return _repository.getTemplateCount(userId);
  }

  /// Extract macro totals from a nutrition plan by summing food items
  Map<String, int> _extractMacroTotals(NutritionPlan plan) {
    var totalCarbs = 0;
    var totalProtein = 0;
    var totalFat = 0;
    var totalSodium = 0;
    var totalFluids = 0;
    var totalCalories = 0;

    for (final section in plan.sections) {
      // Sum from direct food items
      for (final food in section.foodItems) {
        final info = food.nutritionalInfo;
        if (info == null) continue;
        totalCarbs += info.carbs ?? 0;
        totalProtein += info.protein ?? 0;
        totalFat += info.fat ?? 0;
        totalSodium += info.sodium ?? 0;
        totalFluids += (info.fluids ?? 0).round();
        totalCalories += info.calories ?? 0;
      }

      // Sum from sub-phase food items (template-based before sections)
      if (section.hasSubPhases) {
        for (final subPhase in section.subPhases!) {
          for (final food in subPhase.foodItems) {
            final info = food.nutritionalInfo;
            if (info == null) continue;
            totalCarbs += info.carbs ?? 0;
            totalProtein += info.protein ?? 0;
            totalFat += info.fat ?? 0;
            totalSodium += info.sodium ?? 0;
            totalFluids += (info.fluids ?? 0).round();
            totalCalories += info.calories ?? 0;
          }
        }
      }
    }

    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'fat': totalFat,
      'sodium': totalSodium,
      'fluids': totalFluids,
      'calories': totalCalories,
    };
  }
}
