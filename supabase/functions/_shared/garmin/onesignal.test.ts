/**
 * Contract tests for the activity-upload push.
 *
 * These cover the two things that are expensive to discover in production:
 *   1. The copy itself — heading, body, and the Garmin attribution that
 *      Garmin's Developer API Brand Guidelines require wherever
 *      Garmin-derived data is surfaced (see the open production review in
 *      docs/integration/garmin_email/). A refactor that quietly drops the
 *      provider from the body is a compliance regression, not a style change.
 *   2. The analytics contract — `copy_variant` in the push payload and the
 *      `activity_upload_push_sent` denominator. Push click-through is
 *      measured as sent → clicked, and both halves are silent when broken:
 *      no crash, just a funnel that reads zero or a CTR compared against the
 *      wrong denominator.
 *
 * Network is stubbed, so this stays a local (non-`--e2e`) test.
 */

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  afterEach,
  beforeEach,
  describe,
  it,
} from "https://deno.land/std@0.168.0/testing/bdd.ts";

// Both modules read their credentials into module-level constants at import
// time, so the env has to be populated before the dynamic import below.
Deno.env.set("ONESIGNAL_APP_ID", "test-onesignal-app");
Deno.env.set("ONESIGNAL_REST_API_KEY", "test-onesignal-key");
Deno.env.set("MIXPANEL_PROJECT_TOKEN", "test-mixpanel-token");

const {
  ACTIVITY_UPLOAD_COPY_VARIANT,
  buildGarminProviderLabel,
  sendActivityUploadedPush,
} = await import("./onesignal.ts");

interface CapturedRequest {
  url: string;
  // deno-lint-ignore no-explicit-any
  body: any;
}

const originalFetch = globalThis.fetch;
let captured: CapturedRequest[] = [];
let oneSignalAccepts = true;

const oneSignalRequest = () =>
  captured.find((r) => r.url.includes("onesignal.com"));
const mixpanelRequest = () =>
  captured.find((r) => r.url.includes("mixpanel.com"));

const USER_ID = "9e413a30-6cf5-4637-bac5-a70d90a9653a";
const ACTIVITY_ID = "3a7e3fdb-754c-812c-85f2-eb86d213c863";

function send(overrides: Record<string, unknown> = {}) {
  return sendActivityUploadedPush({
    userId: USER_ID,
    activityId: ACTIVITY_ID,
    scheduledDate: "2026-08-05",
    provider: "Garmin Forerunner 955",
    ...overrides,
  });
}

describe("sendActivityUploadedPush", () => {
  beforeEach(() => {
    captured = [];
    oneSignalAccepts = true;

    globalThis.fetch = ((input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : String(input);
      captured.push({ url, body: JSON.parse(String(init?.body ?? "null")) });

      if (url.includes("onesignal.com")) {
        return Promise.resolve(
          oneSignalAccepts
            ? new Response(JSON.stringify({ id: "notification-1" }), {
              status: 200,
            })
            : new Response("invalid_player_ids", { status: 400 }),
        );
      }
      return Promise.resolve(new Response("1", { status: 200 }));
    }) as unknown as typeof fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  describe("copy", () => {
    it("leads with the accuracy hook rather than the file transfer", async () => {
      await send();

      const payload = oneSignalRequest()!.body;
      assertEquals(payload.headings.en, "Your targets just updated");
      assertStringIncludes(payload.contents.en, "recalculated your fuel plan");
      assertStringIncludes(payload.contents.en, "what you actually burned");
    });

    it("keeps the Garmin attribution in the body", async () => {
      await send();

      assertStringIncludes(
        oneSignalRequest()!.body.contents.en,
        "Garmin Forerunner 955",
      );
    });

    it("attributes Garmin Connect when the device model is unknown", async () => {
      await send({ provider: undefined });

      assertStringIncludes(
        oneSignalRequest()!.body.contents.en,
        "Garmin Connect",
      );
    });

    it("shortens the body date to MM/DD so long device names don't truncate", async () => {
      await send();

      const body = oneSignalRequest()!.body.contents.en as string;
      assertStringIncludes(body, "08/05");
      assertEquals(body.includes("08/05/2026"), false);
    });

    it("stays inside the length iOS renders without truncating", async () => {
      // Longest realistic attribution: a full Garmin device model.
      await send({ provider: "Garmin Forerunner 965 Music" });

      const body = oneSignalRequest()!.body.contents.en as string;
      assert(
        body.length <= 130,
        `push body is ${body.length} chars, expected <= 130: ${body}`,
      );
    });
  });

  describe("analytics contract", () => {
    it("tags the push payload with the copy variant", async () => {
      await send();

      assertEquals(
        oneSignalRequest()!.body.data.copy_variant,
        ACTIVITY_UPLOAD_COPY_VARIANT,
      );
    });

    it("keeps the full MM/DD/YYYY date in the data payload", async () => {
      await send();

      // The body date shortened to MM/DD; this one must not, or historical
      // comparisons against `activity_date` break.
      assertEquals(oneSignalRequest()!.body.data.activity_date, "08/05/2026");
    });

    it("emits the sent event that is the click-through denominator", async () => {
      await send();

      const event = mixpanelRequest()!.body[0];
      assertEquals(event.event, "activity_upload_push_sent");
      assertEquals(event.properties.copy_variant, ACTIVITY_UPLOAD_COPY_VARIANT);
      assertEquals(event.properties.activity_id, ACTIVITY_ID);
      assertEquals(event.properties.token, "test-mixpanel-token");
    });

    it("identifies the sent event with the Supabase user id", async () => {
      await send();

      // Must match what the app passes to mixpanel.identify() (user_profiles.id
      // == users.id) or the sent → clicked funnel will not join.
      assertEquals(mixpanelRequest()!.body[0].properties.distinct_id, USER_ID);
    });

    it("dedupes retried webhooks with a stable insert id", async () => {
      await send();
      const first = mixpanelRequest()!.body[0].properties.$insert_id;

      captured = [];
      await send();
      const second = mixpanelRequest()!.body[0].properties.$insert_id;

      // Garmin re-delivers pushes, and garmin-push / garmin-ping can both
      // process the same summary — without this the denominator inflates.
      assertEquals(first, second);
      assertStringIncludes(String(first), ACTIVITY_ID);
    });

    it("does not count a send OneSignal rejected", async () => {
      oneSignalAccepts = false;

      await send();

      assertEquals(mixpanelRequest(), undefined);
    });
  });
});

describe("buildGarminProviderLabel", () => {
  it("prefers the device model when Garmin reports one", () => {
    assertEquals(
      buildGarminProviderLabel("Forerunner 955"),
      "Garmin Forerunner 955",
    );
  });

  it("does not double-prefix a name that already says Garmin", () => {
    assertEquals(buildGarminProviderLabel("Garmin Fenix 7"), "Garmin Fenix 7");
  });

  it("falls back to the full brand name when the model is missing", () => {
    // Never a bare "Garmin" token — brand guidelines forbid abbreviation.
    assertEquals(buildGarminProviderLabel(null), "Garmin Connect");
    assertEquals(buildGarminProviderLabel(""), "Garmin Connect");
    assertEquals(buildGarminProviderLabel("   "), "Garmin Connect");
    assertEquals(buildGarminProviderLabel("unknown"), "Garmin Connect");
    assertEquals(buildGarminProviderLabel("Garmin"), "Garmin Connect");
  });
});
