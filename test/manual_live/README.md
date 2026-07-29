# Manual live-API tests

These tests hit real third-party provider APIs and are excluded from CI via
`@Tags(['integration'])` (see `dart_test.yaml` and the `--exclude-tags` flag in
`codemagic.yaml`). They are a contract check against the live TrainingPeaks and
Final Surge APIs, run by hand when investigating provider behavior.

Prerequisites: fresh OAuth token caches under `tool/` — TrainingPeaks tokens
expire after 1 hour, so re-run `dart run tool/training_peaks_api_test.dart auth`
first. Then:

```bash
flutter test test/manual_live --tags integration
```
