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

GitHub-driven task orchestration for Claude Code. All state lives in GitHub issues — no local state files, no shell script hooks, no external dependencies beyond `gh`.

## Installation

Copy `template/.claude/` into your project root:

```bash
cp -r template/.claude/ YOUR_PROJECT/.claude/
```

The `.claude/settings.json` ships with pre-configured permissions so the orchestrator runs with zero permission prompts. Customize for your stack (e.g., add `Bash(pytest*)`, `Bash(cargo test*)`).

## Commands

- `/plan-epic [feature description]` - Explore the codebase, ask clarifying questions, then create a GitHub epic with sequenced child issues
- `/run-epic [issue-number]` - Execute an epic autonomously: spawn task-builder agents for each issue, validate with task-reviewer agents, update GitHub
- `/epic-status [issue-number]` - Check progress on an epic by querying GitHub

## Workflow

1. **Plan**: `/plan-epic add user authentication`
2. **Review**: Check issues on GitHub, edit as needed
3. **Execute**: `/run-epic 42`
4. **Monitor**: `/epic-status 42` or check GitHub
5. **Resume**: If interrupted, `/run-epic 42` resumes from GitHub state automatically

## Architecture

- **Master orchestrator** (`/run-epic`): Opus model, coordinates but never writes code
- **task-builder** subagent: Sonnet model, implements a single focused issue
- **task-reviewer** subagent: Sonnet model, read-only validation against acceptance criteria
- **GitHub as source of truth**: All state is in issues, labels, and comments — no local state file
- **Crash-resilient**: Re-running `/run-epic` reads GitHub and picks up where it left off

## Key Design Decisions

- **Project-local files**: All commands and agents live in `.claude/` inside the project, not `~/.claude/`. This means no permission prompts for file access.
- **Pre-configured permissions**: `.claude/settings.json` pre-approves all tools the orchestrator needs.
- **Inlined agent instructions**: The orchestrator reads agent `.md` files and pastes their full contents into subagent prompts, so subagents never need to read external files.
- **No shell script hooks**: The orchestrator loop is self-sustaining — no `stop-gate.sh` or `sync-status.sh` needed.
- **No `jq` dependency**: No local JSON state files to manipulate.

## References

See `references/issue-schema.md` for GitHub issue templates and label definitions.
