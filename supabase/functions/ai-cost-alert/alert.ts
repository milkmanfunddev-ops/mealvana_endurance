/** The alert body, and the Sentry events it raises. Kept out of `index.ts` so a test can drive it without the
 *  module-level `serve` starting a listener. ai-cost ticket 05. */

export interface Offender {
  user_id: string;
  day?: string;
  cost_usd: number | string;
  calls: number;
  costed_calls: number;
}

export interface AlertBody {
  day?: string;
  threshold_usd?: number | string;
  accounts?: Offender[];
}

export interface AlertEvent {
  message: string;
  day: string;
  /** One issue per account per day: the same athlete running hot tomorrow is a new number to decide about. */
  fingerprint: string[];
  account: Offender;
}

/** One event per account over the threshold. A body with no accounts raises nothing — the SQL only posts when
 *  somebody crossed, and a malformed body must not invent an alert. */
export function alertEvents(body: AlertBody): AlertEvent[] {
  const day = String(body.day ?? 'unknown');
  const accounts = Array.isArray(body.accounts) ? body.accounts : [];
  return accounts
    .filter((a) => a && typeof a.user_id === 'string' && a.user_id.length > 0)
    .map((account) => ({
      day,
      account,
      fingerprint: ['ai-cost-daily', account.user_id, day],
      message: `AI cost: account ${account.user_id} cost $${Number(account.cost_usd).toFixed(4)} on ${day}`,
    }));
}
