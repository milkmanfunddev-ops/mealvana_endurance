// Region lookup for the analytics-consent gate.
//
// Returns the caller's country and (where available) first-level subdivision,
// derived from Vercel's edge geo headers. The client uses this to decide
// whether a user is in a jurisdiction that requires opt-in consent before any
// analytics runs — EEA/UK (GDPR/ePrivacy) or Washington State (My Health My
// Data Act, which is the reason we need subdivision granularity at all: a
// country code cannot express a US state).
//
// WHY THIS EXISTS RATHER THAN AN ON-DEVICE GUESS
// The previous implementation resolved region from the device locale and UTC
// offset. A locale is a *language* preference, not a location, and an offset
// cannot separate Washington from California — so Washington was approximated
// by treating the whole US Pacific timezone as strict. This endpoint replaces
// that guess with the real answer.
//
// PRIVACY — READ BEFORE CHANGING
// The caller's IP is used transiently, in-request, to derive country/region and
// is then discarded. It is never logged, never persisted, and never forwarded
// to a third party (Vercel resolves the geo at its edge; no IP-geolocation
// vendor is in the loop). Under Apple's definition, "collect" means retaining
// data off-device for longer than needed to service the request in real time —
// this does not, so it is not a declared data type in
// `ios/Runner/PrivacyInfo.xcprivacy`, which stays at its 9 reconciled types.
//
// That reasoning holds ONLY while the following stays true:
//
//   *** The resolved region must NEVER be sent to Mixpanel or Sentry, or
//   *** attached to any analytics event or user property.
//
// The moment region becomes an analytics property it is collected AND linked to
// the user, and PrivacyInfo.xcprivacy, the live App Store label, and
// test/privacy/privacy_manifest_test.dart all have to change together.
// See docs/privacy/ for the manifest/label reconciliation.

module.exports = (req, res) => {
  // Vercel populates these at the edge from the request IP.
  // `x-vercel-ip-country-region` is the ISO-3166-2 subdivision ("WA", "CA").
  // It is not guaranteed to be present — the client falls back to its
  // device-signal heuristic when `region` is null, rather than assuming the
  // user is outside Washington. Do not "helpfully" default it to a value.
  const country = req.headers['x-vercel-ip-country'] || null;
  const region = req.headers['x-vercel-ip-country-region'] || null;

  // MANDATORY. Vercel's CDN does not vary its cache key on the geo headers, so
  // a cacheable response here would serve the first caller's country to every
  // subsequent caller — presenting as nondeterministic regime flapping that is
  // very unpleasant to debug. Never make this cacheable.
  res.setHeader('Cache-Control', 'private, no-store, max-age=0');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');

  // The response contains nothing but the caller's own coarse location, so it
  // is safe to expose to any origin. This is what lets `flutter run -d chrome`
  // against localhost reach the deployed endpoint during development.
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.status(204).end();
    return;
  }

  res.status(200).send(JSON.stringify({ country, region }));
};
