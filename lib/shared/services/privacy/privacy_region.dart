import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

/// Which consent rules apply to this user.
enum ConsentRegime {
  /// Consent must be an explicit affirmative act: the analytics toggle is
  /// presented OFF and the user has to turn it on. Required by GDPR/ePrivacy
  /// (EEA + UK) and by Washington's My Health My Data Act, which additionally
  /// forbids bundling consent into the ToS and carries a private right of
  /// action.
  ///
  /// These are the only users who are shown the consent screen at all.
  strict,

  /// Disclosure plus an easy opt-out is sufficient: analytics defaults on, no
  /// screen is shown, and the user may turn it off at any time in
  /// Settings → Privacy. Applies to the US outside Washington and to most of
  /// the rest of the world.
  standard;

  bool get isStrict => this == ConsentRegime.strict;
}

/// How confident we are about [ConsentRegime] — which is not a detail, because
/// under the current rules the regime decides whether the user is *asked at
/// all*, not merely how the question is presented.
enum RegionSource {
  /// Never resolved (cold cache on a first launch that hasn't reached the
  /// network yet). Callers MUST fail closed: no analytics, no implied grant.
  none,

  /// Derived from device locale + UTC offset because the geo lookup failed.
  /// Good enough to decide *presentation*, NOT good enough to silently opt
  /// someone in — see [ResolvedRegion.source] and `analytics_consent.dart`.
  device,

  /// Resolved server-side from the request IP via `/api/region`. Authoritative,
  /// and the only source that may back an implied grant.
  geo,
}

class ResolvedRegion {
  const ResolvedRegion(this.regime, this.source);

  final ConsentRegime regime;
  final RegionSource source;
}

/// EEA member states + the UK, plus EFTA states covered by GDPR/ePrivacy.
const _strictCountries = <String>{
  // EU
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', //
  'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', //
  'SI', 'ES', 'SE',
  // EEA/EFTA
  'IS', 'LI', 'NO', 'CH',
  // UK
  'GB',
};

/// Treat the US Pacific timezone as strict so that Washington State — whose My
/// Health My Data Act requires opt-in consent for "consumer health data" and
/// lets consumers sue directly — is actually covered.
///
/// This is a *fallback* heuristic. It governs only [PrivacyRegion.resolveFrom]
/// (no geo answer available) and the case where geo returns a country but no
/// subdivision. When [PrivacyRegion.resolveFromGeo] gets a real subdivision it
/// is authoritative and this constant is not consulted — which is the whole
/// point of the geo lookup, since keying off the timezone over-covers
/// California, Oregon and Nevada, none of which require opt-in.
///
/// Set to `false` to accept the Washington gap on the fallback path.
const kPacificUsIsStrict = true;

/// SharedPreferences keys for the cached geo answer. Cached so that every
/// consumer of the regime can stay *synchronous* — the router redirect and the
/// pre-Riverpod Sentry read in `main*.dart` both need an answer without an
/// `await`. The network fetch fills this cache; nothing else reads the network.
const kGeoCountryKey = 'privacy_geo_country';
const kGeoRegionKey = 'privacy_geo_region';
const kRegionSourceKey = 'privacy_region_source';
const kRegionResolvedAtKey = 'privacy_region_at';

/// Resolves which consent regime applies.
///
/// Primary path is [resolveFromGeo], fed by `/api/region` (Vercel edge geo
/// headers, from the request IP). The IP is used transiently server-side and
/// discarded — see `api/region.js` for why this is not a declared data type in
/// the privacy manifest, and for the guardrail that keeps it that way.
///
/// [resolveFrom] is the offline/failure fallback: device locale + UTC offset.
/// It is deliberately unchanged from the original device-only implementation.
/// Its weakness is why [RegionSource] exists — a locale is a *language*
/// preference, not a location (a German in Berlin with an `en_US` phone reports
/// `US`), so a `device` answer must never be trusted enough to silently opt
/// someone in. It may only decide how a question is presented, never whether it
/// is asked.
class PrivacyRegion {
  const PrivacyRegion._();

  /// The synchronous entry point every consumer should use. Reads the cached
  /// geo answer if we have one, else falls back to device signals.
  static ResolvedRegion resolveWithPrefs(SharedPreferences prefs) {
    final locale = ui.PlatformDispatcher.instance.locale;
    final utcOffset = DateTime.now().timeZoneOffset;

    final geoCountry = prefs.getString(kGeoCountryKey);

    // A `geo` source with no country is a corrupted half-written cache, not an
    // authoritative answer. Trusting it would resolve to `standard` with
    // `RegionSource.geo` — which is an IMPLIED GRANT, i.e. we would silently opt
    // someone in on the strength of a cache entry that says nothing about where
    // they are. `PrivacyRegionService` never writes this state (it treats a null
    // country as a failed lookup), so this is belt-and-braces — but it is the
    // belt on the one strap that, if it broke, would opt in EU users in silence.
    if (prefs.getString(kRegionSourceKey) == 'geo' &&
        geoCountry != null &&
        geoCountry.isNotEmpty) {
      return ResolvedRegion(
        resolveFromGeo(
          country: geoCountry,
          region: prefs.getString(kGeoRegionKey),
          utcOffset: utcOffset,
        ),
        RegionSource.geo,
      );
    }

    final regime = resolveFrom(
      countryCode: locale.countryCode,
      utcOffset: utcOffset,
    );

    // Distinguish "we tried the network, it failed, we're on device signals"
    // from "we have never resolved anything". Only the latter fails closed;
    // the former is a usable answer for presentation purposes.
    final attempted = prefs.getString(kRegionSourceKey) == 'device';
    return ResolvedRegion(
      regime,
      attempted ? RegionSource.device : RegionSource.none,
    );
  }

  /// Resolve from an authoritative server-side geo answer.
  ///
  /// [country] is an ISO-3166-1 alpha-2 code; [region] the ISO-3166-2
  /// subdivision ("WA", "CA"). [utcOffset] is consulted ONLY for the
  /// country-without-subdivision safety net below.
  static ConsentRegime resolveFromGeo({
    required String? country,
    required String? region,
    required Duration utcOffset,
  }) {
    final c = country?.toUpperCase();

    // No country at all tells us nothing. Fail toward the device heuristic
    // rather than toward `standard` — `standard` is the permissive answer here,
    // and answering it from no evidence is how you skip the prompt for someone
    // who was entitled to it.
    if (c == null || c.isEmpty) {
      return resolveFrom(countryCode: null, utcOffset: utcOffset);
    }

    if (_strictCountries.contains(c)) return ConsentRegime.strict;

    if (c == 'US') {
      final r = region?.toUpperCase();

      if (r == 'WA') return ConsentRegime.strict;

      // SAFETY NET. Vercel does not guarantee a subdivision. With a US country
      // and no state we cannot rule out Washington, so fall back to the
      // timezone proxy rather than defaulting to `standard` — defaulting would
      // silently drop MHMDA coverage entirely if the header ever stopped being
      // populated, and the failure would be invisible.
      if (r == null || r.isEmpty) {
        return resolveFrom(countryCode: 'US', utcOffset: utcOffset);
      }

      // A real subdivision that isn't Washington. California, Oregon and Nevada
      // land here and are correctly `standard` — CCPA/CPRA is an opt-out
      // regime, not opt-in. Recovering these users is the payoff for doing geo
      // at all.
      return ConsentRegime.standard;
    }

    return ConsentRegime.standard;
  }

  /// Resolve the regime from the current device. Fallback path only.
  static ConsentRegime resolve() {
    final locale = ui.PlatformDispatcher.instance.locale;
    return resolveFrom(
      countryCode: locale.countryCode,
      utcOffset: DateTime.now().timeZoneOffset,
    );
  }

  /// Pure resolution from device signals, split out so it can be tested without
  /// a binding.
  ///
  /// [countryCode] is the device locale's region (may be null/absent).
  /// [utcOffset] is the device's current offset from UTC.
  static ConsentRegime resolveFrom({
    required String? countryCode,
    required Duration utcOffset,
  }) {
    final country = countryCode?.toUpperCase();

    // 1. Locale names an EEA/UK country → strict, unambiguously.
    if (country != null && _strictCountries.contains(country)) {
      return ConsentRegime.strict;
    }

    final offsetHours = utcOffset.inMinutes / 60.0;

    // 2. US Pacific → may be Washington. See [kPacificUsIsStrict].
    if (kPacificUsIsStrict &&
        country == 'US' &&
        offsetHours >= -8 &&
        offsetHours <= -7) {
      return ConsentRegime.strict;
    }

    // 3. Locale gives us no country. Fall back to the offset: UTC+0..+3 spans
    //    the EEA/UK, so treat an unidentified device sitting there as strict
    //    rather than assume it is somewhere permissive.
    if (country == null && offsetHours >= 0 && offsetHours <= 3) {
      return ConsentRegime.strict;
    }

    return ConsentRegime.standard;
  }
}
