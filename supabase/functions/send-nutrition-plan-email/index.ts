/**
 * send-nutrition-plan-email — wiring only. The handler lives in `handler.ts`
 * so it can be tested without binding a port.
 */
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { handleSendEmail } from "./handler.ts";

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry((req) => handleSendEmail(req)));
