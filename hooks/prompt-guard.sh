#!/bin/bash
# ⚠️ SAMPLE HOOK — DO NOT USE AS-IS
# This is a working example to demonstrate the hook format.
# Have your agent adapt this to your actual workflow and goals file structure.
#
# UserPromptSubmit hook: conditional injection
# 1. Action Check: messages >= 30 bytes get intent/goals/worth-it check
# 2. [!Memory]: always checked regardless of message length
# Messages < 30 bytes skip Action Check but still receive Memory alarms.

INPUT=$(cat)
USER_PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

# Opt-out
if echo "$USER_PROMPT" | grep -qiE 'skip check'; then
  exit 0
fi

# Resolve ASSEMBLY_DIR through symlinks (works whether invoked via symlink or directly)
SELF="$0"
if command -v readlink &>/dev/null; then
  RESOLVED="$(readlink -f "$SELF" 2>/dev/null || readlink "$SELF" 2>/dev/null || echo "$SELF")"
else
  RESOLVED="$SELF"
fi
ASSEMBLY_DIR="$(cd "$(dirname "$RESOLVED")/.." && pwd)"

GOALS_FILE="$ASSEMBLY_DIR/modules/profile-goals.md"
CONTEXT=""

# === Message length check ===
PROMPT_LEN=$(echo -n "$USER_PROMPT" | wc -c | tr -d ' ')

if [ "$PROMPT_LEN" -ge 30 ]; then
  GOALS_CONTEXT="no active goals"
  if [ -f "$GOALS_FILE" ]; then
    ACTIVE_SECTION=$(sed '/<!--/,/-->/d' "$GOALS_FILE" | awk '/^## Active$/{p=1;next} /^## Completed$/{p=0} /^## Dropped$/{p=0} p')
    IN_PROGRESS=$(echo "$ACTIVE_SECTION" | awk '/^### /{title=$0} /in progress/{print title}' | sed 's/^### //' | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$IN_PROGRESS" ]; then
      GOALS_CONTEXT="${IN_PROGRESS}"
    else
      FIRST_GOAL=$(echo "$ACTIVE_SECTION" | grep -m1 '^### ' | sed 's/^### //')
      [ -n "$FIRST_GOAL" ] && GOALS_CONTEXT="${FIRST_GOAL}"
    fi
  fi
  CONTEXT="[Action Check] Goals: ${GOALS_CONTEXT} | Check: 1.intent+path 2.goal alignment 3.worth doing?"
fi

# === [!Memory] alarm ===
TODAY=$(date +%Y-%m-%d)
MEMORY_FILE="$ASSEMBLY_DIR/memory/${TODAY}.md"
if [ ! -f "$MEMORY_FILE" ]; then
  CONTEXT="${CONTEXT:+${CONTEXT} }[!Memory] No memory written today."
else
  # Check staleness (>30min since last update)
  if [ "$(uname)" = "Darwin" ]; then
    MOD_TIME=$(stat -f %m "$MEMORY_FILE")
  else
    MOD_TIME=$(stat -c %Y "$MEMORY_FILE" 2>/dev/null || echo 0)
  fi
  NOW=$(date +%s)
  if [ $((NOW - MOD_TIME)) -gt 1800 ]; then
    CONTEXT="${CONTEXT:+${CONTEXT} }[!Memory] Memory not updated for 30+ minutes."
  fi
fi

# Nothing to inject → silent exit
if [ -z "$CONTEXT" ]; then
  exit 0
fi

jq -n --arg ctx "$CONTEXT" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $ctx
  }
}'
