import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/checklist_item.dart';
import '../../data/checklist_repository.dart';
import '../../application/gear_template_service.dart';
import '../../../events/application/events_service.dart';
import '../../../auth/data/user_repository.dart';
import '../../../nutrition_plan/data/nutrition_plan_repository.dart';
import '../../../../shared/services/logging_service.dart';

part 'checklist_controller.g.dart';

/// Provider for the gear template service
@riverpod
GearTemplateService gearTemplateService(Ref ref) {
  return GearTemplateService();
}

/// Controller for race day checklist
@riverpod
class ChecklistController extends _$ChecklistController {
  ChecklistRepository get _repository => ref.read(checklistRepositoryProvider);
  GearTemplateService get _gearService => ref.read(gearTemplateServiceProvider);
  EventsService get _eventsService => ref.read(eventsServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  Future<List<ChecklistItem>> build(String eventId) async {
    // Load checklist items for this event
    return await _loadOrCreateChecklist(eventId);
  }

  /// Load existing checklist or create a new one if it doesn't exist
  /// Always regenerates nutrition items from current nutrition plan to stay in sync
  Future<List<ChecklistItem>> _loadOrCreateChecklist(String eventId) async {
    try {
      // Check if checklist already exists
      final exists = await _repository.checklistExists(eventId);

      if (exists) {
        _logger.debug(
          'Loading existing checklist for event $eventId',
          context: 'CHECKLIST_CONTROLLER',
        );

        // Always regenerate nutrition items to stay in sync with current plan
        await _syncNutritionItems(eventId);

        // Return updated checklist
        return await _repository.getChecklistForEvent(eventId);
      }

      // Checklist doesn't exist - generate it
      _logger.info(
        'Generating new checklist for event $eventId',
        context: 'CHECKLIST_CONTROLLER',
      );

      // Get user profile
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      final userId = userProfile.id;

      // Get event details for event type
      final event = await _eventsService.getEventById(userId, eventId);
      if (event == null) {
        throw Exception('Event not found: $eventId');
      }

      // Generate gear list based on event type and user gender
      final gearItems = _gearService.generateGearList(
        eventType: event.eventType,
        userGender: userProfile.gender.name,
        eventSubtype: event.eventSubtype,
      );

      _logger.info(
        'Generated ${gearItems.length} items for ${event.eventType.displayName}',
        context: 'CHECKLIST_CONTROLLER',
      );

      // Create gear checklist items in database
      await _repository.createChecklistItems(
        eventId: eventId,
        userId: userId,
        gearItems: gearItems,
        category: 'gear',
      );

      // Check if nutrition plan exists for this event
      if (event.activityId != null) {
        final nutritionPlanRepo = await ref.read(nutritionPlanRepositoryProvider.future);
        final nutritionPlan = await nutritionPlanRepo.getNutritionPlanByActivityId(
          userId,
          event.activityId!,
        );

        if (nutritionPlan != null) {
          // Extract and aggregate nutrition items from the plan
          final nutritionItems = _extractNutritionItems(nutritionPlan);

          if (nutritionItems.isNotEmpty) {
            _logger.info(
              'Generated ${nutritionItems.length} nutrition items from plan',
              context: 'CHECKLIST_CONTROLLER',
            );

            // Create nutrition checklist items
            await _repository.createChecklistItems(
              eventId: eventId,
              userId: userId,
              gearItems: nutritionItems,
              category: 'nutrition',
            );
          }
        }
      }

      // Return the newly created items (both gear and nutrition)
      return await _repository.getChecklistForEvent(eventId);
    } catch (e, stackTrace) {
      _logger.error(
        'Error loading/creating checklist',
        context: 'CHECKLIST_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sync nutrition items with current nutrition plan
  /// Deletes old nutrition items and regenerates from current plan
  Future<void> _syncNutritionItems(String eventId) async {
    try {
      // Get user profile
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();
      if (userProfile == null) {
        _logger.warning(
          'Cannot sync nutrition items: User not logged in',
          context: 'CHECKLIST_CONTROLLER',
        );
        return;
      }
      final userId = userProfile.id;

      // Get event details
      final event = await _eventsService.getEventById(userId, eventId);
      if (event == null) {
        _logger.warning(
          'Cannot sync nutrition items: Event not found',
          context: 'CHECKLIST_CONTROLLER',
        );
        return;
      }

      // Delete existing nutrition items
      await _repository.deleteNutritionItemsForEvent(eventId);

      // Check if nutrition plan exists for this event
      if (event.activityId != null) {
        final nutritionPlanRepo = await ref.read(nutritionPlanRepositoryProvider.future);
        final nutritionPlan = await nutritionPlanRepo.getNutritionPlanByActivityId(
          userId,
          event.activityId!,
        );

        if (nutritionPlan != null) {
          // Extract and aggregate nutrition items from the plan
          final nutritionItems = _extractNutritionItems(nutritionPlan);

          if (nutritionItems.isNotEmpty) {
            _logger.info(
              'Synced ${nutritionItems.length} nutrition items from plan',
              context: 'CHECKLIST_CONTROLLER',
            );

            // Create nutrition checklist items
            await _repository.createChecklistItems(
              eventId: eventId,
              userId: userId,
              gearItems: nutritionItems,
              category: 'nutrition',
            );
          }
        } else {
          _logger.debug(
            'No nutrition plan found for event $eventId',
            context: 'CHECKLIST_CONTROLLER',
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error syncing nutrition items',
        context: 'CHECKLIST_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - allow checklist to load with gear items even if nutrition sync fails
    }
  }

  /// Extract and aggregate nutrition items from a nutrition plan
  /// Combines quantities of the same food across all sections (before/during/after)
  /// Includes sub-phases (meal, snack, top-up) from "before" section
  /// Returns list of formatted strings like "GU Vanilla Energy Gel - 3 packets"
  List<String> _extractNutritionItems(dynamic nutritionPlan) {
    final Map<String, double> foodQuantities = {};
    final Map<String, String> foodUnits = {};

    // Loop through all sections (before, during, after)
    for (final section in nutritionPlan.sections) {
      // Check if this section has sub-phases (typical for "before" section)
      if (section.subPhases != null && section.subPhases.isNotEmpty) {
        // Extract from sub-phases (meal, snack, top_up)
        for (final subPhase in section.subPhases) {
          _extractFoodItems(
            subPhase.foodItems,
            foodQuantities,
            foodUnits,
          );
        }
      } else {
        // Extract from section's direct food items
        _extractFoodItems(
          section.foodItems,
          foodQuantities,
          foodUnits,
        );
      }
    }

    // Format as checklist items
    final List<String> items = [];
    foodQuantities.forEach((foodName, quantity) {
      final unit = foodUnits[foodName] ?? '';
      final quantityDisplay = quantity % 1 == 0
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(1);

      if (unit.isNotEmpty) {
        items.add('$foodName - $quantityDisplay $unit');
      } else {
        items.add('$foodName - $quantityDisplay');
      }
    });

    return items;
  }

  /// Helper method to extract food items and aggregate quantities
  void _extractFoodItems(
    List foodItems,
    Map<String, double> foodQuantities,
    Map<String, String> foodUnits,
  ) {
    for (final foodItem in foodItems) {
      final foodName = foodItem.displayName ?? foodItem.name;
      final quantityStr = foodItem.quantity ?? '1';

      // Parse quantity (extract number from strings like "3", "1.5", "30m before")
      final quantityMatch = RegExp(r'[\d.]+').firstMatch(quantityStr);
      final quantity = quantityMatch != null
          ? double.tryParse(quantityMatch.group(0)!) ?? 1.0
          : 1.0;

      // Aggregate quantities for the same food
      foodQuantities[foodName] = (foodQuantities[foodName] ?? 0) + quantity;

      // Store unit (use first occurrence)
      if (!foodUnits.containsKey(foodName)) {
        // Try to extract unit from quantity string (e.g., "3 packets" -> "packets")
        final unitMatch = RegExp(r'[\d.]+\s*(.+)').firstMatch(quantityStr);
        foodUnits[foodName] = unitMatch?.group(1)?.trim() ?? '';
      }
    }
  }

  /// Toggle the checked state of an item
  Future<void> toggleItem(String itemId, bool isChecked) async {
    // Optimistically update UI
    state = AsyncValue.data(
      state.value?.map((item) {
            if (item.id == itemId) {
              return item.copyWith(
                isChecked: isChecked,
                checkedAt: isChecked ? DateTime.now() : null,
              );
            }
            return item;
          }).toList() ??
          [],
    );

    // Persist to database
    try {
      await _repository.toggleItemChecked(itemId, isChecked);
    } catch (e) {
      _logger.error(
        'Error toggling item $itemId',
        context: 'CHECKLIST_CONTROLLER',
        error: e,
      );
      // Revert on error by refreshing from database
      ref.invalidateSelf();
    }
  }

  /// Add a custom item to the checklist
  Future<void> addCustomItem(String itemName, [String category = 'gear']) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }

      await _repository.addCustomItem(
        eventId: eventId,
        userId: userProfile.id,
        itemName: itemName,
        category: category,
      );

      _logger.info(
        'Added custom item "$itemName" to $category category',
        context: 'CHECKLIST_CONTROLLER',
      );

      // Reload checklist
      return await _repository.getChecklistForEvent(eventId);
    });
  }

  /// Delete an item from the checklist
  Future<void> deleteItem(String itemId) async {
    // Optimistically update UI
    state = AsyncValue.data(
      state.value?.where((item) => item.id != itemId).toList() ?? [],
    );

    try {
      await _repository.deleteItem(itemId);
    } catch (e) {
      _logger.error(
        'Error deleting item $itemId',
        context: 'CHECKLIST_CONTROLLER',
        error: e,
      );
      // Revert on error
      ref.invalidateSelf();
    }
  }

  /// Regenerate the entire checklist (useful if event type changes)
  Future<void> regenerateChecklist() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // Delete existing checklist
      await _repository.deleteChecklistForEvent(eventId);

      // Create new one
      return await _loadOrCreateChecklist(eventId);
    });
  }

  /// Refresh the checklist from database
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Computed provider for checklist progress
@riverpod
ChecklistProgress checklistProgress(Ref ref, String eventId) {
  final checklistAsync = ref.watch(checklistControllerProvider(eventId));

  return checklistAsync.when(
    data: (items) {
      final total = items.length;
      final checked = items.where((item) => item.isChecked).length;
      return ChecklistProgress(
        total: total,
        checked: checked,
        progress: total > 0 ? checked / total : 0.0,
        isComplete: total > 0 && checked == total,
      );
    },
    loading: () => const ChecklistProgress(total: 0, checked: 0, progress: 0.0, isComplete: false),
    error: (_, __) => const ChecklistProgress(total: 0, checked: 0, progress: 0.0, isComplete: false),
  );
}

/// Progress data class
class ChecklistProgress {
  final int total;
  final int checked;
  final double progress;
  final bool isComplete;

  const ChecklistProgress({
    required this.total,
    required this.checked,
    required this.progress,
    required this.isComplete,
  });
}
