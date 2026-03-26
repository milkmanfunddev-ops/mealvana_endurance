import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, handleCors } from "../_shared/cors.ts";

const CUSTOM_SCHEME = "com.milkman.mealvanaendurance://callback";

serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Garmin redirects via GET with query params
  const url = new URL(req.url);
  const queryString = url.search; // includes the leading '?'

  const redirectUrl = `${CUSTOM_SCHEME}${queryString}`;

  // Return 302 redirect with a fallback HTML page
  return new Response(
    `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Redirecting...</title>
  <meta http-equiv="refresh" content="0;url=${redirectUrl}">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; text-align: center; padding: 60px 20px;">
  <h2>Redirecting to Mealvana Endurance...</h2>
  <p>If the app doesn't open automatically, <a href="${redirectUrl}">tap here</a>.</p>
</body>
</html>`,
    {
      status: 302,
      headers: {
        ...corsHeaders,
        "Location": redirectUrl,
        "Content-Type": "text/html; charset=utf-8",
      },
    }
  );
});
