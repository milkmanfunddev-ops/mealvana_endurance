// Sign in with Apple on Android: Apple's return URL. See relay.ts for why
// this exists. Register `https://<project-ref>.supabase.co/functions/v1/apple-signin-callback`
// as a Return URL on the Apple Services ID (the app's APPLE_AUTH_SERVICES_ID).
// Apple posts without a Supabase JWT, so `verify_jwt = false` (config.toml).
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { relayAppleCallback } from "./relay.ts";

initSentry();

serve(withSentry("apple-signin-callback", (req: Request) =>
  relayAppleCallback(req, {
    ANDROID_APP_PACKAGE: Deno.env.get("ANDROID_APP_PACKAGE"),
    SUPABASE_URL: Deno.env.get("SUPABASE_URL"),
  })
));
