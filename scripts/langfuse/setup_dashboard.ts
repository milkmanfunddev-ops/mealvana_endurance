/**
 * Sets the ten widgets of the "Vana" dashboard in Langfuse to the definitions below (langfuse ticket 20).
 *
 * The widgets were first made before any Trace existed. Each definition here was checked against real dev Traces.
 * A widget is found by its name (or the name it had before) and updated in place, so its place on the dashboard is
 * kept; one that is missing is created and must then be placed on the dashboard by hand. Running this again changes
 * nothing. After updating, each widget's query is run over the last 30 days and its row count printed, so a widget
 * that matches nothing is seen at once.
 *
 * Alerts are not set here: Langfuse has no public API that creates one. The two Hobby alerts are described in
 * `.scratch/langfuse/issues/20-the-vana-dashboard-matches-real-traces-with-alerts.md`.
 *
 * Run from the repo root:
 *   deno run --allow-read --allow-net scripts/langfuse/setup_dashboard.ts
 * Keys are read from `secrets/langfuse.env`. Hobby allows 30 API requests a minute, so the script waits between calls.
 */
type Filter = { column: string; operator: string; value: unknown; type: string };
interface Widget {
  name: string; was?: string; description: string; view: string; chartType: string;
  dimensions: string[]; metrics: [measure: string, agg: string][]; filters: Filter[]; chartConfig?: Record<string, unknown>;
}

/** Cost and model live on Generations. Without this every span and Tool call adds a blank-model row. */
const GENERATIONS: Filter = { column: 'type', operator: '=', value: 'GENERATION', type: 'string' };
/** One row per Trace: the root observation, whose latency is what the athlete waited. */
const ROOTS: Filter = { column: 'isRootObservation', operator: '=', value: true, type: 'boolean' };
const named = (column: string): Filter => ({ column, operator: 'is not empty', value: '', type: 'string' });

const WIDGETS: Widget[] = [
  { name: 'Spend per day by model', description: 'What the Gateway charged each day, split by model.', view: 'observations', chartType: 'AREA_TIME_SERIES',
    dimensions: ['providedModelName'], metrics: [['totalCost', 'sum']], filters: [GENERATIONS] },
  { name: 'Top athletes by spend', description: 'The ten athletes who cost the most in the selected period. Calls that carry no athlete (the eval app\'s simulated athlete) are left out.', view: 'observations', chartType: 'HORIZONTAL_BAR',
    dimensions: ['userId'], metrics: [['totalCost', 'sum']], filters: [GENERATIONS, named('userId')], chartConfig: { type: 'HORIZONTAL_BAR', row_limit: 10 } },
  { name: 'Spend by entry point', description: 'Cost by Trace name: vana-turn (chat), describe-meal, analyze-meal-photo and the vana-* background calls. Calls with no Trace name (the eval app\'s simulated athlete) are left out.', view: 'observations', chartType: 'HORIZONTAL_BAR',
    dimensions: ['traceName'], metrics: [['totalCost', 'sum']], filters: [GENERATIONS, named('traceName')] },
  { name: 'Model calls per day', was: 'Observations per day', description: 'How many model calls ran each day, by environment. The evaluators\' own calls show under Langfuse\'s environments.', view: 'observations', chartType: 'BAR_TIME_SERIES',
    dimensions: ['environment'], metrics: [['count', 'count']], filters: [GENERATIONS] },
  { name: 'Latency p95 by entry point', description: '95th percentile of the whole Trace, per day: a chat Turn from message to finished reply.', view: 'observations', chartType: 'LINE_TIME_SERIES',
    dimensions: ['traceName'], metrics: [['latency', 'p95']], filters: [ROOTS] },
  { name: 'Time to first token p95', description: 'How long athletes wait before Vana starts replying. Chat only: the other calls do not stream.', view: 'observations', chartType: 'LINE_TIME_SERIES',
    dimensions: ['providedModelName'], metrics: [['timeToFirstToken', 'p95']], filters: [GENERATIONS, { column: 'traceName', operator: '=', value: 'vana-turn', type: 'string' }] },
  { name: 'Spend by prompt version', description: 'Cost and call count for each prompt version. A chat Turn counts under the persona section its kind leads with. The blank row is calls that link to no version: the bundled copy ran, or the call has no prompt in Langfuse. (A widget cannot filter on the prompt name.)', view: 'observations', chartType: 'PIVOT_TABLE',
    dimensions: ['promptName', 'promptVersion'], metrics: [['totalCost', 'sum'], ['count', 'count']], filters: [GENERATIONS] },
  { name: 'Errors per day', description: 'Failed observations per day, by Trace name: a failed Turn, call or Tool.', view: 'observations', chartType: 'BAR_TIME_SERIES',
    dimensions: ['traceName'], metrics: [['count', 'count']], filters: [{ column: 'level', operator: '=', value: 'ERROR', type: 'string' }] },
  { name: 'Evaluator pass rate', description: 'Share of yes answers per yes/no Score per day. For a flag evaluator yes means flagged; for plan_confirmed it means the plan was confirmed.', view: 'scores-boolean', chartType: 'LINE_TIME_SERIES',
    dimensions: ['name'], metrics: [['value', 'avg']], filters: [] },
  { name: 'Scores recorded', description: 'How many Scores each evaluator or reviewer recorded per day.', view: 'scores-boolean', chartType: 'BAR_TIME_SERIES',
    dimensions: ['name'], metrics: [['count', 'count']], filters: [] },
];

const env = Object.fromEntries((await Deno.readTextFile('secrets/langfuse.env')).split('\n')
  .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/)).filter((m): m is RegExpMatchArray => !!m).map((m) => [m[1], m[2]]));
const base = env.LANGFUSE_BASE_URL ?? 'https://us.cloud.langfuse.com';
const headers = { Authorization: `Basic ${btoa(`${env.LANGFUSE_PUBLIC_KEY}:${env.LANGFUSE_SECRET_KEY}`)}`, 'Content-Type': 'application/json' };
const pause = () => new Promise((r) => setTimeout(r, 2_200));
async function api(method: string, path: string, body?: unknown) {
  const r = await fetch(`${base}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  await pause();
  if (!r.ok) throw new Error(`${method} ${path.slice(0, 80)} answered HTTP ${r.status}: ${text.slice(0, 400)}`);
  return JSON.parse(text);
}

const existing = (await api('GET', '/api/public/unstable/dashboard-widgets?limit=100')).data as { id: string; name: string }[];
const now = new Date(); const from = new Date(now.getTime() - 30 * 86_400_000);
for (const w of WIDGETS) {
  const body = {
    name: w.name, description: w.description, view: w.view, chartType: w.chartType, chartConfig: w.chartConfig ?? { type: w.chartType },
    dimensions: w.dimensions.map((field) => ({ field })), metrics: w.metrics.map(([measure, agg]) => ({ measure, agg })), filters: w.filters,
  };
  const held = existing.find((e) => e.name === w.name || e.name === w.was);
  if (held) await api('PATCH', `/api/public/unstable/dashboard-widgets/${held.id}`, body);
  else await api('POST', '/api/public/unstable/dashboard-widgets', body);
  const highCardinality = w.dimensions.includes('userId');
  const query = {
    view: w.view, dimensions: body.dimensions, metrics: w.metrics.map(([measure, aggregation]) => ({ measure, aggregation })), filters: w.filters,
    fromTimestamp: from.toISOString(), toTimestamp: now.toISOString(),
    ...(highCardinality ? { config: { row_limit: 10 }, orderBy: [{ field: `${w.metrics[0][1]}_${w.metrics[0][0]}`, direction: 'desc' }] } : {}),
  };
  const rows = (await api('GET', `/api/public/v2/metrics?query=${encodeURIComponent(JSON.stringify(query))}`)).data as Record<string, unknown>[];
  console.log(`${held ? 'updated' : 'CREATED (place it on the dashboard)'}  ${w.name}: ${rows.length} rows${rows.length ? `, e.g. ${JSON.stringify(rows[0])}` : ''}`);
}
