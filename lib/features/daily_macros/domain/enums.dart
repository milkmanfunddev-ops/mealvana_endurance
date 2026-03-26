/// Training phase for periodized nutrition
enum TrainingPhase {
  base,
  build,
  peak,
  taper,
  raceWeek,
  offSeason;

  String get dbValue {
    switch (this) {
      case TrainingPhase.base:
        return 'base';
      case TrainingPhase.build:
        return 'build';
      case TrainingPhase.peak:
        return 'peak';
      case TrainingPhase.taper:
        return 'taper';
      case TrainingPhase.raceWeek:
        return 'race_week';
      case TrainingPhase.offSeason:
        return 'off_season';
    }
  }

  String get displayName {
    switch (this) {
      case TrainingPhase.base:
        return 'Base';
      case TrainingPhase.build:
        return 'Build';
      case TrainingPhase.peak:
        return 'Peak';
      case TrainingPhase.taper:
        return 'Taper';
      case TrainingPhase.raceWeek:
        return 'Race Week';
      case TrainingPhase.offSeason:
        return 'Off Season';
    }
  }

  static TrainingPhase fromDbValue(String? value) {
    switch (value) {
      case 'build':
        return TrainingPhase.build;
      case 'peak':
        return TrainingPhase.peak;
      case 'taper':
        return TrainingPhase.taper;
      case 'race_week':
        return TrainingPhase.raceWeek;
      case 'off_season':
        return TrainingPhase.offSeason;
      default:
        return TrainingPhase.base;
    }
  }
}

/// Lifestyle activity level for NEAT calculation
enum Lifestyle {
  desk,
  mixed,
  active,
  veryActive;

  String get dbValue {
    switch (this) {
      case Lifestyle.desk:
        return 'desk';
      case Lifestyle.mixed:
        return 'mixed';
      case Lifestyle.active:
        return 'active';
      case Lifestyle.veryActive:
        return 'very_active';
    }
  }

  String get displayName {
    switch (this) {
      case Lifestyle.desk:
        return 'Desk-based';
      case Lifestyle.mixed:
        return 'Mixed';
      case Lifestyle.active:
        return 'Active';
      case Lifestyle.veryActive:
        return 'Very Active';
    }
  }

  static Lifestyle fromDbValue(String? value) {
    switch (value) {
      case 'desk':
        return Lifestyle.desk;
      case 'active':
        return Lifestyle.active;
      case 'very_active':
        return Lifestyle.veryActive;
      default:
        return Lifestyle.mixed;
    }
  }
}

/// Energy availability status tiers
enum EaStatus {
  ok,
  softWarning,
  hardWarning,
  block;

  String get dbValue {
    switch (this) {
      case EaStatus.ok:
        return 'OK';
      case EaStatus.softWarning:
        return 'SOFT_WARNING';
      case EaStatus.hardWarning:
        return 'HARD_WARNING';
      case EaStatus.block:
        return 'BLOCK';
    }
  }

  String get displayName {
    switch (this) {
      case EaStatus.ok:
        return 'OK';
      case EaStatus.softWarning:
        return 'Low Energy Availability';
      case EaStatus.hardWarning:
        return 'Very Low Energy Availability';
      case EaStatus.block:
        return 'Dangerously Low';
    }
  }

  static EaStatus? fromDbValue(String? value) {
    switch (value) {
      case 'OK':
        return EaStatus.ok;
      case 'SOFT_WARNING':
        return EaStatus.softWarning;
      case 'HARD_WARNING':
        return EaStatus.hardWarning;
      case 'BLOCK':
        return EaStatus.block;
      default:
        return null;
    }
  }
}
