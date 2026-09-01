/**
 * The activity match key (RULED, Xuan 2026-08-14 — SSOT:
 * docs/ssot/spec/daily-macros/platform-resolution.md).
 *
 * "Matches" means, in priority order:
 *   1. platform activity id equal (where the platform supplies one)
 *   2. else: same platform AND same sport AND start time within ±15 minutes
 *
 * ONE definition, TWO consumers: tombstone matching and ordinary re-sync
 * dedup both use this, so they cannot drift. The matcher MUST be run against
 * deleted rows too — an incoming platform activity that matches a
 * status='deleted' tombstone is dropped, not re-imported. Filtering
 * status != 'deleted' BEFORE matching reintroduces the reappearing-workout
 * bug the tombstone exists to prevent.
 */

export const MATCH_WINDOW_MIN = 15;

export interface MatchableActivity {
  /** Stable platform-supplied id (Garmin summaryId, TP workout Id, …). */
  platform_id?: string | null;
  /** Integration the activity came from ('garmin', 'training_peaks', …). */
  platform?: string | null;
  sport?: string | null;
  /** Start time in minutes (any consistent epoch/day basis). */
  start_min?: number | null;
  /** Row status; 'deleted' rows are tombstones and MUST still match. */
  status?: string | null;
}

/** The ruled two-tier match key. */
export function activitiesMatch(
  incoming: MatchableActivity,
  local: MatchableActivity,
): boolean {
  if (incoming.platform_id != null && local.platform_id != null) {
    return incoming.platform_id === local.platform_id;
  }

  return (
    incoming.platform != null &&
    incoming.platform === local.platform &&
    incoming.sport != null &&
    incoming.sport === local.sport &&
    incoming.start_min != null &&
    local.start_min != null &&
    Math.abs(incoming.start_min - local.start_min) <= MATCH_WINDOW_MIN
  );
}

/**
 * Find the first local row matching an incoming platform activity.
 * Deleted rows are candidates by design — never pre-filter them.
 */
export function findMatchingActivity<T extends MatchableActivity>(
  incoming: MatchableActivity,
  local_rows: T[],
): T | null {
  for (const row of local_rows) {
    if (activitiesMatch(incoming, row)) return row;
  }
  return null;
}

export type ImportDecision =
  | { import: true }
  | { import: false; reason: 'matched tombstone' | 'already imported' };

/**
 * Should an incoming platform activity be imported as a new row?
 * A tombstone hit is dropped; an ordinary hit is a re-sync dedup drop.
 */
export function decideImport(
  incoming: MatchableActivity,
  local_rows: MatchableActivity[],
): ImportDecision {
  const match = findMatchingActivity(incoming, local_rows);
  if (match == null) return { import: true };
  return {
    import: false,
    reason: match.status === 'deleted' ? 'matched tombstone' : 'already imported',
  };
}
