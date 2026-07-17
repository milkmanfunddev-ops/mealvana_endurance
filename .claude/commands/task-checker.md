# Task Checker

Pre-commit quality gate. Run after significant changes and before committing.
No user prompts mid-run — do all checks, then present one report.

## Steps

### 1. Scope the change
`git status` + `git diff --stat` (include staged and unstaged). Note which
features/layers are touched — this drives which tests run.

### 2. Codegen freshness
If any changed `.dart` file carries `@riverpod`, Drift table, or `@freezed`
annotations and the corresponding `.g.dart`/`.freezed.dart` is missing or older
than its source, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Static analysis
```bash
flutter analyze
```
Count errors / warnings / infos. Errors are always Critical.

### 4. Targeted tests (auto-run — don't ask)
Map changed paths to tests and run them:
- `lib/features/<x>/...` → `test/**/<x>*` and `test/features/<x>/` if present
- shared/db changes → the smoke suite `test/smoke_tests/`
- edge functions → `supabase/functions/run-algorithm-tests.sh` when algorithm fns changed
- If mapping is unclear, run the smoke suite as the floor.

Known environmental failures (not your bug — report as such, don't chase): the
stale-e2e-edge-fn-name tests and the expired-TrainingPeaks-token test.

### 5. Report

```
🔍 Task Checker
  Analyze: X errors / X warnings / X infos
  Tests:   X/X passed (which suites ran)
  Codegen: clean | regenerated | n/a

Verdict: Ready to commit | Needs attention | Critical issues

Critical (fix before commit):
1. file:line — issue

Warnings / suggestions:
1. file:line — issue
```

### 6. Fix policy
- Auto-fix without asking: analyzer errors with obvious fixes, unused imports,
  formatting, missing codegen. Re-run the affected check after fixing.
- Ask first: anything touching architecture, behavior, or public API.

## Deeper review
This command is the fast gate. For a real correctness review of the diff, use the
built-in `/code-review` skill (or `/code-review ultra` for the multi-agent cloud
review of a branch/PR).
