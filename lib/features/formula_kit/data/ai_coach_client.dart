import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/coach_insight.dart';

part 'ai_coach_client.g.dart';

/// Category of failure surfaced by [AiCoachClient].
enum AiCoachFailureKind {
  /// Device has no network connectivity.
  offline,

  /// The edge function or AI Gateway returned an unexpected error.
  serverError,

  /// No signed-in user.
  unauthenticated,
}

/// Thrown by [AiCoachClient] when an insight call cannot be completed.
class AiCoachException implements Exception {
  const AiCoachException({
    required this.kind,
    required this.userMessage,
    this.debugMessage,
  });

  final AiCoachFailureKind kind;

  /// Human-presentable reason, suitable for display directly in the UI.
  final String userMessage;

  /// Internal detail for logs only — never shown to the user.
  final String? debugMessage;

  @override
  String toString() => 'AiCoachException(${kind.name}): $userMessage';
}

@riverpod
AiCoachClient aiCoachClient(Ref ref) {
  return AiCoachClient(supabase: ref.watch(supabaseClientProvider));
}

/// Remote-only client for the `ai-coach` edge function.
///
/// Today it serves `mode: "insight"`. All network failures map to a typed
/// [AiCoachException] so the presentation layer can branch on the kind without
/// string-matching.
class AiCoachClient {
  AiCoachClient({required SupabaseClient supabase}) : _supabase = supabase;

  final SupabaseClient _supabase;

  /// Fetch a coach insight for the supplied draft [context].
  ///
  /// Returns a [CoachInsight] tagged with `context.staleMarker`. Throws
  /// [AiCoachException] on any failure.
  Future<CoachInsight> fetchInsight(CoachInsightContext context) async {
    if (_supabase.auth.currentUser == null) {
      throw const AiCoachException(
        kind: AiCoachFailureKind.unauthenticated,
        userMessage: 'You must be signed in to use this feature.',
      );
    }

    final marker = context.staleMarker;

    try {
      final response = await _supabase.functions.invoke(
        'ai-coach',
        body: {
          'mode': 'insight',
          'stale_marker': marker,
          'context': context.toJson(),
        },
      );

      if (response.status != 200) {
        if (kDebugMode) {
          debugPrint(
            '[AiCoachClient] ai-coach status ${response.status}: ${response.data}',
          );
        }
        throw AiCoachException(
          kind: AiCoachFailureKind.serverError,
          userMessage:
              _extractError(response.data) ??
              'Coach insight is unavailable right now. Please try again.',
          debugMessage: 'ai-coach returned status ${response.status}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final insight = (data['insight'] as String?)?.trim() ?? '';
      if (insight.isEmpty) {
        throw const AiCoachException(
          kind: AiCoachFailureKind.serverError,
          userMessage:
              'Coach insight is unavailable right now. Please try again.',
          debugMessage: 'ai-coach returned an empty insight',
        );
      }

      final usage = data['usage'];
      return CoachInsight(
        insight: insight,
        staleMarker: marker,
        inputTokens: usage is Map
            ? (usage['input_tokens'] as num?)?.toInt() ?? 0
            : 0,
        outputTokens: usage is Map
            ? (usage['output_tokens'] as num?)?.toInt() ?? 0
            : 0,
        model: usage is Map ? usage['model'] as String? : null,
        costUsd: usage is Map ? (usage['cost_usd'] as num?)?.toDouble() : null,
        generationSource: usage is Map
            ? usage['source'] as String? ?? 'model'
            : 'model',
      );
    } on AiCoachException {
      rethrow;
    } on InsufficientCreditsException {
      rethrow;
    } on SocketException catch (e) {
      throw AiCoachException(
        kind: AiCoachFailureKind.offline,
        userMessage:
            'No internet connection. Please check your network and try again.',
        debugMessage: e.toString(),
      );
    } on FunctionException catch (e) {
      if (kDebugMode) debugPrint('[AiCoachClient] FunctionException: $e');

      // HTTP 402 → the user has run out of AI credits.
      // Parse the structured error body and throw a typed exception so the
      // presentation layer can route the user to the buy-credits paywall.
      if (e.status == 402) {
        final body = e.details;
        final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
        if (map['error'] == 'insufficient_credits') {
          throw InsufficientCreditsException.fromMap(map);
        }
        // Malformed 402 — still treat as credits error with safe defaults.
        throw InsufficientCreditsException(
          balance: (map['balance'] as num?)?.toInt() ?? 0,
          cost: (map['cost'] as num?)?.toInt() ?? 0,
          message: (map['message'] as String?) ?? 'Not enough AI credits.',
        );
      }

      throw AiCoachException(
        kind: AiCoachFailureKind.serverError,
        userMessage:
            'Coach insight is unavailable right now. Please try again.',
        debugMessage: 'FunctionException ${e.status}: $e',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AiCoachClient] unexpected error: $e');
      throw AiCoachException(
        kind: AiCoachFailureKind.serverError,
        userMessage: 'Something went wrong. Please try again.',
        debugMessage: e.toString(),
      );
    }
  }

  String? _extractError(dynamic data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return null;
  }
}
