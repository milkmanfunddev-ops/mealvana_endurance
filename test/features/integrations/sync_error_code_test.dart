// Ticket 37 (testing-wave develop-2026-10, wave 2 question k): a failed sync
// stores a short wire code in `integrations.last_sync_error`, and the text
// the athlete reads comes from `integrations.sync_error_*` content keys.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/presentation/integration_sync_helpers.dart';

import '../../helpers/test_content.dart';

void main() {
  group('syncErrorCode: each failure → its wire code', () {
    final cases = <String, (Object, String)>{
      'SocketException': (
        SocketException(
          'Connection failed',
          address: InternetAddress('203.0.113.7'),
          port: 443,
        ),
        'network',
      ),
      'http.ClientException': (http.ClientException('no answer'), 'network'),
      'TimeoutException': (TimeoutException('slow'), 'network'),
      'HandshakeException': (const HandshakeException('tls'), 'network'),
      'NetworkException': (const NetworkException('offline'), 'network'),
      'RateLimitException': (
        const RateLimitException('slow down', retryAfterSeconds: 30),
        'rate_limited',
      ),
      'an API 429': (
        const IntegrationApiException('busy', statusCode: 429),
        'rate_limited',
      ),
      'ServerException 502': (
        const ServerException('bad gateway', statusCode: 502),
        'http_502',
      ),
      'ForbiddenException': (const ForbiddenException('nope'), 'http_403'),
      'TokenExpiredException': (
        const TokenExpiredException('expired'),
        'http_401',
      ),
      'TrainingPeaksApiException 500': (
        TrainingPeaksApiException('boom', statusCode: 500),
        'http_500',
      ),
      'TokenRefreshException requiring a reauth': (
        const TokenRefreshException('refused', requiresReauth: true),
        'reauth_required',
      ),
      'an API exception wrapping a transport failure': (
        const IntegrationApiException(
          'SocketException: Connection refused (address = 10.0.0.1)',
        ),
        'network',
      ),
      'an API exception with no status': (
        const IntegrationApiException('odd answer'),
        'unknown',
      ),
      'a StateError': (StateError('bad state'), 'unknown'),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(syncErrorCode(entry.value.$1), entry.value.$2);
      });
    }

    test('never stores an address, port or exception name', () {
      final code = syncErrorCode(
        SocketException(
          'Connection failed',
          osError: const OSError('Network is unreachable', 51),
          address: InternetAddress('203.0.113.7'),
          port: 443,
        ),
      );
      expect(code, isNot(contains('203.0.113.7')));
      expect(code, isNot(contains('Socket')));
    });
  });

  group('SyncError.parse', () {
    test('reads every wire code back', () {
      expect(
        SyncError.parse('network'),
        const SyncError(SyncErrorCode.network),
      );
      expect(
        SyncError.parse('rate_limited'),
        const SyncError(SyncErrorCode.rateLimited),
      );
      expect(
        SyncError.parse('reauth_required'),
        const SyncError(SyncErrorCode.reauthRequired),
      );
      expect(
        SyncError.parse('unknown'),
        const SyncError(SyncErrorCode.unknown),
      );
      expect(
        SyncError.parse('http_503'),
        const SyncError(SyncErrorCode.httpStatus, status: 503),
      );
      expect(SyncError.parse('http_503').wire, 'http_503');
    });

    test('a legacy English row parses to unknown', () {
      for (final legacy in [
        'Token refresh refused. Please reconnect.',
        'Please reconnect your Final Surge account',
        'Garmin needs you to sign in again. Please reconnect.',
        'Could not reach TrainingPeaks. Check your connection and try again.',
        'TrainingPeaks sync failed (status 500).',
        'http_',
        '',
      ]) {
        expect(SyncError.tryParse(legacy), isNull, reason: legacy);
        expect(SyncError.parse(legacy).code, SyncErrorCode.unknown);
      }
      expect(SyncError.parse(null).code, SyncErrorCode.unknown);
    });

    test('syncFailureCode: a result flag wins over its text', () {
      expect(
        syncFailureCode(error: 'Please reconnect', needsReauth: true),
        'reauth_required',
      );
      expect(
        syncFailureCode(error: 'No internet', isNetworkError: true),
        'network',
      );
      expect(syncFailureCode(error: 'http_404'), 'http_404');
      expect(syncFailureCode(error: 'Missing user ID'), 'unknown');
    });
  });

  group('syncErrorText: code → content text', () {
    late ContentService content;
    final defaults = loadDefaultContent();

    setUp(() {
      final container = ProviderContainer(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
      );
      addTearDown(container.dispose);
      content = container.read(contentServiceProvider);
    });

    test('every code has its own key, filled with the provider', () {
      final byCode = {
        'network': 'integrations.sync_error_network',
        'rate_limited': 'integrations.sync_error_rate_limited',
        'reauth_required': 'integrations.sync_error_reauth',
        'unknown': 'integrations.sync_error_unknown',
      };
      for (final entry in byCode.entries) {
        final template = defaults[entry.value];
        expect(template, isNotNull, reason: entry.value);
        expect(
          syncErrorText(content, entry.key, 'TrainingPeaks'),
          template!.replaceAll('{provider}', 'TrainingPeaks'),
        );
      }
    });

    test('{provider} and {status} are substituted', () {
      expect(
        syncErrorText(content, 'reauth_required', 'Garmin'),
        'Garmin needs you to sign in again. Please reconnect.',
      );
      expect(
        syncErrorText(content, 'http_502', 'Final Surge'),
        'Final Surge sync failed (status 502).',
      );
      expect(
        syncErrorText(content, 'network', 'V.O2'),
        'Could not reach V.O2. Check your connection and try again.',
      );
    });

    test('a legacy English row shows the unknown text, never itself', () {
      final text = syncErrorText(
        content,
        'Token refresh refused. Please reconnect.',
        'TrainingPeaks',
      );
      expect(
        text,
        defaults['integrations.sync_error_unknown']!.replaceAll(
          '{provider}',
          'TrainingPeaks',
        ),
      );
    });

    test('syncFailureText shows a non-code message as is', () {
      const note =
          "Workouts saved, but syncing to your account didn't finish. "
          "We'll retry automatically.";
      expect(
        syncFailureText(content, providerName: 'Runna', stateMessage: note),
        note,
      );
      expect(
        syncFailureText(
          content,
          providerName: 'Runna',
          resultCode: 'rate_limited',
        ),
        'Runna is busy. Try again later.',
      );
    });
  });
}
