/// Domain model for external training platform integrations
///
/// This represents an OAuth connection to a provider like Final Surge,
/// TrainingPeaks, Strava, or Garmin.
class IntegrationModel {
  const IntegrationModel({
    this.id,
    required this.userId,
    required this.provider,
    required this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    required this.providerAthleteId,
    this.providerAthleteName,
    this.providerAthleteEmail,
    this.providerAthleteWeightKg,
    this.providerAthleteBirthMonth,
    this.providerAthleteGender,
    this.providerAthleteBodyFatPct,
    this.athleteZonesJson,
    this.isActive = true,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.lastSyncError,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userId;
  final String provider; // 'final_surge', 'training_peaks', 'strava', 'garmin'
  final String accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;
  final String providerAthleteId;
  final String? providerAthleteName;
  final String? providerAthleteEmail;

  /// Athlete weight in kilograms (from Training Peaks profile)
  final double? providerAthleteWeightKg;

  /// Birth month in "YYYY-MM" format (from Training Peaks profile)
  final String? providerAthleteBirthMonth;

  /// Gender: 'm' for male, 'f' for female (from Training Peaks profile)
  final String? providerAthleteGender;

  /// Body fat percentage (from Garmin body composition API)
  final double? providerAthleteBodyFatPct;

  /// Serialized athlete zone data (HR, Speed, Power zones from Training Peaks)
  final String? athleteZonesJson;
  final bool isActive;
  final DateTime? lastSyncAt;
  final String? lastSyncStatus; // 'success', 'error', 'pending'
  final String? lastSyncError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Check if the access token has expired
  bool get isTokenExpired {
    if (tokenExpiresAt == null) return false;
    return DateTime.now().isAfter(tokenExpiresAt!);
  }

  /// Check if token will expire soon (within 5 minutes)
  bool get isTokenExpiringSoon {
    if (tokenExpiresAt == null) return false;
    final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
    return fiveMinutesFromNow.isAfter(tokenExpiresAt!);
  }

  /// Display name for the integration (athlete name or email or ID)
  String get displayName {
    return providerAthleteName ?? providerAthleteEmail ?? providerAthleteId;
  }

  /// Human-readable provider name
  String get providerDisplayName {
    switch (provider) {
      case 'final_surge':
        return 'Final Surge';
      case 'training_peaks':
        return 'TrainingPeaks';
      case 'strava':
        return 'Strava';
      case 'garmin':
        return 'Garmin Connect';
      case 'vdot':
        return 'V.O2';
      case 'runna':
        return 'Runna';
      default:
        return provider;
    }
  }

  /// Weight in pounds (converted from kg)
  double? get providerAthleteWeightLbs => providerAthleteWeightKg != null
      ? providerAthleteWeightKg! * 2.20462
      : null;

  /// Birthday as DateTime (year only - defaults to Jan 1 since only birth year is used for calculations)
  DateTime? get providerAthleteBirthday {
    if (providerAthleteBirthMonth == null ||
        providerAthleteBirthMonth!.isEmpty) {
      return null;
    }
    try {
      final parts = providerAthleteBirthMonth!.split('-');
      if (parts.isNotEmpty) {
        final year = int.parse(parts[0]);
        return DateTime(year, 1, 1); // Year only
      }
    } catch (_) {
      // Invalid format
    }
    return null;
  }

  /// Create a copy with updated fields
  IntegrationModel copyWith({
    String? id,
    String? userId,
    String? provider,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
    String? providerAthleteId,
    String? providerAthleteName,
    String? providerAthleteEmail,
    double? providerAthleteWeightKg,
    String? providerAthleteBirthMonth,
    String? providerAthleteGender,
    double? providerAthleteBodyFatPct,
    String? athleteZonesJson,
    bool? isActive,
    DateTime? lastSyncAt,
    String? lastSyncStatus,
    String? lastSyncError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IntegrationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      providerAthleteId: providerAthleteId ?? this.providerAthleteId,
      providerAthleteName: providerAthleteName ?? this.providerAthleteName,
      providerAthleteEmail: providerAthleteEmail ?? this.providerAthleteEmail,
      providerAthleteWeightKg:
          providerAthleteWeightKg ?? this.providerAthleteWeightKg,
      providerAthleteBirthMonth:
          providerAthleteBirthMonth ?? this.providerAthleteBirthMonth,
      providerAthleteGender:
          providerAthleteGender ?? this.providerAthleteGender,
      providerAthleteBodyFatPct:
          providerAthleteBodyFatPct ?? this.providerAthleteBodyFatPct,
      athleteZonesJson: athleteZonesJson ?? this.athleteZonesJson,
      isActive: isActive ?? this.isActive,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'IntegrationModel(provider: $provider, athlete: $displayName, active: $isActive)';
  }
}

/// Supported integration providers
enum IntegrationProvider {
  finalSurge('final_surge', 'Final Surge'),
  trainingPeaks('training_peaks', 'TrainingPeaks'),
  strava('strava', 'Strava'),
  garmin('garmin', 'Garmin Connect'),
  vdot('vdot', 'V.O2'),
  runna('runna', 'Runna');

  const IntegrationProvider(this.value, this.displayName);

  final String value;
  final String displayName;

  static IntegrationProvider? fromValue(String value) {
    return IntegrationProvider.values.cast<IntegrationProvider?>().firstWhere(
      (p) => p?.value == value,
      orElse: () => null,
    );
  }
}
