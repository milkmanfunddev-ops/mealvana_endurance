/** §12: the scores each box emits per turn, returned on TurnResult. The caller writes them to Langfuse. */
import type { CheckRule, Counters } from './types.ts';

export const newCounters = (): Counters => ({
  check_catches: {}, check_retry_fixed: 0, check_safe_line: 0, route_reroute: 0, intents_pending: 0, bound_arg_disagreement: 0,
  pass_cap_hit: 0, forced_landing: 0, tokens_per_pass: [], read_label: [], model_calls: 0, steps_run: 0, cards_shown: 0, receipts: 0,
});

export const caught = (c: Counters, rule: CheckRule): void => { c.check_catches[rule] = (c.check_catches[rule] ?? 0) + 1; };

/** The flat list a Langfuse writer can turn into one score per name. */
export function flatten(c: Counters): Record<string, number | string> {
  const out: Record<string, number | string> = {
    check_retry_fixed: c.check_retry_fixed, check_safe_line: c.check_safe_line, route_reroute: c.route_reroute, intents_pending: c.intents_pending,
    bound_arg_disagreement: c.bound_arg_disagreement, pass_cap_hit: c.pass_cap_hit, forced_landing: c.forced_landing, model_calls: c.model_calls,
    steps_run: c.steps_run, cards_shown: c.cards_shown, receipts: c.receipts, read_label: c.read_label.join(','),
    tokens_per_pass_max: c.tokens_per_pass.length ? Math.max(...c.tokens_per_pass) : 0,
  };
  for (const [rule, n] of Object.entries(c.check_catches)) out[`check_catch.${rule}`] = n ?? 0;
  return out;
}
