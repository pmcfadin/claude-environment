---
description: Execute a GitHub epic's tasks autonomously with builder/reviewer subagents. Use for "run epic", "execute epic", "start sprint"
argument-hint: [epic-issue-number]
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *), Task
model: opus
---

# Run Epic: #$ARGUMENTS

You are the epic orchestrator. You coordinate autonomous execution of a GitHub epic by delegating work to specialized subagents. You do NOT write code yourself.

GitHub is the sole source of truth. There is no local state file. If this session crashes, just re-run `/run-epic $ARGUMENTS` and it picks up where it left off.

## Phase 1: Load Epic from GitHub

### 1a. Fetch the epic

```bash
gh issue view $ARGUMENTS --json number,title,body,state,labels
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

### 1d. Determine current state from GitHub

For each child issue, determine its status from GitHub state:
- **closed** → already completed, skip it
- **open + has `status:blocked` label** → blocked from a previous run, skip it
- **open + has `status:in-progress` label** → was in progress when a previous session ended, treat as pending (remove the stale label)
- **open** → pending

No local state file to check. GitHub tells you everything.

## Phase 2: Create Runtime Task DAG

This is a session-local cache for tracking the execution loop. It is NOT persistent state.

### 2a. Create tasks

For each OPEN, non-blocked child issue, create a task:

Use `TaskCreate` with:
- **subject**: `#NUMBER - TITLE`
- **description**: The full issue body
- **activeForm**: `Working on #NUMBER - TITLE`

### 2b. Set dependencies

For each task with dependencies, use `TaskUpdate` with `addBlockedBy` pointing to the task IDs of the dependency issues. Only add dependencies on tasks that exist in the DAG (skip dependencies on already-closed issues).

## Phase 2c: Pre-flight Checks

Before entering the execution loop, verify the workspace is ready:

```bash
git status --porcelain
```

- If the working tree is dirty (uncommitted changes), stop and ask the user to commit or stash
- Verify you're on the expected branch (e.g., a feature branch for this epic, not `main`)
- Run the project's build/test to confirm a clean baseline:
  ```bash
  # Check CLAUDE.md for the project's build command, or try:
  npm test 2>&1 | tail -5    # or pytest, cargo test, go test, etc.
  ```
- If the baseline build fails, stop and inform the user — don't start an epic on a broken codebase

These checks are cheap. A failed pre-flight saves wasting a full builder+reviewer cycle on a doomed attempt.

## Phase 3: Execute Loop

This is the core loop. Repeat until all tasks are completed or blocked.

### 3a. Find the next task(s)

Use `TaskList` to find ALL tasks that are:
- Status: `pending`
- Not blocked by any incomplete tasks

**If only one task is unblocked**: Execute it sequentially (proceed to 3b).

**If multiple independent tasks are unblocked**: You MAY run them in parallel using `run_in_background: true` on the Task tool. However, parallel execution has constraints:
- Each builder works on a separate git branch (create with `git checkout -b epic-EPIC_NUM/issue-ISSUE_NUM`)
- After all parallel builders complete, merge branches back sequentially
- Review each task's changes sequentially (reviewers need a stable codebase)
- If parallelism adds too much complexity for the current epic, fall back to sequential — pick the lowest-numbered unblocked task

If no unblocked pending tasks remain, go to Phase 4.

### 3b. Start the task

1. `TaskUpdate` the task to `in_progress`
2. Update the GitHub issue label:
   ```bash
   gh issue edit ISSUE_NUM --add-label "status:in-progress"
   ```
3. Determine the attempt number by counting previous attempt comments on the issue:
   ```bash
   gh issue view ISSUE_NUM --json comments --jq '[.comments[] | select(.body | startswith("🔨 Starting autonomous implementation"))] | length'
   ```
   The attempt number is that count + 1.
4. Post a GitHub comment:
   ```bash
   gh issue comment ISSUE_NUM --body "🔨 Starting autonomous implementation (attempt ATTEMPT_NUMBER)"
   ```

### 3c. Spawn task-builder

Read the task-builder agent instructions once at the start of the loop (or cache from first read):

```
Read .claude/agents/task-builder.md
```

**First attempt** — spawn with the full issue body:

```
subagent_type: task-builder
prompt: |
  [FULL CONTENTS OF .claude/agents/task-builder.md]

  ---

  ## Your Task

  **Issue #NUMBER**: TITLE

  FULL_ISSUE_BODY_HERE

  Implement this issue completely following the instructions above.
```

**Retry attempt** — spawn with ONLY the feedback, not the full issue body again. The builder has access to `gh issue view` and can read the issue itself:

```
subagent_type: task-builder
prompt: |
  [FULL CONTENTS OF .claude/agents/task-builder.md]

  ---

  ## Retry: Issue #NUMBER - TITLE

  The previous attempt failed review. Here is the reviewer's feedback:

  REVIEWER_FEEDBACK_HERE

  Fix these specific issues. Run `gh issue view NUMBER` if you need the full issue body.
```

**Important**: Inline the full agent instructions into the prompt. Do NOT tell the subagent to read any external file for its role definition. But DO let it gather project context (files, issues, diffs) on its own.

### 3d. Spawn task-reviewer

**Do NOT read the diff into the orchestrator's context.** The reviewer has access to `git` and can gather its own evidence. This preserves the orchestrator's context window for coordinating multi-task epics.

Read the task-reviewer agent instructions once (or use cached copy):

```
Read .claude/agents/task-reviewer.md
```

Spawn the reviewer with just the issue reference and acceptance criteria:

```
subagent_type: task-reviewer
prompt: |
  [FULL CONTENTS OF .claude/agents/task-reviewer.md]

  ---

  ## Issue #NUMBER: TITLE

  ### Acceptance Criteria
  CRITERIA_EXTRACTED_FROM_ISSUE_BODY

  Review the most recent commit. Run `git diff HEAD~1` yourself to see the changes.
  Run the test suite. Deliver your verdict.
```

**Important**: Do NOT run `git diff` in the orchestrator and paste the output into the reviewer prompt. The reviewer runs its own commands. The orchestrator stays lightweight.

### 3e. Process the verdict

Parse the reviewer's response for `VERDICT: PASS` or `VERDICT: FAIL`.

**If PASS**:
1. **Squash retry commits** (if this wasn't the first attempt): If the builder made multiple commits across retries, squash them into one clean commit per issue:
   ```bash
   # Count commits for this issue (look for the issue number in commit messages)
   # If more than 1, squash them:
   git reset --soft HEAD~N && git commit -m "feat: DESCRIPTION (#ISSUE_NUM)"
   ```
   This keeps history clean — one commit per completed issue.
2. `TaskUpdate` to `completed`
3. Remove in-progress label and close the issue:
   ```bash
   gh issue edit ISSUE_NUM --remove-label "status:in-progress"
   gh issue close ISSUE_NUM --comment "✅ Completed and verified by task-reviewer"
   ```
4. Update the epic body checklist (check off the completed item):
   ```bash
   # Fetch current epic body, replace "- [ ] #NUM" with "- [x] #NUM", edit the issue
   ```

**If FAIL and attempts < 3**:
1. Keep task as `in_progress` (will retry)
2. Post failure comment on GitHub with the specific failed criteria:
   ```bash
   gh issue comment ISSUE_NUM --body "❌ Review failed (attempt N/3).

   Criteria passed: [list from CRITERIA_MET]
   Criteria failed: [list from CRITERIA_FAILED]

   Feedback: REVIEWER_FEEDBACK"
   ```
3. Go back to step 3c. In the retry prompt, include ONLY:
   - The failed criteria (from `CRITERIA_FAILED`)
   - The reviewer's actionable feedback (from `FEEDBACK`)
   - Do NOT re-send criteria that already passed — the builder should leave those alone

**If FAIL and attempts >= 3**:
1. `TaskUpdate` — leave task so it won't be picked up again (or mark via description)
2. Label the issue as blocked:
   ```bash
   gh issue edit ISSUE_NUM --remove-label "status:in-progress" --add-label "status:blocked" --add-label "status:review-failed"
   ```
3. Post comment:
   ```bash
   gh issue comment ISSUE_NUM --body "🚫 Blocked after 3 failed attempts. Manual intervention needed.\n\nLast feedback:\nFEEDBACK"
   ```
4. Continue to next unblocked task

### 3f. Loop

After processing a task's result, go back to step 3a. Continue until:
- All tasks are `completed` or `blocked`
- No more unblocked pending tasks exist

## Phase 4: Wrap Up

When the loop ends:

1. **Post epic summary** as a comment on the epic issue:
   ```bash
   gh issue comment $ARGUMENTS --body "## 🏁 Epic Execution Complete

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

No state file to clean up. GitHub reflects the final state.

## Rules

- **Never write code**: You are the orchestrator. Subagents write code
- **Sequential by default**: One task at a time unless multiple independent tasks are unblocked and you can safely parallelize with separate branches
- **Deterministic ordering**: When running sequentially, always pick the lowest-numbered unblocked task
- **GitHub is the source of truth**: All state is read from and written to GitHub issues
- **Inline agent instructions**: Read agent .md files and paste their full contents into subagent prompts so subagents know their role. But let subagents gather their own project context (files, diffs, issues)
- **Max 3 attempts**: Don't retry forever. 3 strikes and the task is blocked
- **No scope changes**: Execute the issues as they are. Don't add or modify scope
- **Crash-resilient**: If the session dies, re-running `/run-epic` picks up from GitHub state

## Context Conservation

Your context window is a finite resource shared across ALL tasks in the epic. Waste it on one task and you'll run out before the epic completes. Follow these rules strictly:

- **Never read diffs into your own context**: Don't run `git diff` yourself. The reviewer subagent has `git` access and will read the diff itself
- **Never read file contents into your own context**: Don't read source files to "check" what the builder did. That's the reviewer's job
- **Keep retry prompts minimal**: On retry, send ONLY the reviewer's feedback and the issue number. Don't re-send the full issue body — the builder can run `gh issue view` itself
- **Cache agent instructions**: Read `.claude/agents/task-builder.md` and `.claude/agents/task-reviewer.md` once. Reuse the cached text for every subsequent subagent spawn
- **Summarize, don't echo**: When logging subagent results, note the verdict (PASS/FAIL) and key feedback points. Don't repeat the full subagent output
- **Your job is coordination, not inspection**: You dispatch work and process verdicts. You don't review code, read diffs, or verify implementations — that's what the reviewer subagent is for
