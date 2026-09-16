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
import { handleMealPhoto } from '../../meal-photo/handler.ts';
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
  return {
    db,
    probed,
    deps: {
      admin: db as unknown as Db,
      userId,
      probeImage: (url: string) => {
        probed.push(url);
        return Promise.resolve(contentType);
      },
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
