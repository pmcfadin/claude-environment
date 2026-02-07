---
description: Check the status of a GitHub epic, or list all epics. Use for "status", "progress", "how's the epic"
argument-hint: [epic-issue-number (optional)]
allowed-tools: Bash(gh *)
---

# Epic Status

Query GitHub directly for epic status. GitHub is the sole source of truth — no local state file.

## Determine mode

- If `$ARGUMENTS` is empty or blank → **List all epics** (go to "List All Epics")
- If `$ARGUMENTS` is a number → **Show detail for that epic** (go to "Single Epic Detail")

---

## List All Epics

### 1. Fetch all epic issues

```bash
gh issue list --label "epic" --state all --json number,title,state,labels --limit 50
```

### 2. For each epic, count child issue statuses

For each epic found:
```bash
gh issue list --search "Part of Epic #N" --json number,state,labels --limit 50
```

Count: total, completed (closed), blocked (open + `status:blocked`), in-progress (open + `status:in-progress`), pending (open, no status label).

### 3. Display summary table

```
## All Epics

| # | Title | State | Progress |
|---|-------|-------|----------|
| 42 | Add User Authentication | open | 3/6 done, 1 blocked |
| 38 | Refactor API layer | closed | 5/5 done |
| 35 | Dark mode support | open | 0/4 done, 1 in progress |
```

For any open epic with remaining work, show:
```
To run: /run-epic 42
To inspect: /epic-status 42
```

---

## Single Epic Detail

### 1. Fetch the epic

```bash
gh issue view $ARGUMENTS --json number,title,state,body,labels
```

If the issue doesn't exist or doesn't have the `epic` label, inform the user.

### 2. Fetch child issues

```bash
gh issue list --search "Part of Epic #$ARGUMENTS" --json number,title,state,labels --limit 50
```

### 3. Display status report

Determine each child issue's status from GitHub:
- **closed** → Completed
- **open + `status:blocked`** → Blocked
- **open + `status:in-progress`** → In Progress
- **open + `status:review-failed`** → Review Failed
- **open** → Pending

Format the output as:

```
## Epic #N: TITLE
Status: OPEN | CLOSED

### Tasks
| # | Title | Status | Labels |
|---|-------|--------|--------|
| 43 | Set up auth middleware | Completed | task, complexity:s |
| 44 | Create user model | In Progress | task, complexity:m, status:in-progress |
| 45 | Implement login | Pending | task, complexity:m |

### Summary
- Completed: N/TOTAL
- In Progress: N/TOTAL
- Blocked: N/TOTAL
- Pending: N/TOTAL

### Next up
[Which pending tasks are unblocked and ready to execute]
```

### 4. Resume hint

If there are pending or in-progress tasks, suggest:

```
To resume execution: /run-epic $ARGUMENTS
```
