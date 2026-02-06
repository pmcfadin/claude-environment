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
