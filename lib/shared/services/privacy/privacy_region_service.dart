import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs_provider.dart';
import 'analytics_consent.dart';
import 'privacy_region.dart';

/// Where the geo lookup lives. This repo deploys to `app.mealvana.io` (Vercel
/// project `mealvana_endurance_coach_mode`), and `api/region.js` sits alongside
/// the Flutter web build — so the endpoint ships with the client that calls it.
///
/// Override with `--dart-define=REGION_ENDPOINT=...` to point a build at a
/// preview deployment.
const _kRegionEndpointOverride = String.fromEnvironment('REGION_ENDPOINT');
const _kDefaultRegionEndpoint = 'https://app.mealvana.io/api/region';

/// Fills the cached region answer that [PrivacyRegion.resolveWithPrefs] reads.
///
/// This is the ONLY thing in the consent stack that touches the network.
/// Everything downstream — the router redirect, `analyticsConsentProvider`, the
/// pre-Riverpod Sentry read in `main*.dart` — stays synchronous by reading the
/// SharedPreferences cache this service writes. That is deliberate: making the
/// consent provider async would mean rewriting all four entrypoints, which arm
/// Sentry session replay before a Riverpod container even exists.
///
/// Never throws. A failure here must degrade to the device-signal fallback, not
/// take down startup.
class PrivacyRegionService {
  PrivacyRegionService({
    required SharedPreferences prefs,
    required http.Client client,
    this.onResolved,
  }) : _prefs = prefs,
       _client = client;

  final SharedPreferences _prefs;
  final http.Client _client;

  /// Fired after a successful refresh so listeners can re-read the cache.
  final void Function()? onResolved;

  static Uri get endpoint {
    if (_kRegionEndpointOverride.isNotEmpty) {
      return Uri.parse(_kRegionEndpointOverride);
    }
    // Same-origin on web: avoids CORS entirely and keeps working on preview
    // deployments, whose hostnames are generated per-branch.
    if (kIsWeb) return Uri.base.resolve('/api/region');
    return Uri.parse(_kDefaultRegionEndpoint);
  }

  /// Ensure a region answer exists in the cache.
  ///
  /// Cold cache → awaits the fetch, bounded by [timeout], because the consent
  /// decision genuinely depends on it and we must not silently opt someone in
  /// while we don't know where they are.
  ///
  /// Warm cache → returns immediately and refreshes in the background, so a
  /// user who has moved between jurisdictions is re-classified without ever
  /// paying a startup cost for it.
  Future<void> ensureResolved({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final hasGeo = _prefs.getString(kRegionSourceKey) == 'geo';
    if (hasGeo) {
      unawaited(_refresh(timeout));
      return;
    }
    await _refresh(timeout);
  }

  Future<void> _refresh(Duration timeout) async {
    try {
      final response = await _client.get(endpoint).timeout(timeout);

      if (response.statusCode != 200) {
        await _markDeviceFallback();
        return;
      }

      final body = jsonDecode(response.body);
      if (body is! Map) {
        await _markDeviceFallback();
        return;
      }

      final country = body['country'] as String?;

      // A response with no country tells us nothing — treat it as a failure
      // rather than caching a null answer as authoritative.
      if (country == null || country.isEmpty) {
        await _markDeviceFallback();
        return;
      }

      final region = body['region'] as String?;

      await _prefs.setString(kGeoCountryKey, country);
      if (region != null && region.isNotEmpty) {
        await _prefs.setString(kGeoRegionKey, region);
      } else {
        // Do not leave a stale subdivision behind — a US/WA answer followed by
        // a US/<null> answer must not keep reporting WA.
        await _prefs.remove(kGeoRegionKey);
      }
      await _prefs.setString(kRegionSourceKey, 'geo');
      await _prefs.setString(
        kRegionResolvedAtKey,
        DateTime.now().toIso8601String(),
      );

      onResolved?.call();
    } catch (_) {
      // Offline, DNS failure, timeout, malformed body — all the same to us.
      await _markDeviceFallback();
    }
  }

  /// Record that we tried and failed, so the regime resolver knows it is on
  /// device signals rather than never having attempted a lookup.
  ///
  /// Critically, this must NOT clobber a good geo answer we already hold: a
  /// user who resolved to `DE` last week and is on a plane today stays `DE`.
  Future<void> _markDeviceFallback() async {
    if (_prefs.getString(kRegionSourceKey) == 'geo') return;
    await _prefs.setString(kRegionSourceKey, 'device');
  }
}

/// Provider is `keepAlive` because it is read once from app startup and its
/// background refresh must outlive whatever widget triggered it.
final privacyRegionServiceProvider = Provider<PrivacyRegionService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  return PrivacyRegionService(
    prefs: ref.read(sharedPreferencesProvider),
    client: client,
    onResolved: () {
      // The cache changed under a synchronous reader — nudge it to re-read.
      // This is what re-classifies a traveller mid-session: a user who moves
      // into the EEA flips to `strict`, their implied grant evaporates, and the
      // tracker rebuilds to a Noop.
      ref.invalidate(analyticsConsentProvider);
    },
  );
});
