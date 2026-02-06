#!/bin/bash
set -euo pipefail

INPUT=$(cat)
STATE_FILE="$HOME/.claude/orchestrator/state/active-epic.json"

# If no active epic, allow stop
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# CRITICAL: Prevent infinite loop
# When stop_hook_active is true, we're in a continuation after a previous block.
# Allow stop to prevent infinite recursion.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Check if all tasks are completed or blocked
PENDING=$(jq '[.tasks[] | select(.status != "completed" and .status != "blocked")] | length' "$STATE_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -eq 0 ]; then
  # All tasks done or blocked - clean up and allow stop
  rm -f "$STATE_FILE"
  exit 0
fi

# Block stop - feed next instruction to continue the loop
echo '{"decision":"block","reason":"Epic in progress. Check TaskList for next unblocked task, spawn task-builder, then validate with task-reviewer. Update active-epic.json state after each task."}'
exit 0
