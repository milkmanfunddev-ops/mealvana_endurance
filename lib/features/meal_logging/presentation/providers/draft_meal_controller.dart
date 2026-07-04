import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../domain/consumed_totals.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import 'meal_log_providers.dart';

part 'draft_meal_controller.g.dart';

/// Immutable state for the in-progress "build-a-meal" draft.
///
/// Holds everything the user has added to the current meal before it's
/// persisted as a single [MealLog] row. Every tab in the log sheet
/// (Recent/Favorites/Common/Recipes/unified search/Manual) appends to this
/// draft via [DraftMealController.addComponent] rather than writing to the
/// database directly — the database write only happens once, on
/// [DraftMealController.save].
class DraftMealState {
  const DraftMealState({
    required this.components,
    required this.eatenAt,
    this.name,
    this.slot,
    this.notes,
  });

  /// The food components added so far.
  final List<MealComponent> components;

  /// When the meal was/will be eaten. Defaults to "now" at draft creation;
  /// user-editable via the time-of-day picker.
  final DateTime eatenAt;

  /// User-chosen display name. When null, [displayName] derives one from the
  /// component list.
  final String? name;

  /// Optional meal category (breakfast/lunch/dinner/snack). May be left
  /// unset — the build-a-meal redesign makes this optional.
  final MealSlot? slot;

  /// Optional free-text note.
  final String? notes;

  bool get isEmpty => components.isEmpty;
  bool get isNotEmpty => components.isNotEmpty;

  /// Running totals across all [components], for the persistent bottom bar.
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

  /// The name to persist: [name] if the user set one, otherwise a name
  /// derived by joining the first few component names, e.g.
  /// "Chicken breast + rice + broccoli" or "... + 2 more" beyond [maxParts].
  String displayName({int maxParts = 3}) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (components.isEmpty) return '';
    final shown = components.take(maxParts).map((c) => c.name).join(' + ');
    final remaining = components.length - maxParts;
    return remaining > 0 ? '$shown + $remaining more' : shown;
  }

  DraftMealState copyWith({
    List<MealComponent>? components,
    DateTime? eatenAt,
    String? name,
    bool clearName = false,
    MealSlot? slot,
    bool clearSlot = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return DraftMealState(
      components: components ?? this.components,
      eatenAt: eatenAt ?? this.eatenAt,
      name: clearName ? null : (name ?? this.name),
      slot: clearSlot ? null : (slot ?? this.slot),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// Accumulator controller for the in-progress build-a-meal draft, scoped to
/// [logDate] (`yyyy-MM-dd`). Auto-disposes when the log sheet closes (no
/// remaining watchers), so re-opening the sheet always starts a fresh draft.
@riverpod
class DraftMealController extends _$DraftMealController {
  @override
  DraftMealState build(String logDate) {
    return DraftMealState(components: const [], eatenAt: DateTime.now());
  }

  void addComponent(MealComponent component) {
    state = state.copyWith(components: [...state.components, component]);
  }

  void addComponents(Iterable<MealComponent> components) {
    if (components.isEmpty) return;
    state = state.copyWith(components: [...state.components, ...components]);
  }

  void updateComponents(List<MealComponent> components) {
    state = state.copyWith(components: components);
  }

  void removeComponentAt(int index) {
    final updated = List<MealComponent>.from(state.components)
      ..removeAt(index);
    state = state.copyWith(components: updated);
  }

  void setName(String? name) {
    final trimmed = name?.trim();
    state = state.copyWith(
      name: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearName: trimmed == null || trimmed.isEmpty,
    );
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
  /// draft's components as a new [SavedMeal] favorite (item 23 — reuses
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
