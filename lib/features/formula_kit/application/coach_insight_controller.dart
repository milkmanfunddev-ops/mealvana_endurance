import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../ai_credits/presentation/insufficient_credits_paywall.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
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
  ///  - `ai_coach_chat_repository.dart` (jade-chat edge function, HTTP 402)
  ///  - describe-meal client (describe-meal edge function, HTTP 402)
  ///  - analyze-meal-photo client (analyze-meal-photo edge function, HTTP 402)
  Future<void> generate(
    CoachInsightContext context, {
    String trigger = 'initial',
  }) async {
    final track = _tracker();
    final client = ref.read(aiCoachClientProvider);
    final repo = ref.read(personalFormulasRepositoryProvider);
    final report = ref.read(reportProvider);
    final fid = formulaId;
    await track('coach_insight_requested', {
      'phase': context.phase.analyticsValue,
      'trigger': trigger,
      'component_count': context.components.length,
    });
    if (ref.mounted) state = const AsyncLoading<CoachInsight?>();
    final sw = Stopwatch()..start();

    final result = await AsyncValue.guard<CoachInsight?>(() async {
      final insight = await client.fetchInsight(context);
      sw.stop();
      await track('coach_insight_generated', {
        'phase': context.phase.analyticsValue,
        'mode': 'insight',
        'cached': false,
        'generation_source': insight.generationSource,
        'ai_called': insight.generationSource == 'model',
        'latency_ms': sw.elapsedMilliseconds,
        'input_tokens': insight.inputTokens,
        'output_tokens': insight.outputTokens,
        'total_tokens': insight.totalTokens,
        if (insight.model != null) 'model': insight.model,
        if (insight.costUsd != null) 'cost_usd': insight.costUsd,
        'component_count': context.components.length,
      });

      if (fid != null) {
        try {
          await repo.persistInsight(
            formulaId: fid,
            insightText: insight.insight,
            marker: insight.staleMarker,
          );
        } catch (e, st) {
          // The insight still shows; only the saved copy is missing.
          await report.fault(
            e,
            stackTrace: st,
            area: 'formula_kit',
            message: 'coach insight auto-persist failed',
            extra: {'formula_id': fid},
          );
        }
      }

      return insight;
    });
    if (ref.mounted) state = result;

    // If the call failed because the user is out of AI credits, surface the
    // buy-credits paywall. The error also stays in [state] so the panel can
    // render its inline error.
    if (result is AsyncError) {
      sw.stop();
      await track('coach_insight_failed', {
        'phase': context.phase.analyticsValue,
        'trigger': trigger,
        'component_count': context.components.length,
        'latency_ms': sw.elapsedMilliseconds,
        'error_type': result.error.runtimeType.toString(),
      });
      maybeShowInsufficientCreditsPaywall(result.error);
    }
  }

  /// Fire the refresh-tapped analytics event, then re-fetch for [context].
  Future<void> refresh(CoachInsightContext context) async {
    await _tracker()('coach_insight_refresh_tapped', {
      'phase': context.phase.analyticsValue,
    });
    if (!ref.mounted) return;
    await generate(context, trigger: 'refresh');
  }

  /// Captures analytics and report now, so the returned tracker stays usable
  /// after an async gap even if this notifier has been disposed.
  Future<void> Function(String event, Map<String, dynamic> properties)
  _tracker() {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    final report = ref.read(reportProvider);
    return (event, properties) async {
      try {
        await analytics.track(event, properties: properties);
      } catch (e, st) {
        // Analytics must never break the feature.
        await report.fault(
          e,
          stackTrace: st,
          area: 'formula_kit',
          message: 'coach insight analytics event failed',
          extra: {'event': event},
        );
      }
    };
  }
}
