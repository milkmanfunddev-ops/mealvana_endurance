// Tests for RunnaIcsClient transport concerns.
//
// The regression that motivates this file: `http.Response.body` decodes using
// the charset in the Content-Type header and falls back to **latin-1** when no
// charset is given. RFC 5545 mandates UTF-8 for iCalendar, and Runna summaries
// lead with an emoji and separate segments with '•'. Decoded as latin-1 those
// become mojibake, the transformer can no longer split SUMMARY on '•', and
// distance / duration / pace are silently dropped from every imported workout.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mealvana_endurance/features/integrations/data/runna_ics_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';

/// Minimal feed carrying the two characters that break under latin-1: the
/// leading emoji and the '•' segment separator.
const _icsWithUtf8 = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Runna//Training Plan//EN
BEGIN:VEVENT
UID:runna-utf8-001@runna.com
DTSTART;VALUE=DATE:20260804
SUMMARY:🏃 Easy Run • 6mi • 50m
END:VEVENT
END:VCALENDAR
''';

http.Client _clientReturning(
  String body, {
  String? contentType,
  int statusCode = 200,
}) {
  return MockClient((request) async {
    return http.Response.bytes(
      utf8.encode(body),
      statusCode,
      headers: contentType == null ? const {} : {'content-type': contentType},
    );
  });
}

void main() {
  group('normalizeFeedUrl', () {
    test('rewrites webcal:// to https://', () {
      expect(
        RunnaIcsClient.normalizeFeedUrl('webcal://runna.com/cal/abc.ics'),
        'https://runna.com/cal/abc.ics',
      );
    });

    test('is case-insensitive on the scheme and trims whitespace', () {
      expect(
        RunnaIcsClient.normalizeFeedUrl('  WEBCAL://runna.com/cal/abc.ics  '),
        'https://runna.com/cal/abc.ics',
      );
    });

    test('leaves https:// untouched', () {
      expect(
        RunnaIcsClient.normalizeFeedUrl('https://runna.com/cal/abc.ics'),
        'https://runna.com/cal/abc.ics',
      );
    });
  });

  group('fetchIcs UTF-8 decoding', () {
    test(
      'decodes as UTF-8 when the response omits a charset parameter',
      () async {
        // The regression case: no charset → package:http would use latin-1.
        final client = RunnaIcsClient(
          httpClient: _clientReturning(
            _icsWithUtf8,
            contentType: 'text/calendar',
          ),
        );

        final body = await client.fetchIcs('https://runna.com/cal/abc.ics');

        expect(body, contains('🏃'));
        expect(body, contains('•'));
        expect(body, contains('SUMMARY:🏃 Easy Run • 6mi • 50m'));
        // The latin-1 mojibake signatures must be absent.
        expect(body, isNot(contains('â¢')));
        expect(body, isNot(contains('ð')));
      },
    );

    test('decodes as UTF-8 when no Content-Type header is present', () async {
      final client = RunnaIcsClient(httpClient: _clientReturning(_icsWithUtf8));

      final body = await client.fetchIcs('https://runna.com/cal/abc.ics');

      expect(body, contains('🏃'));
      expect(body, contains('•'));
    });

    test('still decodes correctly when charset=utf-8 IS declared', () async {
      final client = RunnaIcsClient(
        httpClient: _clientReturning(
          _icsWithUtf8,
          contentType: 'text/calendar; charset=utf-8',
        ),
      );

      final body = await client.fetchIcs('https://runna.com/cal/abc.ics');

      expect(body, contains('🏃'));
      expect(body, contains('•'));
    });
  });

  group('fetchIcs error handling', () {
    test('rejects a URL that is not http/https', () async {
      final client = RunnaIcsClient(httpClient: _clientReturning(_icsWithUtf8));

      expect(
        () => client.fetchIcs('ftp://runna.com/cal/abc.ics'),
        throwsA(isA<IntegrationApiException>()),
      );
    });

    test('rejects a non-200 response', () async {
      final client = RunnaIcsClient(
        httpClient: _clientReturning(_icsWithUtf8, statusCode: 404),
      );

      expect(
        () => client.fetchIcs('https://runna.com/cal/abc.ics'),
        throwsA(isA<IntegrationApiException>()),
      );
    });

    test('rejects a 200 body that is not an iCalendar feed', () async {
      final client = RunnaIcsClient(
        httpClient: _clientReturning('<html>login page</html>'),
      );

      expect(
        () => client.fetchIcs('https://runna.com/cal/abc.ics'),
        throwsA(isA<IntegrationApiException>()),
      );
    });
  });
}
