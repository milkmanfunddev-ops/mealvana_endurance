import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../data/ai_coach_client.dart';
import '../domain/coach_insight.dart';

part 'coach_insight_controller.g.dart';

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// State is the most recently fetched [CoachInsight] (or `null` before the
/// first fetch). The panel computes the live draft's [CoachInsightContext.staleMarker]
/// and compares it with `state.value?.staleMarker` to decide whether the shown
/// insight is current or outdated. Cached hits never re-call the edge function,
/// so each [generate] is one billable model call.
///
/// Auto-disposes with the editor screen that hosts it.
@riverpod
class CoachInsightController extends _$CoachInsightController {
  @override
  FutureOr<CoachInsight?> build() => null;

  /// Fetch an insight for [context] and store it. Fires the
  /// `coach_insight_generated` analytics event on success.
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
