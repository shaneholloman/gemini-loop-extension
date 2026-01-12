#!/bin/bash

# Increment Iteration Hook
# Runs at BeforeAgent to ensure the iteration counter is updated 
# before the agent starts its loop and before BeforeModel reads it.

set -euo pipefail

EXTENSION_DIR="$HOME/.gemini/extensions/pickle-rick"
CURRENT_SESSION_POINTER="$EXTENSION_DIR/current_session_path"

# 1. Read Hook Input
INPUT_JSON=$(cat)

# 2. Determine State File Path
STATE_FILE="${PICKLE_STATE_FILE:-}"
if [[ -z "$STATE_FILE" ]]; then
  if [[ -f "$CURRENT_SESSION_POINTER" ]]; then
    SESSION_DIR=$(cat "$CURRENT_SESSION_POINTER")
    STATE_FILE="$SESSION_DIR/state.json"
  else
    STATE_FILE="$EXTENSION_DIR/state.json"
  fi
fi

# 3. Check if loop is active
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# 4. Read State and Increment
ACTIVE=$(jq -r '.active // false' "$STATE_FILE" 2>/dev/null || echo "false")

if [[ "$ACTIVE" == "true" ]]; then
  ITERATION=$(jq -r '.iteration // 0' "$STATE_FILE")
  NEXT_ITERATION=$((ITERATION + 1))
  
  TMP_STATE=$(mktemp)
  jq --argjson iter "$NEXT_ITERATION" '.iteration = $iter' "$STATE_FILE" > "$TMP_STATE" && mv "$TMP_STATE" "$STATE_FILE"
fi

# 5. Allow continuation
echo '{"decision": "allow"}'
