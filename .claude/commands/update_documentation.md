# Documentation Update Command

This command provides comprehensive instructions for updating all project documentation. Follow this systematic approach to ensure all documentation remains accurate and comprehensive.

## Overview

The Mealvana Endurance project has extensive documentation across multiple domains that must stay synchronized with codebase changes:

- `/docs/architecture/` - System architecture and design patterns
- `/docs/business_logic/` - Nutrition algorithms and business rules
- `/docs/database/` - Schema, migrations, and data management
- `/docs/technical/` - Implementation details and integrations
- `/docs/test/` - Testing strategy and implementation status
- `/CLAUDE.md` - Main AI assistant context file

## Step-by-Step Documentation Update Process

### Phase 1: Comprehensive Codebase Research

#### 1.1 Analyze Current Codebase State
```markdown
**Research Tasks:**
- Use mcp__serena tools to analyze current codebase structure
- List all directories under `/lib/features/` to understand feature scope
- Search for all `@riverpod` annotations to identify controllers/providers
- Search for all `@DriftDatabase` annotations to identify database changes
- Find all `main.dart`, `*_service.dart`, `*_repository.dart` files
- Identify all test files and their current status
```

**Tools to Use:**
- `mcp__serena__list_dir` - Map project structure
- `mcp__serena__find_file` - Locate specific file patterns
- `mcp__serena__search_for_pattern` - Find annotations and patterns
- `mcp__serena__get_symbols_overview` - Understand file structures

#### 1.2 Compare Against Existing Documentation
```markdown
**Comparison Tasks:**
- Read all README files in `/docs/` subdirectories
- Compare documented features vs. actual implementation
- Identify gaps between documentation and reality
- Note deprecated or removed features
- Find new features not yet documented
```

#### 1.3 External Technology Research
```markdown
**Research External Dependencies:**
- Use Context7 MCP to get latest documentation for:
  - Flutter/Dart updates
  - Riverpod pattern changes
  - Drift database updates  
  - Supabase integration changes
- Use WebSearch for:
  - New best practices in identified technologies
  - Breaking changes in dependencies
  - Security updates or recommendations
```

**MCP Tools:**
- `mcp__context7__resolve-library-id` - Find library documentation
- `mcp__context7__get-library-docs` - Get latest API docs
- `WebSearch` - Research current best practices and updates

### Phase 2: Stakeholder Research and Requirements

#### 2.1 Ask Strategic Questions
Before updating documentation, ask the user these key questions:

**Architecture Questions:**
- "What new features or controllers have been added since last documentation update?"
- "Have there been any changes to the Andrea Bizzotto FOA patterns we follow?"
- "Are there new external integrations or services being used?"
- "Have any major refactoring or architectural decisions been made?"

**Business Logic Questions:**
- "Has the nutrition algorithm been updated or modified?"
- "Are there new business rules or constraints we need to document?"
- "Have user flows or requirements changed?"
- "Are there new compliance or safety requirements?"

**Technical Questions:**
- "Have there been database schema changes or new migrations?"
- "Are there new testing requirements or frameworks?"
- "Have deployment or CI/CD processes changed?"
- "Are there new environment variables or configuration requirements?"

**Priority Questions:**
- "Which documentation areas are most critical for the current development phase?"
- "Are there specific compliance or audit requirements for documentation?"
- "What level of detail is needed for different audiences (developers vs. stakeholders)?"

#### 2.2 Gather Context from Recent Changes
```markdown
**Git History Analysis:**
- Review recent commits for major changes
- Look for new files or deleted files
- Identify pattern changes in imports or dependencies
- Note any version bumps in pubspec.yaml or package files
```

### Phase 3: Documentation Update Execution

#### 3.1 Architecture Documentation (`/docs/architecture/`)
```markdown
**Update Tasks:**
- Map current feature structure vs. documented structure
- Update FOA compliance examples with actual code
- Document new controllers, services, and repositories
- Update dependency injection patterns
- Revise system integration diagrams
```

**Key Files to Update:**
- `README.md` - Architecture overview
- `foa-compliance.md` - Feature-oriented patterns
- `system-integration.md` - Service relationships

#### 3.2 Business Logic Documentation (`/docs/business_logic/`)
```markdown
**Update Tasks:**
- Compare current algorithm implementation vs. documented algorithms
- Update nutrition calculation formulas if changed
- Document new business rules or constraints
- Update food suitability rules and safety constraints
- Revise macro target calculation documentation
```

**Key Files to Update:**
- `nutrition_algorithms.md` - Core calculation documentation
- `food_safety_rules.md` - Safety constraint documentation
- `macro_targeting.md` - Macro calculation updates

#### 3.3 Database Documentation (`/docs/database/`)
```markdown
**Update Tasks:**
- Document current schema version and all tables
- Update migration documentation with new migrations
- Document new relationships or foreign keys
- Update data flow diagrams
- Document new database access patterns
```

**Key Files to Update:**
- `schema-overview.md` - Complete schema documentation
- `migrations.md` - Migration history and procedures
- `data-flow.md` - Data access patterns

#### 3.4 Technical Documentation (`/docs/technical/`)
```markdown
**Update Tasks:**
- Update integration documentation for external services
- Document new CI/CD processes or deployment changes
- Update environment variable and configuration documentation
- Document new monitoring or analytics integrations
- Update security and compliance documentation
```

**Key Files to Update:**
- `integrations.md` - External service integrations
- `deployment.md` - Deployment and CI/CD processes
- `configuration.md` - Environment and config management

#### 3.5 Testing Documentation (`/docs/test/`)
```markdown
**Update Tasks:**
- Update test implementation status
- Document new test categories or frameworks
- Update coverage metrics and goals
- Document new testing tools or processes
- Update test execution procedures
```

**Key Files to Update:**
- `README.md` - Complete testing strategy and status
- `implementation-status.md` - Current test coverage
- `procedures.md` - Test execution and maintenance

### Phase 4: CLAUDE.md Synchronization

#### 4.1 Update Main Context File
```markdown
**CLAUDE.md Update Tasks:**
- Synchronize project overview with current state
- Update feature list and technical stack information
- Ensure all documentation links are current
- Update development practices and constraints
- Add new important notes for AI assistants
- Update external integration information
- Verify architecture pattern documentation is current
```

#### 4.2 Cross-Reference Validation
```markdown
**Validation Tasks:**
- Ensure all documentation links in CLAUDE.md work
- Verify examples in CLAUDE.md match current codebase
- Check that key architectural decisions are reflected
- Confirm testing strategy alignment
- Validate that new features are properly referenced
```

### Phase 5: Quality Assurance and Validation

#### 5.1 Documentation Review Checklist
```markdown
**Review Tasks:**
- [ ] All new features are documented
- [ ] All deprecated features are removed
- [ ] Code examples are current and working
- [ ] External links are functional
- [ ] Documentation follows consistent formatting
- [ ] Technical accuracy is verified
- [ ] Business logic accuracy is confirmed
- [ ] Database schema matches reality
- [ ] Testing status is current
```

#### 5.2 Stakeholder Validation
Ask the user to review updated documentation for:
- Technical accuracy
- Business requirement alignment
- Completeness of coverage
- Priority of different sections
- Need for additional detail in specific areas

### Phase 6: Implementation Example

#### 6.1 Systematic Approach
```markdown
**Example Update Sequence:**

1. **Start with Architecture**
   - Run: `mcp__serena__list_dir "lib/features" true`
   - Compare against documented features
   - Update architecture documentation

2. **Continue with Database**
   - Read: `lib/shared/database/app_database.dart`
   - Check schema version and migrations
   - Update database documentation

3. **Update Business Logic**
   - Find: All nutrition calculation files
   - Compare algorithms vs. documentation
   - Update business logic documentation

4. **Technical Integration**
   - Search: Configuration and integration files
   - Update technical documentation

5. **Testing Status**
   - Review: Test implementation status
   - Update testing documentation

6. **CLAUDE.md Sync**
   - Update main context file
   - Validate all cross-references
```

## Tools and Commands Reference

### MCP Serena Tools (Primary Codebase Analysis)
```bash
mcp__serena__list_dir           # Map directory structures
mcp__serena__find_file          # Locate specific files
mcp__serena__search_for_pattern # Find code patterns
mcp__serena__get_symbols_overview # Understand file contents
mcp__serena__find_symbol        # Locate specific implementations
```

### Context7 Tools (External Documentation)
```bash
mcp__context7__resolve-library-id  # Find library documentation
mcp__context7__get-library-docs    # Get latest API documentation
```

### Research Tools
```bash
WebSearch    # Research current best practices
WebFetch     # Get specific documentation from URLs
Read         # Analyze local files
```

### Git Analysis
```bash
git log --oneline --since="1 month ago"  # Recent changes
git diff HEAD~10 --stat                  # File change summary
git ls-files "*.dart" | head -20         # Current Dart files
```

## Quality Standards

### Documentation Quality Metrics
- **Accuracy**: All code examples work and are current
- **Completeness**: All major features are documented
- **Consistency**: Uniform formatting and terminology
- **Clarity**: Technical concepts are explained clearly
- **Maintainability**: Documentation is easy to update

### Success Indicators
- New developers can onboard using documentation alone
- AI assistants have complete context for all major features
- Documentation stays synchronized with codebase changes
- Stakeholders can understand system capabilities and constraints
- Compliance requirements are fully documented

## Maintenance Schedule

### Regular Updates (Monthly)
- Review CLAUDE.md for accuracy
- Update implementation status in testing documentation
- Check external links and dependencies

### Major Updates (After Significant Changes)
- Full documentation review using this command
- Complete codebase synchronization
- Stakeholder validation of updates

### Release Updates (Before Major Releases)
- Complete documentation audit
- Update all version references
- Validate deployment documentation

---

**Note**: This documentation update process ensures that all project documentation remains accurate, complete, and useful for both human developers and AI assistants. Following this systematic approach prevents documentation drift and maintains high-quality project documentation standards.