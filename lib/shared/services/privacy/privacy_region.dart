import 'dart:ui' as ui;

/// Which consent rules apply to this user.
enum ConsentRegime {
  /// Consent must be an explicit affirmative act: the analytics toggle is
  /// presented OFF and the user has to turn it on. Required by GDPR/ePrivacy
  /// (EEA + UK) and by Washington's My Health My Data Act, which additionally
  /// forbids bundling consent into the ToS and carries a private right of
  /// action.
  strict,

  /// Disclosure plus an easy opt-out is sufficient: the toggle is presented ON
  /// and the user may turn it off before continuing. Applies to the US outside
  /// Washington and to most of the rest of the world.
  standard;

  bool get isStrict => this == ConsentRegime.strict;
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
/// We resolve region from on-device signals only (no IP geolocation), and a
/// device locale cannot express a US *state*. The timezone can: Washington sits
/// in US Pacific (UTC-8 standard / UTC-7 daylight). Keying off it over-covers —
/// California, Oregon, Nevada and, seasonally, parts of the Mountain zone also
/// land on those offsets — so those users are asked to opt in rather than being
/// defaulted on. That is a deliberate trade: some lost analytics volume in the
/// American West in exchange for MHMDA coverage we would otherwise simply not
/// have.
///
/// Set to `false` to accept the Washington gap and default the entire US to
/// disclosure + opt-out.
const kPacificUsIsStrict = true;

/// Resolves which consent regime applies, from on-device signals only.
///
/// Deliberately does NOT use IP geolocation or GPS: both would mean collecting
/// location data in order to decide whether we're allowed to collect data, and
/// GPS additionally requires its own runtime permission.
///
/// The cost of that choice is honest inaccuracy — device locale is a *language*
/// preference, not a location. A German living in Berlin with an `en_US` phone
/// reports `US`. [utcOffset] is therefore used as a corroborating signal: a
/// device sitting at a European offset is treated as strict even when its
/// locale says otherwise. When neither signal is conclusive we fail strict.
class PrivacyRegion {
  const PrivacyRegion._();

  /// Resolve the regime from the current device.
  static ConsentRegime resolve() {
    final locale = ui.PlatformDispatcher.instance.locale;
    return resolveFrom(
      countryCode: locale.countryCode,
      utcOffset: DateTime.now().timeZoneOffset,
    );
  }

  /// Pure resolution, split out so it can be tested without a binding.
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
