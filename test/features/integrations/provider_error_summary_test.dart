// Ticket 84: the device's one redaction rule for provider error answers,
// mirroring ticket 76's server helper. Status and error code only.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/domain/provider_error_summary.dart';

void main() {
  group('providerErrorSummary', () {
    test('an OAuth error body gives its code, never the description', () {
      final s = providerErrorSummary(
        400,
        '{"error":"invalid_grant","error_description":"Invalid refresh '
        'token: eyJyZWZyZXNoVG9rZW5WYWx1ZSI6InJ0LWxpdmUtNWYyYyJ9"}',
      );
      expect(s.status, 400);
      expect(s.errorCode, 'invalid_grant');
    });

    test("V.O2's NOK shape gives its error code", () {
      expect(
        providerErrorSummary(
          400,
          '{"status":"NOK","error":"invalid_code"}',
        ).errorCode,
        'invalid_code',
      );
    });

    test('errorCode and code are read when error is absent', () {
      expect(
        providerErrorSummary(400, '{"errorCode":"E_1.2"}').errorCode,
        'E_1.2',
      );
      expect(
        providerErrorSummary(400, '{"code":"PGRST116"}').errorCode,
        'PGRST116',
      );
    });

    test('a free-text-only body gives no code', () {
      expect(
        providerErrorSummary(
          400,
          '{"errorMessage":"Token is not active"}',
        ).errorCode,
        isNull,
      );
      expect(
        providerErrorSummary(400, '{"message":"rt-live-5f2c"}').errorCode,
        isNull,
      );
    });

    test('an HTML page gives no code', () {
      expect(
        providerErrorSummary(
          502,
          '<html><body>Bad gateway</body></html>',
        ).errorCode,
        isNull,
      );
    });

    test('an error with a space gives no code', () {
      expect(
        providerErrorSummary(400, '{"error":"has a space"}').errorCode,
        isNull,
      );
    });

    test('an error longer than 64 characters gives no code', () {
      expect(
        providerErrorSummary(400, '{"error":"${'a' * 200}"}').errorCode,
        isNull,
      );
    });

    test('a non-string error gives no code; a JSON array gives no code', () {
      expect(providerErrorSummary(400, '{"error":42}').errorCode, isNull);
      expect(providerErrorSummary(400, '["invalid_grant"]').errorCode, isNull);
    });

    test('a null or empty body gives no code', () {
      expect(providerErrorSummary(400, null).errorCode, isNull);
      expect(providerErrorSummary(400, '').errorCode, isNull);
      expect(providerErrorSummary(null, null).status, isNull);
    });
  });

  group('providerErrorSuffix', () {
    test('writes status and code, or what is known', () {
      expect(
        providerErrorSuffix((status: 400, errorCode: 'invalid_grant')),
        ' (status: 400, error: invalid_grant)',
      );
      expect(
        providerErrorSuffix((status: 500, errorCode: null)),
        ' (status: 500)',
      );
      expect(providerErrorSuffix((status: null, errorCode: null)), '');
    });
  });
}
