// Where the honesty measure and what it cost are written down.
//
// Two passes touch this document and neither owns all of it: pass 8 appends one
// row to the spend ledger when it finishes, pass 9 replaces the measure. Both
// go through here so the marker names live in one place and neither can
// overwrite the other's region — or the prose a person wrote around them.
import { readFile, writeFile } from 'node:fs/promises';
import { spliceRegion } from './honesty.mjs';

export const REPORT_PATH = new URL('../../../docs/meal-images/honesty.md', import.meta.url);

/** Replace the measured figures. Returns false when the document is missing. */
export async function writeMeasure(body) {
  return splice('honesty', (doc) => spliceRegion(doc, 'honesty', body));
}

/** Append one run to the spend ledger, newest last. */
export async function appendRun(row) {
  return splice('runs', (doc) => {
    const end = doc.indexOf('<!-- runs:end -->');
    return doc.slice(0, end) + row + '\n' + doc.slice(end);
  });
}

async function splice(region, edit) {
  let doc;
  try {
    doc = await readFile(REPORT_PATH, 'utf8');
  } catch {
    console.warn(`docs/meal-images/honesty.md is missing — nothing recorded for ${region}`);
    return false;
  }
  if (!doc.includes(`<!-- ${region}:end -->`)) {
    console.warn(`docs/meal-images/honesty.md has no ${region} region — nothing recorded`);
    return false;
  }
  await writeFile(REPORT_PATH, edit(doc));
  return true;
}
