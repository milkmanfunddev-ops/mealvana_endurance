/**
 * DI-22 sampler behavior (real-payload-corpus@v1): duplicate fingerprint →
 * no exemplar emitted; novel → exactly one; known-registry ids respected
 * (append-only, frozen — the qa samples dir is the registry).
 */
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import { selectNovelExemplars } from "../_shared/corpus/sampler.ts";

const run = (over: Record<string, unknown> = {}) => ({
  provider: "training_peaks",
  payload: {
    Id: 1,
    WorkoutType: "Run",
    IFPlanned: 0.8,
    TssPlanned: 50,
    ...over,
  // deno-lint-ignore no-explicit-any
  } as any,
});

Deno.test("duplicate fingerprints collapse to one exemplar", async () => {
  const out = await selectNovelExemplars(
    [run({ Id: 1 }), run({ Id: 2, IFPlanned: 0.95 }), run({ Id: 3 })],
    [],
  );
  // Same key states (VALUE:number everywhere), same stratum → ONE shape.
  assertEquals(out.length, 1);
});

Deno.test("a genuinely novel shape emits exactly one more", async () => {
  const out = await selectNovelExemplars(
    [run(), run({ IFPlanned: null, TssPlanned: null, Id: 9 })],
    [],
  );
  assertEquals(out.length, 2); // NULL-vs-VALUE splits (basic/premium)
});

Deno.test("known-registry ids are never re-emitted", async () => {
  const first = await selectNovelExemplars([run()], []);
  assertEquals(first.length, 1);
  const again = await selectNovelExemplars(
    [run(), run({ Id: 42 })],
    [first[0].fingerprintId],
  );
  assertEquals(again.length, 0); // registry wins: no write, ever
});

Deno.test("optional-classing within the batch collapses key dropout", async () => {
  const out = await selectNovelExemplars(
    [run({ Description: "hi" }), run({ Id: 2 })],
    [],
  );
  // Description observed both present and absent in the stratum → optional →
  // out of identity → one shape.
  assertEquals(out.length, 1);
  assert(out[0].optionalKeysInStratum.includes("Description"));
});
