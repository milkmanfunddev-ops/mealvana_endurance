/// Unit tests for [AiCoachClient] — the credit-gating and error-mapping layer.
///
/// This tests the LOGIC of how edge-function responses map to typed exceptions,
/// which is the credit-consumption gating path for all AI features.
///
/// Paths covered:
/// - Unauthenticated → AiCoachException(unauthenticated).
/// - HTTP 200 with valid insight → CoachInsight returned.
/// - HTTP 200 with empty insight → AiCoachException(serverError).
/// - HTTP non-200 → AiCoachException(serverError).
/// - FunctionException(status=402, error=insufficient_credits) →
///     InsufficientCreditsException (REVENUE CRITICAL).
/// - FunctionException(status=402, malformed body) →
///     InsufficientCreditsException with safe defaults.
/// - FunctionException(status=402, non-credits error) →
///     InsufficientCreditsException (all 402s treated as credits).
/// - FunctionException(status=500) → AiCoachException(serverError).
/// - SocketException → AiCoachException(offline).
/// - Unexpected exception → AiCoachException(serverError).
/// - invoke() body includes required fields.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/formula_kit/data/ai_coach_client.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/coach_insight.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {
  @override
  final String id;
  _MockUser(this.id);
}

class _MockFunctions extends Mock implements FunctionsClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _userId = 'user-ai-001';

// Minimal CoachInsightContext for test invocations.
CoachInsightContext _context() {
  return const CoachInsightContext(
    phase: FormulaPhase.during,
    components: [],
  );
}

/// Helper that captures the exception thrown by [fn] without a type mismatch.
Future<Object?> _capture(Future<Object?> Function() fn) async {
  try {
    await fn();
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSupabaseClient supabase;
  late _MockGoTrueClient goTrue;
  late _MockFunctions functions;
  late AiCoachClient client;

  setUp(() {
    supabase = _MockSupabaseClient();
    goTrue = _MockGoTrueClient();
    functions = _MockFunctions();

    when(() => supabase.auth).thenReturn(goTrue);
    when(() => supabase.functions).thenReturn(functions);

    client = AiCoachClient(supabase: supabase);
  });

  // -------------------------------------------------------------------------
  // Unauthenticated
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — unauthenticated', () {
    test('throws AiCoachException(unauthenticated) when no user is signed in',
        () async {
      when(() => goTrue.currentUser).thenReturn(null);

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(
          isA<AiCoachException>().having(
            (e) => e.kind,
            'kind',
            AiCoachFailureKind.unauthenticated,
          ),
        ),
      );
    });

    test(
        'unauthenticated error never calls supabase.functions.invoke',
        () async {
      when(() => goTrue.currentUser).thenReturn(null);

      try {
        await client.fetchInsight(_context());
      } catch (_) {}

      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });
  });

  // -------------------------------------------------------------------------
  // HTTP 200 — success
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — HTTP 200 success', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test('returns CoachInsight with correct insight text on 200 response', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {
                  'insight': 'Increase sodium intake by 200mg per hour.',
                  'usage': {
                    'input_tokens': 50,
                    'output_tokens': 20,
                    'model': 'claude-haiku-4-5',
                  },
                },
                status: 200,
              ));

      final insight = await client.fetchInsight(_context());

      expect(insight.insight, 'Increase sodium intake by 200mg per hour.');
    });

    test('trims whitespace from insight text', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {
                  'insight': '  Increase sodium intake.  ',
                  'usage': null,
                },
                status: 200,
              ));

      final insight = await client.fetchInsight(_context());

      expect(insight.insight, 'Increase sodium intake.',
          reason: 'Insight text must be trimmed of leading/trailing whitespace.');
    });

    test('parses token usage when present', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {
                  'insight': 'Good job on hydration.',
                  'usage': {
                    'input_tokens': 120,
                    'output_tokens': 35,
                    'model': 'claude-haiku-4-5',
                  },
                },
                status: 200,
              ));

      final insight = await client.fetchInsight(_context());

      expect(insight.inputTokens, 120);
      expect(insight.outputTokens, 35);
      expect(insight.model, 'claude-haiku-4-5');
    });

    test('returns zero tokens when usage is null', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': 'Good fuel mix.', 'usage': null},
                status: 200,
              ));

      final insight = await client.fetchInsight(_context());

      expect(insight.inputTokens, 0);
      expect(insight.outputTokens, 0);
      expect(insight.model, isNull);
    });

    test('staleMarker on returned insight matches context staleMarker', () async {
      final context = _context();

      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': 'Some insight.', 'usage': null},
                status: 200,
              ));

      final insight = await client.fetchInsight(context);

      expect(insight.staleMarker, context.staleMarker,
          reason: 'The insight must be tagged with the context staleMarker '
              'so the panel can detect staleness correctly.');
    });

    test('empty insight string on 200 → AiCoachException(serverError)', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': '', 'usage': null},
                status: 200,
              ));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(
          isA<AiCoachException>().having(
            (e) => e.kind,
            'kind',
            AiCoachFailureKind.serverError,
          ),
        ),
        reason: 'An empty insight string on 200 must be treated as a server error.',
      );
    });

    test('whitespace-only insight string on 200 → AiCoachException(serverError)',
        () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': '   ', 'usage': null},
                status: 200,
              ));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(isA<AiCoachException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // HTTP non-200 (status code on FunctionResponse, not FunctionException)
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — HTTP error (non-200 FunctionResponse)', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test('throws AiCoachException(serverError) on HTTP 500 FunctionResponse', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'error': 'Internal server error'},
                status: 500,
              ));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(
          isA<AiCoachException>().having(
            (e) => e.kind,
            'kind',
            AiCoachFailureKind.serverError,
          ),
        ),
      );
    });

    test('throws AiCoachException(serverError) on HTTP 400 FunctionResponse', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'error': 'Bad request'},
                status: 400,
              ));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(isA<AiCoachException>()),
      );
    });

    test('error string from response body is surfaced in userMessage', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'error': 'Model overloaded'},
                status: 503,
              ));

      final exception = await _capture(() => client.fetchInsight(_context()));

      expect(exception, isA<AiCoachException>());
      final aiEx = exception as AiCoachException;
      expect(aiEx.userMessage, 'Model overloaded',
          reason: '_extractError must surface the error string from response data.');
    });
  });

  // -------------------------------------------------------------------------
  // FunctionException — HTTP 402 (REVENUE CRITICAL: insufficient credits)
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — HTTP 402 InsufficientCredits', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test(
        'REVENUE CRITICAL: FunctionException(402, error=insufficient_credits) '
        '→ throws InsufficientCreditsException (not AiCoachException)',
        () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(FunctionException(
            status: 402,
            details: {
              'error': 'insufficient_credits',
              'balance': 3,
              'cost': 10,
              'message': 'You need 7 more credits.',
            },
          ));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(isA<InsufficientCreditsException>()),
        reason: 'HTTP 402 with error=insufficient_credits must throw '
            'InsufficientCreditsException so the UI can route to the paywall.',
      );
    });

    test(
        'REVENUE CRITICAL: InsufficientCreditsException has correct balance and cost',
        () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(FunctionException(
            status: 402,
            details: {
              'error': 'insufficient_credits',
              'balance': 5,
              'cost': 20,
              'message': 'Need 15 more credits.',
            },
          ));

      final exception = await _capture(() => client.fetchInsight(_context()));

      expect(exception, isA<InsufficientCreditsException>());
      final ex = exception as InsufficientCreditsException;
      expect(ex.balance, 5);
      expect(ex.cost, 20);
      expect(ex.message, 'Need 15 more credits.');
    });

    test(
        'REVENUE CRITICAL: FunctionException(402) with malformed body '
        '→ InsufficientCreditsException with safe defaults',
        () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(FunctionException(
            status: 402,
            details: 'unexpected string body',
          ));

      final exception = await _capture(() => client.fetchInsight(_context()));

      expect(exception, isA<InsufficientCreditsException>(),
          reason: 'A malformed 402 body must still throw InsufficientCreditsException '
              'with safe defaults — not crash or swallow the error.');
      final ex = exception as InsufficientCreditsException;
      expect(ex.balance, 0, reason: 'Malformed body: balance defaults to 0.');
      expect(ex.cost, 0, reason: 'Malformed body: cost defaults to 0.');
      expect(ex.message, isNotEmpty);
    });

    test(
        'REVENUE CRITICAL: FunctionException(402) with null details '
        '→ InsufficientCreditsException with safe defaults',
        () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(FunctionException(
            status: 402,
            details: null,
          ));

      final exception = await _capture(() => client.fetchInsight(_context()));

      expect(exception, isA<InsufficientCreditsException>());
      final ex = exception as InsufficientCreditsException;
      expect(ex.balance, 0);
      expect(ex.cost, 0);
    });

    test(
        'BUG_CHECK: FunctionException(402) where error key is NOT '
        '"insufficient_credits" still throws InsufficientCreditsException '
        '(all 402s are treated as credits errors)',
        () async {
      // If the server sends a 402 with a different error key, we still treat
      // it as an InsufficientCreditsException — the code doesn't distinguish.
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(FunctionException(
            status: 402,
            details: {
              'error': 'payment_required', // Not the expected key
              'balance': 0,
              'cost': 0,
              'message': 'Payment required',
            },
          ));

      // The code path: map['error'] == 'insufficient_credits' is false,
      // so it falls through to the "malformed 402" case which still throws
      // InsufficientCreditsException.
      final exception = await _capture(() => client.fetchInsight(_context()));

      // This is correct — all 402s should surface as credits errors.
      expect(exception, isA<InsufficientCreditsException>(),
          reason: 'BUG_CHECK: Any 402 must route to InsufficientCreditsException. '
              'If a 402 slips through to AiCoachException, the paywall will '
              'never be triggered and users will see a generic error instead.');
    });
  });

  // -------------------------------------------------------------------------
  // FunctionException — non-402 HTTP errors
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — FunctionException non-402', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test('FunctionException(500) → AiCoachException(serverError)', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(const FunctionException(status: 500));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(
          isA<AiCoachException>().having(
            (e) => e.kind,
            'kind',
            AiCoachFailureKind.serverError,
          ),
        ),
      );
    });

    test('FunctionException(429) → AiCoachException(serverError) (not offline)',
        () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(const FunctionException(status: 429));

      final exception = await _capture(() => client.fetchInsight(_context()));

      expect(exception, isA<AiCoachException>());
      final ex = exception as AiCoachException;
      expect(ex.kind, AiCoachFailureKind.serverError);
    });
  });

  // -------------------------------------------------------------------------
  // Network errors
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — offline / SocketException', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test('SocketException → AiCoachException(offline)', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(const SocketException('Network unreachable'));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(
          isA<AiCoachException>().having(
            (e) => e.kind,
            'kind',
            AiCoachFailureKind.offline,
          ),
        ),
      );
    });

    test('offline error has a user-presentable message', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(const SocketException('No route to host'));

      final exception = await _capture(() => client.fetchInsight(_context()));
      final ex = exception as AiCoachException;
      expect(ex.userMessage, isNotEmpty);
      expect(
        ex.userMessage.toLowerCase(),
        anyOf(
          contains('internet'),
          contains('network'),
          contains('connection'),
        ),
        reason: 'Offline error must have a clear connectivity-related message.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Unexpected exceptions
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — unexpected exceptions', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test('StateError → AiCoachException(serverError), never rethrown raw', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(StateError('Unexpected state'));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(isA<AiCoachException>()),
        reason: 'All unexpected exceptions must be wrapped in AiCoachException, '
            'never rethrown raw to the caller.',
      );
    });

    test('FormatException → AiCoachException(serverError)', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenThrow(const FormatException('Invalid JSON'));

      await expectLater(
        client.fetchInsight(_context()),
        throwsA(isA<AiCoachException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // invoke() body includes required fields
  // -------------------------------------------------------------------------

  group('AiCoachClient.fetchInsight — invoke payload', () {
    setUp(() {
      when(() => goTrue.currentUser).thenReturn(_MockUser(_userId));
    });

    test('invoke is called with mode=insight', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': 'Good plan.', 'usage': null},
                status: 200,
              ));

      await client.fetchInsight(_context());

      final captured = verify(
        () => functions.invoke(any(), body: captureAny(named: 'body')),
      ).captured;

      final body = captured.first as Map<String, dynamic>;
      expect(body['mode'], 'insight',
          reason: 'Edge function mode must be "insight" for coach insights.');
    });

    test('invoke is called with stale_marker matching context', () async {
      final context = _context();

      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': 'Good plan.', 'usage': null},
                status: 200,
              ));

      await client.fetchInsight(context);

      final captured = verify(
        () => functions.invoke(any(), body: captureAny(named: 'body')),
      ).captured;

      final body = captured.first as Map<String, dynamic>;
      expect(body['stale_marker'], context.staleMarker);
    });

    test('invoke is called on the ai-coach function name', () async {
      when(() => functions.invoke(any(), body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'insight': 'Good plan.', 'usage': null},
                status: 200,
              ));

      await client.fetchInsight(_context());

      verify(() => functions.invoke('ai-coach', body: any(named: 'body')))
          .called(1);
    });
  });
}
