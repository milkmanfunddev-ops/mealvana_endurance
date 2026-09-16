// Builds preview/index.html: the real page with a fake `claude` runtime fed from the prepared JSON docs.
import fs from 'node:fs';
const S = process.env.SSOT_SCRATCH || '/tmp/ssot-preview';
const page = fs.readFileSync('/Users/leemartin/development/mealvana_endurance/docs/ssot/decisions/_page/index.html', 'utf8');
const out = S + '/out2';
const decisions = {}, tickets = {};
for (const f of fs.readdirSync(out)) {
  if (f.startsWith('mp-')) decisions[f.replace('.json', '')] = JSON.parse(fs.readFileSync(`${out}/${f}`, 'utf8'));
  if (f.startsWith('ticket-')) tickets[f.replace('ticket-', '').replace('.json', '')] = JSON.parse(fs.readFileSync(`${out}/${f}`, 'utf8'));
}
const shim = `<script>
window.__data = { decisions: ${JSON.stringify(decisions)}, tickets: ${JSON.stringify(tickets)}, vocab: {}, verdicts: {}, chats: {}, meta: { state: { featureNames: { mealplanning: 'Meal planning and Vana' } } } };
window.claude = { use: async (cap) => {
  if (cap === 'db') {
    const listeners = {};
    const emit = (c) => (listeners[c] || []).forEach(fn => fn({ docs: Object.entries(window.__data[c] || {}).map(([id, d]) => ({ id, data: () => d })) }));
    return {
      doc: (path) => { const [c, id] = path.split('/'); return {
        onSnapshot: (fn) => fn({ data: () => (window.__data[c] || {})[id] }),
        set: async (d) => { (window.__data[c] ||= {})[id] = d; emit(c); },
        update: async (d) => { Object.assign((window.__data[c] ||= {})[id] ||= {}, d); emit(c); },
        delete: async () => { delete (window.__data[c] || {})[id]; emit(c); },
      }; },
      collection: (c) => ({ onSnapshot: (fn) => { (listeners[c] ||= []).push(fn); emit(c); } }),
    };
  }
  if (cap === 'sample') return null;
  if (cap === 'artifact') return { publish: async () => { console.log('publish stub'); } };
  return null;
} };
</script>
<meta name="viewport" content="width=device-width,initial-scale=1">
`;
fs.writeFileSync(S + '/preview/index.html', '<!doctype html><html><head><meta charset="utf-8">' + shim + '</head><body>' + page + '</body></html>');
console.log('preview written', Object.keys(decisions).length, 'decisions', Object.keys(tickets).length, 'tickets');
