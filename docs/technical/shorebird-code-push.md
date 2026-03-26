# Shorebird Code Push Guide (Repo Truth)

## Current State (Repo Truth)
- Shorebird configuration exists in repo (`shorebird.yaml`).
- Shorebird applies to mobile release/patch workflows (iOS/Android), not web.
- `CLAUDE.md` policy remains: assistants should not run long release build commands directly.

## Source of Truth
- Shorebird config: `shorebird.yaml`
- Flutter project config: `pubspec.yaml`
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
