import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/checklist_item.dart';
import '../../data/checklist_repository.dart';
import '../../application/gear_template_service.dart';
import '../../../events/application/events_service.dart';
import '../../../auth/data/user_repository.dart';
import '../../../nutrition_plan/data/nutrition_plan_repository.dart';
import '../../../../shared/services/report/report.dart';

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
  Report get _report => ref.report;

  @override
  Future<List<ChecklistItem>> build(String eventId) async {
    // Load checklist items for this event
    return await _loadOrCreateChecklist(eventId);
  }

  /// Load existing checklist or create a new one if it doesn't exist
  /// Always regenerates nutrition items from current nutrition plan to stay in sync
  Future<List<ChecklistItem>> _loadOrCreateChecklist(String eventId) async {
    final report = _report;
    try {
      // Read before the first await: this auto-dispose provider can be
      // disposed mid-load.
      final repository = _repository;
      // Check if checklist already exists
      final exists = await repository.checklistExists(eventId);

      if (exists) {
        report.debug(
          'Loading existing checklist for event $eventId',
          area: 'race_checklist',
        );

        // Always regenerate nutrition items to stay in sync with current plan
        await _syncNutritionItems(eventId);

        // Return updated checklist
        return await repository.getChecklistForEvent(eventId);
      }

      // Checklist doesn't exist - generate it
      report.info(
        'Generating new checklist for event $eventId',
        area: 'race_checklist',
      );

      // Disposed mid-load: the result would be discarded anyway.
      if (!ref.mounted) return const <ChecklistItem>[];
      final gearService = _gearService;
      final eventsService = _eventsService;

      // Get user profile
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      final userId = userProfile.id;

      // Get event details for event type
      final event = await eventsService.getEventById(userId, eventId);
      if (event == null) {
        throw Exception('Event not found: $eventId');
      }

      // Generate gear list based on event type and user gender
      final gearItems = gearService.generateGearList(
        eventType: event.eventType,
        userGender: userProfile.gender.name,
        eventSubtype: event.eventSubtype,
      );

      report.info(
        'Generated ${gearItems.length} items for ${event.eventType.displayName}',
        area: 'race_checklist',
      );

      // Create gear checklist items in database
      await repository.createChecklistItems(
        eventId: eventId,
        userId: userId,
        gearItems: gearItems,
        category: 'gear',
      );

      // Check if nutrition plan exists for this event. Disposed mid-load:
      // the next load sees the checklist and syncs nutrition items then.
      if (event.activityId != null && ref.mounted) {
        final nutritionPlanRepo = await ref.read(
          nutritionPlanRepositoryProvider.future,
        );
        final nutritionPlan = await nutritionPlanRepo
            .getNutritionPlanByActivityId(userId, event.activityId!);

        if (nutritionPlan != null) {
          // Extract and aggregate nutrition items from the plan
          final nutritionItems = _extractNutritionItems(nutritionPlan);

          if (nutritionItems.isNotEmpty) {
            report.info(
              'Generated ${nutritionItems.length} nutrition items from plan',
              area: 'race_checklist',
            );

            // Create nutrition checklist items
            await repository.createChecklistItems(
              eventId: eventId,
              userId: userId,
              gearItems: nutritionItems,
              category: 'nutrition',
            );
          }
        }
      }

      // Return the newly created items (both gear and nutrition)
      return await repository.getChecklistForEvent(eventId);
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error loading/creating checklist',
      );
      rethrow;
    }
  }

  /// Sync nutrition items with current nutrition plan
  /// Deletes old nutrition items and regenerates from current plan
  Future<void> _syncNutritionItems(String eventId) async {
    // Called after the caller's first await: the provider may already be
    // disposed, and its load result would be discarded anyway.
    if (!ref.mounted) return;
    final report = _report;
    try {
      final repository = _repository;
      final eventsService = _eventsService;
      // Get user profile
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();
      if (userProfile == null) {
        report.degraded(
          LoggedFault('Cannot sync nutrition items: User not logged in'),
          area: 'race_checklist',
        );
        return;
      }
      final userId = userProfile.id;

      // Get event details
      final event = await eventsService.getEventById(userId, eventId);
      if (event == null) {
        report.degraded(
          LoggedFault('Cannot sync nutrition items: Event not found'),
          area: 'race_checklist',
        );
        return;
      }

      // Delete existing nutrition items
      await repository.deleteNutritionItemsForEvent(eventId);

      // Check if nutrition plan exists for this event. Disposed mid-sync:
      // the next load re-syncs nutrition items.
      if (event.activityId != null && ref.mounted) {
        final nutritionPlanRepo = await ref.read(
          nutritionPlanRepositoryProvider.future,
        );
        final nutritionPlan = await nutritionPlanRepo
            .getNutritionPlanByActivityId(userId, event.activityId!);

        if (nutritionPlan != null) {
          // Extract and aggregate nutrition items from the plan
          final nutritionItems = _extractNutritionItems(nutritionPlan);

          if (nutritionItems.isNotEmpty) {
            report.info(
              'Synced ${nutritionItems.length} nutrition items from plan',
              area: 'race_checklist',
            );

            // Create nutrition checklist items
            await repository.createChecklistItems(
              eventId: eventId,
              userId: userId,
              gearItems: nutritionItems,
              category: 'nutrition',
            );
          }
        } else {
          report.debug(
            'No nutrition plan found for event $eventId',
            area: 'race_checklist',
          );
        }
      }
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error syncing nutrition items',
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
          _extractFoodItems(subPhase.foodItems, foodQuantities, foodUnits);
        }
      } else {
        // Extract from section's direct food items
        _extractFoodItems(section.foodItems, foodQuantities, foodUnits);
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
    final report = _report;
    try {
      await _repository.toggleItemChecked(itemId, isChecked);
    } catch (e) {
      report.fault(
        e,
        area: 'race_checklist',
        message: 'Error toggling item $itemId',
      );
      // Revert on error by refreshing from database
      if (ref.mounted) ref.invalidateSelf();
    }
  }

  /// Add a custom item to the checklist
  Future<void> addCustomItem(
    String itemName, [
    String category = 'gear',
  ]) async {
    state = const AsyncLoading();
    final repository = _repository;
    final report = _report;

    final result = await AsyncValue.guard(() async {
      final userRepo = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepo.getCurrentUser();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }

      await repository.addCustomItem(
        eventId: eventId,
        userId: userProfile.id,
        itemName: itemName,
        category: category,
      );

      report.info(
        'Added custom item "$itemName" to $category category',
        area: 'race_checklist',
      );

      // Reload checklist
      return await repository.getChecklistForEvent(eventId);
    });
    if (ref.mounted) state = result;
  }

  /// Delete an item from the checklist
  Future<void> deleteItem(String itemId) async {
    // Optimistically update UI
    state = AsyncValue.data(
      state.value?.where((item) => item.id != itemId).toList() ?? [],
    );

    final report = _report;
    try {
      await _repository.deleteItem(itemId);
    } catch (e) {
      report.fault(
        e,
        area: 'race_checklist',
        message: 'Error deleting item $itemId',
      );
      // Revert on error
      if (ref.mounted) ref.invalidateSelf();
    }
  }

  /// Regenerate the entire checklist (useful if event type changes)
  Future<void> regenerateChecklist() async {
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      // Delete existing checklist
      await _repository.deleteChecklistForEvent(eventId);

      // Create new one
      return await _loadOrCreateChecklist(eventId);
    });
    if (ref.mounted) state = result;
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
    loading: () => const ChecklistProgress(
      total: 0,
      checked: 0,
      progress: 0.0,
      isComplete: false,
    ),
    error: (_, __) => const ChecklistProgress(
      total: 0,
      checked: 0,
      progress: 0.0,
      isComplete: false,
    ),
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
