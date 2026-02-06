#!/bin/bash
# sync-status.sh - Update GitHub issue labels based on local state
# Usage: bash sync-status.sh
set -euo pipefail

STATE_FILE="$HOME/.claude/orchestrator/state/active-epic.json"

if [ ! -f "$STATE_FILE" ]; then
  echo "No active epic state file found."
  exit 0
fi

EPIC_NUM=$(jq -r '.epic_number' "$STATE_FILE")
echo "Syncing status for Epic #$EPIC_NUM"

# Iterate through each task in the state file
jq -r '.tasks | to_entries[] | "\(.key) \(.value.status)"' "$STATE_FILE" | while read -r ISSUE_NUM STATUS; do
  case "$STATUS" in
    "in_progress")
      gh issue edit "$ISSUE_NUM" --add-label "status:in-progress" --remove-label "status:blocked" 2>/dev/null || true
      ;;
    "completed")
      gh issue edit "$ISSUE_NUM" --remove-label "status:in-progress" --remove-label "status:blocked" 2>/dev/null || true
      # Close if still open
      ISSUE_STATE=$(gh issue view "$ISSUE_NUM" --json state -q .state 2>/dev/null || echo "UNKNOWN")
      if [ "$ISSUE_STATE" = "OPEN" ]; then
        gh issue close "$ISSUE_NUM" --comment "Completed and verified by epic orchestrator" 2>/dev/null || true
      fi
      ;;
    "blocked")
      gh issue edit "$ISSUE_NUM" --add-label "status:blocked" --remove-label "status:in-progress" 2>/dev/null || true
      ;;
  esac
  echo "  #$ISSUE_NUM -> $STATUS"
done

echo "Sync complete."
