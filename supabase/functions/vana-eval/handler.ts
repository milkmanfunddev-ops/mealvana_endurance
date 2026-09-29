/**
 * The vana-eval request handler (eval-v2 ticket 02), built with its clients injected so the seam tests
 * (tests/vana/vana_eval.test.ts) run this exact code against fakes. index.ts wires the real ones.
 *
 * POST /functions/v1/vana-eval       Auth: an admin's Supabase JWT (`public.users.is_admin`). DEV ONLY.
 *   {action:'start', snapshot}       → 200 {run_user_id, before}
 *       Creates a throwaway auth user, seeds it from the Eval athlete snapshot (copy.ts), and returns the copy as
 *       seeded. Sweeps stale copies first.
 *   {action:'turn', run_user_id, message? | opener:true, conversation_id?, kind?, anchor_date?, timezone?, overrides?}
 *       → application/x-ndjson: runChat's own lines as they stream (text, ui, status, done, error), then one
 *       {type:'trace', conversation_id, persisted, trace} line built from runChat's onTrace seam, never from
 *       partsFromSteps, which keeps only the names of data tools. `trace` is the TurnTrace with each step's tool
 *       calls, full tool results and errors, usage and gateway generation id. The trace line goes out after the
 *       turn's rows are stored (`persisted`), so the next turn's history holds this one. `persisted: false` means
 *       they were not stored within PERSIST_WAIT_MS: the caller treats the turn as failed and sends no next turn.
 *       Pre-stream: 400 {error:'bad_override'} as runChat returns it · 404 {error:'no_copy'}.
 *   {action:'end', run_user_id}      → 200 {before, after}. Deletes the copy.
 *   {action:'sweep'}                 → 200 {deleted}: copies older than COPY_MAX_AGE_MS, left by a Run that died,
 *       including an auth user marked as a copy whose vana_eval_run_users row was never written.
 *   401 {error:'unauthenticated'} · 403 {error:'admin_required'} before anything else happens.
 *
 * Vana runs as the copy with `persist` on, so history and tools work as they do in the app. There is no Pro
 * check and no budget draw: the copy has neither and the caller is an admin. runChat records each turn's cost in
 * `ai_usage` under the copy; when the copy is removed those rows move to the admin who started the Run, so the
 * cost stays on record once and is never counted twice.
 */
import { runChat, type ChatBody, type TurnTrace, type VanaOverrides } from '../_shared/vana/chat.ts';
import { isAdmin } from '../_shared/vana/entitlement.ts';
import { ndjsonHeaders } from '../_shared/vana/stream.ts';
import { jsonResponse as json } from '../_shared/responses.ts';
import type { Db, VanaCtx } from '../_shared/vana/env.ts';
import { BadSnapshotError, COPY_MAX_AGE_MS, parseSnapshot, readCopy, removeCopyRows, seedCopy, type AthleteSnapshot } from './copy.ts';

/** The auth admin, as far as copies need it. */
export interface CopyAuth {
  /** Creates a confirmed user marked as a vana-eval copy; returns its id. */
  create: (email: string, password: string) => Promise<string>;
  /** A session for the copy; returns its access token. */
  signIn: (email: string, password: string) => Promise<string>;
  remove: (userId: string) => Promise<void>;
  /** Users marked as copies that were created before `beforeIso`: the sweep's backstop for a copy whose
   *  vana_eval_run_users row was never written. */
  listStale: (beforeIso: string) => Promise<string[]>;
}

/** A live copy, as vana_eval_run_users records it. */
interface RunUser { user_id: string; email: string; created_by: string; before: AthleteSnapshot | null }

export interface VanaEvalDeps {
  /** The caller's user id from the Authorization header, or null when it names no user. */
  caller: (req: Request) => Promise<string | null>;
  /** The service-role client. */
  admin: Db;
  auth: CopyAuth;
  /** Keys the copies' passwords. The service role key in production: a password is never stored or sent. */
  secret: string;
  /** Vana's context for the copy: its own JWT client, so RLS applies as it does in the app. */
  ctxFor: (userId: string, token: string) => VanaCtx;
  now: () => number;
}

/** How long a turn waits for its rows to be stored before the trace goes out without them. */
const PERSIST_WAIT_MS = 30_000;
const MAX_MESSAGE_LENGTH = 4000;

const enc = new TextEncoder();

async function copyPassword(secret: string, email: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(`vana-eval:${email}`)));
  return Array.from(mac, (b) => b.toString(16).padStart(2, '0')).join('');
}

/** A resolved-or-timed-out wait: true when `p` settled in time. */
const within = (p: Promise<unknown>, ms: number) => {
  let timer: number | undefined;
  return Promise.race([p.then(() => true), new Promise<boolean>((r) => { timer = setTimeout(() => r(false), ms); })]).finally(() => clearTimeout(timer));
};

/** One step as the trace carries it: what the model said, every tool call with its input, every result with its
 *  full output and the compact form the model was sent (`modelOutput`, from `toModelOutput`), every tool error, the
 *  usage, and the gateway generation id to look its cost up by. */
// deno-lint-ignore no-explicit-any
function traceStep(s: any) {
  // deno-lint-ignore no-explicit-any
  const content = (s.content ?? []) as any[];
  // What the SDK sent the model for each result, by call id: the tool messages among the step's response messages.
  const sent = new Map<string, unknown>();
  // deno-lint-ignore no-explicit-any
  for (const m of (s.response?.messages ?? []) as any[]) {
    if (m.role !== 'tool' || !Array.isArray(m.content)) continue;
    for (const p of m.content) if (p.type === 'tool-result') sent.set(p.toolCallId, p.output);
  }
  return {
    text: s.text ?? '',
    reasoningText: s.reasoningText ?? null,
    // deno-lint-ignore no-explicit-any
    toolCalls: (s.toolCalls ?? []).map((c: any) => ({ toolCallId: c.toolCallId, toolName: c.toolName, input: c.input })),
    // deno-lint-ignore no-explicit-any
    toolResults: (s.toolResults ?? []).map((r: any) => ({ toolCallId: r.toolCallId, toolName: r.toolName, input: r.input, output: r.output, modelOutput: sent.get(r.toolCallId) ?? null })),
    toolErrors: content.filter((p) => p.type === 'tool-error').map((p) => ({ toolCallId: p.toolCallId, toolName: p.toolName, input: p.input, error: String(p.error?.message ?? p.error) })),
    finishReason: s.finishReason ?? null,
    usage: s.usage ?? null,
    generationId: s.providerMetadata?.gateway?.generationId ?? null,
    providerMetadata: s.providerMetadata ?? null,
    modelId: s.response?.modelId ?? null,
  };
}

export function makeVanaEvalHandler(deps: VanaEvalDeps) {
  const { admin, auth } = deps;

  async function runUser(userId: unknown): Promise<RunUser | null> {
    if (typeof userId !== 'string' || !userId) return null;
    const { data, error } = await admin.from('vana_eval_run_users').select('user_id, email, created_by, before').eq('user_id', userId).maybeSingle();
    if (error) throw new Error(`reading vana_eval_run_users: ${error.message}`);
    return data as RunUser | null;
  }

  /** The copy's rows, children first; its cost rows handed to the admin who started the Run (when known); then
   *  the auth user, which cascades the rest (call log, wallet); then its vana_eval_run_users row, which the
   *  cascade also takes, deleted by name so the removal does not depend on the foreign key. */
  async function removeCopy(userId: string, createdBy?: string) {
    await removeCopyRows(admin, userId);
    if (createdBy) {
      const { error } = await admin.from('ai_usage').update({ user_id: createdBy }).eq('user_id', userId);
      if (error) throw new Error(`keeping the copy's cost: ${error.message}`);
    }
    await auth.remove(userId);
    const { error } = await admin.from('vana_eval_run_users').delete().eq('user_id', userId);
    if (error) throw new Error(`removing the vana_eval_run_users row: ${error.message}`);
  }

  async function sweep(): Promise<string[]> {
    const cutoff = new Date(deps.now() - COPY_MAX_AGE_MS).toISOString();
    const { data, error } = await admin.from('vana_eval_run_users').select('user_id, created_by').lt('created_at', cutoff);
    if (error) throw new Error(`reading vana_eval_run_users: ${error.message}`);
    const stale = new Map(((data ?? []) as { user_id: string; created_by: string }[]).map((r) => [r.user_id, r.created_by as string | undefined]));
    for (const id of await auth.listStale(cutoff)) if (!stale.has(id)) stale.set(id, undefined);
    const deleted: string[] = [];
    for (const [id, createdBy] of stale) {
      try { await removeCopy(id, createdBy); deleted.push(id); } catch (e) { console.error(`[vana-eval] sweep could not remove ${id}:`, (e as Error).message); }
    }
    return deleted;
  }

  async function start(callerId: string, raw: unknown): Promise<Response> {
    let snapshot: AthleteSnapshot;
    try { snapshot = parseSnapshot(raw); } catch (e) { if (e instanceof BadSnapshotError) return json({ error: 'bad_snapshot', details: e.message }, 400); throw e; }
    try { await sweep(); } catch (e) { console.error('[vana-eval] sweep failed:', (e as Error).message); }
    const email = `vana-eval+${crypto.randomUUID()}@eval.mealvana.invalid`;
    const userId = await auth.create(email, await copyPassword(deps.secret, email));
    try {
      const { error } = await admin.from('vana_eval_run_users').insert({ user_id: userId, email, source_user_id: snapshot.user_id, created_by: callerId, created_at: new Date(deps.now()).toISOString() });
      if (error) throw new Error(`recording the copy: ${error.message}`);
      await seedCopy(admin, snapshot, userId, email);
      const before = await readCopy(admin, userId);
      const { error: beforeError } = await admin.from('vana_eval_run_users').update({ before }).eq('user_id', userId);
      if (beforeError) throw new Error(`recording the before snapshot: ${beforeError.message}`);
      return json({ run_user_id: userId, before });
    } catch (e) {
      // A copy that could not be seeded is removed at once; the sweep is the backstop if this fails too.
      await removeCopy(userId, callerId).catch((err) => console.error(`[vana-eval] could not remove failed copy ${userId}:`, (err as Error).message));
      return json({ error: 'seed_failed', details: (e as Error).message }, 500);
    }
  }

  async function turn(body: Record<string, unknown>): Promise<Response> {
    const copy = await runUser(body.run_user_id);
    if (!copy) return json({ error: 'no_copy' }, 404);
    if (body.message != null && (typeof body.message !== 'string' || body.message.length > MAX_MESSAGE_LENGTH)) return json({ error: 'invalid_body', details: `message must be a string of at most ${MAX_MESSAGE_LENGTH} characters` }, 400);
    const token = await auth.signIn(copy.email, await copyPassword(deps.secret, copy.email));
    const v = deps.ctxFor(copy.user_id, token);

    let trace: TurnTrace | null = null;
    let settle!: () => void;
    const persisted = new Promise<void>((r) => { settle = r; });
    const chatBody: ChatBody = { message: body.message as string | undefined, opener: body.opener === true, conversation_id: (body.conversation_id as string | undefined) ?? null, kind: body.kind as string | undefined, anchor_date: body.anchor_date as string | undefined, timezone: body.timezone as string | undefined, new_plan: body.new_plan === true, situation: (body.situation ?? null) as ChatBody['situation'], moment: body.moment };
    const run = await runChat(v, chatBody, {
      functionName: 'vana-eval',
      overrides: (body.overrides ?? undefined) as VanaOverrides | undefined,
      onTrace: (t) => { trace = t; },
      // The last thing runChat's persistence task does, so the turn's rows are stored when it runs.
      afterFinish: () => { settle(); return Promise.resolve(); },
      onFailure: () => { settle(); return Promise.resolve(); },
      debited: false,
    });
    if (!run.ok) return json(run.body, run.status);

    const conversationId = run.response.headers.get('x-conversation-id') ?? '';
    const upstream = run.response.body!;
    const stream = new ReadableStream<Uint8Array>({
      async start(controller) {
        const reader = upstream.getReader();
        try {
          for (;;) { const { done, value } = await reader.read(); if (done) break; controller.enqueue(value); }
        } catch (e) {
          controller.enqueue(enc.encode(JSON.stringify({ type: 'error', message: (e as Error).message }) + '\n'));
        }
        const stored = await within(persisted, PERSIST_WAIT_MS);
        const t = trace as TurnTrace | null;
        const payload = t ? { ...t, steps: (t.steps ?? []).map(traceStep) } : null;
        controller.enqueue(enc.encode(JSON.stringify({ type: 'trace', conversation_id: conversationId, persisted: stored, trace: payload }) + '\n'));
        controller.close();
      },
    });
    return new Response(stream, { status: 200, headers: ndjsonHeaders({ 'x-conversation-id': conversationId }) });
  }

  async function end(body: Record<string, unknown>): Promise<Response> {
    const copy = await runUser(body.run_user_id);
    if (!copy) return json({ error: 'no_copy' }, 404);
    const after = await readCopy(admin, copy.user_id);
    await removeCopy(copy.user_id, copy.created_by);
    return json({ before: copy.before, after });
  }

  return async function handle(req: Request): Promise<Response> {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    const callerId = await deps.caller(req);
    if (!callerId) return json({ error: 'unauthenticated' }, 401);
    if (!(await isAdmin(admin, callerId))) return json({ error: 'admin_required' }, 403);
    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return json({ error: 'invalid_body' }, 400); }
    if (!body || typeof body !== 'object') return json({ error: 'invalid_body' }, 400);
    try {
      switch (body.action) {
        case 'start': return await start(callerId, body.snapshot);
        case 'turn': return await turn(body);
        case 'end': return await end(body);
        case 'sweep': return json({ deleted: await sweep() });
        default: return json({ error: 'invalid_body', details: "action must be 'start', 'turn', 'end' or 'sweep'" }, 400);
      }
    } catch (e) {
      console.error('[vana-eval] failed:', e);
      return json({ error: 'server_error', details: (e as Error).message }, 500);
    }
  };
}
