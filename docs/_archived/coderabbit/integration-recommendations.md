# CodeRabbit Integration Recommendations

**Created**: 2025-11-17
**Status**: Proposal

---

## The Question

How should we integrate CodeRabbit into the development workflow?

**Options Considered**:
1. ❌ Pre-commit hook (automatic before every commit) - **REJECTED by user**
2. ✅ Integrate into `/git` command (optional flag)
3. ✅ Create new `task-checker` agent (run after completing tasks)
4. Keep manual (run when needed)

---

## Recommendation: Task-Checker Agent (BEST OPTION)

### Overview

Create a new specialized agent called `task-checker` that runs **after** completing significant work. This agent performs comprehensive quality checks including CodeRabbit, linting, and tests.

### Why This Is Best

**Flexibility**
- Run after any task, not just commits
- You control when to invoke
- Can be called by other agents or manually
- Adapts to different scenarios

**Comprehensive Checks**
- CodeRabbit review
- Flutter analyze
- Run tests
- Check for common issues
- All in one command

**Non-Intrusive**
- Doesn't slow down every commit
- Only runs when you want it
- No rate limit concerns from automatic triggers
- Keeps workflow fast

**Agent Pattern Consistency**
- Follows your existing agent patterns (git-commit-helper, docs-manager, etc.)
- Natural fit with your workflow
- Easy to remember and use

### How It Would Work

**You finish a task**:
```dart
// You just implemented a new feature
// Made several changes across multiple files
```

**You run the task-checker**:
```
/task-checker
```

or ask Claude Code:
```
"Run the task checker on my changes"
```

**Task-checker agent**:
1. Runs CodeRabbit review on uncommitted changes
2. Runs `flutter analyze`
3. Optionally runs relevant tests
4. Reports findings in organized format
5. Asks: "Would you like me to fix these issues?"

**Example output**:
```
🔍 Task Checker Report

📊 CodeRabbit Review:
  ✅ No critical issues
  ⚠️  2 code quality suggestions
  💡 1 performance tip

🔬 Flutter Analyze:
  ✅ No issues found

✅ Quick Tests:
  ✅ 15/15 tests passed

Would you like me to:
1. Fix the 2 code quality issues
2. Review the performance tip
3. Proceed to commit
```

**You decide**:
- "Fix the issues" → Agent implements fixes
- "Ignore for now" → Continue to commit
- "Tell me more about #2" → Deep dive into specific issue

### Implementation

**Slash command**: `/task-checker` or `/check`

**File location**: `.claude/commands/task-checker.md`

**What it does**:
```markdown
You are a comprehensive task checker. After the user completes significant work,
run quality checks and report findings.

STEPS:
1. Run CodeRabbit review: `coderabbit --plain --type uncommitted`
2. Run Flutter analyze: `flutter analyze`
3. Optionally run quick tests (ask user first)
4. Parse all results
5. Organize findings by priority:
   - Critical issues (must fix)
   - Important issues (should fix)
   - Suggestions (nice to have)
6. Present clear summary
7. Ask: "Would you like me to fix these issues?"

If user says yes:
- Implement fixes for critical and important issues
- Run checks again to verify
- Report: "All issues resolved!"

If user says no:
- Acknowledge
- Suggest running before commit

FORMATTING:
Use clear sections with emojis:
🔍 Task Checker Report
📊 CodeRabbit Review
🔬 Flutter Analyze
🧪 Tests
✅ Summary
```

### Variants

**Full check** (default):
```
/task-checker
```
Runs everything: CodeRabbit, analyze, tests

**Quick check**:
```
/task-checker --quick
```
Runs only: CodeRabbit + analyze (skip tests)

**CodeRabbit only**:
```
/task-checker --coderabbit-only
```
Just CodeRabbit review

---

## Alternative: Integrate into `/git` Command (GOOD OPTION)

### Overview

Add CodeRabbit check as an **optional step** in your existing `/git` slash command.

### How It Would Work

**Current `/git` command**:
1. Stage files
2. Create commit message
3. Pull latest changes
4. Push to remote

**Enhanced `/git` command with flag**:

**Option A - Always ask**:
```
/git "feat: add new feature"

Claude Code: "Would you like me to run CodeRabbit review before committing? (y/n)"
```

**Option B - Flag-based**:
```
/git --check "feat: add new feature"
# Runs CodeRabbit before committing

/git "feat: add new feature"
# Skips CodeRabbit (fast path)
```

**Option C - After commit, before push**:
```
/git "feat: add new feature"

1. Stages files
2. Creates commit
3. Runs CodeRabbit on committed changes
4. If issues found:
   - Shows issues
   - Asks: "Fix and amend commit? (y/n)"
5. If no issues or user says no:
   - Pulls and pushes
```

### Pros
- Integrated into existing workflow
- You already use `/git` command
- Natural checkpoint before pushing

### Cons
- Adds time to commit flow (even if optional)
- Rate limits could block commits (1/hour free tier)
- May forget to use `--check` flag
- Less flexible than dedicated agent

---

## Comparison Matrix

| Feature | Task-Checker Agent | Git Integration | Manual |
|---------|-------------------|-----------------|--------|
| **Flexibility** | ⭐⭐⭐⭐⭐ High | ⭐⭐⭐ Medium | ⭐⭐⭐⭐ High |
| **Ease of Use** | ⭐⭐⭐⭐ Easy | ⭐⭐⭐⭐⭐ Easiest | ⭐⭐ Manual |
| **Speed** | ⭐⭐⭐⭐ Fast | ⭐⭐⭐ Slower | ⭐⭐⭐⭐⭐ Fastest |
| **Comprehensive** | ⭐⭐⭐⭐⭐ Yes | ⭐⭐⭐ Limited | ⭐⭐⭐ Depends |
| **Rate Limits** | ⭐⭐⭐⭐ Low impact | ⭐⭐ High impact | ⭐⭐⭐⭐⭐ No impact |
| **Control** | ⭐⭐⭐⭐⭐ Full | ⭐⭐⭐ Medium | ⭐⭐⭐⭐⭐ Full |
| **Remember to Use** | ⭐⭐⭐ Medium | ⭐⭐⭐⭐ High | ⭐ Low |

---

## My Recommendation: Task-Checker Agent

### Why I Recommend This

**1. Flexibility Over Automation**
- You're working solo, not on a large team
- You know when checks are appropriate
- Don't need forced automation
- Better than "always check" or "never check"

**2. Comprehensive Coverage**
- Not just CodeRabbit - also analyze, tests, etc.
- One command for all quality checks
- Consistent reporting format
- Easier to maintain

**3. Rate Limit Friendly**
- You control when it runs
- Won't hit 1/hour limit accidentally
- Free tier is sufficient
- Pro tier ($24-30/mo) if you want more

**4. Fits Your Workflow**
You already use specialized agents:
- `/git` for commits
- `git-commit-helper` for smart commits
- `docs-manager` for documentation
- `code-researcher` for searching

Adding `/task-checker` is natural:
- `/task-checker` before committing
- `/git` to commit
- Clean separation of concerns

**5. Works with PR Reviews**
- Manual checks catch issues early
- PR reviews catch what you missed
- Two-layer quality assurance
- Best of both worlds

### Recommended Workflow

**While coding**:
```
// Code, code, code...
// Made significant changes
```

**Before committing**:
```
/task-checker
```
or
```
"Run task checker and fix any issues"
```

**After fixes**:
```
/git "feat: implemented new feature"
```

**On PR**:
- CodeRabbit reviews automatically
- Catches anything manual review missed

---

## Implementation Plan

### Phase 1: Create Task-Checker Agent (30 minutes)

**1. Create command file**:
```bash
mkdir -p .claude/commands
touch .claude/commands/task-checker.md
```

**2. Write command prompt** (I can do this)

**3. Test**:
```
/task-checker
```

**4. Iterate based on feedback**

### Phase 2: Refine Based on Usage (ongoing)

**Week 1**:
- Use on every task
- Note what works/doesn't work
- Adjust based on experience

**Week 2**:
- Add shortcuts if needed (e.g., `/check`)
- Tune what checks run by default
- Consider adding flags (--quick, --full)

### Phase 3: Consider Git Integration (optional)

If you find you **always** run task-checker before `/git`, then:
- Add optional integration
- Make it seamless
- Keep flexibility

---

## Alternative Approach: Simple Alias

If you want something even simpler, just create an alias:

**In your shell config** (`.zshrc` or `.bashrc`):
```bash
alias check='coderabbit --plain --type uncommitted && flutter analyze'
```

Then:
```bash
check
# Runs both CodeRabbit and analyze
```

**Pros**:
- Super simple
- No agent needed
- Fast

**Cons**:
- Less intelligent (no fixing)
- No integration with Claude Code
- Manual interpretation of results

---

## What About the Git Agent?

### Should we enhance `/git` with CodeRabbit?

**My take**: No, keep them separate.

**Reasons**:
1. `/git` should be fast
2. Task-checker is more comprehensive
3. Better separation of concerns
4. Easier to skip checks when needed

**But you could**:
- Add optional `--check` flag to `/git`
- Make it call task-checker internally
- Best of both worlds

---

## Final Recommendation

### Create Task-Checker Agent

**Invoke after completing work**:
```
/task-checker
```

**What it does**:
1. CodeRabbit review
2. Flutter analyze
3. Optional: run tests
4. Present organized report
5. Offer to fix issues

**Benefits**:
- Flexible - you control when
- Comprehensive - multiple checks
- Intelligent - can fix issues
- Fast - only runs when needed
- Natural - fits your workflow

### Keep `/git` Command As-Is

**Current flow works well**:
```
/task-checker  # Check quality
/git "message" # Commit and push
```

Clean, simple, effective.

---

## Decision Time

**Option 1: Task-Checker Agent** ⭐ Recommended
- Most flexible
- Most comprehensive
- Fits your workflow best
- **I can implement this now**

**Option 2: Git Integration**
- Integrate into `/git` command
- Optional flag or always-ask
- Tighter coupling

**Option 3: Both**
- Task-checker for comprehensive checks
- Git integration for quick checks
- Most powerful but more complex

**Option 4: Keep Manual**
- Just run `coderabbit` when you want
- Simplest
- Easy to forget

---

## What I Recommend We Do Now

**Step 1**: Create task-checker agent (I can do this)

**Step 2**: Test it for a week

**Step 3**: Decide if git integration is needed

**Step 4**: Iterate based on experience

---

## Want Me To Implement This?

I can create the task-checker agent right now. Just say:

```
"Create the task-checker agent"
```

Or if you prefer a different approach, let me know!
