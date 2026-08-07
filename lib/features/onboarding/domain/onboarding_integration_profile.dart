import '../../auth/domain/user_preferences.dart';

/// Athlete details a connected training platform already knows, used to
/// pre-fill the onboarding forms instead of asking for what we were just
/// handed.
///
/// Every field is independently nullable because coverage differs sharply
/// by provider — see `onboardingIntegrationProfile` for the precedence
/// rules and, importantly, for which providers must NOT be trusted for
/// which field.
class OnboardingIntegrationProfile {
  const OnboardingIntegrationProfile({
    this.firstName,
    this.lastName,
    this.email,
    this.gender,
    this.birthYear,
    this.weightLbs,
    this.nameSource,
    this.weightSource,
  });

  static const empty = OnboardingIntegrationProfile();

  final String? firstName;
  final String? lastName;
  final String? email;
  final Gender? gender;
  final int? birthYear;
  final double? weightLbs;

  /// Display names of the providers each group came from, for the "we
  /// filled this in from X" captions.
  final String? nameSource;
  final String? weightSource;

  bool get hasAnything =>
      firstName != null ||
      lastName != null ||
      email != null ||
      gender != null ||
      birthYear != null ||
      weightLbs != null;

  /// Splits a provider's single full-name field into first/last.
  ///
  /// Only ever called with names from providers that return a REAL athlete
  /// name — Garmin and V.O2 store the literal strings 'Garmin Connect' and
  /// 'V.O2' in that column, which would otherwise land in someone's name
  /// fields.
  static ({String? first, String? last}) splitFullName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return (first: null, last: null);

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return (first: parts.first, last: null);
    return (
      first: parts.sublist(0, parts.length - 1).join(' '),
      last: parts.last,
    );
  }

  /// TrainingPeaks reports sex as 'm' / 'f'. Anything else (including the
  /// empty string) yields null — we ask rather than guess, and never map an
  /// unrecognized value onto [Gender.other], which is a real answer someone
  /// might have chosen for themselves.
  static Gender? parseGender(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'm':
      case 'male':
        return Gender.male;
      case 'f':
      case 'female':
        return Gender.female;
      default:
        return null;
    }
  }
}
