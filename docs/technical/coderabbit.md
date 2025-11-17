# CodeRabbit: AI-Powered Code Review

## Executive Summary

**CodeRabbit** is an AI-powered code review platform that solves the "AI coding bottleneck" - where developers can write code 10x faster with AI tools, but code reviews still take days. It delivers context-aware, actionable code reviews within **minutes** by combining LLM analysis with **40+ industry-standard linters and security tools**.

---

## Table of Contents

1. [What CodeRabbit Is](#what-coderabbit-is)
2. [Key Features](#key-features)
3. [How It Works](#how-it-works)
4. [CLI vs Web Interface](#cli-vs-web-interface)
5. [Integration Points in Development Workflow](#integration-points-in-development-workflow)
6. [CLI Capabilities](#cli-capabilities)
7. [Best Practices](#best-practices)
8. [Pricing & Plans](#pricing--plans)
9. [Comparison to Alternatives](#comparison-to-alternatives)
10. [Mealvana Endurance Integration](#mealvana-endurance-integration)

---

## What CodeRabbit Is

### Core Purpose
CodeRabbit accelerates code review from hours/days to minutes, serving as an AI assistant that augments (not replaces) human reviewers.

### The Problem It Solves
- **AI Coding Bottleneck**: Tools like Claude Code enable fast coding, but manual reviews remain slow
- **Review Fatigue**: Senior engineers spend excessive time reviewing AI-generated PRs
- **Inconsistent Standards**: Manual reviews can miss issues or apply standards inconsistently
- **Context Loss**: By review time, developers have moved on and lost implementation context

### AI Technology
- **o3 & o4-mini**: Reasoning-heavy models for complex tasks (architecture issues, refactoring, multi-line bugs)
- **GPT-4.1**: 1M token context for summarization, docstrings, routine QA
- **LanceDB Vector Database**: Semantic searches across millions of code interactions with millisecond response
- **Multi-Step Review System**: Clones repos into sandboxed environments, enriches diffs with context from code history, linters, code graphs, issue tickets, and developer conversations

### Infrastructure
- **Google Cloud Run**: Scalable isolated execution
- **Peak Capacity**: 200+ instances handling 10 requests/second
- **Instance Specs**: 8 vCPUs, 32GB memory each
- **Processing**: Ephemeral, in-memory only (no code retention post-completion)

---

## Key Features

### Core Review Capabilities

#### Enhanced PR Comprehension
- AI-generated summaries explaining architectural impact
- File-by-file breakdowns of modifications
- Visual flow diagrams showing system effects
- Interactive chat for clarifying questions

#### Context-Aware Analysis
- Learns from team interactions and coding preferences
- Reads project standards from `CLAUDE.md`, `.cursorrules` files
- Creates dependency maps and code graphs
- Remembers feedback and applies to future reviews

#### Line-by-Line Code Review
- Detailed suggestions with specific line references
- Actionable feedback with fix suggestions
- 1-click fixes for common issues

#### Security & Quality Analysis
- Integrates **40+ linters and SAST tools** (Pro plan)
- Detects race conditions, memory leaks, security vulnerabilities
- Secret detection via Gitleaks
- Vulnerability scanning via Semgrep
- Infrastructure scanning via Checkov

#### Automatic Code Generation
- Comprehensive unit test generation covering edge cases
- Automatic documentation and docstrings
- Test insertion capabilities

### Platform Integration

**Supported Platforms:**
- GitHub (including Enterprise)
- GitLab (including Self-Managed)
- Azure DevOps
- Bitbucket (Cloud and Server)

**Issue Trackers:**
- GitHub Issues
- GitLab Issues
- Jira
- Linear

**CI/CD Pipelines:**
- GitHub Actions
- CircleCI
- Jenkins
- Automatic pipeline configuration validation

### Learning & Customization

- **Team Standards Enforcement**: Applies organization-specific coding guidelines
- **Pattern Learning**: (Paid tier) Learns from team's codebase history
- **Custom Instructions**: Supports custom review guidelines via configuration
- **Feedback Loop**: Improves suggestions based on developer corrections

---

## How It Works

### Review Process Flow

1. **Trigger**: PR opened or CLI command executed
2. **Clone**: Repository cloned into sandboxed environment
3. **Context Enrichment**: System gathers:
   - Code history and diffs
   - Linter outputs from 40+ tools
   - Code graph analysis (dependency mapping)
   - Issue tracker context (Jira/Linear tickets)
   - Previous developer conversations
   - Team coding guidelines
4. **Multi-Model Analysis**:
   - GPT-4.1 processes summarization and routine checks
   - o3/o4-mini handles complex reasoning tasks
   - LanceDB performs semantic searches across codebase
5. **Signal Filtering**: LLM filters raw tool output to surface only actionable findings
6. **Feedback Delivery**: Comments posted directly in PR or CLI output
7. **Iteration**: Developers can chat with CodeRabbit for clarifications or request changes

### Analysis Depth

- **Static Analysis**: 40+ linters run automatically
- **Security Scanning**: SAST tools check for vulnerabilities
- **Architectural Impact**: Downstream effects across codebase
- **Code Graph Analysis**: Dependency relationships and call paths
- **Real-time Web Search**: (Advanced feature) For up-to-date best practices
- **Deterministic Calculations**: Performance-optimized, sub-second responses

### Data Privacy & Security

- **Ephemeral Processing**: All LLM queries exist in-memory only
- **Zero Retention**: No code stored after completion
- **No Training**: Customer code never used for model training
- **Organization Isolation**: Data handling isolated per organization
- **Compliance**: SOC 2 Type II audited annually, GDPR compliant

---

## CLI vs Web Interface

### Web Interface (PR Reviews)

**Use Case**: Traditional PR review workflow

**Features:**
- Automatic reviews triggered on PR open/update
- Visual flow diagrams and architectural summaries
- Interactive chat within PR comments
- Team collaboration features
- Historical learning from all team PRs
- Full 40+ linter integration (Pro)
- Integration with issue trackers (Jira/Linear)

**Best For:**
- Team code reviews
- Production-ready code
- Comprehensive feedback with documentation
- Collaborative review discussions

### CLI Tool

**Use Case**: Pre-commit reviews of local changes

**Features:**
- Reviews uncommitted (working directory) changes
- Reviews committed (staged) changes
- Three output modes:
  - **Interactive**: Full browsable interface
  - **Plain text**: Detailed feedback with fixes
  - **Prompt-only**: Minimal output for AI agents
- Reads project standards (`CLAUDE.md`, `.cursorrules`)
- Instant feedback while context is fresh
- AI agent integration optimized

**Best For:**
- Individual developers
- Pre-commit validation
- Rapid iteration during development
- AI coding agent workflows (Cursor, Claude Code)

**Rate Limits:**
- **Free/Lite**: 1 review/hour
- **Pro**: 5 reviews/hour

### IDE Extension (VSCode)

**Use Case**: In-editor reviews before committing

**Features:**
- Real-time feedback on code as you type
- Reviews staged and unstaged commits
- Same context-aware analysis as platform
- No PR required

**Best For:**
- Catching issues immediately
- Reducing PR review comments
- Learning best practices while coding

---

## Integration Points in Development Workflow

### Where CodeRabbit Fits

```
Developer Writes Code → [CLI Review] → Git Commit →
Push to Branch → Open PR → [Web Review] →
Team Discussion → Merge → [CI/CD Validation]
```

### GitHub/GitLab Integration

**Setup Time**: ~5 minutes

**Installation:**
1. Install CodeRabbit app from GitHub/GitLab marketplace
2. Grant repository access permissions
3. Optional: Configure organization-level settings
4. Optional: Add `.coderabbit.yaml` to repositories

**Automatic Triggers:**
- PR opened
- PR updated (new commits)
- Manual: Use `@coderabbitai review` comment
- Manual: Use `@coderabbitai configuration` to see current config

**Review Commands (in PR comments):**
- `@coderabbitai review` - Re-run full review
- `@coderabbitai configuration` - Show current configuration
- `@coderabbitai help` - List available commands
- Interactive chat for clarifications

### CI/CD Pipeline Integration

**GitHub Actions Example:**

```yaml
name: 'CodeRabbit PR Review'
on: [pull_request]
permissions:
  contents: read
  pull-requests: write
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: coderabbitai/ai-pr-reviewer@latest
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Benefits:**
- Automatic static analysis on every build
- Pipeline configuration validation (GitHub Actions, CircleCI)
- Catches misconfigurations early
- No disruption to existing workflows

**Supported CI/CD:**
- GitHub Actions (actionlint validation)
- CircleCI (pipeline analysis)
- Jenkins
- GitLab CI

### Configuration Methods

**1. Organization-Level Settings (Web UI)**
- Apply consistent behavior across all repositories
- Best for standardized coding practices
- Single configuration point

**2. Repository-Level Settings (Web UI)**
- Per-project customization
- Override organization defaults
- Best for diverse projects

**3. `.coderabbit.yaml` File (Recommended)**
- Version-controlled configuration
- Infrastructure-as-code approach
- Configuration changes go through code review
- Maintain history with application

**Example `.coderabbit.yaml`:**
```yaml
reviews:
  profile: "assertive"  # or "chill"
  request_changes_workflow: true
  high_level_summary: true
  poem: false
  auto_review:
    enabled: true
    drafts: false
language: "en-US"
tools:
  gitleaks:
    enabled: true
  semgrep:
    enabled: true
```

---

## CLI Capabilities

### Authentication

```bash
# Login (OAuth via browser)
coderabbit auth login

# Abbreviated
cr auth login

# Check authentication status
coderabbit auth whoami
```

### Review Commands

**Basic Reviews:**
```bash
# Interactive mode (default) - full browsable interface
coderabbit

# Plain text mode - detailed feedback
coderabbit --plain

# Prompt-only mode - minimal output for AI agents
coderabbit --prompt-only
```

**Scope Options:**
```bash
# Review all changes (committed + uncommitted)
coderabbit --type all

# Review only committed/staged changes
coderabbit --type committed

# Review only working directory (uncommitted) changes
coderabbit --type uncommitted
```

**Branch Comparison:**
```bash
# Compare against specific base branch
coderabbit --base develop
coderabbit --base master
```

**Custom Guidelines:**
```bash
# Include specific configuration files
coderabbit --config CLAUDE.md,.cursorrules
```

### AI Agent Integration Workflow

**Recommended Pattern:**
```bash
# 1. Run review in background for uncommitted changes
coderabbit --prompt-only --type uncommitted

# 2. AI agent evaluates findings
# 3. Agent implements critical fixes only
# 4. Run CodeRabbit again to verify
coderabbit --prompt-only --type uncommitted

# 5. Limit iterations to prevent infinite loops (max 2-3)
```

**Supported AI Agents:**
- Claude Code
- Cursor CLI
- Gemini CLI
- Any CLI-based coding agent

### Detection Capabilities

The CLI catches:
- Logic errors and bugs
- Race conditions
- Memory leaks
- Security vulnerabilities
- Code smells
- Architecture issues
- Hallucinations from AI code generation
- Missing unit tests
- Style violations

### Fix Application

- **Simple fixes**: Applied instantly via CLI
- **Complex problems**: Routed to AI agents with context
- **Verification**: Re-run to confirm no regressions

### Platform Support

- ✅ macOS (Intel and Apple Silicon)
- ✅ Linux
- ❌ Windows (currently unavailable)

---

## Best Practices

### Configuration Best Practices

#### 1. Use `.coderabbit.yaml` for Version Control
- Configuration changes reviewed like code
- Maintains history with application
- Enables GitOps workflows
- Example: Place in repository root

#### 2. Start with Organization Defaults
- Apply common standards across all repos
- Override at repository level as needed
- Reduces configuration duplication

#### 3. Customize Review Profile
- `assertive`: More comprehensive feedback
- `chill`: Focuses on critical issues only
- Adjust based on team preferences and project stage

#### 4. Add Custom Review Instructions
Based on your codebase patterns:
```yaml
custom_instructions: |
  - Follow Flutter best practices
  - Use Riverpod for state management
  - Maintain Andrea Bizzotto's FOA architecture
  - All UI text must come from ContentService
```

### Team Workflow Best Practices

#### 1. Use CLI for Pre-Commit Reviews
- Catch issues before PR creation
- Reduce PR review comments by 50-70%
- Fix problems while context is fresh
- Run `coderabbit --plain` before commits

#### 2. Review Configuration with Team
- Use `@coderabbitai configuration` command in PRs
- Copy output to `.coderabbit.yaml`
- Discuss and adjust team preferences
- Version control agreed-upon standards

#### 3. Leverage Learning Feedback
- When CodeRabbit is wrong, correct it in PR comments
- System learns and applies preferences to future reviews
- Build team-specific knowledge over time

#### 4. Enable Selective Tool Integration
```yaml
tools:
  dart_analyze:
    enabled: true
  semgrep:
    enabled: true
  gitleaks:
    enabled: true
  # Disable noisy tools
  oxlint:
    enabled: false
```

#### 5. Set Appropriate Review Thresholds
- Enable `request_changes_workflow` for critical projects
- Use `drafts: false` to skip draft PR reviews
- Configure `high_level_summary: true` for architectural context

### AI Agent Integration Best Practices

#### 1. Autonomous Generate-Review-Iterate Cycle
```bash
# Agent generates code
# (e.g., Claude Code, Cursor)

# CodeRabbit reviews
coderabbit --prompt-only --type uncommitted

# Agent fixes critical issues only

# Verify (limit to 2-3 iterations)
coderabbit --prompt-only --type uncommitted
```

#### 2. Prevent Infinite Loops
- Set maximum iteration limit (2-3 cycles)
- Focus on critical issues only
- Leave minor issues for human review

#### 3. Use Prompt-Only Mode
- Minimal output optimized for agent parsing
- Faster processing
- Cleaner agent integration

### Security & Compliance

#### 1. Review Open Source Projects Freely
- CodeRabbit Pro is free for public repositories
- No credit card required
- Full feature access

#### 2. Enterprise Self-Hosting
- Available for 500+ user organizations
- Keeps code within infrastructure
- Custom SLAs and support

#### 3. Trust but Verify
- CodeRabbit augments, doesn't replace human reviewers
- Always review security-critical changes manually
- Use CodeRabbit to catch what humans miss

### Performance Optimization

#### 1. Focus on Changed Files
- CodeRabbit automatically scopes to diffs
- Reduces review time significantly
- Sub-second analysis for most changes

#### 2. Use Learnings Feature (Pro)
- Paid tier learns from team history
- Improves relevance over time
- Reduces false positives

#### 3. Tune Linter Selection
- Enable only relevant tools
- Disable noisy linters
- Balance comprehensive vs. actionable feedback

---

## Pricing & Plans

### Pricing Model

CodeRabbit charges **per contributing developer** who creates pull requests, not per repository or review count.

### Plan Comparison

| Feature | Free | Lite ($12-15/mo) | Pro ($24-30/mo) | Enterprise (Custom) |
|---------|------|------------------|-----------------|---------------------|
| **PR Summaries** | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited |
| **PR Reviews (Public)** | ✅ Full | ✅ Full | ✅ Full | ✅ Full |
| **PR Reviews (Private)** | ❌ | ✅ Basic | ✅ Full | ✅ Full |
| **Line-by-Line Reviews** | ❌ | ✅ | ✅ | ✅ |
| **40+ Linters & SAST** | ❌ | ❌ | ✅ | ✅ |
| **Jira/Linear Integration** | ❌ | ❌ | ✅ | ✅ |
| **Product Analytics** | ❌ | ❌ | ✅ | ✅ |
| **Docstrings Generation** | ❌ | ❌ | ✅ | ✅ |
| **Unit Test Generation** | ❌ | ❌ | ✅ | ✅ |
| **CLI Reviews** | 1/hour | 1/hour | 5/hour | Custom |
| **Pattern Learnings** | ❌ | ❌ | ✅ | ✅ |
| **Self-Hosting** | ❌ | ❌ | ❌ | ✅ |
| **SLA Support** | ❌ | ❌ | ❌ | ✅ |
| **Dedicated CSM** | ❌ | ❌ | ❌ | ✅ |

### Pricing Details

**Free Plan:**
- $0/month forever for public repositories
- Full Pro features for open source
- Unlimited summaries for private repos
- 14-day Pro trial for private repos

**Lite Plan:**
- $12/month per developer (annual billing)
- $15/month (monthly billing)
- Entry-level AI code reviews
- No linter integration

**Pro Plan (Recommended):**
- $24/month per developer (annual billing)
- $30/month (monthly billing)
- Sandboxed review environment
- 40+ linters and SAST tools
- Issue tracker integration
- Custom reports and analytics
- Advanced features (tests, docs generation)

**Enterprise Plan:**
- Custom pricing based on organization size
- Self-hosting options
- AWS/GCP marketplace payments
- Agreement redlines
- Vendor security reviews
- Onboarding assistance
- Dedicated customer success manager

### Key Details

- **No Repository Limits**: Unlimited repos on all plans
- **No Review Limits**: Unlimited PR reviews on all plans
- **14-Day Free Trial**: Pro features for entire organization
- **No Credit Card**: Trial doesn't require payment info
- **Pay for Active Contributors**: Only charged for developers who create PRs

---

## Comparison to Alternatives

### CodeRabbit vs Traditional Code Review Tools

| Aspect | Traditional Tools | CodeRabbit |
|--------|-------------------|------------|
| **Speed** | Hours to days | Minutes |
| **Consistency** | Varies by reviewer | Consistent standards |
| **Coverage** | Depends on reviewer attention | 40+ automated tools |
| **Context** | Often lost by review time | Real-time, context-fresh |
| **Learning** | Institutional knowledge siloed | System learns team preferences |
| **Scalability** | Limited by human capacity | Scales infinitely |

**Key Advantage**: CodeRabbit is 10x faster while catching 3x more bugs than manual reviews alone.

### CodeRabbit vs AI Code Review Alternatives

#### vs Qodo Merge (CodiumAI)
- **Qodo**: Open source, strong security focus, all platforms
- **CodeRabbit**: Broader feature set, better team learning, 40+ tool integration
- **Winner**: CodeRabbit for teams; Qodo for strict security requirements

#### vs CodeAnt AI
- **CodeAnt**: Comprehensive platform combining review + quality + security
- **CodeRabbit**: More focused on review workflow, deeper PR integration
- **Winner**: Depends on whether you need all-in-one platform (CodeAnt) or best-in-class review (CodeRabbit)

#### vs GitHub Copilot
- **Copilot**: Code generation primary, reviews secondary (quality concerns)
- **CodeRabbit**: Purpose-built for reviews, specialized multi-model approach
- **Winner**: CodeRabbit significantly better for code review quality

#### vs Greptile
- **Greptile**: Deeper codebase analysis capabilities
- **CodeRabbit**: Better workflow integration, team learning
- **Winner**: Situational - Greptile for analysis depth, CodeRabbit for daily workflow

### Unique CodeRabbit Differentiators

1. **Multi-Model Architecture**: Specialized models for different review tasks (o3/o4 for reasoning, GPT-4.1 for summarization)
2. **40+ Tool Integration**: Signal-first approach filtering noise from linters/SAST
3. **LanceDB Vector Database**: Millisecond semantic searches across codebase
4. **Team Learning**: Remembers preferences and applies to future reviews
5. **Three Interfaces**: Web (PR), CLI (pre-commit), IDE (real-time)
6. **Free for Open Source**: Full Pro features forever for public repos
7. **Visual Diagrams**: Architecture flow diagrams showing system impact
8. **1-Click Fixes**: Committable fix suggestions for common issues

---

## Mealvana Endurance Integration

### Immediate Actions

#### 1. Test CLI (Already Authenticated ✓)
```bash
# Test pre-commit reviews
coderabbit --plain --type uncommitted

# Review current changes
coderabbit --base develop
```

#### 2. Add GitHub Integration
- Install CodeRabbit app from GitHub Marketplace
- Free 14-day Pro trial for private repo
- Start with organization-level defaults

#### 3. Create `.coderabbit.yaml`

Place this configuration in your repository root:

```yaml
reviews:
  profile: "assertive"
  request_changes_workflow: true
  high_level_summary: true
  poem: false  # No emojis per project instructions
  auto_review:
    enabled: true
    drafts: false
language: "en-US"
custom_instructions: |
  - Follow Andrea Bizzotto's Feature-Oriented Architecture (FOA)
  - Use Riverpod @riverpod AsyncNotifier patterns (NEVER StateNotifier)
  - All UI text must come from ContentService (no hardcoded strings)
  - Controllers contain business logic only (no UI, no navigation)
  - UI screens contain only UI logic (no underscore methods with business logic)
  - Follow Flutter and Dart best practices
  - Maintain Drift database schema patterns (v1 baseline)
  - Use AsyncValue.guard for error handling in controllers
  - Include part directive for code generation (@riverpod, @DriftDatabase)
  - Follow offline-first architecture (write to Drift first)
  - Use dependency injection via Riverpod (no static methods)
  - Respect privacy-first design (device_id based auth)
tools:
  # Enable security scanning
  gitleaks:
    enabled: true
  semgrep:
    enabled: true
  # Disable noisy tools if needed
  # oxlint:
  #   enabled: false
```

#### 4. Add GitHub Actions Integration (Optional)

Create `.github/workflows/coderabbit.yml`:

```yaml
name: 'CodeRabbit PR Review'
on: [pull_request]
permissions:
  contents: read
  pull-requests: write
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: coderabbitai/ai-pr-reviewer@latest
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Workflow Integration for Your Project

```bash
# 1. Development (use CLI)
flutter run
# Make changes
coderabbit --plain --type uncommitted
# Fix issues
git add .

# 2. Commit (use git-commit-helper agent)
# Your existing agent handles this

# 3. Push & PR (CodeRabbit web review)
git push origin feature-branch
# Open PR - CodeRabbit auto-reviews

# 4. CI/CD (existing GitHub Actions)
# Your tests run, CodeRabbit provides additional validation
```

### Value Proposition for Mealvana Endurance

- **Speed**: Reduce review time for your solo/small team project
- **Quality**: Catch FOA violations, ContentService misuse, database issues
- **Architecture Compliance**: Enforce Andrea Bizzotto patterns automatically
- **Learning**: Free for open source if you open-source later
- **Cost**: $24-30/month Pro if needed; free tier may suffice for solo dev

### Project-Specific Detection Capabilities

CodeRabbit can catch common issues in this project:

**FOA Architecture Violations:**
- Business logic in UI screens (underscore methods like `_generateMacros()`)
- UI logic in controllers (navigation, loading spinners)
- Missing `@riverpod` annotations
- Using `StateNotifier` instead of `AsyncNotifier`

**Content Management Issues:**
- Hardcoded UI text instead of ContentService
- Missing content fallbacks
- Algorithm parameters in code instead of content JSON

**Database Issues:**
- Drift schema violations
- Missing offline-first writes
- Improper migration patterns

**Riverpod Pattern Issues:**
- Missing `part` directive for code generation
- Not using `AsyncValue.guard` for error handling
- Missing `ref.invalidateSelf()` for refresh patterns

**Security Issues:**
- Secret leaks (via Gitleaks)
- SQL injection vulnerabilities
- Insecure data handling

### Evaluation Period

**Week 1-2 (Free Trial):**
- Test CLI on 5-10 commits
- Open 2-3 PRs to test web review
- Evaluate suggestion quality for Flutter/Dart
- Check FOA pattern recognition
- Test detection of ContentService violations

**Decision Point:**
- If catching 3+ issues per PR → Pro tier worth it ($24-30/month)
- If mostly noise → Use free tier for summaries only
- If helpful learning tool → Great for solo developer education
- If FOA enforcement is valuable → Consider paid tier for pattern learning

---

## Resources

### Official Documentation
- [CodeRabbit Documentation](https://docs.coderabbit.ai/) - Complete platform documentation
- [CodeRabbit CLI Overview](https://docs.coderabbit.ai/cli/overview) - CLI-specific guide
- [CodeRabbit Introduction](https://docs.coderabbit.ai/overview/introduction) - Platform overview
- [Linters & SAST Tools](https://docs.coderabbit.ai/tools) - Integrated tools reference
- [CodeRabbit Pricing](https://www.coderabbit.ai/pricing) - Official pricing page
- [CodeRabbit FAQ](https://www.coderabbit.ai/faq) - Common questions

### Technical Articles
- [How CodeRabbit Built with Google Cloud Run](https://cloud.google.com/blog/products/ai-machine-learning/how-coderabbit-built-its-ai-code-review-agent-with-google-cloud-run) - Infrastructure architecture
- [CodeRabbit + OpenAI Case Study](https://openai.com/index/coderabbit/) - o3, o4-mini, GPT-4.1 integration
- [LanceDB Case Study](https://lancedb.com/blog/case-study-coderabbit/) - Vector database implementation

### Configuration Guides
- [Configuration Overview](https://docs.coderabbit.ai/guides/configuration-overview) - Setup best practices
- [GitHub Actions Integration](https://dev.to/coderabbitai/how-to-run-static-analysis-on-your-cicd-pipelines-using-ai-3cl4) - CI/CD setup

---

## License & Compliance

CodeRabbit is:
- **SOC 2 Type II** certified (audited annually)
- **GDPR compliant**
- **Zero data retention** (code not stored post-review)
- **No model training** on customer code

---

**Last Updated**: 2025-11-17
**Authentication Status**: ✅ Authenticated as lbm54
**Project Phase**: Evaluation (14-day Pro trial recommended)
