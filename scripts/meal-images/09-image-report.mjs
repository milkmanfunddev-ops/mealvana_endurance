// Pass 9: how many meals are showing something wrong — asked, not sampled.
//
// Every number quoted about this library before now came from a sample of a few
// dozen meals. This reads all 1,922 and counts what passes 3 and 8 recorded, so
// "is it getting better?" is one command rather than an afternoon.
//
// The arithmetic lives in `lib/honesty.mjs` — what counts as honest, how the
// wrong list is ordered, what a run cost — with tests beside it. This pass is
// the part that cannot be pure: read the rows, print, write the document.
//
// Costs nothing and changes no meal. Safe to run whenever.
//
//   node scripts/meal-images/09-image-report.mjs           # print the measure
//   node scripts/meal-images/09-image-report.mjs --write    # …and record it
//   node scripts/meal-images/09-image-report.mjs --wrong    # the whole work queue
//   node scripts/meal-images/09-image-report.mjs --wrong --csv > queue.csv
import { selectAll } from './lib/db.mjs';
import { rankByReach, renderReport, summarise } from './lib/honesty.mjs';
import { pinnedGeometry } from './lib/mosaic-geometry.mjs';
import { REPORT_PATH, writeMeasure } from './lib/report-doc.mjs';

const args = new Set(process.argv.slice(2));
const geometry = pinnedGeometry();

const rows = await selectAll(
  'meal_library',
  'select=id,name,image_mode,image_verdict,image_verdict_reason,image_blocked,' +
    'image_blocked_reason,frequency,contexts,allergens&is_active=eq.true&order=id',
);

const summary = summarise(rows);
const wrong = rankByReach(rows.filter((r) => r.image_verdict === 'wrong'));

// ── the whole work queue, on request ─────────────────────────────────────────
if (args.has('--wrong')) {
  if (args.has('--csv')) {
    const q = (v) => `"${String(v ?? '').replaceAll('"', '""')}"`;
    console.log('rank,id,name,mode,frequency,reason');
    wrong.forEach((w, i) =>
      console.log([i + 1, q(w.id), q(w.name), w.image_mode, w.frequency ?? '', q(w.image_verdict_reason)].join(',')));
  } else {
    console.log(`${wrong.length} meals are showing something wrong, most-surfaced first:\n`);
    wrong.forEach((w, i) =>
      console.log(
        `${String(i + 1).padStart(4)}  ${(w.frequency ?? '-').padEnd(11)}${w.image_mode.padEnd(7)}` +
          `${w.name.slice(0, 46).padEnd(48)}${(w.image_verdict_reason ?? '').slice(0, 60)}`,
      ));
  }
  process.exit(0);
}

// ── the measure ──────────────────────────────────────────────────────────────
console.log(`mosaic geometry: v${geometry.version}   (every verdict below describes that grid)\n`);
console.log(`HONESTY:  ${summary.honest}/${summary.total} = ${summary.honestPct.toFixed(1)}%` +
  `   (${summary.byVerdict.ok} showing an ok image + ${summary.blocked} honestly showing nothing)`);
console.log(`coverage: ${summary.coverage}/${summary.total} = ${summary.coveragePct.toFixed(1)}%` +
  `   (meals with *a* picture — the old headline, kept only for the contrast)\n`);

console.log('mode      meals     ok   weak  wrong  unjudged');
for (const [mode, m] of Object.entries(summary.byMode)) {
  if (mode === 'none') { console.log(`${mode.padEnd(9)} ${String(m.total).padStart(5)}      —      —      —         —`); continue; }
  console.log(
    `${mode.padEnd(9)} ${String(m.total).padStart(5)}  ${String(m.ok).padStart(5)}` +
      `  ${String(m.weak).padStart(5)}  ${String(m.wrong).padStart(5)}  ${String(m.unjudged).padStart(8)}`,
  );
}

console.log(`\nshowing nothing, by reason:`);
for (const [reason, n] of Object.entries(summary.blockedByReason).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${reason.padEnd(24)} ${String(n).padStart(5)}`);
}

if (summary.unjudged) {
  console.log(`\n${summary.unjudged} meals showing a picture have no verdict yet — the figure above ` +
    `can only fall.\nRun pass 8 to finish measuring.`);
}
if (summary.unaccounted) {
  console.log(`\n${summary.unaccounted} meals show nothing but are not flagged blocked — passes 3 ` +
    `and 8 disagree.\nRe-run pass 3.`);
}

console.log(`\nthe work queue: ${summary.byVerdict.wrong} meals rated wrong` +
  (wrong.length ? `, worst-reaching first:` : '.'));
for (const [i, w] of wrong.slice(0, 15).entries()) {
  console.log(`${String(i + 1).padStart(4)}  ${w.image_mode.padEnd(7)}${w.name.slice(0, 44).padEnd(46)}` +
    `${(w.image_verdict_reason ?? '').slice(0, 52)}`);
}
if (wrong.length > 15) console.log(`      … ${wrong.length - 15} more (--wrong for all of them)`);

if (!args.has('--write')) {
  console.log('\n--write to record this in docs/meal-images/honesty.md');
  process.exit(0);
}

const ok = await writeMeasure(renderReport({
  summary,
  wrong,
  geometryVersion: geometry.version,
  at: new Date().toISOString(),
}));
if (ok) console.log(`\nrecorded in ${REPORT_PATH.pathname.replace(`${process.cwd()}/`, '')}`);
