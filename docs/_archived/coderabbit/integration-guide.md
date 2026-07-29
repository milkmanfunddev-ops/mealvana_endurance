# CodeRabbit Integration Guide

**Last Updated**: 2025-11-17
**Status**: Active

---

## Table of Contents

1. [Current Integration Status](#current-integration-status)
2. [Claude Code Access to CodeRabbit](#claude-code-access-to-coderabbit)
3. [Integration Options](#integration-options)
4. [Recommended Workflow](#recommended-workflow)
5. [Advanced Features](#advanced-features)
6. [Troubleshooting](#troubleshooting)

---

## Current Integration Status

### ✅ What's Automated (Active Now)

#### 1. GitHub Pull Request Reviews
**Status**: ✅ Active
**Trigger**: Automatic when PR is opened/updated
**Location**: GitHub PR comments
**Configuration**: CodeRabbit GitHub app installed

**How it works**:
1. You push commits to a branch
2. You open a PR on GitHub
3. CodeRabbit automatically reviews within 1-2 minutes
4. Comments appear in PR as `@coderabbitai`

**What you see**:
- Summary comment with issue count
- Line-by-line comments on specific files
- Interactive chat capability with `@coderabbitai` commands

**Commands in PR**:
- `@coderabbitai review` - Re-run full review
- `@coderabbitai configuration` - Show current config
- `@coderabbitai help` - List available commands
- Chat naturally with CodeRabbit for clarifications

---

#### 2. GitHub Actions Workflow
**Status**: ✅ Active
**File**: `.github/workflows/coderabbit.yml`
**Trigger**: Automatic on PR events

**What it does**:
- Runs CodeRabbit as part of CI/CD
- Validates code on every PR update
- Posts results as PR comments
- Integrates with your test workflow

**Triggers**:
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
```

---

#### 3. Pre-Commit Hook (NEW - Just Added)
**Status**: ✅ Active
**File**: `.git/hooks/pre-commit`
**Trigger**: Automatic before every commit

**What it does**:
- Runs CodeRabbit CLI before allowing commit
- Blocks commits with critical issues
- Catches problems before they reach GitHub
- Can be bypassed with `git commit --no-verify` if needed

**How it works**:
1. You run `git commit`
2. Hook runs `coderabbit --prompt-only --type uncommitted`
3. If issues found: commit blocked, message shown
4. If clean: commit proceeds normally

**Example output**:
```bash
git commit -m "feat: add new feature"

🤖 Running CodeRabbit pre-commit review...
❌ CodeRabbit found issues. Please fix before committing.
💡 Run 'coderabbit --plain --type uncommitted' for details
⚠️  To bypass (not recommended): git commit --no-verify
```

---

### ❌ What's NOT Automated

#### 1. CLI Reviews
**Status**: Manual
**Command**: `coderabbit --plain --type uncommitted`
**When to use**: Development time, before committing

#### 2. Integration with git-commit-helper Agent
**Status**: Not configured
**Could do**: Agent could run CodeRabbit before committing
**See**: [Integration Options](#option-2-git-commit-helper-agent-integration)

#### 3. VSCode Extension
**Status**: Not installed
**Could do**: Real-time feedback in editor
**See**: [Advanced Features](#vscode-extension)

---

## Claude Code Access to CodeRabbit

### What Claude Code CAN See

#### ✅ CLI Output (Direct Access)
When you run CodeRabbit CLI, Claude Code sees the output via `BashOutput` tool:

```bash
coderabbit --plain --type uncommitted
# Claude Code captures this output automatically
```

**Use cases**:
- Ask Claude Code to run CodeRabbit during development
- Claude Code can parse issues and suggest fixes
- Claude Code can verify issues are resolved

#### ✅ GitHub PR Comments (Via GitHub CLI)
Claude Code can fetch PR comments using `gh` CLI:

```bash
# Claude Code can run this:
gh pr view 123 --json comments --jq '.comments[].body' | grep -A 50 "@coderabbitai"
```

**Use cases**:
- Fetch CodeRabbit's PR review
- Parse and address issues
- Respond to CodeRabbit findings

### What Claude Code CANNOT See

#### ❌ GitHub Web UI (No Direct Access)
Claude Code cannot:
- Browse GitHub.com
- See PR page visually
- Click links in PR comments
- View CodeRabbit dashboard

**Workaround**: You can copy/paste CodeRabbit PR comments to Claude Code

---

## Integration Options

### Option 1: Pre-Commit Hook ✅ (Just Enabled)

**Status**: Active now

**How it works**:
- Runs before every `git commit`
- Blocks commits with issues
- Catches problems early

**Pros**:
- Automatic
- Catches issues before GitHub
- No manual step required
- Fast feedback loop

**Cons**:
- Adds 5-10 seconds to commit time
- Rate limited (1 review/hour on free tier, 5/hour on Pro)
- Can be bypassed with `--no-verify`

**Configuration**: Already set up in `.git/hooks/pre-commit`

**To disable**:
```bash
rm .git/hooks/pre-commit
```

**To bypass once**:
```bash
git commit --no-verify -m "message"
```

---

### Option 2: Git-Commit-Helper Agent Integration

**Status**: Not configured (proposal)

**What it would do**:
Modify your git-commit-helper agent to:
1. Run CodeRabbit before committing
2. Parse issues
3. Ask if you want to fix or proceed
4. Optionally auto-fix simple issues

**Implementation**:
Update `/claude/commands/git.md` to include CodeRabbit step:

```markdown
## Git Commit Workflow

1. Run CodeRabbit review
2. If issues found, ask user to fix or proceed
3. Stage files
4. Create commit message
5. Pull latest changes
6. Push to remote
```

**Pros**:
- Integrated into your existing workflow
- Claude Code parses and understands issues
- Can auto-fix some issues
- More intelligent than pre-commit hook

**Cons**:
- Requires slash command modification
- Adds complexity to commit flow
- May slow down quick commits

**Want me to implement this?** Let me know and I can update the git-commit-helper agent.

---

### Option 3: GitHub PR Review Integration

**Status**: Active, but Claude Code doesn't see output automatically

**Enhancement**: Create workflow to notify Claude Code of PR reviews

**Implementation idea**:
1. GitHub Actions runs CodeRabbit
2. Action posts review as PR comment
3. You ask Claude Code to fetch PR review
4. Claude Code runs `gh pr view` to get comments
5. Claude Code parses and addresses issues

**Manual workflow now**:
```bash
# You ask Claude Code:
# "Check the CodeRabbit review on PR #123 and fix the issues"

# Claude Code runs:
gh pr view 123 --json comments
# Parses CodeRabbit comments
# Suggests or implements fixes
```

**Pros**:
- Works with existing setup
- No additional automation needed
- Claude Code can address issues intelligently

**Cons**:
- Manual step (you must ask)
- Requires PR to be created first

---

### Option 4: Watch Mode (Development)

**Status**: Not configured

**What it would do**:
Run CodeRabbit continuously during development, like a linter

**Implementation**:
```bash
# Run in background terminal
while true; do
  coderabbit --prompt-only --type uncommitted
  sleep 300  # Check every 5 minutes
done
```

**Pros**:
- Continuous feedback
- Catches issues as you code
- No manual intervention

**Cons**:
- Rate limits (1/hour free, 5/hour Pro)
- Resource usage
- May be noisy

**Better alternative**: Use VSCode extension (see [Advanced Features](#vscode-extension))

---

## Recommended Workflow

Based on your setup, here's the optimal workflow:

### During Development

**Option A: Manual CLI Reviews** (Current)
```bash
# Before committing, run:
coderabbit --plain --type uncommitted

# Review issues
# Fix issues
# Commit
```

**Option B: Pre-Commit Hook** (Now Active)
```bash
# Just commit normally:
git commit -m "feat: add feature"

# Hook runs automatically
# Blocks if issues found
# Proceeds if clean
```

**Option C: Ask Claude Code**
```
"Run CodeRabbit on my current changes and tell me what needs fixing"
```

**Recommendation**: Use pre-commit hook for automatic checking, ask Claude Code for help fixing issues.

---

### Before Opening PR

**1. Run comprehensive review**:
```bash
coderabbit --plain --base develop > review.txt
```

**2. Review and fix all issues**

**3. Ask Claude Code for help**:
```
"Here's the CodeRabbit review: [paste review.txt]. Please help me fix these issues."
```

**4. Commit fixes**

**5. Open PR** - CodeRabbit will review again automatically

---

### During PR Review

**1. CodeRabbit comments appear on PR**

**2. Fetch review via CLI**:
```bash
gh pr view --json comments
```

**3. Ask Claude Code**:
```
"Fetch CodeRabbit's review on my latest PR and help me address the issues"
```

**4. Claude Code can**:
- Run `gh pr view`
- Parse CodeRabbit comments
- Implement fixes
- Push updates

**5. CodeRabbit re-reviews automatically**

---

## Advanced Features

### Features You're Using

✅ **CLI Reviews** - `coderabbit --plain`
✅ **GitHub PR Reviews** - Automatic on PRs
✅ **GitHub Actions Integration** - `.github/workflows/coderabbit.yml`
✅ **Custom Configuration** - `.coderabbit.yaml`
✅ **Pre-Commit Hook** - Just enabled

### Features You're NOT Using

#### VSCode Extension

**What it is**: Real-time CodeRabbit feedback in your editor

**Install**:
1. Open VSCode
2. Search extensions: "CodeRabbit"
3. Install "CodeRabbit Code Review"
4. Sign in with GitHub account

**What it provides**:
- Inline suggestions as you type
- Real-time feedback
- No need to run CLI
- Integrates with VSCode UI

**Pros**:
- Fastest feedback
- No manual commands
- Works offline (with cached rules)

**Cons**:
- VSCode only
- Another extension to manage
- May be distracting

**Recommendation**: Try it if you use VSCode, see if you like real-time feedback

---

#### Interactive Mode

**What you've used**: `--plain` mode (text output)

**What you haven't tried**: Interactive mode (default)

**Try it**:
```bash
coderabbit  # No flags = interactive mode
```

**What it provides**:
- Browsable interface in terminal
- Navigate between issues with arrow keys
- Expand/collapse details
- Apply fixes interactively

**When to use**:
- Reviewing complex issues
- Want to explore issues interactively
- Have time for detailed review

---

#### AI-Powered Auto-Fix

**What it is**: CodeRabbit can auto-generate fix commits

**How to use** (in PR):
```
@coderabbitai fix this issue
```

**What it does**:
- Generates fix based on issue
- Creates suggested commit
- You review and accept/reject

**Pros**:
- Saves time
- Good for simple issues
- Learn from suggested fixes

**Cons**:
- Not always perfect
- Need to review carefully
- Only works in PRs

**Recommendation**: Try on simple issues, always review before accepting

---

#### CodeRabbit Dashboard

**What it is**: Web interface at app.coderabbit.ai

**Access**: Login with GitHub account

**What you see**:
- All reviews across repos
- Analytics and trends
- Review history
- Configuration management

**Features**:
- Download reports
- See review statistics
- Team analytics (if applicable)
- Manage organization settings

**Recommendation**: Check it out to see review history and trends

---

#### Advanced Linters (Pro Tier)

**What you have**: Basic reviews

**What Pro adds**:
- 40+ integrated linters (ESLint, Semgrep, etc.)
- Advanced security scanning
- Performance analysis
- Test coverage insights

**Cost**: $24-30/month per developer

**Recommendation**: Try 14-day free trial, evaluate if 40+ linters add value

---

## Claude Code + CodeRabbit Workflows

Here are specific workflows where Claude Code and CodeRabbit work together:

### Workflow 1: Review and Fix Loop

**You**:
```
"Run CodeRabbit on my uncommitted changes"
```

**Claude Code**:
```bash
coderabbit --plain --type uncommitted
```

**Claude Code**:
```
Found 3 issues:
1. Unnecessary Riverpod dependency in selection_button.dart
2. Missing accessibility in sport_preferences_screen.dart
3. Nested ternaries in kyle_design.dart

Shall I fix these?
```

**You**: "Yes, fix them"

**Claude Code**:
- Implements all fixes
- Runs CodeRabbit again to verify
- Reports: "All issues resolved!"

---

### Workflow 2: PR Review Response

**CodeRabbit comments on your PR**

**You**:
```
"Fetch CodeRabbit's review on PR #42 and address all issues"
```

**Claude Code**:
```bash
gh pr view 42 --json comments
# Parses CodeRabbit comments
```

**Claude Code**:
```
CodeRabbit found 5 issues on PR #42:
1. Security: Exposed private key
2. Config: Outdated auth pattern
3. Code quality: Complex nested logic
...

I'll fix these now.
```

**Claude Code**:
- Implements fixes
- Commits changes
- Pushes to PR branch
- CodeRabbit auto-reviews updated PR

---

### Workflow 3: Pre-Commit Check

**You**:
```bash
git commit -m "feat: new feature"
```

**Pre-commit hook**:
```
🤖 Running CodeRabbit pre-commit review...
❌ CodeRabbit found issues.
```

**You**:
```
"CodeRabbit blocked my commit. Help me fix the issues."
```

**Claude Code**:
```bash
coderabbit --plain --type uncommitted
# Shows detailed issues
```

**Claude Code**:
```
I see 2 blocking issues:
1. Missing required field validation
2. Potential null pointer exception

Fixing now...
```

**Claude Code**:
- Fixes issues
- You commit again
- Pre-commit hook passes
- Commit succeeds

---

### Workflow 4: Continuous Improvement

**Weekly/Monthly**:

**You**:
```
"Run CodeRabbit on the entire codebase and create a cleanup roadmap"
```

**Claude Code**:
```bash
coderabbit --plain --base develop --type all
```

**Claude Code**:
```
Found 23 issues across the codebase:
- 12 code quality improvements
- 6 performance optimizations
- 3 security suggestions
- 2 accessibility enhancements

Creating prioritized cleanup roadmap...
```

**Claude Code**:
- Creates roadmap document
- Prioritizes by severity
- Estimates effort
- You tackle items over time

---

## Troubleshooting

### Pre-Commit Hook Issues

#### Hook doesn't run
```bash
# Check if executable
ls -la .git/hooks/pre-commit

# Should show: -rwxr-xr-x
# If not:
chmod +x .git/hooks/pre-commit
```

#### Want to bypass once
```bash
git commit --no-verify -m "message"
```

#### Want to disable permanently
```bash
rm .git/hooks/pre-commit
```

---

### Rate Limit Issues

**Symptom**: "Rate limit exceeded" error

**Cause**: Free tier = 1 CLI review/hour, Lite tier = 1/hour, Pro tier = 5/hour

**Solutions**:
1. **Wait**: Rate limit resets after 1 hour
2. **Upgrade**: Pro tier = 5 reviews/hour
3. **Reduce frequency**: Don't run on every commit
4. **Use PR reviews**: Unlimited (only counts CLI reviews)

**Check current usage**:
```bash
coderabbit auth whoami
# Shows your plan and rate limits
```

---

### Claude Code Can't See Output

**Issue**: CodeRabbit runs but Claude Code doesn't see results

**Solution**: Save to file and ask Claude Code to read it
```bash
coderabbit --plain --type uncommitted > review.txt
```

Then:
```
"Read review.txt and help me fix the issues"
```

---

### GitHub Actions Not Running

**Check**:
1. Workflow file exists: `.github/workflows/coderabbit.yml`
2. PR is opened (workflow only runs on PRs, not commits)
3. Check Actions tab on GitHub for errors

**Debug**:
```bash
# Validate workflow syntax
gh workflow view coderabbit.yml
```

---

## What's Not Being Used (Opportunities)

### 1. VSCode Extension
**Status**: Not installed
**Benefit**: Real-time feedback while coding
**Effort**: 5 minutes to install
**Recommendation**: Try it

### 2. Interactive Mode
**Status**: Not tried
**Benefit**: Better UX for exploring issues
**Effort**: Just run `coderabbit` (no flags)
**Recommendation**: Try once to see if you prefer it

### 3. Auto-Fix in PRs
**Status**: Available but not used
**Benefit**: CodeRabbit can auto-fix simple issues
**How**: Comment `@coderabbitai fix this` on PR
**Recommendation**: Try on simple issues

### 4. Dashboard Analytics
**Status**: Not explored
**Benefit**: See review trends, download reports
**Access**: https://app.coderabbit.ai
**Recommendation**: Check it out

### 5. Git-Commit-Helper Integration
**Status**: Not configured
**Benefit**: Smarter integration with your workflow
**Effort**: 30 minutes to implement
**Recommendation**: Let me know if you want this

### 6. Pro Tier Features
**Status**: Using free tier
**Benefit**: 40+ linters, better limits
**Cost**: $24-30/month
**Recommendation**: Try 14-day free trial

---

## Next Steps

### Immediate (Do Now)

1. **Test pre-commit hook**:
```bash
# Make a small change
echo "test" >> README.md

# Try to commit
git commit -m "test: pre-commit hook"

# Should run CodeRabbit automatically
```

2. **Try interactive mode**:
```bash
coderabbit
# Navigate with arrow keys
```

3. **Check GitHub PR integration**:
- Open a test PR
- Wait 1-2 minutes
- See CodeRabbit comment appear

---

### Soon (This Week)

1. **Install VSCode extension** (if you use VSCode):
   - Extensions → Search "CodeRabbit"
   - Install and test

2. **Explore dashboard**:
   - Visit https://app.coderabbit.ai
   - Review your repo statistics

3. **Try auto-fix**:
   - On next PR, comment: `@coderabbitai fix this`
   - See if suggested fix is good

---

### Later (Optional)

1. **Consider Pro tier**:
   - Start 14-day free trial
   - Evaluate 40+ linters
   - Decide if worth $24-30/month

2. **Git-commit-helper integration**:
   - Let me know if you want this
   - I can implement it

3. **Custom workflows**:
   - Define team-specific workflows
   - Automate more of the process

---

## Summary

### What's Working Now

✅ **GitHub PR reviews** - Automatic
✅ **GitHub Actions** - Runs on every PR
✅ **Pre-commit hook** - Blocks bad commits (just added)
✅ **CLI reviews** - Manual when needed
✅ **Custom config** - Mealvana-specific rules

### What Claude Code Can Do

✅ **Run CodeRabbit** - Via CLI
✅ **See CLI output** - Parse and understand issues
✅ **Fetch PR reviews** - Via `gh pr view`
✅ **Fix issues** - Implement suggested changes
✅ **Verify fixes** - Re-run CodeRabbit

### What You Could Add

- VSCode extension (real-time feedback)
- Git-commit-helper integration (smarter workflow)
- Interactive mode usage (better UX)
- Auto-fix in PRs (save time)
- Pro tier features (40+ linters)

---

**Questions? Want me to implement any of these integrations? Just ask!**
