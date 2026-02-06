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
