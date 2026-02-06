# Claude Code Skills Ecosystem — Research Notes

## What Are Skills?

Skills are reusable capability packages for Claude Code. They live in `~/.claude/skills/<skill-name>/SKILL.md` and provide structured context that Claude loads based on trigger keywords in user prompts.

### Skill File Structure

```
~/.claude/skills/<skill-name>/
├── SKILL.md          # Required — frontmatter + instructions
└── references/       # Optional — supporting docs, schemas, templates
    └── *.md
```

### SKILL.md Frontmatter

```yaml
---
name: skill-name
description: >
  What this skill does and when to trigger it.
  Include keywords Claude uses to match user intent.
user-invocable: false  # true if it registers a slash command
---
```

## Key Marketplaces & Directories

- **Claude Code official docs**: https://docs.anthropic.com/en/docs/claude-code
- **GitHub topic — claude-code-skills**: Search `topic:claude-code-skills` on GitHub for community skills
- **Awesome Claude Code**: Community-curated lists of extensions, skills, and configurations
- **Anthropic Cookbook**: https://github.com/anthropics/anthropic-cookbook — patterns and examples

## Skill Design Patterns

### Command Skills
Register slash commands (e.g., `/plan-epic`). The SKILL.md describes the workflow, and companion command files in `~/.claude/commands/` provide the actual command prompts.

### Context Skills
Loaded automatically based on keyword matching in user messages. Good for coding standards, framework-specific guidance, or project conventions. Set `user-invocable: false`.

### Agent Skills
Define specialized subagent behaviors (e.g., `task-builder`, `task-reviewer`). Agent definitions go in `~/.claude/agents/` and the skill's SKILL.md ties them together.

## Best Practices for Writing Skills

1. **Trigger keywords in description**: Claude matches skills to user intent via the description field — include natural phrases users would say
2. **Keep SKILL.md concise**: It's loaded into context, so bloat costs tokens. Put detailed references in the `references/` directory
3. **Frontmatter is required**: Without valid YAML frontmatter, the skill won't be recognized
4. **One skill per concern**: Don't bundle unrelated capabilities into a single skill
5. **Test with `/` commands**: After installing, verify the skill triggers correctly

## Hooks Integration

Skills often pair with hooks in `~/.claude/settings.json`:
- **Stop hooks**: Prevent session end during autonomous workflows
- **SessionStart hooks**: Display state or run checks when a session begins
- **PreToolUse / PostToolUse hooks**: Gate or augment tool calls

## Installed Skills in This Project

| Skill | Location | Purpose |
|-------|----------|---------|
| epic-orchestration | `~/.claude/skills/epic-orchestration/` | Plan and execute GitHub epics with builder/reviewer agents |

## Future Exploration

- MCP (Model Context Protocol) server integration with skills
- Cross-project skill sharing via git submodules or symlinks
- Skill versioning and dependency management
- Community skill registry / package manager concepts
