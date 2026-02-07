#!/bin/bash
# Epic Orchestration System - Quick Install
#
# Copies the template/.claude/ directory into your project.
# Usage:
#   bash install.sh /path/to/your/project
#   bash install.sh .                        # current directory
#   bash install.sh                           # current directory (default)
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template/.claude"
TARGET_DIR="${1:-.}"
TARGET_CLAUDE="$TARGET_DIR/.claude"

# Validate template exists
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo -e "${RED}[ERROR]${NC} Template not found at $TEMPLATE_DIR"
  exit 1
fi

# Check prerequisites
MISSING=()
if ! command -v gh &>/dev/null; then
  MISSING+=("gh (GitHub CLI) - https://cli.github.com/")
fi
if ! command -v claude &>/dev/null; then
  MISSING+=("claude (Claude Code CLI)")
fi
if [ ${#MISSING[@]} -gt 0 ]; then
  echo -e "${YELLOW}[WARN]${NC} Missing optional prerequisites:"
  for dep in "${MISSING[@]}"; do
    echo "  - $dep"
  done
  echo ""
fi

# Check for existing .claude directory
if [ -d "$TARGET_CLAUDE" ]; then
  echo -e "${YELLOW}[WARN]${NC} $TARGET_CLAUDE already exists."

  if [ -f "$TARGET_CLAUDE/settings.json" ]; then
    echo "  Existing settings.json will be preserved (backed up to settings.json.bak)"
    cp "$TARGET_CLAUDE/settings.json" "$TARGET_CLAUDE/settings.json.bak"
  fi
fi

# Copy template
echo -e "${BLUE}[INFO]${NC} Installing epic orchestration to $TARGET_CLAUDE"
mkdir -p "$TARGET_CLAUDE"
cp -r "$TEMPLATE_DIR/commands" "$TARGET_CLAUDE/"
cp -r "$TEMPLATE_DIR/agents" "$TARGET_CLAUDE/"

# Only copy settings.json if it doesn't exist (don't overwrite user customizations)
if [ ! -f "$TARGET_CLAUDE/settings.json" ]; then
  cp "$TEMPLATE_DIR/settings.json" "$TARGET_CLAUDE/"
  echo -e "${GREEN}[OK]${NC} Created settings.json with pre-configured permissions"
else
  echo -e "${YELLOW}[INFO]${NC} Kept existing settings.json (template saved as settings.json.template)"
  cp "$TEMPLATE_DIR/settings.json" "$TARGET_CLAUDE/settings.json.template"
fi

# Create GitHub labels if in a repo
if git -C "$TARGET_DIR" remote get-url origin &>/dev/null 2>&1 && command -v gh &>/dev/null; then
  echo -e "${BLUE}[INFO]${NC} Creating GitHub labels..."
  LABELS=(
    "epic:#6F42C1:Parent epic issue"
    "task:#0075CA:Child task issue"
    "complexity:s:#22863A:Small task (~30 min)"
    "complexity:m:#FBCA04:Medium task (~1-2 hrs)"
    "complexity:l:#D93F0B:Large task (~half day)"
    "status:blocked:#E4E669:Task cannot proceed"
    "status:in-progress:#1D76DB:Task being worked on"
    "status:review-failed:#B60205:Task failed review"
  )
  for LABEL_DEF in "${LABELS[@]}"; do
    IFS=':' read -r NAME COLOR DESC <<< "$LABEL_DEF"
    gh label create "$NAME" --color "${COLOR#\#}" --description "$DESC" -R "$(git -C "$TARGET_DIR" remote get-url origin)" 2>/dev/null && \
      echo -e "  ${GREEN}[OK]${NC} $NAME" || \
      echo -e "  ${BLUE}[INFO]${NC} $NAME (already exists)"
  done
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Epic Orchestration Installed!         ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Installed to: $TARGET_CLAUDE"
echo ""
echo "Files:"
echo "  $TARGET_CLAUDE/settings.json      # Pre-configured permissions"
echo "  $TARGET_CLAUDE/commands/plan-epic.md"
echo "  $TARGET_CLAUDE/commands/run-epic.md"
echo "  $TARGET_CLAUDE/commands/epic-status.md"
echo "  $TARGET_CLAUDE/agents/task-builder.md"
echo "  $TARGET_CLAUDE/agents/task-reviewer.md"
echo ""
echo "Usage:"
echo "  /plan-epic add user authentication   # Plan a feature epic"
echo "  /run-epic 42                         # Execute epic #42 autonomously"
echo "  /epic-status 42                      # Check progress"
echo ""
echo "Customize .claude/settings.json for your stack:"
echo "  Python:  add \"Bash(pytest*)\", \"Bash(pip *)\""
echo "  Rust:    add \"Bash(cargo *)\""
echo "  Go:      add \"Bash(go *)\""
echo ""
