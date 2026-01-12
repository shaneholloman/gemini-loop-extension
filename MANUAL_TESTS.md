# Manual Test Plan for Limits & Timeouts

## 1. Iteration Limit Test (Main Loop)
**Goal:** Verify that the main `/pickle` loop respects the `--max-iterations` flag.

**Steps:**
1. Run a task with a very low iteration limit (e.g., 2).
2. Give it a task that requires multiple steps (like a complex refactor or multi-step feature).
3. Observe if it stops exactly after the specified number of iterations.

**Command:**
```bash
/pickle "Refactor the 'commands/pickle.toml' file to add comments to every line. Then verify it. Then revert it." --max-iterations 2
```

**Expected Outcome:**
- The agent should perform 2 loops (e.g., plan, then start implementing).
- On the 3rd attempt to loop, it should exit or print a message indicating the limit was reached.
- Check `state.json` in the session folder; `"iteration"` should be `2` (or `3` depending on when check happens) and active should be false or loop terminated.

---

## 2. Time Limit Test (Main Loop)
**Goal:** Verify that the main `/pickle` loop respects the `--max-time` flag.

**Steps:**
1. Run a task with a very short time limit (e.g., 1 minute).
2. Give it a task that takes longer than 1 minute to complete (or just wait).
3. Observe if it terminates after the time expires.

**Command:**
```bash
/pickle "Research the entire codebase and map every single file dependency." --max-time 1
```

**Expected Outcome:**
- The agent will start working.
- After ~1 minute, the next time the loop hook triggers (or script checks), it should detect the timeout and exit.
- *Note: It might finish the current iteration before stopping.*

---

## 3. Worker Timeout Test
**Goal:** Verify that an individual Worker process (spawned by the manager) is killed if it exceeds the `--timeout` passed to `spawn_worker.py`.

**Steps:**
1. This is harder to trigger via `/pickle` directly without a long task.
2. We can manually invoke the worker spawner with a short timeout and a task that sleeps or hangs.
3. Since we can't easily tell the model to "sleep", we can give it a massive task and a 10-second timeout.

**Command (Manual Invocation):**
```bash
# Create a dummy ticket dir
mkdir -p /tmp/test-ticket

# Run the spawner manually with a 5-second timeout
python3 scripts/spawn_worker.py \
  --ticket-id "TEST-001" \
  --ticket-path "/tmp/test-ticket" \
  --timeout 5 \
  "Count to 1 million by writing numbers to a file one by one."
```

**Expected Outcome:**
- The script should start the worker.
- It should show the spinner.
- After 5 seconds, it should print `[TIMEOUT] Worker killed after timeout.`
- The log file in `/tmp/test-ticket` should contain the timeout message.
- The exit code of the python script should be non-zero (specifically 124 or 1).

---

## 4. Completion Promise Test
**Goal:** Verify the loop stops EARLY if the completion promise is found.

**Steps:**
1. Run a simple task.
2. Set a specific completion promise string.
3. instruct the agent to output that string immediately.

**Command:**
```bash
/pickle "Say hello and then stop." --completion-promise "I AM DONE"
```

**Expected Outcome:**
- The agent should say hello.
- The agent should output `<promise>I AM DONE</promise>`.
- The loop should terminate immediately, even if max iterations haven't been reached.
