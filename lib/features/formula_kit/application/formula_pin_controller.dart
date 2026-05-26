import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../auth/data/user_repository.dart';
import '../data/formula_pins_repository.dart';
import '../domain/formula_phase.dart';
import '../domain/formula_pin.dart';
import '../domain/formula_view.dart';

part 'formula_pin_controller.g.dart';

/// State for the pin controller — the user's active pins, indexed by
/// template id for O(1) lookup from card / detail widgets.
class FormulaPinState {
  const FormulaPinState({required this.pinnedTemplateIds});

  /// Set of `pre_workout_templates.id` / `during_workout_templates.id` values
  /// the user has actively pinned. Includes pins of any [TemplateKind]; the
  /// kind is implied by which list the template appears in. PR 4 widens this
  /// to include `personal_template` pins.
  final Set<String> pinnedTemplateIds;

  FormulaPinState copyWith({Set<String>? pinnedTemplateIds}) {
    return FormulaPinState(
      pinnedTemplateIds: pinnedTemplateIds ?? this.pinnedTemplateIds,
    );
  }

  static const empty = FormulaPinState(pinnedTemplateIds: <String>{});
}

/// Owns the active-pin set for the current user. Card / detail widgets read
/// `pinnedTemplateIds.contains(id)` to render the icon state; `togglePin`
/// mutates Drift (and triggers a non-blocking Supabase upload via the
/// repository) then updates state optimistically.
///
/// Failures during the local Drift write revert the optimistic flip and
/// surface to the UI via the AsyncNotifier error channel. Drift writes are
/// fast and reliable, so the failure case is rare — but it's handled so the
/// icon never lies about persisted state.
@riverpod
class FormulaPinController extends _$FormulaPinController {
  @override
  FutureOr<FormulaPinState> build() async {
    final userRepo = await ref.read(userRepositoryProvider.future);
    final pinsRepo = ref.read(formulaPinsRepositoryProvider);
    final logger = ref.read(appExternalDepsProvider).logger;

    final user = await userRepo.getCurrentUser();
    final userId = user?.id;
    if (userId == null) {
      logger.warning(
        'FormulaPinController build with no authenticated user — '
        'returning empty pin set',
        context: 'FORMULA_KIT',
      );
      return FormulaPinState.empty;
    }

    // On-demand sync (#32 follow-up): this controller drives the ★ icon
    // state for every formula card; on a fresh install (or any state where
    // Drift hasn't been populated yet) we must pull from Supabase before
    // reading. Without this gate, the controller returns an empty pin set
    // and every card renders unpinned even when the user has pins in
    // Supabase.
    //
    // The original #32 fix added the same gate to FormulaLibraryController,
    // but Riverpod builds these two controllers independently — the screen
    // watches both. Whichever builds first wins, and FormulaPinController
    // was racing ahead of FormulaLibraryController's sync. The gate is
    // idempotent (SharedPreferences-backed timestamp shared across all
    // readers of the pins repo), so adding it here costs nothing when
    // FormulaLibraryController has already synced.
    //
    // Caught during the 2026-05-24 smoke test: fresh sim install showed
    // 0/0 pinned despite Supabase having 5 active pins for the user.
    if (await pinsRepo.isStale()) {
      await pinsRepo.syncFromRemote(userId);
    }

    final activePins = await pinsRepo.getActivePinsForUser(userId);
    return FormulaPinState(
      pinnedTemplateIds: {for (final p in activePins) p.templateId},
    );
  }

  /// Toggle the pin for [templateId] / [kind]. Idempotent: if pinned,
  /// unpins; if not, pins. Fires the appropriate `formula_pinned` /
  /// `formula_unpinned` analytics event with the supplied [source] and
  /// scope metadata.
  ///
  /// `phase` is derived from [kind] for the analytics payload.
  /// `subPhase` is used for Before pins; `activities` + `durationBrackets`
  /// for During pins. Pass empty/null for the dimensions that don't apply.
  Future<void> togglePin({
    required String templateId,
    required TemplateKind kind,
    required String source,
    String? subPhase,
    List<String>? activities,
    List<String>? durationBrackets,
  }) async {
    final current = state.value;
    if (current == null) return;

    final userRepo = await ref.read(userRepositoryProvider.future);
    final user = await userRepo.getCurrentUser();
    final userId = user?.id;
    if (userId == null) return;

    final pinsRepo = ref.read(formulaPinsRepositoryProvider);
    final wasPinned = current.pinnedTemplateIds.contains(templateId);

    // Optimistic flip — UI updates immediately.
    final nextIds = Set<String>.from(current.pinnedTemplateIds);
    if (wasPinned) {
      nextIds.remove(templateId);
    } else {
      nextIds.add(templateId);
    }
    state = AsyncData(current.copyWith(pinnedTemplateIds: nextIds));

    try {
      if (wasPinned) {
        await pinsRepo.unpin(
          userId: userId,
          templateId: templateId,
          kind: kind,
        );
      } else {
        await pinsRepo.pin(
          userId: userId,
          templateId: templateId,
          kind: kind,
        );
      }
    } catch (e, st) {
      // Revert optimistic state on failure.
      state = AsyncData(current);
      final logger = ref.read(appExternalDepsProvider).logger;
      logger.error(
        'Failed to toggle pin',
        context: 'FORMULA_KIT',
        error: e,
        stackTrace: st,
        data: {
          'template_id': templateId,
          'kind': kind.wireValue,
          'was_pinned': wasPinned,
        },
      );
      rethrow;
    }

    // Fire analytics after the write succeeds.
    final eventName = wasPinned ? 'formula_unpinned' : 'formula_pinned';
    final payload = <String, dynamic>{
      'template_id': templateId,
      'template_kind': kind.wireValue,
      'phase': _phaseForKind(kind).analyticsValue,
      'source': source,
    };
    if (subPhase != null) payload['sub_phase'] = subPhase;
    if (activities != null && activities.isNotEmpty) {
      payload['activities'] = activities;
    }
    if (durationBrackets != null && durationBrackets.isNotEmpty) {
      payload['duration_brackets'] = durationBrackets;
    }
    await _track(eventName, payload);
  }

  /// Convenience for Before card / detail — extracts scope metadata from a
  /// [BeforeFormulaView] and delegates to [togglePin].
  Future<void> toggleBefore({
    required BeforeFormulaView formula,
    required String source,
  }) async {
    await togglePin(
      templateId: formula.id,
      kind: TemplateKind.preSystem,
      source: source,
      subPhase: formula.subPhase?.storageValue,
    );
  }

  /// Convenience for During card / detail — extracts scope metadata from a
  /// [DuringFormulaView] and delegates to [togglePin].
  Future<void> toggleDuring({
    required DuringFormulaView formula,
    required String source,
  }) async {
    await togglePin(
      templateId: formula.id,
      kind: TemplateKind.duringSystem,
      source: source,
      activities: formula.activityTypes,
      durationBrackets: formula.durationBrackets,
    );
  }

  FormulaPhase _phaseForKind(TemplateKind kind) {
    return switch (kind) {
      TemplateKind.preSystem => FormulaPhase.before,
      TemplateKind.duringSystem => FormulaPhase.during,
      TemplateKind.postSystem => FormulaPhase.after,
    };
  }

  Future<void> _track(String event, Map<String, dynamic> properties) async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(event, properties: properties);
  }
}
