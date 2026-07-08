# Shorebird Code Push Guide (Repo Truth)

## Current State (Repo Truth)
- Shorebird configuration exists in repo (`shorebird.yaml`).
- Shorebird applies to mobile release/patch workflows (iOS/Android), not web.
- `CLAUDE.md` policy remains: assistants should not run long release build commands directly.

## Flavor → Shorebird App mapping
Each flavor maps to its own Shorebird app_id (in `shorebird.yaml`). Distinct
app_ids keep patches isolated — a dev patch is never served to a prod build.

| Flavor | Shorebird app_id | Display name |
|--------|------------------|--------------|
| prod   | `16f10ae3-5b24-4e65-81cd-917f904f50d6` | mealvana_endurance |
| dev    | `d25496f9-4335-4332-81e7-e108e3f48eaa` | mealvana_endurance (dev) |

## CI workflows (Codemagic)
Shorebird release/patch is driven from `codemagic.yaml`. Auth in CI comes from
the `shorebird_credentials` variable group (`SHOREBIRD_TOKEN`, read by the CLI).

| Workflow | Trigger | Action |
|----------|---------|--------|
| `dev-ios` | push to `develop` | `shorebird release ios --flavor dev` → TestFlight |
| `dev-ios-patch` | manual | `shorebird patch ios --flavor dev` (OTA) |
| `prod-ios` | push to `release/*` | `shorebird release ios --flavor prod` → TestFlight |
| `prod-ios-patch` | manual | `shorebird patch ios --flavor prod` (OTA) |
| `prod-android` / `prod-android-patch` | push `release/*` / manual | Android release / patch |

## Source of Truth
- Shorebird config: `shorebird.yaml`
- Flutter project config: `pubspec.yaml`
- CI workflows: `codemagic.yaml`
- Deployment process context: `/docs/deployment/README.md`

## Runbook / Commands
- Verify Shorebird CLI setup:
```bash
shorebird doctor
```
- Create mobile releases:
```bash
shorebird release ios
shorebird release android
```
- Publish mobile patches:
```bash
shorebird patch ios
shorebird patch android
```

## Verification Checklist
- `shorebird.yaml` is present and aligned with current app identifiers.
- Release/patch commands target correct app and environment.
- Patch scope is Dart-level changes only; native changes require full store release.

## Related Docs
- `/docs/deployment/README.md`
- `/docs/ci-cd/README.md`

## Deprecated/Legacy Notes
- Web deployment is Vercel-based and outside Shorebird.
