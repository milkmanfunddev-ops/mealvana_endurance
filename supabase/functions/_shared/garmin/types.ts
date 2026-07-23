/**
 * Garmin Connect API TypeScript interfaces
 *
 * Models for push/ping notification payloads and activity/health data.
 * Reference: https://developer.garmin.com/gc-developer-program/overview/
 */

// ============================================================================
// Activity Types
// ============================================================================

/**
 * Garmin activity type codes mapped to our sport types.
 * Full list: https://developer.garmin.com/gc-developer-program/activity-api/
 */
export const GARMIN_ACTIVITY_TYPE_MAP: Record<string, string> = {
  // Running
  running: 'running',
  trail_running: 'running',
  treadmill_running: 'running',
  track_running: 'running',
  ultra_run: 'running',
  virtual_run: 'running',
  indoor_running: 'running',

  // Cycling
  cycling: 'cycling',
  mountain_biking: 'cycling',
  road_biking: 'cycling',
  indoor_cycling: 'cycling',
  virtual_ride: 'cycling',
  gravel_cycling: 'cycling',
  e_bike_mountain: 'cycling',
  e_bike_fitness: 'cycling',
  cyclocross: 'cycling',
  bmx: 'cycling',
  recumbent_cycling: 'cycling',

  // Swimming
  lap_swimming: 'swimming',
  open_water_swimming: 'swimming',
  swimming: 'swimming',

  // Multi-sport
  multi_sport: 'multisport',
  triathlon: 'triathlon',
  duathlon: 'duathlon',
  transition: 'transition',

  // Everything else → 'other' (we'll handle on the Dart side)
};

/** Our supported sport types for the activities table */
export type OurSportType =
  | 'running'
  | 'cycling'
  | 'swimming'
  | 'triathlon'
  | 'duathlon'
  | 'multisport'
  | 'transition'
  | 'other';

/**
 * Sport types Mealvana fuels and recalculates daily macros for.
 * Garmin uploads outside this set (e.g. strength, hiking, walking, yoga —
 * anything that maps to the generic 'other' bucket) are still imported as
 * an [OurSportType] `'other'` activity for visibility/deletion, but never
 * get a nutrition plan and never match/complete a planned activity — see
 * [insertGarminActivityIfMissing] and `findMatchingPlannedActivity` in
 * activity_completion.ts. Garmin's `'transition'` legs (T1/T2 within a
 * multisport activity) are the one type still dropped entirely — they
 * aren't a standalone activity a user would want listed.
 *
 * Triathlon/duathlon/multisport parents are included so the parent row
 * still gets created; child legs share the parent's nutrition context.
 */
export const ENDURANCE_SPORT_TYPES: ReadonlySet<OurSportType> = new Set<
  OurSportType
>([
  'running',
  'cycling',
  'swimming',
  'triathlon',
  'duathlon',
  'multisport',
]);

export function isEnduranceSportType(sport: string | undefined | null): boolean {
  if (!sport) return false;
  return ENDURANCE_SPORT_TYPES.has(sport as OurSportType);
}

// ============================================================================
// Garmin Activity Summary (Push payload)
// ============================================================================

export interface GarminActivitySummary {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  activityType: string;
  activityName?: string;
  durationInSeconds: number;
  startTimeInSeconds: number;
  startTimeOffsetInSeconds: number;
  distanceInMeters?: number;
  activeKilocalories?: number;
  averageHeartRateInBeatsPerMinute?: number;
  maxHeartRateInBeatsPerMinute?: number;
  averageRunCadenceInStepsPerMinute?: number;
  averageBikeCadenceInRoundsPerMinute?: number;
  averageSwimCadenceInStrokesPerMinute?: number;
  averageSpeedInMetersPerSecond?: number;
  maxSpeedInMetersPerSecond?: number;
  averagePaceInMinutesPerKilometer?: number;
  elevationGainInMeters?: number;
  elevationLossInMeters?: number;
  maxElevationInMeters?: number;
  minElevationInMeters?: number;
  averagePowerInWatts?: number;
  maxPowerInWatts?: number;
  normalizedPowerInWatts?: number;
  deviceName?: string;
  manual?: boolean;
  // Multi-sport / brick support
  isParent?: boolean;
  parentSummaryId?: string;
}

// ============================================================================
// Garmin Activity Detail (Push payload - detailed)
// ============================================================================

export interface GarminActivityDetail {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  summary: GarminActivitySummary;
  samples?: GarminSample[];
  laps?: GarminLap[];
}

export interface GarminSample {
  startTimeInSeconds: number;
  latitudeInDegree?: number;
  longitudeInDegree?: number;
  elevationInMeters?: number;
  heartRate?: number;
  speedMetersPerSecond?: number;
  powerInWatts?: number;
  bikeCadenceInRPM?: number;
  runCadenceInStepsPerMinute?: number;
  swimCadenceInStrokesPerMinute?: number;
}

export interface GarminLap {
  startTimeInSeconds: number;
  durationInSeconds?: number;
  distanceInMeters?: number;
  averageHeartRate?: number;
  maxHeartRate?: number;
  averageSpeedInMetersPerSecond?: number;
}

// ============================================================================
// Health / Wellness Data
// ============================================================================

export interface GarminDailySummary {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  calendarDate: string; // "YYYY-MM-DD"
  startTimeInSeconds: number;
  startTimeOffsetInSeconds: number;
  durationInSeconds: number;
  steps?: number;
  distanceInMeters?: number;
  activeTimeInSeconds?: number;
  activeKilocalories?: number;
  bmrKilocalories?: number;
  averageHeartRateInBeatsPerMinute?: number;
  maxHeartRateInBeatsPerMinute?: number;
  minHeartRateInBeatsPerMinute?: number;
  restingHeartRateInBeatsPerMinute?: number;
  averageStressLevel?: number;
  maxStressLevel?: number;
  stressDurationInSeconds?: number;
  restStressDurationInSeconds?: number;
  activityStressDurationInSeconds?: number;
  lowStressDurationInSeconds?: number;
  mediumStressDurationInSeconds?: number;
  highStressDurationInSeconds?: number;
  bodyBatteryChargedValue?: number;
  bodyBatteryDrainedValue?: number;
  bodyBatteryHighestValue?: number;
  bodyBatteryLowestValue?: number;
  floorsClimbed?: number;
}

export interface GarminSleepSummary {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  calendarDate: string;
  startTimeInSeconds: number;
  startTimeOffsetInSeconds: number;
  durationInSeconds: number;
  unmeasurableSleepInSeconds?: number;
  deepSleepDurationInSeconds?: number;
  lightSleepDurationInSeconds?: number;
  remSleepInSeconds?: number;
  awakeDurationInSeconds?: number;
  sleepScoreQuality?: string; // "EXCELLENT", "GOOD", "FAIR", "POOR"
  overallSleepScore?: number;
  sleepQualityScore?: number;
  sleepDurationScore?: number;
  restlessMomentsCount?: number;
}

export interface GarminBodyComposition {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  measurementTimeInSeconds: number;
  measurementTimeOffsetInSeconds: number;
  weightInGrams?: number;
  percentFat?: number;
  percentHydration?: number;
  boneMassInGrams?: number;
  muscleMassInGrams?: number;
  bmi?: number;
}

export interface GarminStressDetail {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  startTimeInSeconds: number;
  startTimeOffsetInSeconds: number;
  durationInSeconds: number;
  calendarDate: string;
  timeOffsetStressLevelValues?: Array<[number, number]>; // [offsetInSeconds, stressLevel]
  timeOffsetBodyBatteryValues?: Array<[number, number]>; // [offsetInSeconds, bodyBattery]
}

export interface GarminUserMetrics {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  calendarDate: string;
  vo2Max?: number;
  fitnessAge?: number;
}

export interface GarminEpochSummary {
  userId: string;
  userAccessToken: string;
  summaryId: string;
  startTimeInSeconds: number;
  startTimeOffsetInSeconds: number;
  durationInSeconds: number; // typically 900 (15 min)
  activityType: string;
  activeKilocalories?: number;
  steps?: number;
  distanceInMeters?: number;
  averageHeartRateInBeatsPerMinute?: number;
  maxHeartRateInBeatsPerMinute?: number;
  intensity?: string; // "SEDENTARY", "ACTIVE", "HIGHLY_ACTIVE"
}

// ============================================================================
// Notification Envelope Types
// ============================================================================

/** Push notification - Garmin sends data directly */
export interface GarminPushNotification {
  activities?: GarminActivitySummary[];
  activityDetails?: GarminActivityDetail[];
  manuallyUpdatedActivities?: GarminActivitySummary[];
  dailies?: GarminDailySummary[];
  epochs?: GarminEpochSummary[];
  sleeps?: GarminSleepSummary[];
  bodyComps?: GarminBodyComposition[];
  stressDetails?: GarminStressDetail[];
  userMetrics?: GarminUserMetrics[];
  // User permissions change notification
  userPermissionsChange?: GarminUserPermissionChange[];
}

/** User permissions change notification (CONSUMER_PERMISSIONS) */
export interface GarminUserPermissionChange {
  userId: string;
  userAccessToken: string;
  permissions?: Record<string, boolean>;
}

/** Ping notification - Garmin says data is available at callback URL */
export interface GarminPingEntry {
  userId: string;
  userAccessToken: string;
  callbackURL: string;
  uploadStartTimeInSeconds?: number;
  uploadEndTimeInSeconds?: number;
}

export interface GarminPingNotification {
  activities?: GarminPingEntry[];
  activityDetails?: GarminPingEntry[];
  dailies?: GarminPingEntry[];
  epochs?: GarminPingEntry[];
  sleeps?: GarminPingEntry[];
  bodyComps?: GarminPingEntry[];
  stressDetails?: GarminPingEntry[];
  userMetrics?: GarminPingEntry[];
}

/** Deregistration notification */
export interface GarminDeregistrationNotification {
  deregistrations: Array<{
    userId: string;
    userAccessToken: string;
  }>;
}
