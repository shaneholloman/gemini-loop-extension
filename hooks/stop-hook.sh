#!/bin/bash

# Stop Hook for Pickle Rick
# Intercepts exit attempts to maintain the iterative loop

set -euo pipefail

EXTENSION_DIR="$HOME/.gemini/extensions/pickle-rick"
CURRENT_SESSION_POINTER="$EXTENSION_DIR/current_session_path"

# 1. Read Hook Input (JSON from stdin)
INPUT_JSON=$(cat)

# 2. Determine State File Path
STATE_FILE="${PICKLE_STATE_FILE:-}"
if [[ -z "$STATE_FILE" ]]; then
  if [[ -f "$CURRENT_SESSION_POINTER" ]]; then
    SESSION_DIR=$(cat "$CURRENT_SESSION_POINTER")
    STATE_FILE="$SESSION_DIR/state.json"
  else
    # Fallback (or no session active)
    STATE_FILE="$EXTENSION_DIR/state.json"
  fi
else
  SESSION_DIR=$(dirname "$STATE_FILE")
fi

# 3. Check if loop is active
if [[ ! -f "$STATE_FILE" ]]; then
  # No state file -> Allow exit
  echo '{"decision": "allow"}'
  exit 0
fi

# 3. Read State using jq
ACTIVE=$(jq -r '.active // false' "$STATE_FILE" 2>/dev/null || echo "false")

if [[ "$ACTIVE" != "true" ]]; then
  # Not active -> Allow exit
  echo '{"decision": "allow"}'
  exit 0
fi

# 4. Parse Loop State
ITERATION=$(jq -r '.iteration // 1' "$STATE_FILE")
MAX_ITERATIONS=$(jq -r '.max_iterations // 0' "$STATE_FILE")
MAX_TIME_MINS=$(jq -r '.max_time_minutes // 0' "$STATE_FILE")
START_TIME=$(jq -r '.start_time_epoch // 0' "$STATE_FILE")
COMPLETION_PROMISE=$(jq -r '.completion_promise // "null"' "$STATE_FILE")
ORIGINAL_PROMPT=$(jq -r '.original_prompt' "$STATE_FILE")

# 5. Check Termination Conditions

# 5a. Time Limit
CURRENT_TIME=$(date +%s)
ELAPSED_SECONDS=$((CURRENT_TIME - START_TIME))
MAX_TIME_SECONDS=$((MAX_TIME_MINS * 60))

echo "[StopHook] Time Check | Elapsed: $ELAPSED_SECONDS / $MAX_TIME_SECONDS (Max Mins: $MAX_TIME_MINS)" >> "$EXTENSION_DIR/debug.log"

if [[ "$MAX_TIME_MINS" -gt 0 ]] && [[ "$ELAPSED_SECONDS" -ge "$MAX_TIME_SECONDS" ]]; then
  # Time limit reached -> Allow exit
  TMP_STATE=$(mktemp)
  jq '.active = false' "$STATE_FILE" > "$TMP_STATE" && mv "$TMP_STATE" "$STATE_FILE"
  echo '{"decision": "allow"}'
  exit 0
fi

# 5b. Max Iterations
if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  # Limit reached -> Allow exit
  # Disable loop
  TMP_STATE=$(mktemp)
  jq '.active = false' "$STATE_FILE" > "$TMP_STATE" && mv "$TMP_STATE" "$STATE_FILE"
  echo '{"decision": "allow"}'
  exit 0
fi

# 5b. Completion Promise
# Extract the assistant response from the input
LAST_MESSAGE=$(echo "$INPUT_JSON" | jq -r '.prompt_response // ""')

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ "$COMPLETION_PROMISE" != "" ]]; then
  if echo "$LAST_MESSAGE" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
    # Promise fulfilled -> Allow exit
    # Disable loop
    TMP_STATE=$(mktemp)
    jq '.active = false' "$STATE_FILE" > "$TMP_STATE" && mv "$TMP_STATE" "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
  fi
fi

# 6. Continue Loop (Prevent Exit)

# Construct Feedback Message
FEEDBACK="🥒 **Pickle Rick Loop Active** (Iteration $ITERATION)"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  FEEDBACK="$FEEDBACK of $MAX_ITERATIONS"
fi

# Output JSON to prevent exit and send new prompt
jq -n \
  --arg prompt "$ORIGINAL_PROMPT" \
  --arg feedback "$FEEDBACK" \
  '{
    "decision": "block",
    "systemMessage": $feedback,
    "hookSpecificOutput": {
      "hookEventName": "AfterAgent",
      "additionalContext": $prompt
    }
  }'
