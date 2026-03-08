# Requirements: run-until-error.sh

## Purpose
A bash script that repeatedly runs `./cjpm-run.sh` and stops only when a **fatal** condition is seen in the output. All other exits or errors should cause another run (retry). Output must be shown exactly once, in production order.

## Command to run
- Invoke `./cjpm-run.sh` from the script’s working directory (same directory as the script).
- No arguments are passed to `cjpm-run.sh`.

## Stream handling
- Capture **both** stdout and stderr from `./cjpm-run.sh`.
- Output must appear in **production order** (no reordering due to different buffering of stdout vs stderr).
- Output must be printed **exactly once** (no duplicate lines from the same run).
- Use a single stream for capture so ordering and single-copy are guaranteed (e.g. run under a pty and redirect the pty output to a single pipe/FIFO; do not let the pty also echo to the terminal).

## Fatal conditions (stop criteria)
The script must stop **only** when it sees one of these in a line of output:

1. **INTERNAL ERROR**  
   Match the exact substring `INTERNAL ERROR` (with a space). No other spelling or casing is required; this phrase is the only internal-error pattern.

2. **Segfault**  
   Match either:
   - the substring `Segmentation fault` (case-insensitive), or  
   - the substring `segfault` (case-insensitive).

Any other output (e.g. other errors, exceptions, test failures) must **not** stop the script; the script must keep retrying.

## Control flow
- **Loop:** Run `./cjpm-run.sh` in a loop. After each run finishes, if no fatal condition was seen, start the next run immediately.
- **When a fatal is seen:** Do **not** kill the process immediately. Continue reading and printing all remaining output until the run ends (so the full error trace is shown), then exit the script with status 1.
- **Stop on first fatal:** Exit as soon as one run has produced at least one line matching a fatal condition (after letting that run finish). Do not run another iteration after that.
- **Exit codes:**  
  - Exit 0 only if the script is stopped by the user (e.g. Ctrl+C) before any fatal was seen (optional; may also propagate signal exit).  
  - Exit 1 when a run produced at least one fatal line and has finished.

## Output and UX
- Print every line from the run exactly once, in the order it was produced.
- No extra “Script started” or similar banners (use quiet mode if using `script`).
- On normal exit after a fatal, ensure cleanup (remove temporary FIFO, avoid leaving child processes).

## Cleanup and robustness
- Remove any temporary file (e.g. FIFO) on exit (normal exit, exit after fatal, or interrupt).
- On exit, kill the current child process if it is still running (e.g. on interrupt), so no orphaned `cjpm-run.sh` or helper (e.g. `script`) processes remain.
- Do not rely on `set -e` for control flow; handle process exit and “saw fatal” explicitly so the script only stops on the defined fatal conditions and after the run has finished.

## Summary checklist
- [ ] Runs `./cjpm-run.sh` in a loop.
- [ ] Captures stdout and stderr in one ordered stream; prints each line once.
- [ ] Stops only on line containing `INTERNAL ERROR` or (case-insensitive) `Segmentation fault` / `segfault`.
- [ ] On first such line: keep reading until the run ends, then exit with status 1 (no second run).
- [ ] On any other outcome: run again (retry).
- [ ] Cleans up FIFO and child process on exit/interrupt.
