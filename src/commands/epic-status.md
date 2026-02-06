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
