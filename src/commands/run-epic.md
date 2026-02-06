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
4. Update the epic body checklist (check off completed item):
   ```bash
   # Fetch current body, update the checkbox, edit the issue
   ```

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
