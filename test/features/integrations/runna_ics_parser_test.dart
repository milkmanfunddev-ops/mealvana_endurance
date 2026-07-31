// Tests for the Runna ICS feed parser (pure RFC 5545 subset).
//
// Coverage goals:
// 1. Line unfolding (CRLF + space/tab continuations, bare LF tolerated)
// 2. All three DTSTART forms (UTC Z, TZID local, VALUE=DATE all-day — the
//    all-day form is Runna's COMMON case)
// 3. DURATION (ISO 8601) and X-WORKOUT-ESTIMATED-DURATION (seconds) parsing
// 4. RFC text unescaping (\n, \, \; \\)
// 5. STATUS:CANCELLED skip, RRULE skip (counted, not thrown)
// 6. Malformed-event resilience (counted, not thrown)
// 7. A realistic multi-event fixture

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/integrations/application/runna_ics_parser.dart';

const _parser = RunnaIcsParser();

/// Wrap a VEVENT body in a minimal VCALENDAR. Uses CRLF line endings by
/// default (the RFC norm).
String _calendar(String veventBody, {String lineEnding = '\r\n'}) {
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Runna//Training Plan//EN',
    'BEGIN:VEVENT',
    ...veventBody.split('\n'),
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return lines.join(lineEnding);
}

/// A realistic multi-event Runna feed: two all-day runs (the common case),
/// one timed run, one strength session, one cancelled, one recurring.
const _realisticFeed =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'PRODID:-//Runna//Training Plan//EN\r\n'
    'X-WR-CALNAME:Runna Training Plan\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:runna-evt-001@runna.com\r\n'
    'DTSTART;VALUE=DATE:20260724\r\n'
    'SUMMARY:🏃 Easy Run • 6mi • 50m - 55m\r\n'
    'X-WORKOUT-ESTIMATED-DURATION:3120\r\n'
    'DESCRIPTION:Warm up: 10 mins easy\\nMain: 4mi at 8:30/mi\\nCool down: 5 \r\n'
    ' mins easy\r\n'
    'URL:https://runna.com/workout/001\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:runna-evt-002@runna.com\r\n'
    'DTSTART;VALUE=DATE:20260726\r\n'
    'SUMMARY:🔥 Pyramid Intervals • 45m\r\n'
    'DESCRIPTION:3 reps of:\\n0.5mi at 7:00/mi\\n2 mins rest\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:runna-evt-003@runna.com\r\n'
    'DTSTART:20260728T060000Z\r\n'
    'DTEND:20260728T070000Z\r\n'
    'SUMMARY:🏃 Long Run • 10mi\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:runna-evt-004@runna.com\r\n'
    'DTSTART;VALUE=DATE:20260729\r\n'
    'SUMMARY:💪 Strength & Conditioning • 30m\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:runna-evt-005@runna.com\r\n'
    'DTSTART;VALUE=DATE:20260730\r\n'
    'SUMMARY:🏃 Tempo Run • 45m\r\n'
    'STATUS:CANCELLED\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:runna-evt-006@runna.com\r\n'
    'DTSTART;VALUE=DATE:20260731\r\n'
    'SUMMARY:🏃 Weekly Club Run\r\n'
    'RRULE:FREQ=WEEKLY;BYDAY=FR\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR\r\n';

void main() {
  group('line unfolding', () {
    test('unfolds CRLF + space continuations', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:🏃 Easy Run • 6mi\n'
          'DESCRIPTION:First part of the descrip\n'
          ' tion continues here',
        ),
      );

      expect(result.events, hasLength(1));
      expect(
        result.events.first.description,
        'First part of the description continues here',
      );
    });

    test('unfolds tab continuations and tolerates bare LF endings', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:Split summ\n'
          '\tary',
          lineEnding: '\n',
        ),
      );

      expect(result.events, hasLength(1));
      expect(result.events.first.summary, 'Split summary');
    });
  });

  group('DTSTART forms', () {
    test('VALUE=DATE all-day (the common case) anchors at 06:00 local', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:Easy Run',
        ),
      );

      final event = result.events.single;
      expect(event.isAllDay, isTrue);
      expect(event.start, DateTime(2026, 7, 22, 6, 0));
      expect(event.start.isUtc, isFalse);
    });

    test('bare 8-digit DTSTART is treated as all-day too', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:20260722\n'
          'SUMMARY:Easy Run',
        ),
      );

      final event = result.events.single;
      expect(event.isAllDay, isTrue);
      expect(event.start, DateTime(2026, 7, 22, 6, 0));
    });

    test('UTC Z form converts via toLocal', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:20260722T060000Z\n'
          'SUMMARY:Easy Run',
        ),
      );

      final event = result.events.single;
      expect(event.isAllDay, isFalse);
      expect(event.start.isUtc, isFalse);
      expect(event.start, DateTime.utc(2026, 7, 22, 6).toLocal());
    });

    test(
      'TZID form is treated as device-local wall clock (no tz database)',
      () {
        final result = _parser.parse(
          _calendar(
            'UID:evt-1\n'
            'DTSTART;TZID=Europe/London:20260722T060000\n'
            'SUMMARY:Easy Run',
          ),
        );

        final event = result.events.single;
        expect(event.isAllDay, isFalse);
        // Wall-clock fidelity: a 6am run stays a 6am run on this device.
        expect(event.start, DateTime(2026, 7, 22, 6, 0));
      },
    );

    test('floating (no TZID, no Z) is treated as device-local wall clock', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:20260722T183000\n'
          'SUMMARY:Evening Run',
        ),
      );

      expect(result.events.single.start, DateTime(2026, 7, 22, 18, 30));
    });
  });

  group('duration sources', () {
    test('parses X-WORKOUT-ESTIMATED-DURATION as seconds', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:Easy Run\n'
          'X-WORKOUT-ESTIMATED-DURATION:3120',
        ),
      );

      expect(result.events.single.estimatedDurationSeconds, 3120);
    });

    test('tolerates fractional X-WORKOUT-ESTIMATED-DURATION', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:Easy Run\n'
          'X-WORKOUT-ESTIMATED-DURATION:3021.5',
        ),
      );

      expect(result.events.single.estimatedDurationSeconds, 3022);
    });

    test('parses ISO 8601 DURATION forms', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:20260722T060000Z\n'
          'DURATION:PT45M\n'
          'SUMMARY:Easy Run',
        ),
      );

      expect(result.events.single.duration, const Duration(minutes: 45));
    });

    test('parses compound DURATION PT1H30M', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:20260722T060000Z\n'
          'DURATION:PT1H30M\n'
          'SUMMARY:Long Run',
        ),
      );

      expect(
        result.events.single.duration,
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('keeps DTEND only for timed events', () {
      final timed = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:20260722T060000Z\n'
          'DTEND:20260722T070000Z\n'
          'SUMMARY:Timed Run',
        ),
      );
      expect(timed.events.single.end, DateTime.utc(2026, 7, 22, 7).toLocal());

      // All-day DTEND is exclusive-next-day noise, not a duration signal.
      final allDay = _parser.parse(
        _calendar(
          'UID:evt-2\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'DTEND;VALUE=DATE:20260723\n'
          'SUMMARY:All Day Run',
        ),
      );
      expect(allDay.events.single.end, isNull);
    });
  });

  group('text unescaping', () {
    test('unescapes \\n, \\, \\; and \\\\ per RFC 5545', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:Easy Run\n'
          r'DESCRIPTION:Line one\nLine two\, with comma\; and semi\\backslash',
        ),
      );

      expect(
        result.events.single.description,
        'Line one\nLine two, with comma; and semi\\backslash',
      );
    });
  });

  group('skips', () {
    test('skips STATUS:CANCELLED events with a count', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:Cancelled Run\n'
          'STATUS:CANCELLED',
        ),
      );

      expect(result.events, isEmpty);
      expect(result.skippedCancelled, 1);
    });

    test(
      'skips RRULE events (no recurrence expansion in MVP) with a count',
      () {
        final result = _parser.parse(
          _calendar(
            'UID:evt-1\n'
            'DTSTART;VALUE=DATE:20260722\n'
            'SUMMARY:Weekly Run\n'
            'RRULE:FREQ=WEEKLY;BYDAY=MO',
          ),
        );

        expect(result.events, isEmpty);
        expect(result.skippedRecurring, 1);
      },
    );
  });

  group('malformed resilience', () {
    test('missing UID is skipped and counted, not thrown', () {
      final result = _parser.parse(
        _calendar(
          'DTSTART;VALUE=DATE:20260722\n'
          'SUMMARY:No UID Run',
        ),
      );

      expect(result.events, isEmpty);
      expect(result.skippedMalformed, 1);
    });

    test('missing DTSTART is skipped and counted', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'SUMMARY:No Date Run',
        ),
      );

      expect(result.events, isEmpty);
      expect(result.skippedMalformed, 1);
    });

    test('unparseable DTSTART is skipped and counted', () {
      final result = _parser.parse(
        _calendar(
          'UID:evt-1\n'
          'DTSTART:not-a-date\n'
          'SUMMARY:Bad Date Run',
        ),
      );

      expect(result.events, isEmpty);
      expect(result.skippedMalformed, 1);
    });

    test('a malformed event does not poison its neighbors', () {
      final ics =
          'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:good-1\r\n'
          'DTSTART;VALUE=DATE:20260722\r\n'
          'SUMMARY:Good Run\r\n'
          'END:VEVENT\r\n'
          'BEGIN:VEVENT\r\n'
          'DTSTART:garbage\r\n'
          'SUMMARY:Broken Run\r\n'
          'END:VEVENT\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:good-2\r\n'
          'DTSTART;VALUE=DATE:20260723\r\n'
          'SUMMARY:Another Good Run\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final result = _parser.parse(ics);
      expect(result.events.map((e) => e.uid), ['good-1', 'good-2']);
      expect(result.skippedMalformed, 1);
    });

    test('non-ICS garbage yields zero events without throwing', () {
      final result = _parser.parse('<html>This is not a calendar</html>');
      expect(result.events, isEmpty);
      expect(result.skippedTotal, 0);
    });
  });

  group('realistic multi-event fixture', () {
    test('parses the runnable events and counts every skip category', () {
      final result = _parser.parse(_realisticFeed);

      expect(result.events, hasLength(4));
      expect(result.skippedCancelled, 1);
      expect(result.skippedRecurring, 1);
      expect(result.skippedMalformed, 0);

      final easy = result.events[0];
      expect(easy.uid, 'runna-evt-001@runna.com');
      expect(easy.isAllDay, isTrue);
      expect(easy.start, DateTime(2026, 7, 24, 6));
      expect(easy.summary, '🏃 Easy Run • 6mi • 50m - 55m');
      expect(easy.estimatedDurationSeconds, 3120);
      expect(easy.url, 'https://runna.com/workout/001');
      // Folded + escaped description restored.
      expect(
        easy.description,
        'Warm up: 10 mins easy\nMain: 4mi at 8:30/mi\nCool down: 5 mins easy',
      );

      final intervals = result.events[1];
      expect(intervals.uid, 'runna-evt-002@runna.com');
      expect(
        intervals.description,
        '3 reps of:\n0.5mi at 7:00/mi\n2 mins rest',
      );

      final longRun = result.events[2];
      expect(longRun.isAllDay, isFalse);
      expect(longRun.start, DateTime.utc(2026, 7, 28, 6).toLocal());
      expect(longRun.end, DateTime.utc(2026, 7, 28, 7).toLocal());

      // Strength stays in the parser output — filtering it is the
      // transformer's job.
      expect(result.events[3].summary, '💪 Strength & Conditioning • 30m');
    });
  });
}
