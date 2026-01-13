#!/bin/bash

# -----------------------------------------------------------------------------
# Pickle Rick: Session Bootstrapper
# -----------------------------------------------------------------------------
# Initializes the recursive development environment.
# -----------------------------------------------------------------------------

set -euo pipefail

# -- Configuration --
ROOT_DIR="$HOME/.gemini/extensions/pickle-rick"
SESSIONS_ROOT="$ROOT_DIR/sessions"
LATEST_LINK="$ROOT_DIR/current_session_path"

# -- State Variables --
LOOP_LIMIT=3
TIME_LIMIT=60
WORKER_TIMEOUT=1200
PROMISE_TOKEN="null"
SESSION_NAME=""
TASK_ARGS=()
RESUME_MODE="false"
RESUME_PATH=""

# -- Helpers --

die() {
  echo "❌ Error: $1" >&2
  exit 1
}

# -- Argument Parser --

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)

      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "Invalid iteration limit: '${2:-}'"
      LOOP_LIMIT="$2"
      shift 2
      ;;
    --max-time)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "Invalid time limit: '${2:-}'"
      TIME_LIMIT="$2"
      shift 2
      ;;
    --worker-timeout)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "Invalid worker timeout: '${2:-}'"
      WORKER_TIMEOUT="$2"
      shift 2
      ;;
    --completion-promise)
      [[ -n "${2:-}" ]] || die "Missing promise text."
      PROMISE_TOKEN="$2"
      shift 2
      ;;
    --name)
      [[ -n "${2:-}" ]] || die "Missing name."
      SESSION_NAME="$2"
      shift 2
      ;;
    --resume)
      RESUME_MODE="true"
      if [[ -n "${2:-}" ]] && [[ ! "${2:-}" =~ ^- ]]; then
        RESUME_PATH="$2"
        shift 2
      else
        shift 1
      fi
      ;;
    *)
      TASK_ARGS+=("$1")
      shift
      ;;
  esac
done
TASK_STR="${TASK_ARGS[*]}"

# -- Session Setup --

if [[ "$RESUME_MODE" == "true" ]]; then
  # 1. Resolve Path
  if [[ -n "$RESUME_PATH" ]]; then
    FULL_SESSION_PATH="$RESUME_PATH"
  elif [[ -f "$LATEST_LINK" ]]; then
    FULL_SESSION_PATH=$(cat "$LATEST_LINK")
  else
    die "No active session to resume. Provide a path or run a new task."
  fi

  # 2. Validate
  [[ -d "$FULL_SESSION_PATH" ]] || die "Session directory not found: $FULL_SESSION_PATH"
  STATE_PATH="$FULL_SESSION_PATH/state.json"
  [[ -f "$STATE_PATH" ]] || die "State file not found in: $FULL_SESSION_PATH"

  # 3. Load State (for display only)
  # We do NOT overwrite the state file in resume mode
  echo "$FULL_SESSION_PATH" > "$LATEST_LINK"

else
  # -- New Session Logic --
  [[ -n "$TASK_STR" ]] || die "No task specified. Run /pickle --help for usage."

  if [[ -n "$SESSION_NAME" ]]; then
    # Use provided name, sanitized
    SESSION_SLUG=$(echo "$SESSION_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c 1-50)
  else
    # Auto-generate: remove stop words and slugify
    # Stop words: a, an, the, for, to, of, in, with, and, is, are
    CLEAN_TASK=$(echo "$TASK_STR" | sed -E 's/\b(a|an|the|for|to|of|in|with|and|is|are)\b//gi')
    SESSION_SLUG=$(echo "$CLEAN_TASK" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c 1-50)
  fi

  TODAY=$(date +%Y-%m-%d)
  SESSION_ID="${TODAY}-${SESSION_SLUG}"

  FULL_SESSION_PATH="$SESSIONS_ROOT/$SESSION_ID"
  STATE_PATH="$FULL_SESSION_PATH/state.json"

  mkdir -p "$FULL_SESSION_PATH"
  echo "$FULL_SESSION_PATH" > "$LATEST_LINK"

  # -- JSON Generation --

  # Handle JSON string escaping
  JSON_SAFE_PROMPT=$(echo "$TASK_STR" | sed 's/"/\\"/g')
  JSON_SAFE_PROMISE=$( [[ "$PROMISE_TOKEN" == "null" ]] && echo "null" || echo "\"$PROMISE_TOKEN\"" )
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  START_EPOCH=$(date +%s)

  cat > "$STATE_PATH" <<JSON
{
  "active": true,
  "working_dir": "$PWD",
  "step": "prd",
  "iteration": 1,
  "max_iterations": $LOOP_LIMIT,
  "max_time_minutes": $TIME_LIMIT,
  "worker_timeout_seconds": $WORKER_TIMEOUT,
  "start_time_epoch": $START_EPOCH,
  "completion_promise": $JSON_SAFE_PROMISE,
  "original_prompt": "$JSON_SAFE_PROMPT",
  "current_ticket": null,
  "history": [],
  "started_at": "$TIMESTAMP",
  "session_dir": "$FULL_SESSION_PATH"
}
JSON

fi

# -- User Output --

cat <<EOF
🥒 Pickle Rick Activated!

>> Loop Config:
   Iteration: 1
   Limit:     $( [[ $LOOP_LIMIT -gt 0 ]] && echo "$LOOP_LIMIT" || echo "∞" )
   Max Time:  ${TIME_LIMIT}m
   Worker TO: ${WORKER_TIMEOUT}s
   Promise:   $( [[ "$PROMISE_TOKEN" != "null" ]] && echo "$PROMISE_TOKEN" || echo "None" )

>> Workspace:
   Path:      $FULL_SESSION_PATH
   State:     $STATE_PATH

>> Directive:
   $TASK_STR

⚠️  WARNING: This loop will continue until the task is complete,
    the iteration limit ($LOOP_LIMIT) is reached, the time limit (${TIME_LIMIT}m) expires, or a promise is fulfilled.
EOF

if [[ "$PROMISE_TOKEN" != "null" ]]; then
  echo ""
  echo "⚠️  STRICT EXIT CONDITION ACTIVE"
  echo "   You must output: <promise>$PROMISE_TOKEN</promise>"
fi
