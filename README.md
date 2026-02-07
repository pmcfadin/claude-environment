# Epic Orchestration System for Claude Code

Autonomous GitHub-driven task orchestration. Plan features as epics, execute them hands-off with builder/reviewer subagents, track everything through GitHub issues.

## Quick Start

### 1. Install into your project

```bash
# Option A: Use the installer
bash install.sh /path/to/your/project

# Option B: Copy manually
cp -r template/.claude/ /path/to/your/project/.claude/
```

### 2. Create GitHub labels (first time per repo)

The installer does this automatically if you're in a git repo. Otherwise:

```bash
cd your-project
gh label create epic --color 6F42C1 --description "Parent epic issue"
gh label create task --color 0075CA --description "Child task issue"
gh label create complexity:s --color 22863A --description "Small task"
gh label create complexity:m --color FBCA04 --description "Medium task"
gh label create complexity:l --color D93F0B --description "Large task"
gh label create status:blocked --color E4E669 --description "Task cannot proceed"
gh label create status:in-progress --color 1D76DB --description "Task being worked on"
gh label create status:review-failed --color B60205 --description "Task failed review"
```

### 3. Use it

```
/plan-epic add user authentication    # Plan a feature epic
/run-epic 42                          # Execute epic #42 autonomously
/epic-status 42                       # Check progress
```

## How It Works

### Planning (`/plan-epic`)

1. Explores your codebase to understand the tech stack and patterns
2. Asks 2-3 clarifying questions about scope
3. Creates a parent GitHub issue (epic) with child issues
4. Each child issue has testable acceptance criteria, affected files, and dependency declarations

### Execution (`/run-epic`)

1. Reads the epic and all child issues from GitHub
2. Builds a dependency graph and finds the next unblocked task
3. Spawns a **task-builder** subagent to implement the task
4. Spawns a **task-reviewer** subagent to validate against acceptance criteria
5. On pass: closes the issue. On fail: retries up to 3 times
6. Repeats until all tasks are done or blocked
7. Posts a summary on the epic issue

### Crash Recovery

GitHub is the sole source of truth. If a session crashes mid-execution, just run `/run-epic N` again — it reads GitHub state and picks up where it left off.

## Architecture

```
/run-epic (Opus orchestrator)
  ├── Reads .claude/agents/task-builder.md
  │   └── Spawns task-builder subagent (Sonnet) with inlined instructions
  ├── Reads .claude/agents/task-reviewer.md
  │   └── Spawns task-reviewer subagent (Sonnet) with inlined instructions
  └── Updates GitHub issues (labels, comments, close/open)
```

- **Orchestrator** never writes code — only coordinates
- **task-builder** implements a single issue, writes tests, commits
- **task-reviewer** validates the implementation (read-only), delivers PASS/FAIL verdict
- All agent instructions are **inlined** into subagent prompts (no external file reads by subagents)

## What's in the Template

```
template/.claude/
├── settings.json           # Pre-configured permissions (zero prompts)
├── commands/
│   ├── plan-epic.md        # /plan-epic command
│   ├── run-epic.md         # /run-epic command
│   └── epic-status.md      # /epic-status command
└── agents/
    ├── task-builder.md     # Builder agent definition
    └── task-reviewer.md    # Reviewer agent definition
```

## Customizing Permissions

The `settings.json` ships with permissions for a typical Node.js project. Customize for your stack:

```json
{
  "permissions": {
    "allow": [
      "Read", "Write", "Edit", "Glob", "Grep",
      "Bash(git *)", "Bash(npm test*)", "Bash(npm run *)",
      "Bash(npx *)", "Bash(gh *)",
      "Bash(pytest*)",
      "Bash(cargo *)",
      "Task"
    ]
  }
}
```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI (`gh`)](https://cli.github.com/) — authenticated (`gh auth login`)
- A GitHub repository with issues enabled

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Project-local `.claude/` | No permission prompts (files are in the project directory) |
| Pre-configured permissions | Zero tool approval prompts during execution |
| GitHub as sole source of truth | Crash-resilient, no state drift, no `jq` dependency |
| Inlined agent instructions | Subagents don't need to read external files |
| No shell script hooks | Simpler, fewer moving parts |
| Max 3 attempts per task | Prevents infinite retry loops |

## Source Files

The `src/` directory contains the source markdown files and skill definitions. The `template/` directory is what gets deployed to user projects.

| Directory | Contents |
|-----------|----------|
| `src/commands/` | Command definitions (plan-epic, run-epic, epic-status, refresh-claude-md) |
| `src/agents/` | Agent definitions (task-builder, task-reviewer) |
| `src/skills/epic-orchestration/` | Skill metadata and issue schema reference |
| `template/.claude/` | Deployable template for user projects |
