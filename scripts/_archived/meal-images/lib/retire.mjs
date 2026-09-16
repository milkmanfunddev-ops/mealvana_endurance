// Taking a picture away from a meal, and making sure it stays away.
//
// Pass 10 retires a meal's picture when the judge rated it `wrong` and no
// photograph of the dish could be found. The spec's rule is that a wrong
// picture is worse than an icon, so the meal drops down the ladder — to the
// Mosaic it is entitled to if one exists and has not been refused, otherwise
// to nothing, blocked, with a reason.
//
// The part that needs care is memory. A verdict is a statement about a
// picture, and the picture can come back by two routes nobody would notice:
// pass 3 recomputes every meal from scratch and would hand a retired grid
// straight back, and a later sourcing run could find the same photograph again
// and pay the judge to refuse it twice. So every picture the judge rated wrong
// is remembered on the meal — photographs in `image_rejected_urls`, grids in
// `image_rejected_mosaics` — and the ladder refuses to offer either again.
//
// Pure: no network, no database, no model, no mutation of its arguments.
// `retire.test.mjs` holds it.
import { pictureIdentity, resolveMealImage } from './ladder.mjs';

/**
 * Is this meal, right now, showing an athlete a picture the judge rated wrong?
 *
 * A meal showing nothing is not, whatever verdict is still lying on the row.
 */
export function showsWrongPicture(meal) {
  return meal.image_verdict === 'wrong' && !!meal.image_mode && meal.image_mode !== 'none';
}

/**
 * The meal's refusal lists, with its current picture added if it is refused —
 * by default, if the judge rated it wrong.
 *
 * Pass 10 writes this whenever it moves a meal off its picture — by retiring
 * it, or by replacing it with a photograph. The second matters as much as the
 * first: a mosaic rescued by a photograph must not return if that photograph
 * is retired one day.
 *
 * `refuse` lets the caller hold a picture to a higher bar than `wrong`. Pass 10
 * does, for the grid a wrong photograph falls back to: that grid must be `ok`
 * (Lee, 2026-09-10), so a `weak` one is refused as well.
 */
export function rememberRejected(meal, { refuse = showsWrongPicture(meal) } = {}) {
  const urls = [...(meal.image_rejected_urls ?? [])];
  const mosaics = [...(meal.image_rejected_mosaics ?? [])];
  if (refuse && meal.image_mode && meal.image_mode !== 'none') {
    if (meal.image_mode === 'dish' && meal.image_url) {
      if (!urls.includes(meal.image_url)) urls.push(meal.image_url);
    } else if (meal.image_tiles?.length) {
      const id = pictureIdentity(meal.image_tiles);
      if (!mosaics.includes(id)) mosaics.push(id);
    }
  }
  return { image_rejected_urls: urls, image_rejected_mosaics: mosaics };
}

/**
 * Take the meal's picture away and let the ladder answer again.
 *
 * `refuse` as for `rememberRejected`.
 *
 * Returns the columns to write. The next rung may be a Mosaic nobody has
 * judged on this meal yet — `image_verdict` comes back null for it, and the
 * caller is expected to judge it before calling the meal done. If the judge
 * rates that one wrong too, retiring again lands on nothing: the ladder then
 * knows both refusals.
 *
 * The verdict always goes with the picture. Leaving it behind would keep the
 * meal in pass 9's "showing something wrong" list while it shows an icon.
 */
export function retire(meal, bank, { refuse = showsWrongPicture(meal) } = {}) {
  const rejected = rememberRejected(meal, { refuse });
  const rung = resolveMealImage({ ...meal, ...rejected, image_url: null }, bank);
  return {
    image_url: null,
    image_source_url: null,
    image_license: null,
    image_creator: null,
    image_provider: null,
    image_credit: null,
    image_unlicensed: false,
    image_verdict: null,
    image_verdict_reason: null,
    image_verdict_at: null,
    image_mode: rung.mode,
    image_tiles: rung.tiles,
    image_blocked: rung.blocked,
    image_blocked_reason: rung.blocked ? rung.reason : null,
    ...rejected,
  };
}
