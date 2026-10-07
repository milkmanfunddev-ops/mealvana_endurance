// Entry point that lets `node --test test/scripts/testing-wave/` run the whole folder.
// Node 22's test runner takes files or globs, not a directory: given a directory it loads it as a
// module, which resolves through package.json's `main` to this file. Every *.test.mjs beside it is
// imported here and registers its tests with node:test. The glob form still works on its own:
//   node --test 'test/scripts/testing-wave/*.test.mjs'
import { readdirSync } from 'node:fs';

const here = new URL('.', import.meta.url);
for (const name of readdirSync(here).filter(n => n.endsWith('.test.mjs')).sort()) await import(new URL(name, here));
