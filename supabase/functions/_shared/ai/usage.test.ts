import { assertEquals } from "https://deno.land/std@0.177.1/testing/asserts.ts";
import { gatewayCostUsd } from "./usage.ts";

Deno.test("gatewayCostUsd parses the gateway decimal cost string", () => {
  assertEquals(
    gatewayCostUsd({ gateway: { cost: "0.0045405" }, anthropic: {} }),
    0.0045405,
  );
});

Deno.test("gatewayCostUsd accepts numeric cost and rejects missing metadata", () => {
  assertEquals(gatewayCostUsd({ gateway: { cost: 0.25 } }), 0.25);
  assertEquals(gatewayCostUsd({ anthropic: {} }), null);
  assertEquals(gatewayCostUsd(null), null);
});
