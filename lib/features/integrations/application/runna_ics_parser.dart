/// Runna iCalendar (.ics) feed parser.
///
/// A pure, dependency-free RFC 5545 SUBSET parser — deliberately not a general
/// iCalendar implementation. It handles exactly what Runna's calendar-sync
/// feed emits (verified against the feed format used by third-party tooling):
/// - One VEVENT per planned workout.
/// - SUMMARY like "🏃 Easy Run • 6mi • 50m - 55m" (leading emoji +
///   bullet-separated segments).
/// - DTSTART as all-day `VALUE=DATE` (the COMMON case — Runna only emits a
///   timed DTSTART when the user schedules a time in the Runna app), UTC
///   (`...Z`), or TZID/floating local time.
/// - `X-WORKOUT-ESTIMATED-DURATION`: Runna's custom property carrying the
///   estimated moving time in SECONDS.
/// - DESCRIPTION with RFC-escaped step-by-step workout text.
///
/// Timezone policy (documented tradeoff): we do NOT bundle a timezone
/// database. `TZID=...` local times and floating times are treated as the
/// device's local wall-clock. Planned workouts are day-anchored, so wall-clock
/// fidelity ("6am run") matters more than absolute-instant fidelity; a user
/// who authored a 6am run in Europe/London still sees a 6am run when their
/// device is in America/Chicago. UTC (`Z`) times are converted via
/// `.toLocal()`. All-day `VALUE=DATE` events are anchored at 06:00 local —
/// the same "avoid midnight workouts" convention the Final Surge transformer
/// uses for date-only schedules.
///
/// Malformed events are skipped and counted, never thrown.
library;

/// A single parsed VEVENT from a Runna feed.
class RunnaIcsEvent {
  const RunnaIcsEvent({
    required this.uid,
    required this.start,
    this.isAllDay = false,
    this.summary,
    this.description,
    this.url,
    this.location,
    this.end,
    this.duration,
    this.estimatedDurationSeconds,
    this.lastModified,
  });

  /// Stable per-event identifier — the dedup key for provider sync.
  final String uid;

  /// Scheduled start in device-local time (see the library docs for the
  /// timezone policy). All-day events are anchored at 06:00 local.
  final DateTime start;

  /// True when DTSTART was a `VALUE=DATE` all-day form.
  final bool isAllDay;

  /// Workout name line, RFC-unescaped (e.g. "🏃 Easy Run • 6mi • 50m - 55m").
  final String? summary;

  /// Step-by-step workout text, RFC-unescaped (literal newlines restored).
  final String? description;

  /// Deep link / web link, if the feed provides one.
  final String? url;

  final String? location;

  /// DTEND, only populated for timed (non-all-day) events. For all-day
  /// events DTEND is exclusive-next-day noise, so it is dropped.
  final DateTime? end;

  /// Parsed `DURATION` property (ISO 8601, e.g. PT45M), if present.
  final Duration? duration;

  /// Runna's `X-WORKOUT-ESTIMATED-DURATION` — estimated moving time in
  /// seconds. Preferred duration source when present.
  final int? estimatedDurationSeconds;

  final DateTime? lastModified;
}

/// Result of parsing a feed: the usable events plus skip counts for
/// observability (surfaced through the sync result's `filtered` count).
class RunnaIcsParseResult {
  const RunnaIcsParseResult({
    required this.events,
    this.skippedMalformed = 0,
    this.skippedCancelled = 0,
    this.skippedRecurring = 0,
  });

  final List<RunnaIcsEvent> events;

  /// Events missing UID/DTSTART or with an unparseable DTSTART.
  final int skippedMalformed;

  /// Events with STATUS:CANCELLED.
  final int skippedCancelled;

  /// Events carrying an RRULE — MVP does not expand recurrences.
  final int skippedRecurring;

  int get skippedTotal =>
      skippedMalformed + skippedCancelled + skippedRecurring;
}

/// Parses Runna's ICS feed text into typed events. Pure and synchronous.
class RunnaIcsParser {
  const RunnaIcsParser();

  RunnaIcsParseResult parse(String icsText) {
    final lines = _unfoldLines(icsText);

    final events = <RunnaIcsEvent>[];
    var skippedMalformed = 0;
    var skippedCancelled = 0;
    var skippedRecurring = 0;

    Map<String, _RawProperty>? currentProps;

    for (final line in lines) {
      final upper = line.trim().toUpperCase();
      if (upper == 'BEGIN:VEVENT') {
        currentProps = <String, _RawProperty>{};
        continue;
      }
      if (upper == 'END:VEVENT') {
        if (currentProps != null) {
          switch (_buildEvent(currentProps, events)) {
            case _EventOutcome.ok:
              break;
            case _EventOutcome.malformed:
              skippedMalformed++;
            case _EventOutcome.cancelled:
              skippedCancelled++;
            case _EventOutcome.recurring:
              skippedRecurring++;
          }
        }
        currentProps = null;
        continue;
      }
      if (currentProps == null) continue; // outside a VEVENT block

      final prop = _parsePropertyLine(line);
      if (prop != null) {
        // Last occurrence wins — Runna doesn't repeat the properties we care
        // about, and this keeps a stray duplicate from corrupting the event.
        currentProps[prop.name] = prop;
      }
    }

    return RunnaIcsParseResult(
      events: events,
      skippedMalformed: skippedMalformed,
      skippedCancelled: skippedCancelled,
      skippedRecurring: skippedRecurring,
    );
  }

  // ---------------------------------------------------------------------------
  // Line handling
  // ---------------------------------------------------------------------------

  /// Split into logical lines, unfolding RFC 5545 folded lines (a CRLF
  /// followed by a single space or tab continues the previous line). Bare LF
  /// line endings are tolerated.
  List<String> _unfoldLines(String icsText) {
    final rawLines = icsText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final unfolded = <String>[];
    for (final raw in rawLines) {
      if (raw.isEmpty) continue;
      if ((raw.startsWith(' ') || raw.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] = unfolded.last + raw.substring(1);
      } else {
        unfolded.add(raw);
      }
    }
    return unfolded;
  }

  /// Parse `NAME;PARAM=VAL;PARAM2="q:uoted":value`. Returns null for lines
  /// that aren't property-shaped (tolerated, not fatal).
  _RawProperty? _parsePropertyLine(String line) {
    // Find the first ':' outside double quotes (params may quote colons).
    var inQuotes = false;
    var colonIndex = -1;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ':' && !inQuotes) {
        colonIndex = i;
        break;
      }
    }
    if (colonIndex <= 0) return null;

    final head = line.substring(0, colonIndex);
    final value = line.substring(colonIndex + 1);

    final headParts = head.split(';');
    final name = headParts.first.trim().toUpperCase();
    if (name.isEmpty) return null;

    final params = <String, String>{};
    for (final part in headParts.skip(1)) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final key = part.substring(0, eq).trim().toUpperCase();
      var val = part.substring(eq + 1).trim();
      if (val.length >= 2 && val.startsWith('"') && val.endsWith('"')) {
        val = val.substring(1, val.length - 1);
      }
      params[key] = val;
    }

    return _RawProperty(name: name, params: params, value: value);
  }

  // ---------------------------------------------------------------------------
  // Event assembly
  // ---------------------------------------------------------------------------

  _EventOutcome _buildEvent(
    Map<String, _RawProperty> props,
    List<RunnaIcsEvent> out,
  ) {
    // RRULE → skip: MVP does not expand recurrences.
    if (props.containsKey('RRULE')) return _EventOutcome.recurring;

    // STATUS:CANCELLED → skip. Removal of the workout is handled by the
    // rolling-window absence rule in the sync service.
    final status = props['STATUS']?.value.trim().toUpperCase();
    if (status == 'CANCELLED') return _EventOutcome.cancelled;

    final uid = props['UID']?.value.trim();
    if (uid == null || uid.isEmpty) return _EventOutcome.malformed;

    final dtStartProp = props['DTSTART'];
    if (dtStartProp == null) return _EventOutcome.malformed;
    final start = _parseDateTime(dtStartProp);
    if (start == null) return _EventOutcome.malformed;

    _ParsedDateTime? end;
    final dtEndProp = props['DTEND'];
    if (dtEndProp != null) {
      end = _parseDateTime(dtEndProp);
    }

    final lastModified = props['LAST-MODIFIED'] != null
        ? _parseDateTime(props['LAST-MODIFIED']!)?.value
        : null;

    out.add(
      RunnaIcsEvent(
        uid: uid,
        start: start.value,
        isAllDay: start.isAllDay,
        summary: _nullIfEmpty(_unescapeText(props['SUMMARY']?.value)),
        description: _nullIfEmpty(_unescapeText(props['DESCRIPTION']?.value)),
        url: _nullIfEmpty(props['URL']?.value.trim()),
        location: _nullIfEmpty(_unescapeText(props['LOCATION']?.value)),
        // For all-day events DTEND is exclusive-next-day, not a duration
        // signal — only keep a timed end.
        end: (end != null && !end.isAllDay && !start.isAllDay)
            ? end.value
            : null,
        duration: _parseIsoDuration(props['DURATION']?.value),
        estimatedDurationSeconds: _parseEstimatedDurationSeconds(
          props['X-WORKOUT-ESTIMATED-DURATION']?.value,
        ),
        lastModified: lastModified,
      ),
    );
    return _EventOutcome.ok;
  }

  // ---------------------------------------------------------------------------
  // Value parsing
  // ---------------------------------------------------------------------------

  /// Parse the three DTSTART/DTEND forms:
  /// - `VALUE=DATE:20260722` (all-day) → that date at 06:00 local
  /// - `20260722T060000Z` (UTC) → converted with `.toLocal()`
  /// - `TZID=Europe/London:20260722T060000` / floating → device-local
  ///   wall-clock (no tz database; see library docs for the tradeoff)
  _ParsedDateTime? _parseDateTime(_RawProperty prop) {
    final value = prop.value.trim();
    final isDateOnly =
        prop.params['VALUE'] == 'DATE' || RegExp(r'^\d{8}$').hasMatch(value);

    if (isDateOnly) {
      final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
      if (match == null) return null;
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      // All-day anchor: 06:00 local (documented above).
      return _ParsedDateTime(DateTime(year, month, day, 6), isAllDay: true);
    }

    // DateTime.parse handles both ISO 8601 basic ("20260722T060000[Z]") and
    // extended forms; a trailing Z yields a UTC instant.
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;

    if (parsed.isUtc) {
      return _ParsedDateTime(parsed.toLocal(), isAllDay: false);
    }
    // TZID/floating: already a local wall-clock DateTime — keep as-is.
    return _ParsedDateTime(parsed, isAllDay: false);
  }

  /// Parse an ISO 8601 duration (`PT45M`, `PT1H30M`, `P1DT2H`, ...).
  Duration? _parseIsoDuration(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'^(-)?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;

    int part(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
    final weeks = part(2);
    final days = part(3);
    final hours = part(4);
    final minutes = part(5);
    final seconds = part(6);

    final total = Duration(
      days: weeks * 7 + days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
    if (total == Duration.zero) return null;
    return match.group(1) == '-' ? -total : total;
  }

  /// `X-WORKOUT-ESTIMATED-DURATION` is moving time in seconds; tolerate a
  /// fractional value.
  int? _parseEstimatedDurationSeconds(String? raw) {
    if (raw == null) return null;
    final value = double.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value.round();
  }

  /// Unescape RFC 5545 TEXT values: `\n`/`\N` → newline, `\,` → `,`,
  /// `\;` → `;`, `\\` → `\`.
  String? _unescapeText(String? raw) {
    if (raw == null) return null;
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == r'\' && i + 1 < raw.length) {
        final next = raw[i + 1];
        i++;
        switch (next) {
          case 'n':
          case 'N':
            buffer.write('\n');
          case ',':
            buffer.write(',');
          case ';':
            buffer.write(';');
          case r'\':
            buffer.write(r'\');
          default:
            // Unknown escape — keep the character, drop the backslash.
            buffer.write(next);
        }
      } else {
        buffer.write(c);
      }
    }
    return buffer.toString();
  }

  String? _nullIfEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;
}

class _RawProperty {
  const _RawProperty({
    required this.name,
    required this.params,
    required this.value,
  });

  final String name;
  final Map<String, String> params;
  final String value;
}

class _ParsedDateTime {
  const _ParsedDateTime(this.value, {required this.isAllDay});

  final DateTime value;
  final bool isAllDay;
}

enum _EventOutcome { ok, malformed, cancelled, recurring }
