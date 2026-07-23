#!/usr/bin/env node
// Mirror refresh-managed tables PROD -> DEV. `id` is per-DB, so match on business keys.
// catalog_products: upsert on shopify_product_id, keep dev id (catalog_variants FKs it).
// public_events: merge on canonical key lower(event_name)|event_date|lower(city) (no simple unique constraint).
const { PROD_SUPABASE_URL, PROD_SUPABASE_SERVICE_ROLE_KEY, DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY } = process.env;
for (const [k, v] of Object.entries({ PROD_SUPABASE_URL, PROD_SUPABASE_SERVICE_ROLE_KEY, DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY }))
  if (!v) { console.error('Missing env ' + k); process.exit(1); }
const H = (key) => ({ apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' });
const stripId = ({ id, ...rest }) => rest;

async function getAll(base, key, table, select = '*') {
  const rows = [], step = 1000;
  for (let off = 0; ; off += step) {
    const r = await fetch(`${base}/rest/v1/${table}?select=${select}&order=id&limit=${step}&offset=${off}`, { headers: H(key) });
    if (!r.ok) throw new Error(`GET ${table} ${r.status}: ${await r.text()}`);
    const b = await r.json(); rows.push(...b); if (b.length < step) break;
  }
  return rows;
}
async function upsert(base, key, table, onConflict, rows) {
  for (let i = 0; i < rows.length; i += 500) {
    const q = onConflict ? `?on_conflict=${onConflict}` : '';
    const r = await fetch(`${base}/rest/v1/${table}${q}`, { method: 'POST', headers: { ...H(key), Prefer: 'resolution=merge-duplicates,return=minimal' }, body: JSON.stringify(rows.slice(i, i + 500)) });
    if (!r.ok) throw new Error(`POST ${table} ${r.status}: ${await r.text()}`);
  }
}
async function patchById(base, key, table, id, row) {
  const r = await fetch(`${base}/rest/v1/${table}?id=eq.${id}`, { method: 'PATCH', headers: { ...H(key), Prefer: 'return=minimal' }, body: JSON.stringify(row) });
  if (!r.ok) throw new Error(`PATCH ${table} ${r.status}: ${await r.text()}`);
}
(async () => {
  // catalog_products
  const cat = await getAll(PROD_SUPABASE_URL, PROD_SUPABASE_SERVICE_ROLE_KEY, 'catalog_products');
  await upsert(DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY, 'catalog_products', 'shopify_product_id', cat.map(stripId));
  console.log(`catalog_products: ${cat.length} upserted (on shopify_product_id)`);
  // public_events
  const ekey = (e) => `${(e.event_name || '').toLowerCase()}|${e.event_date}|${(e.city || '').toLowerCase()}`;
  const pEvents = await getAll(PROD_SUPABASE_URL, PROD_SUPABASE_SERVICE_ROLE_KEY, 'public_events');
  const dEvents = await getAll(DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY, 'public_events', 'id,event_name,event_date,city');
  const dmap = new Map(dEvents.map(e => [ekey(e), e.id]));
  const inserts = []; let updated = 0;
  for (const e of pEvents) {
    const did = dmap.get(ekey(e));
    if (did) { await patchById(DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY, 'public_events', did, stripId(e)); updated++; }
    else inserts.push(stripId(e));
  }
  await upsert(DEV_SUPABASE_URL, DEV_SUPABASE_SERVICE_ROLE_KEY, 'public_events', null, inserts);
  console.log(`public_events: ${updated} updated, ${inserts.length} inserted`);
  console.log('prod -> dev sync complete');
})().catch(e => { console.error(e.message || e); process.exit(1); });
