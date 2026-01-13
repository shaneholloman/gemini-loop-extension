#!/bin/bash

# Cancel Pickle Rick Script
# Sets the loop state to inactive

set -euo pipefail

EXTENSION_DIR="$HOME/.gemini/extensions/pickle-rick"
CURRENT_SESSION_POINTER="$EXTENSION_DIR/current_session_path"

if [[ ! -f "$CURRENT_SESSION_POINTER" ]]; then
  echo "❌ No active session found (pointer missing)" >&2
  exit 1
fi

SESSION_DIR=$(cat "$CURRENT_SESSION_POINTER")
STATE_FILE="$SESSION_DIR/state.json"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "❌ No active Pickle Rick loop found" >&2
  echo "   State file not found: $STATE_FILE" >&2
  exit 1
fi

# Check CWD
SESSION_CWD=$(jq -r '.working_dir // empty' "$STATE_FILE")
if [[ -n "$SESSION_CWD" ]] && [[ "$PWD" != "$SESSION_CWD" ]]; then
  echo "❌ Cancelling Pickle Rick failed: You are in a different directory ($PWD) than the active session ($SESSION_CWD)." >&2
  exit 1
fi

# Update state file to set active: false
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS sed requires empty string after -i
  sed -i '' 's/"active": true/"active": false/' "$STATE_FILE"
else
  # GNU sed
  sed -i 's/"active": true/"active": false/' "$STATE_FILE"
fi

echo "✅ Pickle Rick cancelled"
echo "State file: $STATE_FILE"