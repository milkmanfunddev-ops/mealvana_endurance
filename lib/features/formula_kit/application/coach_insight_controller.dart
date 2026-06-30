import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../shared/services/app_external_deps.dart';
import '../data/ai_coach_client.dart';
import '../data/personal_formulas_repository.dart';
import '../domain/coach_insight.dart';

part 'coach_insight_controller.g.dart';

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
/// the persisted insight from the Drift row so it survives navigation. For new
/// formulas ([formulaId] == null), starts blank.
///
/// On [generate], the insight is auto-persisted to the formula's row so it
/// survives navigating away and back without an explicit Save.
@riverpod
class CoachInsightController extends _$CoachInsightController {
  @override
  FutureOr<CoachInsight?> build(String? formulaId) async {
    if (formulaId == null) return null;
    final repo = ref.read(personalFormulasRepositoryProvider);
    final formula = await repo.getById(formulaId);
    if (formula == null || formula.coachInsightText == null) return null;
    return CoachInsight(
      insight: formula.coachInsightText!,
      staleMarker: formula.coachInsightMarker ?? '',
    );
  }

  /// Fetch an insight for [context] and store it. Auto-persists to the
  /// formula's Drift row for existing formulas. Fires the
  /// `coach_insight_generated` analytics event on success.
  ///
  /// **402 / insufficient-credits handling**: [AiCoachClient.fetchInsight]
  /// throws [InsufficientCreditsException] when the edge function returns
  /// HTTP 402. [AsyncValue.guard] captures it as
  /// `AsyncError(InsufficientCreditsException(...))` in [state]. The
  /// presentation layer should use `ref.listen` on this controller's state
  /// to detect that error type and open the `/buy-credits` paywall. Example:
  ///
  /// ```dart
  /// ref.listen<AsyncValue<CoachInsight?>>(
  ///   coachInsightControllerProvider(formulaId),
  ///   (_, next) {
  ///     if (next.error is InsufficientCreditsException) {
  ///       MealvanaSnackbar.showError(context, 'Not enough credits',
  ///           actionLabel: 'Buy Credits',
  ///           onAction: () => context.pushNamed('buy-credits'));
  ///     }
  ///   },
  /// );
  /// ```
  ///
  /// TODO: adopt the same [InsufficientCreditsException] catch pattern in:
  ///  - `jade_chat_repository.dart` (jade-chat edge function, HTTP 402)
  ///  - describe-meal client (describe-meal edge function, HTTP 402)
  ///  - analyze-meal-photo client (analyze-meal-photo edge function, HTTP 402)
  Future<void> generate(CoachInsightContext context) async {
    state = const AsyncLoading<CoachInsight?>();
    final sw = Stopwatch()..start();

    state = await AsyncValue.guard<CoachInsight?>(() async {
      final client = ref.read(aiCoachClientProvider);
      final insight = await client.fetchInsight(context);
      sw.stop();
      await _track('coach_insight_generated', {
        'phase': context.phase.analyticsValue,
        'mode': 'insight',
        'cached': false,
        'latency_ms': sw.elapsedMilliseconds,
        'input_tokens': insight.inputTokens,
        'output_tokens': insight.outputTokens,
      });

      if (formulaId != null) {
        try {
          final repo = ref.read(personalFormulasRepositoryProvider);
          await repo.persistInsight(
            formulaId: formulaId!,
            insightText: insight.insight,
            marker: insight.staleMarker,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[CoachInsightController] auto-persist failed: $e');
          }
        }
      }

      return insight;
    });
  }

  /// Fire the refresh-tapped analytics event, then re-fetch for [context].
  Future<void> refresh(CoachInsightContext context) async {
    await _track('coach_insight_refresh_tapped', {
      'phase': context.phase.analyticsValue,
    });
    await generate(context);
  }

  Future<void> _track(String event, Map<String, dynamic> properties) async {
    try {
      final analytics = ref.read(appExternalDepsProvider).analytics;
      await analytics.track(event, properties: properties);
    } catch (e) {
      // Analytics must never break the feature.
      if (kDebugMode) debugPrint('[CoachInsightController] analytics error: $e');
    }
  }
}
