// Drawn pictures for screenless decisions: a small spec in, inline SVG out.
//
// A decision with no screen (a paywall rule, a sync rule, a window
// calculation) gets a plain diagram of its mechanism instead of a screenshot:
// boxes and arrows, or a timeline, plus one worked example with real numbers.
// Every colour is a page token (`var(--token, fallback)`), so the picture
// follows the page's light and dark themes and `svgCheck` in sync.mjs accepts
// it. No raster, no stock art.
//
// Spec shapes (JSON):
//   { kind: 'flow', title?, width?, rows: [[{id, label, tone?}], ...], edges: [{from, to, label?, tone?}], example?: [lines] }
//   { kind: 'timeline', title?, width?, steps: [{at, label, tone?}], example?: [lines] }
// `label` may hold `\n` for a second line. `tone` is one of ink (default),
// accent, ok, no, pending, amend, muted. `width` is a minimum in viewBox
// units (default 320); the drawing grows to fit its text. The page shows a picture about
// 320 px wide, so keep a flow to two or three boxes per row and labels
// short; a timeline runs down the page and takes longer labels.

// The page's tokens (index.html `:root`), with their light values as fallbacks so
// the file reads on its own in an editor. A token added to the page is added here.
const LIGHT = { ground: '#F8F6EB', 'ground-2': '#EFECDF', line: '#DDD8C8', ink: '#381633', 'ink-2': '#5E4A5C', muted: '#8A7A8C', accent: '#F78B14', 'accent-ink': '#2B1305', ok: '#2FB9A6', 'ok-soft': '#DDF5F0', no: '#DC2597', 'no-soft': '#FBE1EF', pending: '#D9730A', 'pending-soft': '#FDEBD9', amend: '#7A5AA6', 'amend-soft': '#EDE6F7', card: '#FFFFFF', focus: '#F78B14' };
export const TOKENS = Object.keys(LIGHT);
const v = t => `var(--${t}, ${LIGHT[t]})`;
const TONES = { ink: ['card', 'line'], accent: ['pending-soft', 'accent'], ok: ['ok-soft', 'ok'], no: ['no-soft', 'no'], pending: ['pending-soft', 'pending'], amend: ['amend-soft', 'amend'], muted: ['ground-2', 'muted'] };

const FONT = '"Source Sans 3", "Helvetica Neue", Arial, sans-serif';
const TITLE_FONT = 'Sansita, Georgia, serif';
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const lines = s => String(s ?? '').split('\n');
const textW = (s, size = 13) => Math.ceil(s.length * size * 0.54);

const STYLE = `svg.dg{font-family:${FONT};font-size:13px}svg.dg .dg-title{font-family:${TITLE_FONT};font-size:15px;font-weight:700;fill:${v('ink')}}svg.dg text{fill:${v('ink')}}svg.dg .dg-sub{fill:${v('ink-2')};font-size:12px}svg.dg .dg-muted{fill:${v('muted')};font-size:12px}svg.dg .dg-box{stroke-width:1.2}svg.dg .dg-edge{fill:none;stroke:${v('ink-2')};stroke-width:1.4}svg.dg .dg-axis{stroke:${v('line')};stroke-width:2}svg.dg .dg-ex{fill:${v('card')};stroke:${v('line')}}`;

function tone(name) {
  const t = TONES[name || 'ink'];
  if (!t) throw new Error(`unknown tone ${name}; use one of ${Object.keys(TONES).join(', ')}`);
  return { fill: v(t[0]), stroke: v(t[1]) };
}

function wrap(width, height, body, title) {
  const head = title ? `<text class="dg-title" x="16" y="24">${esc(title)}</text>` : '';
  // width 100% and no height: the page's `.fig svg {height:auto}` keeps the aspect ratio.
  return `<svg class="dg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="100%" role="img" aria-label="${esc(title || 'Diagram')}">\n<style>${STYLE}</style>\n<defs><marker id="dg-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="${v('ink-2')}"/></marker></defs>\n${head}${body}</svg>\n`;
}

// The worked example: a soft panel of one to three lines under the drawing.
function example(ex, width, y) {
  const ls = (ex || []).flatMap(lines).filter(Boolean);
  if (!ls.length) return { body: '', height: 0 };
  const h = 14 + ls.length * 18;
  const body = `<rect class="dg-ex" x="16" y="${y}" width="${width - 32}" height="${h}" rx="8"/>` +
    ls.map((l, i) => `<text class="dg-sub" x="28" y="${y + 22 + i * 18}">${esc(l)}</text>`).join('');
  return { body, height: h + 12 };
}

function flow(spec) {
  const rows = spec.rows || [];
  if (!rows.length) throw new Error('a flow needs rows of nodes');
  const nodes = new Map();
  const rowH = 96, top = spec.title ? 44 : 20, gap = 24;
  // A row wider than the page's picture box is wrapped onto extra rows, so the
  // text is not shrunk to fit; the boxes keep their order and the arrows follow.
  const MAX_ROW = 380;
  const boxes = [];
  for (const row of rows) {
    const sized = row.map(n => { const ls = lines(n.label); const w = Math.max(96, ...ls.map(l => textW(l) + 28)); const h = 20 + ls.length * 18; return { ...n, ls, w, h }; });
    let chunk = [], chunkW = 0;
    for (const n of sized) {
      if (chunk.length && chunkW + gap + n.w > MAX_ROW) { boxes.push({ sized: chunk, rowW: chunkW, r: boxes.length }); chunk = []; chunkW = 0; }
      chunkW += (chunk.length ? gap : 0) + n.w; chunk.push(n);
    }
    boxes.push({ sized: chunk, rowW: chunkW, r: boxes.length });
  }
  const width = Math.max(spec.width || 0, 320, ...boxes.map(b => b.rowW + 32), exampleWidth(spec.example));
  for (const { sized, rowW, r } of boxes) {
    let x = (width - rowW) / 2;
    for (const n of sized) {
      if (!n.id) throw new Error('every node needs an id');
      if (nodes.has(n.id)) throw new Error(`duplicate node id ${n.id}`);
      nodes.set(n.id, { ...n, x, y: top + r * rowH, cx: x + n.w / 2, cy: top + r * rowH + n.h / 2 });
      x += n.w + gap;
    }
  }
  let body = '';
  for (const e of spec.edges || []) {
    const a = nodes.get(e.from), b = nodes.get(e.to);
    if (!a) throw new Error(`edge from unknown node ${e.from}`);
    if (!b) throw new Error(`edge to unknown node ${e.to}`);
    const p = clip(a, b), q = clip(b, a);
    const stroke = e.tone ? ` style="stroke:${tone(e.tone).stroke}"` : '';
    body += `<line class="dg-edge" x1="${p.x}" y1="${p.y}" x2="${q.x}" y2="${q.y}" marker-end="url(#dg-arrow)"${stroke}/>`;
    if (e.label) {
      const mx = (p.x + q.x) / 2, my = (p.y + q.y) / 2, w = textW(e.label, 12) + 10;
      body += `<rect x="${mx - w / 2}" y="${my - 9}" width="${w}" height="18" rx="4" fill="${v('ground')}"/><text class="dg-muted" x="${mx}" y="${my + 4}" text-anchor="middle">${esc(e.label)}</text>`;
    }
  }
  for (const n of nodes.values()) {
    const t = tone(n.tone);
    body += `<rect class="dg-box" x="${n.x}" y="${n.y}" width="${n.w}" height="${n.h}" rx="8" fill="${t.fill}" stroke="${t.stroke}"/>`;
    n.ls.forEach((l, i) => { body += `<text x="${n.cx}" y="${n.y + 18 + i * 18}" text-anchor="middle">${esc(l)}</text>`; });
  }
  const bottom = top + (boxes.length - 1) * rowH + Math.max(...[...nodes.values()].map(n => n.h)) + 16;
  const ex = example(spec.example, width, bottom);
  return wrap(width, bottom + ex.height + (ex.height ? 0 : 4), body + ex.body, spec.title);
}

const exampleWidth = ex => Math.max(0, ...(ex || []).flatMap(lines).map(l => textW(l, 12) + 40));

// Where the line from a's centre towards b leaves a's box.
function clip(a, b) {
  const dx = b.cx - a.cx, dy = b.cy - a.cy;
  if (!dx && !dy) return { x: a.cx, y: a.cy };
  const sx = dx ? (a.w / 2) / Math.abs(dx) : Infinity, sy = dy ? (a.h / 2) / Math.abs(dy) : Infinity;
  const s = Math.min(sx, sy);
  return { x: round(a.cx + dx * s), y: round(a.cy + dy * s) };
}
const round = n => Math.round(n * 10) / 10;

// Steps run down the page: a dot on the left, the moment in bold, its label under it.
function timeline(spec) {
  const steps = spec.steps || [];
  if (steps.length < 2) throw new Error('a timeline needs at least two steps');
  const top = spec.title ? 44 : 16;
  const x = 30, tx = 50;
  const sized = steps.map(s => ({ ...s, ls: lines(s.label) }));
  const width = Math.max(spec.width || 0, 320, ...sized.flatMap(s => [textW(s.at) + tx + 16, ...s.ls.map(l => textW(l, 12) + tx + 16)]), exampleWidth(spec.example));
  let y = top, body = '';
  const dots = [];
  for (const s of sized) {
    const t = tone(s.tone);
    dots.push(y + 6);
    body += `<circle cx="${x}" cy="${y + 6}" r="7" fill="${t.fill}" stroke="${t.stroke}" stroke-width="2"/>`;
    body += `<text x="${tx}" y="${y + 11}" font-weight="700">${esc(s.at)}</text>`;
    s.ls.forEach((l, k) => { body += `<text class="dg-sub" x="${tx}" y="${y + 29 + k * 16}">${esc(l)}</text>`; });
    y += 29 + s.ls.length * 16 + 8;
  }
  const axis = `<line class="dg-axis" x1="${x}" y1="${dots[0]}" x2="${x}" y2="${dots[dots.length - 1]}"/>`;
  const bottom = y + 4;
  const ex = example(spec.example, width, bottom);
  return wrap(width, bottom + ex.height + (ex.height ? 0 : 4), axis + body + ex.body, spec.title);
}

export function draw(spec) {
  if (!spec || typeof spec !== 'object') throw new Error('draw needs a spec object');
  if (spec.kind === 'flow') return flow(spec);
  if (spec.kind === 'timeline') return timeline(spec);
  throw new Error(`unknown diagram kind ${spec.kind}; use flow or timeline`);
}
