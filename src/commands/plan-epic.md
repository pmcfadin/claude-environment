---
description: Plan a feature as a GitHub epic with sequenced child issues. Use for "plan", "brainstorm", "epic", "break down", "decompose"
argument-hint: [feature-description]
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *)
model: opus
---

# Plan Epic: $ARGUMENTS

You are a senior software architect planning a feature epic. Your job is to deeply understand the codebase, then decompose the feature into well-sequenced, implementable child issues on GitHub.

## Phase 1: Understand the Codebase

Before planning anything, explore the project thoroughly:

1. **Read CLAUDE.md** (if it exists) to understand project conventions, tech stack, and patterns
2. **Glob for project structure**: `**/*.{ts,tsx,js,jsx,py,go,rs,java}` (adapt to the stack)
3. **Grep for related code**: Search for keywords related to "$ARGUMENTS"
4. **Read key files**: Entry points, routers, schemas, config files, test setup
5. **Check existing tests**: Understand the test infrastructure and patterns

Build a mental model of:
- Tech stack and framework
- Directory structure and conventions
- Existing patterns for similar features
- Test infrastructure (framework, helpers, fixtures)
- CI/CD setup (if visible)

## Phase 2: Clarify Scope

Ask the user 2-3 targeted questions about:
- **Scope boundaries**: What's explicitly in vs out of scope?
- **Priority trade-offs**: If time-constrained, what's the must-have vs nice-to-have?
- **Technical preferences**: Any specific libraries, patterns, or approaches they prefer?

Wait for answers before proceeding.

## Phase 3: Create the Epic

### 3a. Create the parent epic issue

Use the issue schema from `~/.claude/skills/epic-orchestration/references/issue-schema.md`.

```bash
gh issue create \
  --title "Epic: [descriptive title]" \
  --label "epic" \
  --body "[epic body following template]"
```

Capture the epic issue number from the output.

### 3b. Create child issues in dependency order

For each child issue:

1. Determine **affected files** from your codebase exploration
2. Write **specific, testable acceptance criteria** (not vague descriptions)
3. Identify **dependencies** on other child issues
4. Estimate **complexity** (S/M/L)

Create issues with:
```bash
gh issue create \
  --title "[concise action description]" \
  --label "task" \
  --label "complexity:[s|m|l]" \
  --body "[child issue body following template]"
```

### 3c. Update the epic with child issue links

After all child issues are created, update the epic body with the checklist:
```bash
gh issue edit [EPIC_NUMBER] --body "[updated body with child issue checklist]"
```

## Phase 4: Output the Dependency Graph

Display a clear dependency graph showing:
- Issue numbers and titles
- Which issues block which
- Suggested execution order
- Complexity estimates

Example format:
```
Epic #42: Add User Authentication

  #43 [S] Set up auth middleware        (no deps)
  #44 [M] Create user model + migration (no deps)
  #45 [M] Implement login endpoint      (blocked by #43, #44)
  #46 [S] Add session management        (blocked by #45)
  #47 [L] Build login UI                (blocked by #45)
  #48 [M] Add auth tests                (blocked by #46, #47)

Parallel tracks: #43 and #44 can run simultaneously
Critical path: #44 -> #45 -> #47 -> #48
```

## Rules

- **Read before planning**: Never create issues about code you haven't explored
- **Small issues**: Each issue should be completable in a single focused session
- **Testable criteria**: Every acceptance criterion must be verifiable
- **Explicit dependencies**: If issue B needs code from issue A, say so
- **No over-decomposition**: 4-8 issues per epic is ideal. Don't create issues for trivial tasks
- **YAGNI**: Only include issues for what was requested, not "nice to haves"
