// node --test .claude/skills/ssot/matt.test.mjs
//
// The locator finds Matt Pocock's skill of a given name in the plugin cache
// through a version glob, and stops loudly, naming the path it looked for,
// when the file is not there.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { locate } from './matt.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), 'matt.mjs');

function cache() {
  const root = mkdtempSync(join(tmpdir(), 'matt-'));
  for (const [version, group, name] of [['1.2.3', 'engineering', 'to-spec'], ['1.2.3', 'productivity', 'grill-me'], ['1.10.0', 'engineering', 'to-spec']]) {
    const dir = join(root, version, 'skills', group, name);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'SKILL.md'), `---\nname: ${name}\n---\n${version}\n`);
  }
  return root;
}

test('the newest version of a skill is found under any group', () => {
  const root = cache();
  assert.equal(locate('to-spec', root), join(root, '1.10.0', 'skills', 'engineering', 'to-spec', 'SKILL.md'));
  assert.equal(locate('grill-me', root), join(root, '1.2.3', 'skills', 'productivity', 'grill-me', 'SKILL.md'));
  assert.equal(execFileSync('node', [cli, 'grill-me'], { encoding: 'utf8', env: { ...process.env, MATT_SKILLS_ROOT: root } }).trim(), locate('grill-me', root));
});

test('a renamed or missing skill stops the run and names the path it looked for', () => {
  const root = cache();
  assert.throws(() => locate('to-tickets', root), /to-tickets.*SKILL\.md/);
  const r = spawnSync('node', [cli, 'to-tickets'], { encoding: 'utf8', env: { ...process.env, MATT_SKILLS_ROOT: root } });
  assert.equal(r.status, 1);
  assert.equal(r.stdout, '');
  assert.match(r.stderr, new RegExp(`${root.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&')}/\\*/skills/\\*/to-tickets/SKILL\\.md`));
  assert.match(r.stderr, /Stop/);
});
