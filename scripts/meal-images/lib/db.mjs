// Minimal PostgREST client for the meal-image scripts. Dev-only by default:
// the project ref is asserted so a stray env var can never point these
// bulk writes at prod.
import { readFileSync } from 'node:fs';

const DEV_REF = 'vlmtsdzpnjnavdgytcmi';

function devKey() {
  if (process.env.SUPABASE_DEV_SERVICE_ROLE_KEY) return process.env.SUPABASE_DEV_SERVICE_ROLE_KEY;
  const md = readFileSync(new URL('../../../secrets/supabase_service_role_keys.md', import.meta.url), 'utf8');
  const dev = md.split(/^##\s+/m).find((s) => s.includes(DEV_REF));
  const key = dev && dev.match(/eyJ[A-Za-z0-9._-]+/);
  if (!key) throw new Error('dev service-role key not found in secrets/supabase_service_role_keys.md');
  return key[0];
}

export const REF = DEV_REF;
export const BASE = `https://${DEV_REF}.supabase.co`;
export const KEY = devKey();

/**
 * One PostgREST call, retried on transient failures.
 *
 * Supabase returns the occasional 502/503/504 under load, and an unretried
 * write is enough to kill a long batch job: a single `504 Gateway Timeout` on
 * one PATCH ended a 516-tile vision run at tile 88 on 2026-09-08.
 */
export async function rest(path, init = {}, tries = 4) {
  let last;
  for (let i = 0; i < tries; i++) {
    try {
      return await restOnce(path, init);
    } catch (e) {
      last = e;
      const transient = /-> (408|429|5\d\d)\b/.test(e.message) || /fetch failed|timeout|network/i.test(e.message);
      if (!transient || i === tries - 1) throw e;
      await new Promise((r) => setTimeout(r, 500 * 2 ** i));
    }
  }
  throw last;
}

async function restOnce(path, init = {}) {
  const res = await fetch(`${BASE}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: KEY, Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json', ...(init.headers || {}),
    },
  });
  if (!res.ok) throw new Error(`${init.method || 'GET'} ${path} -> ${res.status} ${await res.text()}`);
  const body = await res.text();
  return body ? JSON.parse(body) : null;
}

/** Page through a table so we are never capped by PostgREST's row limit. */
export async function selectAll(table, query, pageSize = 1000) {
  const out = [];
  for (let from = 0; ; from += pageSize) {
    const res = await fetch(`${BASE}/rest/v1/${table}?${query}`, {
      headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, Range: `${from}-${from + pageSize - 1}` },
    });
    if (!res.ok) throw new Error(`select ${table} -> ${res.status} ${await res.text()}`);
    const rows = await res.json();
    out.push(...rows);
    if (rows.length < pageSize) return out;
  }
}

export async function upsert(table, rows, onConflict = 'id', chunk = 500) {
  for (let i = 0; i < rows.length; i += chunk) {
    await rest(`${table}?on_conflict=${onConflict}`, {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
      body: JSON.stringify(rows.slice(i, i + chunk)),
    });
  }
}

/**
 * Update many existing rows by primary key.
 *
 * A PostgREST upsert cannot be used for this: it is an INSERT with an
 * ON CONFLICT clause, so a partial payload trips the NOT NULL constraints on
 * every column we did not send. PATCH-by-id touches only the given columns.
 */
export async function updateMany(table, rows, { key = 'id', concurrency = 10 } = {}) {
  const queue = [...rows];
  let done = 0;
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (queue.length) {
      const row = queue.shift();
      const { [key]: id, ...patch } = row;
      await rest(`${table}?${key}=eq.${encodeURIComponent(id)}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify(patch),
      });
      done++;
    }
  }));
  return done;
}

export async function uploadImage(bucket, path, bytes, contentType) {
  const res = await fetch(`${BASE}/storage/v1/object/${bucket}/${path}`, {
    method: 'POST',
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': contentType, 'x-upsert': 'true' },
    body: bytes,
  });
  if (!res.ok) throw new Error(`upload ${path} -> ${res.status} ${await res.text()}`);
  return `${BASE}/storage/v1/object/public/${bucket}/${path}`;
}
