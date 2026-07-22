import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/integration_exceptions.dart';

/// Fetches Runna's calendar-subscription (.ics) feed over HTTP.
///
/// Runna's calendar sync exposes a per-user URL (webcal:// or https://)
/// containing an embedded token — there is no auth beyond the URL itself,
/// which is why the sync layer stores the URL in the integration row's
/// accessToken field (see RunnaSyncService).
class RunnaIcsClient {
  RunnaIcsClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  static const _provider = 'runna';

  /// Normalize a user-pasted feed URL: trim whitespace and rewrite
  /// `webcal://` (the scheme calendar apps register) to `https://`.
  static String normalizeFeedUrl(String raw) {
    final url = raw.trim();
    final lower = url.toLowerCase();
    if (lower.startsWith('webcal://')) {
      return 'https://${url.substring('webcal://'.length)}';
    }
    return url;
  }

  /// Fetch the raw ICS text for [feedUrl].
  ///
  /// Throws:
  /// - [IntegrationApiException] for an invalid URL, a non-200 response, or a
  ///   body that isn't an iCalendar feed.
  /// - [NetworkException] for timeouts and connection failures (retryable).
  Future<String> fetchIcs(String feedUrl) async {
    final normalized = normalizeFeedUrl(feedUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw const IntegrationApiException(
        'That doesn\'t look like a valid calendar link',
        provider: _provider,
      );
    }

    http.Response response;
    try {
      response = await _http
          .get(uri, headers: const {'Accept': 'text/calendar, text/plain, */*'})
          .timeout(timeout);
    } on TimeoutException {
      throw const NetworkException(
        'The Runna calendar request timed out. Please try again.',
        provider: _provider,
      );
    } on http.ClientException catch (e) {
      // package:http wraps socket/connection failures in ClientException on
      // both IO and web platforms.
      throw NetworkException(
        'Could not reach the Runna calendar: ${e.message}',
        provider: _provider,
      );
    }

    if (response.statusCode != 200) {
      throw IntegrationApiException(
        'The Runna calendar link returned an error (${response.statusCode}). '
        'Copy a fresh link from the Runna app and try again.',
        statusCode: response.statusCode,
        provider: _provider,
      );
    }

    final body = response.body;
    if (!body.toUpperCase().contains('BEGIN:VCALENDAR')) {
      throw const IntegrationApiException(
        'That link didn\'t return a calendar feed. In the Runna app, go to '
        'Settings → Calendar sync and copy the subscription link.',
        provider: _provider,
      );
    }

    return body;
  }
}
