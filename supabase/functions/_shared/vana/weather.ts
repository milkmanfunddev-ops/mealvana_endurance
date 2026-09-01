/** Open-Meteo (no key). Cached per (date, lat, lon) in-isolate. */
type Cached = { at: number; summary: string };
const cache = new Map<string, Cached>();
const geo = new Map<string, { lat: number; lon: number; name: string } | null>();

export async function geocode(place: string) {
  if (geo.has(place)) return geo.get(place)!;
  try {
    const r = await fetch(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(place)}&count=1&language=en&format=json`, { signal: AbortSignal.timeout(5_000) });
    const j = (await r.json()) as { results?: { latitude: number; longitude: number; name: string; admin1?: string }[] };
    const hit = j.results?.[0];
    const out = hit ? { lat: hit.latitude, lon: hit.longitude, name: [hit.name, hit.admin1].filter(Boolean).join(', ') } : null;
    geo.set(place, out); return out;
  } catch { geo.set(place, null); return null; }
}

/** One line: "Panama City, FL · 91°F, humid, 20% rain" for a given ISO date (≤16 days out). */
export async function weatherLine(place: string | null, dateIso: string): Promise<string | null> {
  if (!place) return null;
  const g = await geocode(place); if (!g) return null;
  const key = `${dateIso}|${g.lat.toFixed(2)}|${g.lon.toFixed(2)}`;
  const c = cache.get(key); if (c && Date.now() - c.at < 6 * 3600_000) return c.summary;
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${g.lat}&longitude=${g.lon}&daily=temperature_2m_max,relative_humidity_2m_mean,precipitation_probability_max&temperature_unit=fahrenheit&timezone=auto&start_date=${dateIso}&end_date=${dateIso}`;
    const r = await fetch(url, { signal: AbortSignal.timeout(5_000) }); const j = (await r.json()) as { daily?: { temperature_2m_max?: number[]; relative_humidity_2m_mean?: number[]; precipitation_probability_max?: number[] } };
    const t = j.daily?.temperature_2m_max?.[0]; const h = j.daily?.relative_humidity_2m_mean?.[0]; const p = j.daily?.precipitation_probability_max?.[0];
    if (t == null) return null;
    const summary = `${g.name} · ${Math.round(t)}°F${h != null && h >= 70 ? ', humid' : ''}${p != null ? `, ${Math.round(p)}% rain` : ''}`;
    cache.set(key, { at: Date.now(), summary }); return summary;
  } catch { return null; }
}
