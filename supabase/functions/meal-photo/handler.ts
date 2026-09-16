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
  /**
   * The public image bucket, as a port rather than a Supabase client, so the
   * Deno test drives a fake store with no network. Only the service role
   * writes here — the bucket has no storage policies at all.
   */
  storage: PhotoStorage;
}

/** What `add_upload` needs of the `meal-images` bucket, and nothing more. */
export interface PhotoStorage {
  /** Stores the bytes, answering an error message or null. */
  upload(path: string, bytes: Uint8Array, contentType: string): Promise<string | null>;
  /** Best-effort delete, used to clean up after a failed write. */
  remove(path: string): Promise<void>;
  /** The address athletes will load the photograph from. */
  publicUrl(path: string): string;
}

/** The bucket a Meal's photographs live in (see the bucket migration). */
export const PHOTO_BUCKET = 'meal-images';

/**
 * The bucket's own ceiling. The app prepares uploads to ~1600px JPEG, far
 * inside this, so hitting it means something is wrong with the photo rather
 * than with the Tester — checked here so the answer is a clear 400 rather than
 * a storage error surfacing as a 500.
 */
export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

/** The longest base64 string that could still decode to a legal upload. */
const BASE64_CEILING = Math.ceil(MAX_UPLOAD_BYTES / 3) * 4 + 4;

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
    case 'add_upload':
      return await addUpload(mealId, body, deps);
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
 * A photograph the Tester took or chose: prepared bytes in, a stored file out.
 *
 * The app has already cropped, shrunk and stripped the photo of its EXIF
 * before it left the phone (`prepareDishPhoto`) — this does NOT re-encode, so
 * what athletes see is exactly what the Tester previewed. The server's job is
 * to check the bytes really are a JPEG, put them somewhere public, and record
 * the photograph the same way an address is recorded.
 *
 * The storage path is kept on the History row so ticket 06 can delete the file
 * when the row is deleted for good, and so the cutover knows which files it has
 * to carry into prod.
 */
async function addUpload(
  mealId: string,
  body: Record<string, unknown>,
  { admin, userId, storage }: PhotoDeps,
): Promise<HandlerResult> {
  const encoded = str(body.data);
  if (encoded === null) return fail(400, 'invalid_input', 'data is required');

  // Refuse on the encoded length first: base64 is 4 bytes per 3, so this bounds
  // the real size without materialising a huge payload in memory to measure it.
  if (encoded.length > BASE64_CEILING) return fail(400, 'too_large');

  let bytes: Uint8Array;
  try {
    bytes = decodeBase64(encoded);
  } catch {
    return fail(400, 'invalid_input', 'data is not base64');
  }
  if (bytes.length === 0) return fail(400, 'invalid_input', 'data is empty');
  if (bytes.length > MAX_UPLOAD_BYTES) return fail(400, 'too_large');
  // The app only ever sends JPEG, and the bucket only accepts image types, but
  // a hidden button is not protection here either: anyone with a JWT can call
  // this, so the bytes are checked rather than trusted.
  if (!isJpeg(bytes)) return fail(400, 'not_an_image');

  // One folder per Meal, a fresh name per photograph: replacing a photo never
  // overwrites the file the old History row still points at (story 41).
  const path = `photos/${mealId}/${crypto.randomUUID()}.jpg`;
  const uploadError = await storage.upload(path, bytes, 'image/jpeg');
  if (uploadError !== null) {
    console.error('[meal-photo] upload failed:', uploadError);
    return fail(500, 'server_error');
  }

  const { data, error } = await admin.rpc('meal_photo_add', {
    p_meal_id: mealId,
    p_url: storage.publicUrl(path),
    p_credit: str(body.credit),
    p_credit_url: str(body.credit_url),
    p_storage_path: path,
    p_account: userId,
  });

  if (error) {
    // The row was never written, so the file it would have named is litter in
    // a public bucket. Take it back out before answering.
    await storage.remove(path);
    const code = (error as { code?: string }).code;
    if (code === 'P0002' || error.message.includes('meal_not_found')) {
      return fail(404, 'meal_not_found');
    }
    console.error('[meal-photo] meal_photo_add failed:', error.message);
    return fail(500, 'server_error');
  }

  const answer = (data ?? {}) as { photo?: PhotoJson; entry?: Record<string, unknown> };
  if (!answer.photo || !answer.entry) {
    await storage.remove(path);
    console.error('[meal-photo] meal_photo_add answered without a photo or entry');
    return fail(500, 'server_error');
  }
  return ok({ photo: answer.photo, entry: answer.entry });
}

/** The two-byte SOI plus the marker every JPEG opens with. */
function isJpeg(bytes: Uint8Array): boolean {
  return bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
}

/** base64 (as the app sends it) to bytes. Throws on anything that is not. */
function decodeBase64(encoded: string): Uint8Array {
  const binary = atob(encoded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
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

/** The `meal-images` bucket through the service-role client. */
export function bucketStorage(admin: Db, baseUrl: string): PhotoStorage {
  return {
    async upload(path, bytes, contentType) {
      const { error } = await admin.storage
        .from(PHOTO_BUCKET)
        .upload(path, bytes, { contentType, upsert: false });
      return error ? error.message : null;
    },
    async remove(path) {
      const { error } = await admin.storage.from(PHOTO_BUCKET).remove([path]);
      if (error) console.warn('[meal-photo] could not remove', path, error.message);
    },
    // The bucket is public, so the object URL needs no signing and never
    // expires — a card can draw straight from the address History stores.
    publicUrl: (path) =>
      `${baseUrl}/storage/v1/object/public/${PHOTO_BUCKET}/${path}`,
  };
}
