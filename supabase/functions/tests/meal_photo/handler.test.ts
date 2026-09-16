/**
 * The meal-photo handler with the fake database and no network (seam 3).
 *
 * Rows go in producer-shaped — exactly what `users`, `meal_library` and the two
 * History tables hold — and the assertions are about what the server stores and
 * what it answers, never about call order.
 *
 * `meal_photo_add` is a SQL function, so the fake supplies an rpc handler that
 * does what the migration's function does: one History row, the Meal's
 * current-photo fields, one event, or nothing at all when the Meal is unknown.
 * The tests then assert those three writes really happened.
 *
 * Run: deno test --allow-read --allow-write --allow-env --allow-sys \
 *        --node-modules-dir=none supabase/functions/tests/meal_photo
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { handleMealPhoto, MAX_UPLOAD_BYTES } from '../../meal-photo/handler.ts';
import type { PhotoDeps } from '../../meal-photo/handler.ts';
import { fakeDb } from '../vana/support/fake_db.ts';
import type { FakeDb, Row } from '../vana/support/fake_db.ts';
import type { Db } from '../../_shared/vana/env.ts';

const TESTER = '11111111-1111-4111-8111-111111111111';
const ATHLETE = '22222222-2222-4222-8222-222222222222';
const IMAGE = 'https://images.pexels.com/photos/1/salmon-salad.jpeg';

/** The salmon salad the ADR names, as `meal_library` holds it after ticket 01. */
const salad = (over: Row = {}): Row => ({
  id: 'AD-001',
  name: 'Salmon, quinoa, asparagus & spinach salad',
  is_active: true,
  photo_url: null,
  photo_credit: null,
  photo_credit_url: null,
  photo_history_id: null,
  // The frozen pipeline's columns are still here and must stay untouched.
  image_mode: 'mosaic',
  image_url: 'https://images.pexels.com/raw-salmon.jpeg',
  image_verdict: 'ok',
  ...over,
});

/** What the migration's `meal_photo_add` does, in one transaction. */
function addRpc(db: FakeDb) {
  // deno-lint-ignore no-explicit-any
  return (args: any) => {
    const meal = db.rows('meal_library').find((m) => m.id === args.p_meal_id);
    if (!meal) throw new Error('meal_not_found');
    const id = crypto.randomUUID();
    // Postgres stamps created_at with microsecond precision, so two adds never
    // share one. Date.now() has milliseconds and two adds in a test do, which
    // would make the newest-first order a coin toss rather than a rule.
    const at = new Date(Date.now() + db.rows('meal_photo_history').length).toISOString();
    db.rows('meal_photo_history').push({
      id,
      meal_id: args.p_meal_id,
      url: args.p_url,
      credit: args.p_credit ?? null,
      credit_url: args.p_credit_url ?? null,
      storage_path: args.p_storage_path ?? null,
      added_by: args.p_account ?? null,
      created_at: at,
    });
    meal.photo_url = args.p_url;
    meal.photo_credit = args.p_credit ?? null;
    meal.photo_credit_url = args.p_credit_url ?? null;
    meal.photo_history_id = id;
    db.rows('meal_photo_events').push({
      id: crypto.randomUUID(),
      action: 'add',
      meal_id: args.p_meal_id,
      photo_id: id,
      photo_url: args.p_url,
      account_id: args.p_account ?? null,
      created_at: at,
    });
    return {
      photo: {
        url: args.p_url,
        credit: args.p_credit ?? null,
        creditUrl: args.p_credit_url ?? null,
      },
      entry: {
        id,
        url: args.p_url,
        credit: args.p_credit ?? null,
        creditUrl: args.p_credit_url ?? null,
        storagePath: args.p_storage_path ?? null,
        addedBy: args.p_account ?? null,
        createdAt: at,
        isCurrent: true,
      },
    };
  };
}

interface Harness {
  db: FakeDb;
  deps: PhotoDeps;
  /** Every address the handler asked about, so a refusal proves it looked. */
  probed: string[];
  /** The fake bucket, so a test can see whether a file was really stored. */
  store: FakeStore;
}

/**
 * The `meal-images` bucket, in memory. Holds what was stored so a test can
 * assert a photograph really landed, and records removals so the cleanup after
 * a failed write is visible rather than assumed.
 */
class FakeStore {
  readonly files = new Map<string, { bytes: Uint8Array; contentType: string }>();
  readonly removed: string[] = [];
  failWith: string | null = null;

  upload(path: string, bytes: Uint8Array, contentType: string): Promise<string | null> {
    if (this.failWith) return Promise.resolve(this.failWith);
    this.files.set(path, { bytes, contentType });
    return Promise.resolve(null);
  }
  remove(path: string): Promise<void> {
    this.removed.push(path);
    this.files.delete(path);
    return Promise.resolve();
  }
  publicUrl(path: string): string {
    return `https://dev.supabase.co/storage/v1/object/public/meal-images/${path}`;
  }
}

/** A minimal real JPEG: the SOI + APP0 marker, then a byte of body. */
const JPEG_BYTES = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);

/** Spreading a multi-megabyte array into `fromCharCode` overflows the stack,
 *  so the oversized-upload case is encoded in chunks. */
function base64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

function harness(
  { userId = TESTER, meals = [salad()], contentType = 'image/jpeg' as string | null } = {},
): Harness {
  const probed: string[] = [];
  // The rpc handler needs the database it writes to, and the database needs the
  // handler, so the closure reaches `db` only when it is actually called.
  let db!: FakeDb;
  db = fakeDb(
    {
      users: [
        { id: TESTER, is_internal: true },
        { id: ATHLETE, is_internal: false },
      ],
      meal_library: meals,
      meal_photo_history: [],
      meal_photo_events: [],
    },
    // deno-lint-ignore no-explicit-any
    { rpc: { meal_photo_add: (args: any) => addRpc(db)(args) } },
  );
  const store = new FakeStore();
  return {
    db,
    probed,
    store,
    deps: {
      admin: db as unknown as Db,
      userId,
      probeImage: (url: string) => {
        probed.push(url);
        return Promise.resolve(contentType);
      },
      storage: store,
    },
  };
}

Deno.test('a non-Tester is refused and nothing is written', async () => {
  const h = harness({ userId: ATHLETE });
  const res = await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: IMAGE },
    h.deps,
  );

  assertEquals(res.status, 403);
  assertEquals(res.body, { error: 'not_tester' });
  assertEquals(h.db.rows('meal_photo_history'), []);
  assertEquals(h.db.rows('meal_photo_events'), []);
  assertEquals(h.db.rows('meal_library')[0].photo_url, null);
  // Refused before the address was even looked at.
  assertEquals(h.probed, []);
});

Deno.test('an account with no users row is refused too', async () => {
  const h = harness({ userId: '33333333-3333-4333-8333-333333333333' });
  const res = await handleMealPhoto({ action: 'history', meal_id: 'AD-001' }, h.deps);
  assertEquals(res.status, 403);
  assertEquals(res.body, { error: 'not_tester' });
});

Deno.test('an add writes the current photo, one History row and one event with the account', async () => {
  const h = harness();
  const res = await handleMealPhoto(
    {
      action: 'add_address',
      meal_id: 'AD-001',
      url: IMAGE,
      credit: '  Photo by Lee  ',
      credit_url: 'https://example.com/photos/1',
    },
    h.deps,
  );

  assertEquals(res.status, 200);
  assertEquals(h.probed, [IMAGE]);

  const history = h.db.rows('meal_photo_history');
  assertEquals(history.length, 1);
  assertEquals(history[0].meal_id, 'AD-001');
  assertEquals(history[0].url, IMAGE);
  // Trimmed once, on the way in — the app never sees a padded credit line.
  assertEquals(history[0].credit, 'Photo by Lee');
  assertEquals(history[0].credit_url, 'https://example.com/photos/1');
  // A web address is shown where it lives; nothing is copied into our storage.
  assertEquals(history[0].storage_path, null);
  assertEquals(history[0].added_by, TESTER);

  const events = h.db.rows('meal_photo_events');
  assertEquals(events.length, 1);
  assertEquals(events[0].action, 'add');
  assertEquals(events[0].meal_id, 'AD-001');
  assertEquals(events[0].photo_id, history[0].id);
  assertEquals(events[0].account_id, TESTER);

  const meal = h.db.rows('meal_library')[0];
  assertEquals(meal.photo_url, IMAGE);
  assertEquals(meal.photo_credit, 'Photo by Lee');
  assertEquals(meal.photo_history_id, history[0].id);
  // The frozen pipeline's columns are not touched (ADR 0003).
  assertEquals(meal.image_mode, 'mosaic');
  assertEquals(meal.image_url, 'https://images.pexels.com/raw-salmon.jpeg');

  assertEquals(res.body.photo, {
    url: IMAGE,
    credit: 'Photo by Lee',
    creditUrl: 'https://example.com/photos/1',
  });
  // The History row the app shows comes back with the server's own id, account
  // and clock, so nothing about it is invented on the device.
  assertEquals(res.body.entry, {
    id: history[0].id,
    url: IMAGE,
    credit: 'Photo by Lee',
    creditUrl: 'https://example.com/photos/1',
    storagePath: null,
    addedBy: TESTER,
    createdAt: history[0].created_at,
    isCurrent: true,
  });
});

Deno.test('an add with no credit stores none, rather than an empty one', async () => {
  const h = harness();
  const res = await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: IMAGE, credit: '   ' },
    h.deps,
  );

  assertEquals(res.status, 200);
  assertEquals(h.db.rows('meal_photo_history')[0].credit, null);
  assertEquals(h.db.rows('meal_library')[0].photo_credit, null);
});

Deno.test('an address that does not answer with an image is refused', async () => {
  const h = harness({ contentType: 'text/html' });
  const res = await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: 'https://example.com/a-page' },
    h.deps,
  );

  assertEquals(res.status, 400);
  assertEquals(res.body, { error: 'not_an_image' });
  assertEquals(h.db.rows('meal_photo_history'), []);
  assertEquals(h.db.rows('meal_photo_events'), []);
  assertEquals(h.db.rows('meal_library')[0].photo_url, null);
});

Deno.test('an address that cannot be loaded at all is refused', async () => {
  const h = harness({ contentType: null });
  const res = await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: 'https://example.com/gone.jpg' },
    h.deps,
  );
  assertEquals(res.status, 400);
  assertEquals(res.body, { error: 'not_an_image' });
  assertEquals(h.db.rows('meal_photo_history'), []);
});

Deno.test('a non-https address is refused without being loaded', async () => {
  const h = harness();
  for (const url of ['http://example.com/a.jpg', 'not a url', 'ftp://example.com/a.jpg']) {
    const res = await handleMealPhoto(
      { action: 'add_address', meal_id: 'AD-001', url },
      h.deps,
    );
    assertEquals(res.status, 400);
    assertEquals(res.body.error, 'invalid_input');
  }
  assertEquals(h.probed, []);
  assertEquals(h.db.rows('meal_photo_history'), []);
});

Deno.test('an unknown Meal is a 404 and writes nothing', async () => {
  const h = harness();
  const res = await handleMealPhoto(
    { action: 'add_address', meal_id: 'NOPE-999', url: IMAGE },
    h.deps,
  );

  assertEquals(res.status, 404);
  assertEquals(res.body, { error: 'meal_not_found' });
  assertEquals(h.db.rows('meal_photo_history'), []);
  assertEquals(h.db.rows('meal_photo_events'), []);
});

Deno.test('history answers the current photo and an empty History for an untouched Meal', async () => {
  // The 170 photographs the ticket-01 switchover copied across have no History
  // row on purpose, so a rejected pipeline picture can never be restored.
  const h = harness({
    meals: [
      salad({
        photo_url: 'https://upload.wikimedia.org/avocado.jpg',
        photo_credit: 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
        photo_credit_url: 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
      }),
    ],
  });

  const res = await handleMealPhoto({ action: 'history', meal_id: 'AD-001' }, h.deps);

  assertEquals(res.status, 200);
  assertEquals(res.body, {
    photo: {
      url: 'https://upload.wikimedia.org/avocado.jpg',
      credit: 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
      creditUrl: 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
      historyId: null,
    },
    history: [],
  });
});

Deno.test('history lists what a Meal has shown, newest first, marking the current one', async () => {
  const h = harness();
  await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: IMAGE + '?first' },
    h.deps,
  );
  await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: IMAGE + '?second', credit: 'Lee' },
    h.deps,
  );

  const res = await handleMealPhoto({ action: 'history', meal_id: 'AD-001' }, h.deps);
  const rows = res.body.history as Record<string, unknown>[];

  assertEquals(res.status, 200);
  assertEquals(rows.length, 2);
  // Replacing a photo keeps the old one in History — nothing is lost by trying.
  assertEquals(rows.map((r) => r.url), [IMAGE + '?second', IMAGE + '?first']);
  assertEquals(rows.map((r) => r.isCurrent), [true, false]);
  assertEquals(rows[0].addedBy, TESTER);
  assertEquals((res.body.photo as Record<string, unknown>).url, IMAGE + '?second');
});

Deno.test('history for a Meal that is not in the library is a 404', async () => {
  const h = harness();
  const res = await handleMealPhoto({ action: 'history', meal_id: 'NOPE-999' }, h.deps);
  assertEquals(res.status, 404);
  assertEquals(res.body, { error: 'meal_not_found' });
});

Deno.test('a missing or unknown action is refused', async () => {
  const h = harness();
  for (const body of [
    { meal_id: 'AD-001' },
    { action: 'add_upload', meal_id: 'AD-001' },
    { action: 'add_address' },
  ]) {
    const res = await handleMealPhoto(body, h.deps);
    assertEquals(res.status, 400);
    assertEquals(res.body.error, 'invalid_input');
  }
  assertEquals(h.db.rows('meal_photo_history'), []);
});

// ─────────────────────────── add_upload (ticket 05) ───────────────────────────

Deno.test('an upload stores the file and records where it was put', async () => {
  const h = harness();
  const res = await handleMealPhoto(
    {
      action: 'add_upload',
      meal_id: 'AD-001',
      data: base64(JPEG_BYTES),
      credit: 'Photo by Lee',
    },
    h.deps,
  );

  assertEquals(res.status, 200);

  // The file really landed, once, under a per-Meal folder.
  assertEquals(h.store.files.size, 1);
  const [path, file] = [...h.store.files.entries()][0];
  assertEquals(path.startsWith('photos/AD-001/'), true);
  assertEquals(path.endsWith('.jpg'), true);
  assertEquals(file.contentType, 'image/jpeg');
  assertEquals(file.bytes, JPEG_BYTES);

  // History carries the storage path, so ticket 06 can delete the file and the
  // cutover knows which files have to travel to prod.
  const history = h.db.rows('meal_photo_history');
  assertEquals(history.length, 1);
  assertEquals(history[0].storage_path, path);
  assertEquals(history[0].url, h.store.publicUrl(path));
  assertEquals(history[0].credit, 'Photo by Lee');
  assertEquals(history[0].added_by, TESTER);

  // And it is the photograph the Meal now wears, with one event to say so.
  const meal = h.db.rows('meal_library')[0];
  assertEquals(meal.photo_url, h.store.publicUrl(path));
  assertEquals(meal.photo_history_id, history[0].id);
  const events = h.db.rows('meal_photo_events');
  assertEquals(events.length, 1);
  assertEquals(events[0].action, 'add');
  assertEquals(events[0].account_id, TESTER);

  assertEquals((res.body.entry as Record<string, unknown>).storagePath, path);
});

Deno.test('a non-Tester cannot upload, and nothing is stored', async () => {
  const h = harness({ userId: ATHLETE });
  const res = await handleMealPhoto(
    { action: 'add_upload', meal_id: 'AD-001', data: base64(JPEG_BYTES) },
    h.deps,
  );

  assertEquals(res.status, 403);
  assertEquals(res.body, { error: 'not_tester' });
  // Refused before the bytes were even written down.
  assertEquals(h.store.files.size, 0);
  assertEquals(h.db.rows('meal_photo_history'), []);
});

Deno.test('bytes that are not a JPEG are refused and never stored', async () => {
  const h = harness();
  const res = await handleMealPhoto(
    {
      action: 'add_upload',
      meal_id: 'AD-001',
      data: base64(new Uint8Array([0x89, 0x50, 0x4e, 0x47])), // a PNG header
    },
    h.deps,
  );

  assertEquals(res.status, 400);
  assertEquals(res.body, { error: 'not_an_image' });
  assertEquals(h.store.files.size, 0);
  assertEquals(h.db.rows('meal_photo_history'), []);
});

Deno.test('an upload past the bucket limit is refused before it is stored', async () => {
  const h = harness();
  const huge = new Uint8Array(MAX_UPLOAD_BYTES + 1);
  huge.set(JPEG_BYTES);

  const res = await handleMealPhoto(
    { action: 'add_upload', meal_id: 'AD-001', data: base64(huge) },
    h.deps,
  );

  assertEquals(res.status, 400);
  assertEquals(res.body, { error: 'too_large' });
  assertEquals(h.store.files.size, 0);
});

Deno.test('data that is not base64, or missing, is refused', async () => {
  const h = harness();
  for (const body of [
    { action: 'add_upload', meal_id: 'AD-001' },
    { action: 'add_upload', meal_id: 'AD-001', data: 'not base64 at all!!' },
    { action: 'add_upload', meal_id: 'AD-001', data: '' },
  ]) {
    const res = await handleMealPhoto(body, h.deps);
    assertEquals(res.status, 400);
    assertEquals(res.body.error, 'invalid_input');
  }
  assertEquals(h.store.files.size, 0);
  assertEquals(h.db.rows('meal_photo_history'), []);
});

Deno.test('an upload for an unknown Meal leaves no orphan file behind', async () => {
  const h = harness();
  const res = await handleMealPhoto(
    { action: 'add_upload', meal_id: 'NOPE-999', data: base64(JPEG_BYTES) },
    h.deps,
  );

  assertEquals(res.status, 404);
  assertEquals(res.body, { error: 'meal_not_found' });
  // The row was never written, so the file it would have named must not be
  // left sitting in a public bucket.
  assertEquals(h.store.files.size, 0);
  assertEquals(h.store.removed.length, 1);
  assertEquals(h.db.rows('meal_photo_history'), []);
});

Deno.test('a bucket that refuses the write is a 500, and nothing is recorded', async () => {
  const h = harness();
  h.store.failWith = 'bucket is full';

  const res = await handleMealPhoto(
    { action: 'add_upload', meal_id: 'AD-001', data: base64(JPEG_BYTES) },
    h.deps,
  );

  assertEquals(res.status, 500);
  assertEquals(res.body, { error: 'server_error' });
  assertEquals(h.db.rows('meal_photo_history'), []);
  assertEquals(h.db.rows('meal_photo_events'), []);
  assertEquals(h.db.rows('meal_library')[0].photo_url, null);
});

Deno.test('an uploaded photo replaces whatever the Meal showed, keeping the old row', async () => {
  const h = harness();
  await handleMealPhoto(
    { action: 'add_address', meal_id: 'AD-001', url: IMAGE },
    h.deps,
  );
  await handleMealPhoto(
    { action: 'add_upload', meal_id: 'AD-001', data: base64(JPEG_BYTES) },
    h.deps,
  );

  const res = await handleMealPhoto({ action: 'history', meal_id: 'AD-001' }, h.deps);
  const rows = res.body.history as Record<string, unknown>[];

  assertEquals(rows.length, 2);
  // Newest first: the upload is current, the pasted address is still there.
  assertEquals(rows.map((r) => r.isCurrent), [true, false]);
  assertEquals(rows[0].storagePath !== null, true);
  assertEquals(rows[1].url, IMAGE);
  assertEquals(rows[1].storagePath, null);
});
