# Local Edge Function Test Harness

This directory exists because CI and deploy workflows run edge-function tests
from `test/local_edge_functions`.

The actual algorithm tests live next to the Supabase functions and run with
Deno:

```bash
npm test
npm run test:e2e
```

`npm test` delegates to `../../supabase/functions/run-algorithm-tests.sh`.
`npm run test:e2e` also runs the deployed Supabase E2E tests and requires
`SUPABASE_URL` and `SUPABASE_ANON_KEY`.
