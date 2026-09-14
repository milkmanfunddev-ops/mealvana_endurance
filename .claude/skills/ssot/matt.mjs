#!/usr/bin/env node
// Locate Matt Pocock's skill of a given name in the plugin cache.
//
//   node .claude/skills/ssot/matt.mjs <name>   -> prints the SKILL.md path
//
// The -lee skills follow Matt's skills by reading the file this prints; his
// skills are user-only, so a wrapper cannot invoke them and never keeps a copy.
// The version segment is a glob so a plugin update needs no edit here. A missing or
// renamed file exits 1 with the path it looked for on stderr; there is no fallback. MATT_SKILLS_ROOT overrides the cache root (tests, other machines).
import { readdirSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const defaultRoot = () => join(homedir(), '.claude', 'plugins', 'cache', 'claude-plugins-official', 'mattpocock-skills');

const versionKey = v => v.split('.').map(n => parseInt(n, 10) || 0);
const newestFirst = (a, b) => { const x = versionKey(a), y = versionKey(b); for (let i = 0; i < 3; i++) if ((y[i] || 0) !== (x[i] || 0)) return (y[i] || 0) - (x[i] || 0); return 0; };

export function locate(name, root = process.env.MATT_SKILLS_ROOT || defaultRoot()) {
  const pattern = join(root, '*', 'skills', '*', name, 'SKILL.md');
  const versions = existsSync(root) ? readdirSync(root).filter(v => /^\d+\.\d+\.\d+$/.test(v)).sort(newestFirst) : [];
  for (const v of versions) {
    const groups = join(root, v, 'skills');
    if (!existsSync(groups)) continue;
    for (const g of readdirSync(groups)) {
      const f = join(groups, g, name, 'SKILL.md');
      if (existsSync(f)) return f;
    }
  }
  throw new Error(`Matt's skill "${name}" was not found. Looked for ${pattern}. Stop: do not fall back to memory of the skill; check the plugin is installed and the skill's name.`);
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split('/').pop())) {
  const name = process.argv[2];
  if (!name) { console.error('usage: matt.mjs <skill name>'); process.exit(2); }
  try { console.log(locate(name)); }
  catch (e) { console.error(e.message); process.exit(1); }
}
