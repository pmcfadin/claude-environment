#!/bin/bash
# Epic Orchestration System Installer for Claude Code
# Installs: /plan-epic, /run-epic, /epic-status commands
#           task-builder, task-reviewer agents
#           Stop hook for autonomous execution
#           GitHub issue templates and labels
#
# Usage:
#   bash install.sh              # Install everything
#   bash install.sh --uninstall  # Remove everything (restores settings.json backup)
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills/epic-orchestration"
ORCH_DIR="$CLAUDE_DIR/orchestrator"
SCRIPTS_DIR="$ORCH_DIR/scripts"
STATE_DIR="$ORCH_DIR/state"
REFS_DIR="$SKILLS_DIR/references"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Uninstall ────────────────────────────────────────────────────────────────

if [ "${1:-}" = "--uninstall" ]; then
  echo -e "${YELLOW}Uninstalling Epic Orchestration System...${NC}"
  echo ""

  # Remove commands
  rm -f "$COMMANDS_DIR/plan-epic.md"
  rm -f "$COMMANDS_DIR/run-epic.md"
  rm -f "$COMMANDS_DIR/epic-status.md"
  ok "Removed commands"

  # Remove agents
  rm -f "$AGENTS_DIR/task-builder.md"
  rm -f "$AGENTS_DIR/task-reviewer.md"
  ok "Removed agents"

  # Remove skill
  rm -rf "$SKILLS_DIR"
  ok "Removed skill"

  # Remove orchestrator
  rm -rf "$ORCH_DIR"
  ok "Removed orchestrator scripts and state"

  # Restore settings backup if it exists
  if [ -f "$CLAUDE_DIR/settings.json.pre-epic-orchestrator" ]; then
    cp "$CLAUDE_DIR/settings.json.pre-epic-orchestrator" "$CLAUDE_DIR/settings.json"
    ok "Restored settings.json from backup"
  else
    warn "No settings.json backup found. You may need to manually remove the hooks from ~/.claude/settings.json"
  fi

  echo ""
  ok "Uninstall complete. Restart Claude Code to apply changes."
  exit 0
fi

# ─── Prerequisites ────────────────────────────────────────────────────────────

echo -e "${BLUE}Epic Orchestration System Installer${NC}"
echo "===================================="
echo ""

MISSING=()

if ! command -v gh &>/dev/null; then
  MISSING+=("gh (GitHub CLI) - install: https://cli.github.com/")
fi

if ! command -v jq &>/dev/null; then
  MISSING+=("jq (JSON processor) - install: brew install jq / apt install jq")
fi

if ! command -v claude &>/dev/null; then
  MISSING+=("claude (Claude Code CLI) - install: https://docs.anthropic.com/en/docs/claude-code")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  error "Missing prerequisites:"
  for dep in "${MISSING[@]}"; do
    echo "  - $dep"
  done
  echo ""
  error "Install the missing dependencies and try again."
  exit 1
fi

# Check gh auth
if ! gh auth status &>/dev/null 2>&1; then
  error "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

ok "All prerequisites met"
echo ""

# ─── Create Directories ──────────────────────────────────────────────────────

info "Creating directories..."
mkdir -p "$COMMANDS_DIR" "$AGENTS_DIR" "$REFS_DIR" "$SCRIPTS_DIR" "$STATE_DIR"
ok "Directories created"

# ─── Backup hey-claude.md ────────────────────────────────────────────────────

if [ -f "$COMMANDS_DIR/hey-claude.md" ]; then
  echo ""
  warn "Found existing hey-claude.md command."
  read -r -p "  Back up and retire it? (y/N) " RETIRE_HC
  if [[ "$RETIRE_HC" =~ ^[Yy]$ ]]; then
    cp "$COMMANDS_DIR/hey-claude.md" "$COMMANDS_DIR/hey-claude.md.bak"
    rm "$COMMANDS_DIR/hey-claude.md"
    ok "hey-claude.md backed up to hey-claude.md.bak and removed"
  else
    info "Keeping hey-claude.md as-is"
  fi
fi

# ─── Write Commands ──────────────────────────────────────────────────────────

info "Writing commands..."

cat > "$COMMANDS_DIR/plan-epic.md" << 'CMDEOF'
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
CMDEOF
ok "plan-epic.md"

cat > "$COMMANDS_DIR/run-epic.md" << 'CMDEOF'
---
description: Execute a GitHub epic's tasks autonomously with builder/reviewer subagents. Use for "run epic", "execute epic", "start sprint"
argument-hint: [epic-issue-number]
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *), Bash(jq *), Task
model: opus
---

# Run Epic: #$ARGUMENTS

You are the epic orchestrator. You coordinate autonomous execution of a GitHub epic by delegating work to specialized subagents. You do NOT write code yourself.

## Phase 1: Load the Epic

### 1a. Fetch the epic

```bash
gh issue view $ARGUMENTS --json number,title,body,state
```

If the epic is closed or doesn't have the `epic` label, stop and inform the user.

### 1b. Fetch child issues

```bash
gh issue list --search "Part of Epic #$ARGUMENTS" --json number,title,body,state,labels --limit 50
```

### 1c. Parse dependencies

For each child issue, extract dependencies from the body by looking for:
- `Blocked by: #N`
- `Blocked by: #N, #M`

Build a dependency map: `{ issue_number: [blocked_by_numbers] }`

### 1d. Check for resumable state

```bash
cat ~/.claude/orchestrator/state/active-epic.json 2>/dev/null
```

If state exists for this epic, resume from it. If state exists for a DIFFERENT epic, inform the user and ask whether to abandon it.

## Phase 2: Create Task DAG

### 2a. Create tasks

For each OPEN child issue, create a task:

Use `TaskCreate` with:
- **subject**: `#NUMBER - TITLE`
- **description**: The full issue body
- **activeForm**: `Working on #NUMBER - TITLE`

### 2b. Set dependencies

For each task with dependencies, use `TaskUpdate` with `addBlockedBy` pointing to the task IDs of the dependency issues.

### 2c. Write state file

Write the state to `~/.claude/orchestrator/state/active-epic.json`:

```bash
cat > ~/.claude/orchestrator/state/active-epic.json << 'STATEEOF'
{
  "epic_number": EPIC_NUM,
  "epic_title": "TITLE",
  "repo": "OWNER/REPO",
  "tasks": {
    "ISSUE_NUM": { "task_id": "TASK_ID", "status": "pending", "attempts": 0 }
  }
}
STATEEOF
```

Use `jq` to build this properly from the data you have. Get the repo with:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## Phase 3: Execute Loop

This is the core loop. Repeat until all tasks are completed or blocked:

### 3a. Find the next task

Use `TaskList` to find tasks that are:
- Status: `pending`
- Not blocked by any incomplete tasks

Pick the first unblocked pending task (lowest issue number for deterministic ordering).

### 3b. Start the task

1. `TaskUpdate` the task to `in_progress`
2. Update the state file:
   ```bash
   jq '.tasks["ISSUE_NUM"].status = "in_progress" | .tasks["ISSUE_NUM"].attempts += 1' \
     ~/.claude/orchestrator/state/active-epic.json > /tmp/epic-state-tmp.json && \
     mv /tmp/epic-state-tmp.json ~/.claude/orchestrator/state/active-epic.json
   ```
3. Post a GitHub comment:
   ```bash
   gh issue comment ISSUE_NUM --body "Starting autonomous implementation (attempt N)"
   ```

### 3c. Spawn task-builder

Use the `Task` tool to spawn a task-builder subagent:

```
subagent_type: general-purpose
model: sonnet
prompt: |
  You are a task-builder agent. Read ~/.claude/agents/task-builder.md for your full instructions.

  ## Your Task

  **Issue #NUMBER**: TITLE

  ISSUE_BODY_HERE

  ## Previous Attempt Feedback (if retry)
  FEEDBACK_IF_ANY

  Implement this issue completely following the task-builder instructions.
```

### 3d. Spawn task-reviewer

After the builder completes, get the diff and spawn a reviewer:

```bash
git diff HEAD~1 --stat
git diff HEAD~1
```

Use the `Task` tool to spawn:

```
subagent_type: general-purpose
model: sonnet
prompt: |
  You are a task-reviewer agent. Read ~/.claude/agents/task-reviewer.md for your full instructions.

  ## Issue #NUMBER: TITLE

  ### Acceptance Criteria
  CRITERIA_FROM_ISSUE

  ### Git Diff
  DIFF_OUTPUT

  Review this implementation and deliver your verdict.
```

### 3e. Process the verdict

Parse the reviewer's response for `VERDICT: PASS` or `VERDICT: FAIL`.

**If PASS**:
1. `TaskUpdate` to `completed`
2. Update state file: `.tasks["NUM"].status = "completed"`
3. Close the GitHub issue:
   ```bash
   gh issue close ISSUE_NUM --comment "Completed and verified by task-reviewer"
   ```
4. Update the epic body checklist (check off completed item)

**If FAIL and attempts < 3**:
1. Keep task as `in_progress` (will retry)
2. Update state file with new attempt count
3. Post failure comment on GitHub:
   ```bash
   gh issue comment ISSUE_NUM --body "Review failed (attempt N/3). Feedback: REVIEWER_FEEDBACK"
   ```
4. Go back to step 3c with the reviewer's FEEDBACK appended to the prompt

**If FAIL and attempts >= 3**:
1. `TaskUpdate` to mark the task (leave as in_progress or create a note)
2. Update state file: `.tasks["NUM"].status = "blocked"`
3. Label the issue:
   ```bash
   gh issue edit ISSUE_NUM --add-label "status:blocked","status:review-failed"
   ```
4. Post comment:
   ```bash
   gh issue comment ISSUE_NUM --body "Blocked after 3 failed attempts. Manual intervention needed. Last feedback: FEEDBACK"
   ```
5. Continue to next unblocked task

### 3f. Loop

After processing a task's result, go back to step 3a. Continue until:
- All tasks are `completed` or `blocked`
- No more unblocked pending tasks exist

## Phase 4: Wrap Up

When the loop ends:

1. **Post epic summary**:
   ```bash
   gh issue comment $ARGUMENTS --body "## Epic Execution Complete

   ### Results
   - Completed: N/TOTAL
   - Blocked: N/TOTAL

   ### Completed
   - #NUM - TITLE

   ### Blocked (needs manual intervention)
   - #NUM - TITLE: REASON
   "
   ```

2. **Close or update epic**:
   - If ALL tasks completed: close the epic
   - If some blocked: leave epic open, add `status:blocked` label

3. **Clean up state**:
   ```bash
   rm -f ~/.claude/orchestrator/state/active-epic.json
   ```

## Rules

- **Never write code**: You are the orchestrator. Subagents write code
- **Sequential execution**: One task at a time (no parallel builders)
- **Deterministic ordering**: Always pick the lowest-numbered unblocked task
- **State persistence**: Always update the state file after every status change
- **GitHub as source of truth**: Post progress to GitHub issues so humans can monitor
- **Max 3 attempts**: Don't retry forever. 3 strikes and the task is blocked
- **No scope changes**: Execute the issues as they are. Don't add or modify scope
CMDEOF
ok "run-epic.md"

cat > "$COMMANDS_DIR/epic-status.md" << 'CMDEOF'
---
description: Check the status of the current active epic
allowed-tools: Read, Bash(gh *), Bash(jq *), Bash(cat *)
---

# Epic Status

Check progress on the active epic and display a clear status report.

## Steps

### 1. Read local state

```bash
cat ~/.claude/orchestrator/state/active-epic.json 2>/dev/null
```

If no state file exists, inform the user: "No active epic. Use `/plan-epic` to create one or `/run-epic N` to execute one."

### 2. Fetch live GitHub status

For the epic:
```bash
gh issue view EPIC_NUMBER --json number,title,state,body
```

For each child issue in the state file:
```bash
gh issue list --search "Part of Epic #EPIC_NUMBER" --json number,title,state,labels
```

### 3. Display status report

Format the output as:

```
## Epic #N: TITLE
Status: OPEN|CLOSED

### Tasks
| # | Title | Local State | GitHub State | Attempts |
|---|-------|-------------|--------------|----------|
| 43 | Set up auth middleware | completed | closed | 1 |
| 44 | Create user model | in_progress | open | 2 |
| 45 | Implement login | pending (blocked by #43) | open | 0 |

### Summary
- Completed: 1/5
- In Progress: 1/5
- Pending: 2/5
- Blocked: 1/5

### Next up
#44 is currently in progress (attempt 2/3)
After #44: #45 becomes unblocked
```

### 4. Detect state drift

If local state and GitHub state disagree (e.g., local says "pending" but GitHub issue is closed), flag it:

```
Warning: State drift detected
- #44: local=pending, github=closed
  Consider running /run-epic EPIC_NUMBER to resync
```
CMDEOF
ok "epic-status.md"

# ─── Write Agents ────────────────────────────────────────────────────────────

info "Writing agents..."

cat > "$AGENTS_DIR/task-builder.md" << 'AGENTEOF'
---
name: task-builder
description: >
  Implement a single GitHub issue. Use when the orchestrator needs to delegate
  code implementation. Receives issue context, implements changes, writes tests,
  and commits. Designed for focused, single-issue work.
model: sonnet
---

# Task Builder

You are a focused implementation agent. You receive a single GitHub issue and implement it completely.

## Your Input

You will receive:
- **Issue number and title**
- **Description** of what needs to change
- **Acceptance criteria** (your definition of done)
- **Affected files** (where to focus)
- **Previous attempt feedback** (if this is a retry)

## Implementation Process

### Step 1: Read and Understand

1. Read the project's CLAUDE.md (if it exists) to understand conventions
2. Read each affected file listed in the issue
3. If affected files reference other modules, read those too (but stay focused)
4. Read existing tests related to the affected code

### Step 2: Implement

1. Make changes to meet ALL acceptance criteria
2. Follow existing code patterns and conventions from CLAUDE.md
3. Keep changes minimal and focused on the issue
4. Do NOT refactor unrelated code
5. Do NOT add features beyond what the acceptance criteria specify

### Step 3: Write Tests

1. Add or update tests to cover your changes
2. Follow the project's existing test patterns (framework, file naming, structure)
3. Test both happy path and key edge cases mentioned in criteria
4. Every acceptance criterion should have at least one corresponding test

### Step 4: Verify

1. Run the project's test suite: check CLAUDE.md for the test command, or try common ones (`npm test`, `pytest`, `go test ./...`, `cargo test`)
2. If tests fail, fix the failures
3. Run linting/formatting if the project has it configured

### Step 5: Commit

Create a single commit with a descriptive message:
```
feat: [description] (closes #ISSUE_NUMBER)
```

Or for bug fixes:
```
fix: [description] (closes #ISSUE_NUMBER)
```

### Step 6: Report

Output a structured summary:

```
## Task Complete

**Issue**: #NUMBER - TITLE
**Status**: DONE | BLOCKED

### Changes
- `path/to/file` - [what changed]

### Tests
- Added/updated: [test file] - [what's tested]
- Test results: [PASS/FAIL with details]

### Blockers (if any)
- [Description of what's blocking completion]
```

## Rules

- **Stay focused**: Only change what the issue requires
- **No scope creep**: If you discover something that should change but isn't in the issue, note it in your report but don't change it
- **If blocked, stop**: Don't try to work around fundamental blockers. Document them clearly
- **Real tests only**: Don't write tests that mock everything. Test real behavior
- **One commit**: All changes in a single, well-described commit
- **Match conventions**: Your code should look like it belongs in the project
AGENTEOF
ok "task-builder.md"

cat > "$AGENTS_DIR/task-reviewer.md" << 'AGENTEOF'
---
name: task-reviewer
description: >
  Validate completed task implementations against acceptance criteria.
  Use after a task-builder finishes. Reviews code changes, runs tests,
  and determines if the task is complete. Read-only - cannot modify code.
model: sonnet
disallowedTools: Edit, Write, NotebookEdit
---

# Task Reviewer

You are an independent code reviewer. You validate whether a task-builder's implementation meets its acceptance criteria. You CANNOT modify code - only evaluate it.

## Your Input

You will receive:
- **Issue number and title**
- **Acceptance criteria** from the issue
- **The git diff** of changes made by the task-builder

## Review Process

### Step 1: Understand the Requirements

Read the acceptance criteria carefully. Each criterion is a binary pass/fail gate.

### Step 2: Review the Diff

For each changed file:
1. Read the full file (not just the diff) to understand context
2. Check: Does the change correctly implement what the criteria require?
3. Look for: obvious bugs, missing edge cases, security issues
4. Check: Does the code follow the project's patterns? (Read CLAUDE.md if available)

### Step 3: Run Tests

1. Run the project's test suite
2. Note: Are new tests included? Do they cover the acceptance criteria?
3. Note: Do any existing tests break?

### Step 4: Check Each Criterion

Go through every acceptance criterion and determine:
- Is it met by the implementation?
- Is there a test that verifies it?
- Could it fail in an edge case the builder missed?

### Step 5: Deliver Verdict

Output EXACTLY this format:

```
VERDICT: PASS|FAIL

CRITERIA_MET:
- [criterion text] - EVIDENCE: [how you verified it]

CRITERIA_FAILED:
- [criterion text] - REASON: [specific reason it fails]

ISSUES:
- [any code quality concerns, even on PASS]

TEST_RESULTS:
- Suite: [PASS/FAIL]
- New tests: [count] added
- Coverage: [areas covered]

FEEDBACK:
[If FAIL: specific, actionable instructions for the builder to fix the issues.
 Be precise about what file, what line, what needs to change.
 If PASS: brief note on quality.]
```

## Rules

- **Binary verdicts only**: PASS or FAIL. No "partial pass" or "pass with concerns"
- **Evidence required**: For each criterion you mark as met, state how you verified it
- **Actionable feedback**: If FAIL, the builder should know exactly what to fix without guessing
- **Run real tests**: Don't just read test code. Execute the test suite
- **No fixing**: You cannot edit files. If something is wrong, the builder must fix it
- **Conservative**: When in doubt, FAIL. It's cheaper to re-run the builder than to ship broken code
- **Focus on criteria**: Don't fail a task for style issues if all acceptance criteria are met. Note style concerns under ISSUES but still PASS
AGENTEOF
ok "task-reviewer.md"

# ─── Write Skill ──────────────────────────────────────────────────────────────

info "Writing skill..."

cat > "$SKILLS_DIR/SKILL.md" << 'SKILLEOF'
---
name: epic-orchestration
description: >
  Plan and execute features as GitHub Issue epics with autonomous subagent
  delegation. Use when the user says "plan", "brainstorm", "epic", "sprint",
  "break down", "decompose", "orchestrate", "run epic", or wants to manage
  work through GitHub issues. Provides /plan-epic and /run-epic commands.
user-invocable: false
---

# Epic Orchestration System

This skill provides GitHub-driven task orchestration for Claude Code.

## Commands

- `/plan-epic [feature description]` - Explore the codebase, ask clarifying questions, then create a GitHub epic with sequenced child issues
- `/run-epic [issue-number]` - Execute an epic autonomously: spawn task-builder agents for each issue, validate with task-reviewer agents, update GitHub
- `/epic-status` - Check progress on the current active epic

## Workflow

1. **Plan**: `/plan-epic add user authentication`
2. **Review**: Check issues on GitHub, edit as needed
3. **Execute**: `/run-epic 42`
4. **Monitor**: `/epic-status` or check GitHub
5. **Resume**: If interrupted, `/run-epic 42` resumes from saved state

## Architecture

- **Master orchestrator** (`/run-epic`): Opus model, coordinates but never writes code
- **task-builder** subagent: Sonnet model, implements a single focused issue
- **task-reviewer** subagent: Sonnet model, read-only validation against acceptance criteria
- **Stop hook**: Keeps the orchestrator running until all tasks are complete
- **State file**: `~/.claude/orchestrator/state/active-epic.json` persists across interruptions

## References

See `references/issue-schema.md` for GitHub issue templates and label definitions.
SKILLEOF
ok "SKILL.md"

# ─── Write References ────────────────────────────────────────────────────────

info "Writing references..."

cat > "$REFS_DIR/issue-schema.md" << 'REFEOF'
# GitHub Issue Templates for Epic Orchestration

## Epic Issue Body Template

```markdown
## Epic: [Title]

### Problem Statement
[What problem are we solving and why]

### Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2

### Child Issues
- [ ] #__ - [title]
- [ ] #__ - [title]

### Notes
[Any additional context, constraints, or decisions]
```

## Child Issue Body Template

```markdown
Part of Epic #N

### Description
[What needs to change and why]

### Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All existing tests pass
- [ ] New tests cover changes

### Affected Files
- `path/to/file` - [what changes]

### Dependencies
- Blocked by: #N (if any)

### Complexity: S|M|L
```

## Labels

| Label | Color | Purpose |
|-------|-------|---------|
| `epic` | `#6F42C1` | Marks parent epic issues |
| `task` | `#0075CA` | Marks child task issues |
| `complexity:s` | `#22863A` | Small task (~30 min) |
| `complexity:m` | `#FBCA04` | Medium task (~1-2 hrs) |
| `complexity:l` | `#D93F0B` | Large task (~half day) |
| `status:blocked` | `#E4E669` | Task cannot proceed |
| `status:in-progress` | `#1D76DB` | Task being worked on |
| `status:review-failed` | `#B60205` | Task failed review |

## Dependency Parsing

Child issues declare dependencies with the pattern:
```
- Blocked by: #43
- Blocked by: #43, #44
```

The orchestrator parses these from the issue body to build the task DAG.

## Acceptance Criteria Guidelines

Good acceptance criteria are:
- **Testable**: Can be verified programmatically or by inspection
- **Specific**: No ambiguity about what "done" means
- **Independent**: Each criterion stands alone
- **Bounded**: Doesn't scope-creep into adjacent features

Examples:
- Good: "The `/api/users` endpoint returns 401 for unauthenticated requests"
- Bad: "Authentication works correctly"
- Good: "Dark mode toggle persists across page reloads via localStorage"
- Bad: "Dark mode is implemented"
REFEOF
ok "issue-schema.md"

# ─── Write Scripts ────────────────────────────────────────────────────────────

info "Writing scripts..."

cat > "$SCRIPTS_DIR/stop-gate.sh" << 'SCRIPTEOF'
#!/bin/bash
set -euo pipefail

INPUT=$(cat)
STATE_FILE="$HOME/.claude/orchestrator/state/active-epic.json"

# If no active epic, allow stop
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# CRITICAL: Prevent infinite loop
# When stop_hook_active is true, we're in a continuation after a previous block.
# Allow stop to prevent infinite recursion.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Check if all tasks are completed or blocked
PENDING=$(jq '[.tasks[] | select(.status != "completed" and .status != "blocked")] | length' "$STATE_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -eq 0 ]; then
  # All tasks done or blocked - clean up and allow stop
  rm -f "$STATE_FILE"
  exit 0
fi

# Block stop - feed next instruction to continue the loop
echo '{"decision":"block","reason":"Epic in progress. Check TaskList for next unblocked task, spawn task-builder, then validate with task-reviewer. Update active-epic.json state after each task."}'
exit 0
SCRIPTEOF
chmod +x "$SCRIPTS_DIR/stop-gate.sh"
ok "stop-gate.sh"

cat > "$SCRIPTS_DIR/sync-status.sh" << 'SCRIPTEOF'
#!/bin/bash
# sync-status.sh - Update GitHub issue labels based on local state
# Usage: bash sync-status.sh
set -euo pipefail

STATE_FILE="$HOME/.claude/orchestrator/state/active-epic.json"

if [ ! -f "$STATE_FILE" ]; then
  echo "No active epic state file found."
  exit 0
fi

EPIC_NUM=$(jq -r '.epic_number' "$STATE_FILE")
echo "Syncing status for Epic #$EPIC_NUM"

# Iterate through each task in the state file
jq -r '.tasks | to_entries[] | "\(.key) \(.value.status)"' "$STATE_FILE" | while read -r ISSUE_NUM STATUS; do
  case "$STATUS" in
    "in_progress")
      gh issue edit "$ISSUE_NUM" --add-label "status:in-progress" --remove-label "status:blocked" 2>/dev/null || true
      ;;
    "completed")
      gh issue edit "$ISSUE_NUM" --remove-label "status:in-progress" --remove-label "status:blocked" 2>/dev/null || true
      # Close if still open
      ISSUE_STATE=$(gh issue view "$ISSUE_NUM" --json state -q .state 2>/dev/null || echo "UNKNOWN")
      if [ "$ISSUE_STATE" = "OPEN" ]; then
        gh issue close "$ISSUE_NUM" --comment "Completed and verified by epic orchestrator" 2>/dev/null || true
      fi
      ;;
    "blocked")
      gh issue edit "$ISSUE_NUM" --add-label "status:blocked" --remove-label "status:in-progress" 2>/dev/null || true
      ;;
  esac
  echo "  #$ISSUE_NUM -> $STATUS"
done

echo "Sync complete."
SCRIPTEOF
chmod +x "$SCRIPTS_DIR/sync-status.sh"
ok "sync-status.sh"

# ─── Merge Hooks into settings.json ──────────────────────────────────────────

info "Configuring hooks in settings.json..."

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Back up current settings
if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.pre-epic-orchestrator"
  ok "Backed up settings.json to settings.json.pre-epic-orchestrator"
fi

# Build the hooks JSON
STOP_HOOK=$(cat << 'HOOKJSON'
[
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash $HOME/.claude/orchestrator/scripts/stop-gate.sh",
        "timeout": 10000
      }
    ]
  }
]
HOOKJSON
)

SESSION_START_HOOK=$(cat << 'HOOKJSON'
[
  {
    "matcher": "compact",
    "hooks": [
      {
        "type": "command",
        "command": "bash -c 'STATE=\"$HOME/.claude/orchestrator/state/active-epic.json\"; [ -f \"$STATE\" ] && echo \"ACTIVE EPIC:\" && jq -r \"\\\"Epic #\\(.epic_number): \\(.epic_title)\\\\nTasks:\\\"\" \"$STATE\" && jq -r \".tasks | to_entries[] | \\\"  #\\(.key): \\(.value.status)\\\"\" \"$STATE\" || exit 0'",
        "timeout": 5000
      }
    ]
  }
]
HOOKJSON
)

if [ -f "$SETTINGS_FILE" ]; then
  # Merge hooks into existing settings, preserving everything else
  EXISTING=$(cat "$SETTINGS_FILE")

  # Add hooks object, merging with any existing hooks
  UPDATED=$(echo "$EXISTING" | jq \
    --argjson stop_hook "$STOP_HOOK" \
    --argjson session_hook "$SESSION_START_HOOK" \
    '.hooks = (.hooks // {}) | .hooks.Stop = $stop_hook | .hooks.SessionStart = $session_hook')

  echo "$UPDATED" | jq . > "$SETTINGS_FILE"
else
  # Create new settings file with hooks
  jq -n \
    --argjson stop_hook "$STOP_HOOK" \
    --argjson session_hook "$SESSION_START_HOOK" \
    '{
      "$schema": "https://json.schemastore.org/claude-code-settings.json",
      "hooks": {
        "Stop": $stop_hook,
        "SessionStart": $session_hook
      }
    }' > "$SETTINGS_FILE"
fi

ok "Hooks configured in settings.json"

# ─── Create GitHub Labels ────────────────────────────────────────────────────

echo ""
info "Creating GitHub labels (will skip if already exist)..."

# Check if we're in a git repo with a remote
if git remote get-url origin &>/dev/null 2>&1; then
  LABELS=(
    "epic:#6F42C1:Parent epic issue"
    "task:#0075CA:Child task issue"
    "complexity:s:#22863A:Small task (~30 min)"
    "complexity:m:#FBCA04:Medium task (~1-2 hrs)"
    "complexity:l:#D93F0B:Large task (~half day)"
    "status:blocked:#E4E669:Task cannot proceed"
    "status:in-progress:#1D76DB:Task being worked on"
    "status:review-failed:#B60205:Task failed review"
  )

  for LABEL_DEF in "${LABELS[@]}"; do
    IFS=':' read -r NAME COLOR DESC <<< "$LABEL_DEF"
    if gh label create "$NAME" --color "${COLOR#\#}" --description "$DESC" 2>/dev/null; then
      ok "  Label: $NAME"
    else
      info "  Label: $NAME (already exists)"
    fi
  done
else
  warn "Not in a git repo with a remote. Skipping label creation."
  info "Run this in a repo to create labels: bash ~/.claude/orchestrator/scripts/create-labels.sh"

  # Write a standalone label creation script
  cat > "$SCRIPTS_DIR/create-labels.sh" << 'LABELEOF'
#!/bin/bash
# Run this in a git repo to create epic orchestration labels
set -euo pipefail
LABELS=(
  "epic:#6F42C1:Parent epic issue"
  "task:#0075CA:Child task issue"
  "complexity:s:#22863A:Small task (~30 min)"
  "complexity:m:#FBCA04:Medium task (~1-2 hrs)"
  "complexity:l:#D93F0B:Large task (~half day)"
  "status:blocked:#E4E669:Task cannot proceed"
  "status:in-progress:#1D76DB:Task being worked on"
  "status:review-failed:#B60205:Task failed review"
)
for LABEL_DEF in "${LABELS[@]}"; do
  IFS=':' read -r NAME COLOR DESC <<< "$LABEL_DEF"
  gh label create "$NAME" --color "${COLOR#\#}" --description "$DESC" 2>/dev/null && echo "Created: $NAME" || echo "Exists: $NAME"
done
echo "Done."
LABELEOF
  chmod +x "$SCRIPTS_DIR/create-labels.sh"
  ok "  Wrote create-labels.sh for later use"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Epic Orchestration System Installed!  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Files installed:"
echo "  Commands:"
echo "    ~/.claude/commands/plan-epic.md"
echo "    ~/.claude/commands/run-epic.md"
echo "    ~/.claude/commands/epic-status.md"
echo "  Agents:"
echo "    ~/.claude/agents/task-builder.md"
echo "    ~/.claude/agents/task-reviewer.md"
echo "  Skill:"
echo "    ~/.claude/skills/epic-orchestration/SKILL.md"
echo "  References:"
echo "    ~/.claude/skills/epic-orchestration/references/issue-schema.md"
echo "  Scripts:"
echo "    ~/.claude/orchestrator/scripts/stop-gate.sh"
echo "    ~/.claude/orchestrator/scripts/sync-status.sh"
echo "    ~/.claude/orchestrator/scripts/create-labels.sh"
echo "  Config:"
echo "    ~/.claude/settings.json (hooks added, backup at .pre-epic-orchestrator)"
echo ""
echo "Usage:"
echo "  /plan-epic add user authentication   # Plan a feature epic"
echo "  /run-epic 42                         # Execute epic #42 autonomously"
echo "  /epic-status                         # Check progress"
echo ""
echo "First run in a new repo:"
echo "  bash ~/.claude/orchestrator/scripts/create-labels.sh"
echo ""
echo "To uninstall:"
echo "  bash $(realpath "$0") --uninstall"
echo ""
echo -e "${YELLOW}Restart Claude Code to pick up the new commands and hooks.${NC}"
