/**
 * meal-photo — the one place a Meal's Dish photo changes (ADR 0003).
 *
 * The handler is separated from `index.ts` so a Deno test can drive it with a
 * fake database and a fake image probe, with no network and no Supabase. It
 * takes an already-authenticated caller: `index.ts` resolves the JWT, this
 * decides whether that caller is a Tester and what they may do.
 *
 * Actions (ticket 04): `add_address`, `history`. `add_upload` (ticket 05) and
 * `remove` / `restore` / `delete` (ticket 06) land here too, against the same
 * Tester check and the same one-transaction SQL functions.
 *
 * Errors: 401 unauthenticated (index.ts) · 403 not_tester · 400 invalid_input /
 * not_an_image · 404 meal_not_found · 500 server_error.
 */
import type { Db } from '../_shared/vana/env.ts';

export interface PhotoDeps {
  /** Service-role client: the History tables have RLS on and no client policies. */
  admin: Db;
  /** auth.users id of the caller, as resolved from their JWT. */
  userId: string;
  /**
   * What content type an address actually serves, or null when it cannot be
   * loaded at all. Injected so a test never leaves the process.
   */
  probeImage: (url: string) => Promise<string | null>;
}

export interface HandlerResult {
  status: number;
  body: Record<string, unknown>;
}

const ok = (body: Record<string, unknown>): HandlerResult => ({ status: 200, body });
const fail = (status: number, error: string, details?: string): HandlerResult => ({
  status,
  body: details ? { error, details } : { error },
});

/**
 * One photograph on the wire. camelCase, because this is the shape the app
 * already parses for a Meal's photo (`MealPhoto.fromJsonOrNull`, the Vana
 * `MealDetail.photo` contract) — so the page and the recipe screen read a
 * photograph through exactly one parser.
 */
interface PhotoJson {
  url: string;
  credit: string | null;
  creditUrl: string | null;
  historyId: string | null;
}

const str = (v: unknown): string | null => {
  const t = typeof v === 'string' ? v.trim() : '';
  return t.length ? t : null;
};

/**
 * The server-side gate. The entry point being hidden in the app is not
 * protection — anyone can call this function with a valid JWT — so every
 * action passes through here first (story 45).
 */
export async function isTester(admin: Db, userId: string): Promise<boolean> {
  const { data, error } = await admin
    .from('users')
    .select('is_internal')
    .eq('id', userId)
    .maybeSingle();
  if (error) {
    console.error('[meal-photo] is_internal read failed:', error.message);
    return false;
  }
  return (data as { is_internal?: boolean } | null)?.is_internal === true;
}

/**
 * An https address that answers with an image content type, or a reason it
 * isn't one. A Tester must not be able to publish a link to a 404 page or to
 * an HTML page that merely shows an image (story 30).
 */
async function checkAddress(
  url: string,
  probeImage: PhotoDeps['probeImage'],
): Promise<{ ok: true } | { ok: false; result: HandlerResult }> {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { ok: false, result: fail(400, 'invalid_input', 'address is not a URL') };
  }
  if (parsed.protocol !== 'https:') {
    return { ok: false, result: fail(400, 'invalid_input', 'address must be https') };
  }
  const contentType = await probeImage(url);
  if (contentType === null || !contentType.toLowerCase().startsWith('image/')) {
    return { ok: false, result: fail(400, 'not_an_image') };
  }
  return { ok: true };
}

/** The Meal's current photo as the app reads it, or null when it shows nothing. */
function currentPhoto(row: Record<string, unknown>): PhotoJson | null {
  const url = str(row.photo_url);
  if (url === null) return null;
  return {
    url,
    credit: str(row.photo_credit),
    creditUrl: str(row.photo_credit_url),
    historyId: str(row.photo_history_id),
  };
}

export async function handleMealPhoto(
  body: Record<string, unknown>,
  deps: PhotoDeps,
): Promise<HandlerResult> {
  const { admin, userId } = deps;

  if (!(await isTester(admin, userId))) return fail(403, 'not_tester');

  const action = str(body.action);
  const mealId = str(body.meal_id);
  if (action === null) return fail(400, 'invalid_input', 'action is required');
  if (mealId === null) return fail(400, 'invalid_input', 'meal_id is required');

  switch (action) {
    case 'add_address':
      return await addAddress(mealId, body, deps);
    case 'history':
      return await history(mealId, admin);
    default:
      return fail(400, 'invalid_input', `unknown action: ${action}`);
  }
}

/**
 * Paste a web address: check it really is an image, then write the current
 * photo, the History row and the event in one transaction (meal_photo_add).
 * The photograph is shown where it lives — nothing is copied into our storage
 * (ADR 0003), so storage_path stays null.
 */
async function addAddress(
  mealId: string,
  body: Record<string, unknown>,
  { admin, userId, probeImage }: PhotoDeps,
): Promise<HandlerResult> {
  const url = str(body.url);
  if (url === null) return fail(400, 'invalid_input', 'url is required');

  const checked = await checkAddress(url, probeImage);
  if (!checked.ok) return checked.result;

  const { data, error } = await admin.rpc('meal_photo_add', {
    p_meal_id: mealId,
    p_url: url,
    p_credit: str(body.credit),
    p_credit_url: str(body.credit_url),
    p_storage_path: null,
    p_account: userId,
  });

  if (error) {
    // The SQL function raises before writing anything when the Meal is unknown.
    // P0002 is the SQLSTATE `raise ... using errcode = 'no_data_found'` arrives
    // as; the message is checked too, so a reworded raise still maps to 404.
    const code = (error as { code?: string }).code;
    if (code === 'P0002' || error.message.includes('meal_not_found')) {
      return fail(404, 'meal_not_found');
    }
    console.error('[meal-photo] meal_photo_add failed:', error.message);
    return fail(500, 'server_error');
  }

  const answer = (data ?? {}) as { photo?: PhotoJson; entry?: Record<string, unknown> };
  if (!answer.photo || !answer.entry) {
    console.error('[meal-photo] meal_photo_add answered without a photo or entry');
    return fail(500, 'server_error');
  }
  // `entry` is the History row the app shows, carrying the server's own id,
  // account and clock — nothing about the new row is invented on the device.
  return ok({ photo: answer.photo, entry: answer.entry });
}

/**
 * The Meal's current photo and everything it has shown, newest first — what
 * the Meal photos page opens on. A Meal that has never been touched by a
 * Tester answers its current photo with an empty History, because the
 * switchover deliberately created no History rows (story 47).
 */
async function history(mealId: string, admin: Db): Promise<HandlerResult> {
  const { data: meal, error: mealError } = await admin
    .from('meal_library')
    .select('id, photo_url, photo_credit, photo_credit_url, photo_history_id')
    .eq('id', mealId)
    .maybeSingle();

  if (mealError) {
    console.error('[meal-photo] meal_library read failed:', mealError.message);
    return fail(500, 'server_error');
  }
  if (!meal) return fail(404, 'meal_not_found');

  const { data: rows, error: rowsError } = await admin
    .from('meal_photo_history')
    .select('id, url, credit, credit_url, storage_path, added_by, created_at')
    .eq('meal_id', mealId)
    .order('created_at', { ascending: false });

  if (rowsError) {
    console.error('[meal-photo] meal_photo_history read failed:', rowsError.message);
    return fail(500, 'server_error');
  }

  const current = currentPhoto(meal as Record<string, unknown>);
  return ok({
    photo: current,
    history: ((rows ?? []) as Record<string, unknown>[]).map((r) => ({
      id: r.id,
      url: r.url,
      credit: str(r.credit),
      creditUrl: str(r.credit_url),
      storagePath: str(r.storage_path),
      addedBy: r.added_by ?? null,
      createdAt: r.created_at,
      // Which row the Meal is wearing right now, so the page can mark it
      // without the app having to compare addresses.
      isCurrent: current?.historyId != null && current.historyId === r.id,
    })),
  });
}

/**
 * The real probe: ask for the address and read its content type. GET rather
 * than HEAD — several image CDNs answer HEAD with 405 — and the body is
 * cancelled the moment the headers arrive, so nothing large is downloaded.
 */
export async function probeImageOverNetwork(url: string): Promise<string | null> {
  try {
    const res = await fetch(url, { method: 'GET', redirect: 'follow' });
    const type = res.headers.get('content-type');
    await res.body?.cancel();
    if (!res.ok) return null;
    return type;
  } catch (e) {
    console.warn('[meal-photo] address could not be loaded:', (e as Error).message);
    return null;
  }
}
