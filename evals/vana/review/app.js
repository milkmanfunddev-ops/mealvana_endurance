/* Vana trace review app — one trace at a time, Pass/Fail/Defer + notes, autosaved to the local server.
 * Data: GET /traces.json (sampled rows; payload = TurnTrace + ndjson). Labels: GET/POST /labels. */
'use strict';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pretty = (o) => esc(JSON.stringify(o, null, 2));
const $ = (id) => document.getElementById(id);

let traces = [], labels = {}, i = 0, noteTimer = null, lastAction = null;

// ---------------------------------------------------------------- Vana part rendering (what the app drew)
const mealRow = (m) => `<tr><td><b>${esc(m.name)}</b><div class="why">${esc(m.why ?? '')}</div></td><td>${esc(m.mealType ?? '')}</td><td>${m.kcal ?? '–'}</td><td>${m.carbsG ?? '–'}C/${m.proteinG ?? '–'}P</td><td>${m.prepMinutes != null ? m.prepMinutes + 'm' : '–'}</td></tr>`;

function renderPart(p) {
  if (!p || typeof p !== 'object') return '';
  const head = (t) => `<div class="kind">${t ?? p.kind}</div>`;
  switch (p.kind) {
    case 'meal_picker':
      return `<div class="part">${head(`picker · ${esc(p.title)}`)}<table class="meals"><tr><th>meal</th><th>type</th><th>kcal</th><th>macros</th><th>prep</th></tr>${(p.meals ?? []).map(mealRow).join('')}</table>${(p.chips ?? []).length ? `<div class="pills">${p.chips.map((c) => `<span class="pill chip">${esc(c)}</span>`).join('')}</div>` : ''}${p.more?.length ? `<div class="why">+${p.more.length} behind “Show more”</div>` : ''}</div>`;
    case 'choices':
      return `<div class="part">${head('question')}${p.question ? `<div><b>${esc(p.question)}</b></div>` : ''}<div class="pills">${(p.options ?? []).map((o) => `<span class="pill">${esc(o)}</span>`).join('')}</div></div>`;
    case 'batch': {
      const plan = p.plan ?? {};
      return `<div class="part">${head(`plan · ${esc(plan.status)} · ${esc(plan.weekStart)} · batch ${plan.batchCooking ? 'on' : 'off'}`)}<table class="meals"><tr><th>meal</th><th>type</th><th>servings</th><th>macros</th><th></th></tr>${(plan.meals ?? []).map((m) => `<tr><td><b>${esc(m.name)}</b></td><td>${esc(m.mealType)}</td><td>${m.servings} (${m.servingsLeft} left)</td><td>${m.kcal ?? '–'}kcal ${m.carbsG ?? '–'}C</td><td>${(m.swaps ?? []).join(', ')}</td></tr>`).join('')}</table></div>`;
    }
    case 'shopping_list':
      return `<div class="part">${head(`shopping list · ${p.itemCount} to buy`)}${(p.skipped ?? []).length ? `<div class="why">already have: ${p.skipped.map(esc).join(', ')}</div>` : ''}<ul class="list">${(p.items ?? []).filter((x) => !x.have).slice(0, 40).map((x) => `<li>${esc(x.name)}${x.qty ? ` · ${esc(x.qty)}` : ''} <span class="why">${esc(x.aisle ?? '')}</span></li>`).join('')}</ul></div>`;
    case 'hand_off':
      return `<div class="part">${head('hand-off')}<div class="pills"><span class="pill chip">→ ${esc(p.label)} (${esc(p.target)})</span></div></div>`;
    case 'day_guidance':
      return `<div class="part">${head(`day guidance · ${esc(p.date)} · ${esc(p.label)}`)}<div>${esc(p.note ?? '')}</div>${(p.suggestions ?? []).length ? `<table class="meals"><tr><th>suggested</th><th>type</th><th>kcal</th><th>macros</th><th>prep</th></tr>${p.suggestions.map(mealRow).join('')}</table>` : ''}</div>`;
    case 'staples':
      return `<div class="part">${head('staples')}<table class="meals"><tr><th>meal</th><th>type</th><th>logged</th><th>kcal</th><th>macros</th><th></th></tr>${(p.meals ?? []).map((m) => `<tr><td><b>${esc(m.name)}</b><div class="why">${esc(m.why ?? '')}</div></td><td>${esc(m.mealType)}</td><td>${m.timesLogged}×</td><td>${m.kcal ?? '–'}</td><td>${m.carbsG ?? '–'}C/${m.proteinG ?? '–'}P</td><td>${m.ticked ? '✓' : ''}</td></tr>`).join('')}</table></div>`;
    case 'week':
      return `<div class="part">${head('week laid out')}<table class="meals"><tr><th>date</th><th>label</th><th>breakfast</th><th>lunch</th><th>dinner</th><th>snack</th></tr>${(p.days ?? []).map((d) => `<tr><td>${esc(d.date)}</td><td>${esc(d.label)}</td><td>${esc(d.slots?.breakfast?.name ?? '–')}</td><td>${esc(d.slots?.lunch?.name ?? '–')}</td><td>${esc(d.slots?.dinner?.name ?? '–')}</td><td>${esc(d.slots?.snack?.name ?? '–')}</td></tr>`).join('')}</table></div>`;
    case 'day':
      return `<div class="part">${head(`day · ${esc(p.date)} · ${esc(p.label)}`)}<div class="kv">${Object.entries(p.slots ?? {}).map(([k, v]) => `<div>${k}</div><div>${esc(v?.name ?? '–')}</div>`).join('')}</div></div>`;
    case 'debrief':
      return `<div class="part">${head('debrief recorded')}<div class="kv"><div>completed</div><div>${p.completed} of ${p.planned}</div>${p.skipReason ? `<div>skip reason</div><div>${esc(p.skipReason)}</div>` : ''}</div>${(p.memories ?? []).length ? `<div class="why">learnings kept: ${p.memories.map((m) => esc(m.fact)).join(' | ')}</div>` : ''}</div>`;
    case 'memory_saved':
      return `<div class="part">${head('memory saved')}<div>${esc(p.memory?.fact)}</div></div>`;
    case 'feedback_saved':
      return `<div class="part">${head('feedback saved')}<div>${esc(p.message)} <span class="why">(${esc(p.about)} · ${esc(p.sentiment)})</span></div></div>`;
    case 'logged':
      return `<div class="part">${head('logged')}<div>${esc(p.name)} — ${p.servingsLeft} serving(s) left</div></div>`;
    case 'rule':
      return `<div class="part">${head('rule proposed')}<div>${esc(p.rule?.day)}: ${esc(p.rule?.rule)}</div></div>`;
    case 'feedback_prompt':
      return `<div class="part">${head('feedback prompt (server-authored)')}<div class="why">“Give feedback for me here” — shown to a first-ever conversation</div></div>`;
    default:
      if (p.kind === 'receipt' || p.kind === 'needs_confirmation' || p.kind?.startsWith('receipt')) return `<div class="part">${head(p.kind)}<div class="kv">${Object.entries(p).filter(([k]) => k !== 'kind').slice(0, 8).map(([k, v]) => `<div>${esc(k)}</div><div>${esc(typeof v === 'object' ? JSON.stringify(v) : v)}</div>`).join('')}</div></div>`;
      return `<div class="part">${head(p.kind)}<pre>${pretty(p)}</pre></div>`;
  }
}

// ---------------------------------------------------------------- model messages (what the model read/replied)
function renderContentPart(p) {
  if (p.type === 'text') return `<div class="body">${esc(p.text)}</div>`;
  if (p.type === 'tool-call') return `<div class="part"><div class="kind">tool call · ${esc(p.toolName)}</div><pre>${pretty(p.input)}</pre></div>`;
  if (p.type === 'tool-result') return renderPart(p.output);
  return `<div class="part"><div class="kind">${esc(p.type)}</div><pre>${pretty(p)}</pre></div>`;
}
function renderModelMessage(m) {
  const body = typeof m.content === 'string' ? `<div class="body">${esc(m.content)}</div>` : (Array.isArray(m.content) ? m.content.map(renderContentPart).join('') : `<pre>${pretty(m.content)}</pre>`);
  if (m.role === 'user') return `<div class="userline">${typeof m.content === 'string' ? esc(m.content) : body}</div>`;
  return `<div class="msg"><div class="who">Vana</div>${body}</div>`;
}

// ---------------------------------------------------------------- one trace
function render(t) {
  const p = t.payload ?? {};
  const key = `${t.scenario_id}.${t.turn}`;
  const badges = [
    `<span class="badge task">${esc(t.task)}</span>`,
    `<span class="badge athlete">${esc(t.athlete)}</span>`,
    `<span class="badge char">${esc(t.character)}</span>`,
    t.payload?.kind === 'general' ? `<span class="badge">general chat</span>` : `<span class="badge">meal planning</span>`,
    `<span class="badge">${esc(t.model ?? '')}</span>`,
    t.error ? `<span class="badge err">error: ${esc(t.error)}</span>` : '',
  ].join('');
  const uiParts = (p.ndjson ?? []).filter((l) => l && typeof l === 'object' && l.type === 'ui' && l.part?.kind !== 'feedback_prompt').map((l) => renderPart(l.part));
  const streamedText = (p.ndjson ?? []).filter((l) => l && typeof l === 'object' && l.type === 'text').map((l) => l.delta).join('');

  $('trace').innerHTML = `
    <div class="badges">${badges} <span class="badge">${esc(key)}</span></div>
    <details><summary>System — persona (${esc((p.system?.persona ?? '').length)} chars, same for every athlete)</summary><div class="inner"><pre>${esc(p.system?.persona ?? '')}</pre></div></details>
    <details open><summary>System — the Doll (what Vana was told about this athlete)</summary><div class="inner"><pre>${esc(p.system?.context ?? '')}</pre></div></details>
    ${(p.modelMessages ?? []).map(renderModelMessage).join('')}
    <details open><summary>Model steps — raw text, tool inputs, results (${(p.steps ?? []).length} step${(p.steps ?? []).length === 1 ? '' : 's'})</summary><div class="inner">
      ${(p.steps ?? []).map((s, n) => `<div><b>step ${n + 1}</b>${Array.isArray(s.content) ? s.content.map((c) => c.type === 'text' ? `<div class="msg"><div class="who">Vana (raw)</div><div class="body">${esc(c.text)}</div></div>` : renderContentPart(c)).join('') : `<pre>${pretty(s)}</pre>`}</div>`).join('')}
    </div></details>
    ${uiParts.length ? `<h3 style="font-size:13px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em">What the app showed</h3>${uiParts.join('')}` : ''}
    ${streamedText && !uiParts.length ? `<div class="msg"><div class="who">Vana (streamed)</div><div class="body">${esc(streamedText)}</div></div>` : ''}
    <details><summary>Raw trace JSON</summary><div class="inner"><pre>${pretty(p)}</pre></div></details>`;

  const l = labels[key] ?? {};
  for (const [b, v] of [['b-pass', 'pass'], ['b-fail', 'fail'], ['b-defer', 'defer']]) $(b).classList.toggle('active', l.label === v);
  // Never clobber a note being typed: a label save re-renders, and the debounce hasn't fired yet.
  if (document.activeElement !== $('note')) $('note').value = l.note ?? '';
  $('counter').innerHTML = `<b>${i + 1}</b> of ${traces.length} · <b>${esc(key)}</b>`;
  const done = Object.keys(labels).filter((k) => labels[k]?.label).length;
  $('progress').textContent = `${done} labeled · ${traces.length - done} remaining`;
  $('meta').innerHTML = [
    ['run', t.run_id], ['tokens', `${t.input_tokens ?? '?'} in (${t.cache_read_tokens ?? 0} cache) / ${t.output_tokens ?? '?'} out`],
    ['duration', `${t.duration_ms ?? '?'} ms`], ['tools offered', (p.tools ?? []).length], ['context', p.contextReused ? 'reused (cached)' : 'built fresh'],
    ['situation', p.situation ? 'carried on the message' : 'none'],
  ].map(([k, v]) => `<div>${esc(k)}</div><div>${esc(v)}</div>`).join('');
}

// ---------------------------------------------------------------- labels + nav
const key = () => `${traces[i].scenario_id}.${traces[i].turn}`;
async function save(patch, k = key()) {
  lastAction = { key: k, prev: { ...(labels[k] ?? {}) } };
  labels[k] = { ...(labels[k] ?? {}), ...patch, at: new Date().toISOString() };
  $('saved').textContent = 'saving…';
  try {
    const res = await fetch('/labels', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ key: k, ...patch }) });
    if (!res.ok) throw new Error(`${res.status}`);
    $('saved').textContent = `saved ${new Date().toLocaleTimeString()}`;
  } catch { $('saved').textContent = 'SAVE FAILED — check the server'; }
  render(traces[i]);
}
const setLabel = (label) => save({ label });
const go = (n) => { i = Math.max(0, Math.min(traces.length - 1, n)); render(traces[i]); };
const next = () => go(i + 1);

async function boot() {
  [traces, labels] = await Promise.all([(await fetch('/traces.json')).json(), (await (fetch('/labels'))).json()]);
  traces.sort((a, b) => String(a.scenario_id).localeCompare(String(b.scenario_id)) || a.turn - b.turn);
  render(traces[0]);
  $('b-pass').onclick = () => setLabel('pass');
  $('b-fail').onclick = () => setLabel('fail');
  $('b-defer').onclick = () => setLabel('defer');
  $('b-prev').onclick = () => go(i - 1);
  $('b-next').onclick = next;
  $('b-jump').onclick = () => { const n = traces.findIndex((t) => `${t.scenario_id}.${t.turn}` === $('jump').value.trim()); if (n >= 0) go(n); else alert(`no trace ${$('jump').value}`); };
  // The key is captured when the debounce is armed: Cmd+Enter saves-and-navigates, and a stale timer must not
  // land the note on the next trace.
  $('note').oninput = () => { clearTimeout(noteTimer); const k = key(); noteTimer = setTimeout(() => save({ note: $('note').value }, k), 400); };
  document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'TEXTAREA' || e.target.tagName === 'INPUT') { if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') { save({ note: $('note').value }).then(next); } return; }
    if (e.key === 'ArrowRight') next();
    else if (e.key === 'ArrowLeft') go(i - 1);
    else if (e.key === '1') setLabel('pass');
    else if (e.key === '2') setLabel('fail');
    else if (e.key.toLowerCase() === 'd') setLabel('defer');
    else if (e.key.toLowerCase() === 'u' && lastAction) { labels[lastAction.key] = lastAction.prev; save(lastAction.prev); }
  });
}
boot();
