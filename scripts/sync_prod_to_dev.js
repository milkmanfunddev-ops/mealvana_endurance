#!/usr/bin/env node
// Mirror the refresh-managed tables PROD -> DEV (catalog_products, public_events).
// PostgREST + service-role keys; upsert on primary key `id` (merge, no deletes).
const TABLES = ['catalog_products', 'public_events'];
const { PROD_SUPABASE_URL, PROD_SUPABASE_SERVICE_ROLE_KEY,
        DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY } = process.env;
for (const [k, v] of Object.entries({ PROD_SUPABASE_URL, PROD_SUPABASE_SERVICE_ROLE_KEY, DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY }))
  if (!v) { console.error('Missing env ' + k); process.exit(1); }
const H = (key) => ({ apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' });

async function fetchAll(table) {
  const rows = [], step = 1000;
  for (let off = 0; ; off += step) {
    const r = await fetch(`${PROD_SUPABASE_URL}/rest/v1/${table}?select=*&order=id&limit=${step}&offset=${off}`, { headers: H(PROD_SUPABASE_SERVICE_ROLE_KEY) });
    if (!r.ok) throw new Error(`prod GET ${table} ${r.status}: ${await r.text()}`);
    const batch = await r.json(); rows.push(...batch);
    if (batch.length < step) break;
  }
  return rows;
}
async function upsertAll(table, rows) {
  const chunk = 500;
  for (let i = 0; i < rows.length; i += chunk) {
    const r = await fetch(`${DEV_SUPABASE_URL}/rest/v1/${table}?on_conflict=id`, {
      method: 'POST',
      headers: { ...H(DEV_SUPABASE_SERVICE_ROLE_KEY), Prefer: 'resolution=merge-duplicates,return=minimal' },
      body: JSON.stringify(rows.slice(i, i + chunk)),
    });
    if (!r.ok) throw new Error(`dev UPSERT ${table} ${r.status}: ${await r.text()}`);
  }
}
(async () => {
  for (const t of TABLES) {
    const rows = await fetchAll(t);
    await upsertAll(t, rows);
    console.log(`synced ${t}: ${rows.length} rows prod -> dev`);
  }
  console.log('prod -> dev sync complete');
})().catch(e => { console.error(e.message || e); process.exit(1); });
