# Claude Code Workflow Upgrade: From hey-claude to Orchestrated Expert System

Patrick — here's a concrete plan to upgrade your workflow based on the latest Claude Code features (v2.1.19+, January 2026).

---

## The Problem with Your Current Setup

Your `hey-claude` command is a monolithic system prompt that tries to enforce behavior through instructions alone. This is fundamentally "vibe coding the prompt" — you're relying on the LLM to remember and follow a wall of rules. The research you attached actually diagnoses this exact failure mode:

- **Skills are rarely invoked** because Claude has no compressed index or explicit pointers to them
- **Quality gates are aspirational** — your command says "review as senior developer" but there's no deterministic enforcement
- **No separation of concerns** — one agent is doing planning, implementing, reviewing, and testing

The fix is to move enforcement out of the prompt and into **hooks** (deterministic), **subagents** (specialized), and **skills** (reusable knowledge), with **Tasks** as the orchestration layer.

---

## Your Upgraded Workflow: Three Phases

### Phase 1: Brainstorm → Epic → Issues (Human-Guided)
### Phase 2: Epic → Task List → Parallel Subagent Execution (Automated)
### Phase 3: Quality Gates → Merge (Deterministic Hooks)

---

## Phase 1: The Planning Pipeline

### Skill: `epic-planner`

Create `.claude/skills/epic-planner/SKILL.md`:

```yaml
---
name: epic-planner
description: >
  Break down a feature idea into a GitHub epic with linked issues. Use when the
  user says "plan", "brainstorm", "epic", "break down", "new feature idea", or
  wants to decompose a problem into implementable steps.
---
```

```markdown
# Epic Planner

## Workflow

1. Explore the current repo structure using Glob/Grep to understand existing patterns
2. Ask the user 2-3 clarifying questions about scope and priorities
3. Create the epic issue FIRST via `gh issue create` to get its GitHub number (e.g. #42)
   - Label it with `epic`
   - Include: problem statement, success criteria, architecture notes
4. Create child issues, each:
   - Labeled with `epic/#42` (the parent epic's issue number)
   - Body starts with "Part of epic #42"
   - Clear acceptance criteria
   - Files likely to be modified (discovered from repo exploration)
   - Dependencies on other child issues (use "blocked by #N" syntax)
   - Estimated complexity: S/M/L
5. Update the epic issue body with all child issue numbers via `gh issue edit`

## Issue Templates

### Epic Issue Body

```
## Epic: [Title]

### Problem Statement
[What problem are we solving]

### Success Criteria
- [ ] Criterion 1 (testable)
- [ ] Criterion 2 (testable)

### Architecture Notes
[References to actual files/patterns discovered in repo]

### Child Issues
- [ ] #__ - [title]
- [ ] #__ - [title]
```

Update the "Child Issues" section after creating all children.

### Child Issue Body

```
Part of epic #[epic_number]

### What
[One paragraph describing the change]

### Acceptance Criteria
- [ ] Criterion 1 (testable)
- [ ] Criterion 2 (testable)

### Files Likely Affected
- `path/to/file.rs` - reason
- `path/to/other.rs` - reason

### Dependencies
- Blocked by: #issue_number (if any)

### Test Plan
- Unit: describe what to test
- Integration: describe what to verify
```

**Why this works**: The description field contains trigger words ("plan", "brainstorm", "epic") that match how you naturally talk. The skill forces repo exploration *before* planning, so issues reference actual files.

### Slash Command: `/plan`

Create `.claude/commands/plan.md`:

```yaml
---
description: Start planning mode — brainstorm a feature and create a GitHub epic with issues
allowed-tools: Read, Grep, Glob, Bash, WebSearch
---
```

```markdown
Enter planning mode. Use the epic-planner skill to:

1. Explore the current repository structure
2. Brainstorm with me about: $ARGUMENTS
3. Create a GitHub epic with linked, sequenced issues

Do NOT write any code. Focus only on planning and issue creation.
```

This gives you a deterministic entry point: `/plan add CDC streaming support for real-time OLAP`

---

## Phase 2: Task Orchestration

This is where the new **Tasks** system (v2.1.16+) replaces your manual process.

### Slash Command: `/execute-epic`

Create `.claude/commands/execute-epic.md`:

```yaml
---
description: Load a GitHub epic and execute all issues as tasks with subagents
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Task
---
```

```markdown
# Execute Epic

## Step 1: Load the Epic
Run these commands to load the epic:
1. `gh issue view $ARGUMENTS --json number,title,body` to fetch the epic itself
2. `gh issue list --label "epic/#$ARGUMENTS" --json number,title,body,state` to fetch all child issues

$ARGUMENTS is the GitHub issue number of the epic (e.g. `/execute-epic 42`).

## Step 2: Create Task List
For each open issue, create a Task with:
- Subject: Issue title with issue number
- Description: The issue body (acceptance criteria, files affected, test plan)
- Dependencies: Map "blocked by #N" references to task blockers using addBlockedBy

## Step 3: Execute Tasks
For each task, in dependency order:
1. Set task status to `in_progress`
2. Spawn a general-purpose subagent with this prompt:

   "You are implementing GitHub issue #N: [title].

   Acceptance criteria:
   [paste from issue]

   Files to modify:
   [paste from issue]

   Rules:
   - Read CLAUDE.md for project conventions
   - Run existing tests before making changes to establish a baseline
   - Implement the minimum change that satisfies all acceptance criteria
   - Write tests for new functionality
   - Run the full test suite and fix any failures
   - Do NOT modify files outside the scope of this issue
   - When done, output a summary of: files changed, tests added, tests passing"

3. When subagent completes, update the task with the summary
4. Proceed to the next unblocked task

## Step 4: Summary
After all tasks complete, provide a summary of all changes across the epic.
```

### Why Tasks Over Todos

The key upgrade here: **Tasks support dependency DAGs**. Your old workflow was linear — issue 1, then 2, then 3. Tasks let you express "issue 3 is blocked by issues 1 AND 2" and the system respects that. Tasks also persist to `~/.claude/tasks/` so you can `/clear` context without losing the plan.

You can also share task lists across sessions:
```bash
export CLAUDE_CODE_TASK_LIST_ID=cdc-streaming-epic
```

---

## Phase 3: Quality Gates (The Big Upgrade)

This is where your current setup is weakest. You're asking the LLM to "review as a senior developer" — that's a suggestion, not enforcement. Hooks make it deterministic.

### Hook Configuration

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-edit.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "A subagent just completed its task. Review the subagent's output against these criteria:\n\n1. Were ALL acceptance criteria from the original task met?\n2. Were tests written for new functionality?\n3. Did the test suite pass?\n4. Were only the files in scope modified?\n\nIf ALL criteria are met, respond with: {\"decision\": \"allow\"}\nIf ANY criterion failed, respond with: {\"decision\": \"block\", \"reason\": \"[specific failure]\"}\n\nSubagent output:\n$ARGUMENTS"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/final-validation.sh",
            "timeout": 120
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-files.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### Hook Scripts

#### `.claude/hooks/post-edit.sh` — Auto-lint after every edit

```bash
#!/bin/bash
# Runs after every Edit/Write — auto-format and lint
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Determine file type and run appropriate linter
case "$FILE_PATH" in
  *.rs)
    cargo fmt -- "$FILE_PATH" 2>/dev/null
    cargo clippy --quiet 2>&1 | head -20
    ;;
  *.py)
    ruff check --fix "$FILE_PATH" 2>/dev/null
    ruff format "$FILE_PATH" 2>/dev/null
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    npx prettier --write "$FILE_PATH" 2>/dev/null
    npx eslint --fix "$FILE_PATH" 2>/dev/null
    ;;
esac

exit 0
```

#### `.claude/hooks/protect-files.sh` — Block edits to sensitive files

```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED_PATTERNS=(".env" "package-lock.json" "Cargo.lock" ".git/" "CLAUDE.md")

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "BLOCKED: Cannot edit protected file '$FILE_PATH'" >&2
    exit 2
  fi
done

exit 0
```

#### `.claude/hooks/final-validation.sh` — Run before session ends

```bash
#!/bin/bash
# Runs when Claude tries to stop — ensures tests pass
echo "Running final validation..." >&2

# Run tests
TEST_OUTPUT=$(cargo test 2>&1) || {
  echo "BLOCKED: Tests are failing. Fix before completing:" >&2
  echo "$TEST_OUTPUT" | tail -30 >&2
  exit 2
}

# Run security check (if cargo-audit is installed)
if command -v cargo-audit &> /dev/null; then
  AUDIT_OUTPUT=$(cargo audit 2>&1) || {
    echo "WARNING: Security audit found issues:" >&2
    echo "$AUDIT_OUTPUT" | tail -20 >&2
    # Don't block, but inform
  }
fi

# Check for common security issues
grep -rn "unsafe" --include="*.rs" . 2>/dev/null | head -10 | while read line; do
  echo "NOTE: unsafe block found: $line" >&2
done

echo "All validations passed." >&2
exit 0
```

### The SubagentStop Prompt Hook — This Is the Key Innovation

The `SubagentStop` hook with `type: "prompt"` uses a **lightweight Haiku model** to evaluate whether the subagent actually completed its work. If it didn't, the hook returns `{"decision": "block"}` and the error is fed back to the subagent, forcing it to try again. This is your automated code reviewer — it's not a suggestion in a prompt, it's a deterministic gate.

---

## Subagents: Your Expert Team

### Agent: Code Reviewer

Create `.claude/agents/code-reviewer.md`:

```yaml
---
name: code-reviewer
description: >
  Reviews code changes for quality, security, and test coverage.
  Use proactively after implementation tasks complete.
model: sonnet
tools: Read, Grep, Glob, Bash
disallowedTools: Edit, Write
---
```

```markdown
You are a senior code reviewer. Your job is to review recent changes and provide
a structured assessment. You CANNOT modify files — only read and analyze.

## Review Checklist

### Code Quality
- Are functions focused and under 50 lines?
- Are error cases handled explicitly?
- Is there dead code or unnecessary complexity?
- Do variable/function names clearly communicate intent?

### Security
- Are there hardcoded secrets or credentials?
- Is user input validated/sanitized?
- Are there SQL injection or command injection risks?
- Are unsafe operations justified with comments?

### Testing
- Do new functions have corresponding tests?
- Do tests cover edge cases and error paths?
- Are tests deterministic (no flaky timing dependencies)?

### Architecture
- Do changes respect existing patterns in the codebase?
- Are module boundaries maintained?
- Are dependencies appropriate?

## Output Format

For each file changed, output:

**`path/to/file`**: [PASS | NEEDS_WORK | CRITICAL]
- Finding 1: description (severity: low/medium/high)
- Finding 2: description

**Overall**: [APPROVE | REQUEST_CHANGES]
Summary: [one paragraph]
```

### Agent: Security Scanner

Create `.claude/agents/security-scanner.md`:

```yaml
---
name: security-scanner
description: >
  Scans code for security vulnerabilities, exposed secrets, and unsafe patterns.
  Use after implementation or before merging.
model: sonnet
tools: Read, Grep, Glob, Bash
disallowedTools: Edit, Write
permissionMode: dontAsk
---
```

```markdown
You are a security analyst. Scan the codebase for vulnerabilities.

## Scan Categories

1. **Secrets**: grep for API keys, passwords, tokens, private keys
2. **Injection**: look for unparameterized queries, shell command construction from user input
3. **Dependencies**: check for known vulnerable packages
4. **Unsafe code**: review any `unsafe` blocks, `eval()`, `exec()`, raw SQL
5. **Authentication/Authorization**: verify auth checks on sensitive endpoints

## Commands to Run

```bash
# Check for secrets
grep -rn "password\|secret\|api_key\|token\|private_key" --include="*.rs" --include="*.py" --include="*.ts" .

# Check dependencies
cargo audit 2>/dev/null || echo "cargo-audit not installed"
npm audit 2>/dev/null || echo "no npm project"

# Check for unsafe patterns
grep -rn "unsafe\|eval\|exec\|system(" --include="*.rs" --include="*.py" .
```

## Output Format

**Security Report**
- 🔴 CRITICAL: [finding] — must fix before merge
- 🟡 WARNING: [finding] — should fix
- 🟢 INFO: [finding] — noted, acceptable

**Overall**: [SECURE | NEEDS_REMEDIATION]
```

---

## Fixing the Skill Discovery Problem

This is the #1 issue you identified. Skills only get invoked ~50% of the time. Here's the fix:

### 1. Compressed Index in CLAUDE.md

Add to your project's `CLAUDE.md`:

```markdown
## Available Skills & Agents

When working on tasks, use these specialized capabilities:

| Trigger | Skill/Agent | What it does |
|---------|------------|--------------|
| Planning a feature | `epic-planner` | Creates GitHub epic with sequenced issues |
| After implementation | `code-reviewer` agent | Read-only code review |
| Before merging | `security-scanner` agent | Security vulnerability scan |
| Working with Cassandra CQL | check `.claude/skills/` | Domain-specific patterns |

Always check `.claude/skills/` for available skills before starting work.
When spawning subagents for implementation, include in the prompt:
"Check .claude/skills/ for relevant skills before implementing."
```

### 2. Trigger-Rich Descriptions

The `description` field in your SKILL.md is the **only thing Claude sees** when deciding whether to invoke a skill. Your descriptions must contain the exact words a user (or orchestrator prompt) would use.

Bad: `description: Helps with planning`
Good: `description: Break down a feature idea into a GitHub epic with linked issues. Use when the user says "plan", "brainstorm", "epic", "break down", or wants to decompose a problem into steps.`

### 3. Explicit Skill References in Subagent Prompts

When your `/execute-epic` command spawns subagents, include this in every subagent prompt:

```
Before implementing, check available skills with: ls .claude/skills/
If any skill matches your task, invoke it.
```

This is the "Shotgun Approach" from your research — put the pointer everywhere.

---

## The Complete File Structure

Since you want this everywhere on your machine, the key split is **user-level** (global, in `~/.claude/`) vs **project-level** (repo-specific, in `.claude/`).

### What Goes Where

| Component | Location | Why |
|-----------|----------|-----|
| Agents (code-reviewer, security-scanner) | `~/.claude/agents/` | Same review standards everywhere |
| Epic planner skill | `~/.claude/skills/epic-planner/` | You plan features in any repo |
| Commands (/plan, /execute-epic, /review) | `~/.claude/commands/` | Workflow is repo-agnostic |
| Quality gate hooks (protect-files, SubagentStop) | `~/.claude/settings.json` | Universal standards |
| Generic hook scripts | `~/.claude/hooks/` | Shared across all projects |
| Project-specific linter config | `.claude/settings.json` | Rust vs Python vs JS differ per repo |
| Project-specific skills (CQL, etc.) | `.claude/skills/` | Domain knowledge tied to the repo |
| CLAUDE.md with skill index | repo root | Project conventions + available skills |

### User-Level (`~/.claude/`) — Set Up Once, Use Everywhere

```
~/.claude/
├── CLAUDE.md                              # Your global preferences + skill index
├── settings.json                          # Global hooks (protect-files, SubagentStop)
├── hooks/
│   ├── protect-files.sh                   # Block .env, lockfiles, .git edits
│   ├── subagent-quality-gate.sh           # Validate subagent completion (optional)
│   └── notify-complete.sh                 # Desktop notification when tasks finish
├── commands/
│   ├── plan.md                            # /plan — brainstorm and create epic
│   ├── execute-epic.md                    # /execute-epic 42 — run all issues as tasks
│   └── review.md                          # /review — trigger code review agent
├── skills/
│   └── epic-planner/
│       └── SKILL.md                       # Planning skill
└── agents/
    ├── code-reviewer.md                   # Read-only code review
    └── security-scanner.md                # Security vulnerability scan
```

This is your **"agentic layer"** — it travels with you. CoWork, Claude Code, any project.

### Project-Level (`.claude/` in each repo) — Repo-Specific Overrides

```
your-repo/
├── CLAUDE.md                              # Project conventions, tech stack, skill index
└── .claude/
    ├── settings.json                      # Project-specific hooks (linter commands)
    ├── hooks/
    │   ├── post-edit.sh                   # Auto-lint with THIS project's linter
    │   └── final-validation.sh            # Run THIS project's test suite
    └── skills/
        └── [domain-specific]/
            └── SKILL.md                   # CQL patterns, API conventions, etc.
```

### How They Merge

Claude Code **merges** user-level and project-level config. Hooks from both fire. Skills from both are discovered. Project-level settings override user-level for conflicts. This means:

- Your agents and planning workflow work in ANY repo without setup
- Each repo adds its own linter hooks and domain skills on top
- The SubagentStop quality gate fires everywhere, regardless of project

### Global `~/.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/protect-files.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "A subagent just completed its task. Review its output against these criteria:\n\n1. Were ALL acceptance criteria from the original task met?\n2. Were tests written for new functionality?\n3. Did the test suite pass?\n4. Were only the files in scope modified?\n\nIf ALL criteria are met, respond with: {\"decision\": \"allow\"}\nIf ANY criterion failed, respond with: {\"decision\": \"block\", \"reason\": \"[specific failure]\"}\n\nSubagent output:\n$ARGUMENTS"
          }
        ]
      }
    ]
  }
}
```

### Per-Project `.claude/settings.json` (Example: Rust project)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post-edit.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/final-validation.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

### Global `~/.claude/CLAUDE.md`

```markdown
## Patrick's Global Preferences

- Prefer explicit error handling over silent failures
- Write tests alongside implementation, not after
- Use conventional commits (feat/fix/chore)
- When spawning subagents, always include: "Check available skills before implementing"

## Available Global Skills & Agents

| Trigger | Name | Type | What it does |
|---------|------|------|--------------|
| "plan", "brainstorm", "epic" | epic-planner | skill | Creates GitHub epic with sequenced issues |
| After implementation | code-reviewer | agent | Read-only code review (disallowed: Edit, Write) |
| Before merging | security-scanner | agent | Security vulnerability scan |

Also check project-level `.claude/skills/` for repo-specific skills.
```

---

## Using CoWork to Bootstrap This

You can point CoWork at `~/.claude/` and have it scaffold everything:

1. Open CoWork, grant access to `~/.claude/`
2. Tell it:
   > "Set up my Claude Code agentic infrastructure. Create the directory structure with agents, skills, commands, and hooks as described in the workflow-upgrade doc I'll share. Make all hook scripts executable."
3. Or do it manually — it's just files:

```bash
# Create the structure
mkdir -p ~/.claude/{hooks,commands,skills/epic-planner,agents}

# Copy your files into place
# (agents, skills, commands, hooks from the templates above)

# Make hooks executable
chmod +x ~/.claude/hooks/*.sh
```

---

## Your New Daily Workflow

```
1. /plan CDC streaming for OLAP workloads
   → Works in ANY repo — skill is in ~/.claude/skills/
   → Claude explores repo, asks questions, creates epic issue #42 + child issues #43-#48

2. /execute-epic 42
   → Works in ANY repo — command is in ~/.claude/commands/
   → Claude creates Tasks from issues (with dependencies)
   → Spawns subagents for each task
   → Global SubagentStop hook validates each task completion (from ~/.claude/settings.json)
   → Global protect-files hook blocks .env edits (from ~/.claude/settings.json)
   → Project PostToolUse hook auto-lints with THIS repo's linter (from .claude/settings.json)
   → Project Stop hook runs THIS repo's test suite (from .claude/settings.json)
   → Code reviewer agent runs after implementation (from ~/.claude/agents/)
   → Security scanner runs before completion (from ~/.claude/agents/)

3. Review the output, approve/iterate
```

---

## Migration Checklist

### One-Time Global Setup (do once, in `~/.claude/`)
- [ ] Update Claude Code to v2.1.17+ (`claude update`)
- [ ] Create `~/.claude/settings.json` with global hooks (protect-files, SubagentStop)
- [ ] Create `~/.claude/hooks/protect-files.sh` and `chmod +x`
- [ ] Create `~/.claude/agents/code-reviewer.md`
- [ ] Create `~/.claude/agents/security-scanner.md`
- [ ] Create `~/.claude/skills/epic-planner/SKILL.md`
- [ ] Create `~/.claude/commands/plan.md`
- [ ] Create `~/.claude/commands/execute-epic.md`
- [ ] Create `~/.claude/CLAUDE.md` with global preferences + skill index
- [ ] Install `jq` if not present (hooks need it)
- [ ] Retire the monolithic `hey-claude` command

### Per-Project Setup (do in each repo)
- [ ] Create `.claude/settings.json` with project-specific hooks (linter, test runner)
- [ ] Create `.claude/hooks/post-edit.sh` with repo-appropriate linter commands
- [ ] Create `.claude/hooks/final-validation.sh` with repo-appropriate test commands
- [ ] Add any domain-specific skills to `.claude/skills/`
- [ ] Update project `CLAUDE.md` with tech stack, conventions, and skill index

---

## What You're Deliberately NOT Doing (YAGNI)

- **Agent Teams** (experimental, requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`): Overkill until your subagent pipeline is proven. Agent Teams add inter-agent messaging complexity you don't need yet.
- **Git worktree isolation per agent**: Nice for true parallelism, but adds operational complexity. Start sequential.
- **Prompt-based hooks everywhere**: Use them only on SubagentStop. Command hooks are faster and more predictable for linting/testing.
- **Mental model YAML files**: Your CLAUDE.md + skills already serve this purpose without the maintenance burden.
- **Custom MCP servers**: The gh CLI + Bash give you everything you need for GitHub integration.
- **CoWork plugins**: Until your workflow is stable, keep it as raw files in `~/.claude/`. Packaging into a plugin is a future step once you want to share across machines or teams.
