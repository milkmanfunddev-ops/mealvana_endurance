import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../domain/consumed_totals.dart';
import '../../domain/meal_auto_name.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import 'meal_log_providers.dart';

part 'draft_meal_controller.g.dart';

/// Immutable state for the in-progress "build-a-meal" draft.
///
/// Holds everything the user has added to the current meal before it's
/// persisted as a single [MealLog] row. This draft only lives inside
/// `BuildMealScreen` (the dedicated meal-builder surface) — `LogMealScreen`
/// is quick-log only and writes a terminal [MealLog] row per tap instead of
/// accumulating into this draft.
class DraftMealState {
  const DraftMealState({
    required this.components,
    required this.eatenAt,
    this.name,
    this.nameManuallySet = false,
    this.slot,
    this.notes,
  });

  /// The food components added so far.
  final List<MealComponent> components;

  /// When the meal was/will be eaten. Defaults to "now" at draft creation;
  /// user-editable via the time-of-day picker.
  final DateTime eatenAt;

  /// The current display name — auto-derived from [components] via
  /// [deriveMealName] whenever [nameManuallySet] is false, or the user's own
  /// typed name once they've edited the field.
  final String? name;

  /// True once the user has manually edited the name field. While false,
  /// [name] is kept in sync with [components] automatically (mirrors the
  /// activity-title `activityTitleManuallySet` pattern).
  final bool nameManuallySet;

  /// Optional meal category (breakfast/lunch/dinner/snack). May be left
  /// unset — the build-a-meal redesign makes this optional.
  final MealSlot? slot;

  /// Optional free-text note.
  final String? notes;

  bool get isEmpty => components.isEmpty;
  bool get isNotEmpty => components.isNotEmpty;

  /// Running totals across all [components], for the builder's summary.
  ConsumedTotals get totals {
    return components.fold(const ConsumedTotals(), (acc, c) {
      return ConsumedTotals(
        calories: acc.calories + (c.calories ?? 0),
        carbsG: acc.carbsG + (c.carbG ?? 0),
        proteinG: acc.proteinG + (c.proteinG ?? 0),
        fatG: acc.fatG + (c.fatG ?? 0),
        sodiumMg: acc.sodiumMg + (c.sodiumMg ?? 0),
      );
    });
  }

  /// The name to persist/display. [name] is always kept resolved (auto or
  /// manual) by the controller, so this is a plain accessor with an empty
  /// fallback for the pre-first-component state.
  String displayName() => name ?? '';

  DraftMealState copyWith({
    List<MealComponent>? components,
    DateTime? eatenAt,
    String? name,
    bool clearName = false,
    bool? nameManuallySet,
    MealSlot? slot,
    bool clearSlot = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return DraftMealState(
      components: components ?? this.components,
      eatenAt: eatenAt ?? this.eatenAt,
      name: clearName ? null : (name ?? this.name),
      nameManuallySet: nameManuallySet ?? this.nameManuallySet,
      slot: clearSlot ? null : (slot ?? this.slot),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// Accumulator controller for the in-progress build-a-meal draft, scoped to
/// [logDate] (`yyyy-MM-dd`). Auto-disposes when `BuildMealScreen` closes (no
/// remaining watchers), so re-opening it always starts a fresh draft.
@riverpod
class DraftMealController extends _$DraftMealController {
  @override
  DraftMealState build(String logDate) {
    return DraftMealState(components: const [], eatenAt: DateTime.now());
  }

  void addComponent(MealComponent component) {
    _applyComponents([...state.components, component]);
  }

  void addComponents(Iterable<MealComponent> components) {
    if (components.isEmpty) return;
    _applyComponents([...state.components, ...components]);
  }

  void updateComponents(List<MealComponent> components) {
    _applyComponents(components);
  }

  void removeComponentAt(int index) {
    final updated = List<MealComponent>.from(state.components)
      ..removeAt(index);
    _applyComponents(updated);
  }

  /// Applies [components] to state, recomputing the auto-derived name via
  /// [deriveMealName] unless the user has manually set one
  /// ([DraftMealState.nameManuallySet]).
  void _applyComponents(List<MealComponent> components) {
    if (state.nameManuallySet) {
      state = state.copyWith(components: components);
      return;
    }
    final auto = deriveMealName(components);
    state = state.copyWith(
      components: components,
      name: auto.isEmpty ? null : auto,
      clearName: auto.isEmpty,
    );
  }

  /// Sets the meal name from user input. An empty/blank [name] reverts to
  /// auto-naming (recomputed from the current components) rather than
  /// leaving the field permanently blank.
  void setName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      final auto = deriveMealName(state.components);
      state = state.copyWith(
        name: auto.isEmpty ? null : auto,
        clearName: auto.isEmpty,
        nameManuallySet: false,
      );
      return;
    }
    state = state.copyWith(name: trimmed, nameManuallySet: true);
  }

  void setEatenAt(DateTime eatenAt) {
    state = state.copyWith(eatenAt: eatenAt);
  }

  void setSlot(MealSlot? slot) {
    state = state.copyWith(slot: slot, clearSlot: slot == null);
  }

  void setNotes(String? notes) {
    final trimmed = notes?.trim();
    state = state.copyWith(
      notes: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearNotes: trimmed == null || trimmed.isEmpty,
    );
  }

  /// Discards the current draft (e.g. user taps "Clear").
  void clear() {
    state = DraftMealState(components: const [], eatenAt: DateTime.now());
  }

  /// Persists the draft as a single [MealLog] row via
  /// [MealLogController.logFromComponents], then clears the draft on success.
  ///
  /// When [alsoSaveAsFavorite] is true and the write succeeds, also saves the
  /// draft's components as a new [SavedMeal] favorite (reuses
  /// [MealLogController.saveLogAsFavorite] with a throwaway in-memory
  /// [MealLog], since that method only reads name/components/totals off it).
  ///
  /// Returns true on success. No-ops (returns false) when the draft is empty.
  Future<bool> save({bool alsoSaveAsFavorite = false}) async {
    final current = state;
    if (current.isEmpty) return false;

    final controller = ref.read(mealLogControllerProvider.notifier);
    final name = current.displayName();

    await controller.logFromComponents(
      name: name,
      slot: current.slot,
      logDate: logDate,
      source: MealLogSource.manual,
      components: current.components,
      notes: current.notes,
      eatenAt: current.eatenAt,
    );

    if (!ref.mounted) return false;
    final result = ref.read(mealLogControllerProvider);
    final success = result is AsyncData;
    if (!success) return false;

    if (alsoSaveAsFavorite) {
      final userRepo = await ref.read(userRepositoryProvider.future);
      final user = await userRepo.getCurrentUser();
      if (user != null && ref.mounted) {
        final now = DateTime.now();
        final tempLog = MealLog(
          id: '',
          userId: user.id,
          logDate: logDate,
          slot: current.slot,
          name: name,
          source: MealLogSource.manual,
          components: current.components,
          notes: current.notes,
          eatenAt: current.eatenAt,
          createdAt: now,
          updatedAt: now,
        );
        await ref
            .read(mealLogControllerProvider.notifier)
            .saveLogAsFavorite(tempLog);
      }
    }

    if (ref.mounted) clear();
    return true;
  }
}
