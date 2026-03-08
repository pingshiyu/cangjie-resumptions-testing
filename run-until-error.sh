#!/usr/bin/env bash
# Run ./cjpm-run.sh repeatedly. Stop only when "internal error" or a segfault is seen;
# on any other error or normal exit, keep trying.
# When a fatal condition is seen, we let the run finish so the full error trace is produced.

shopt -s nocasematch

FIFO=$(mktemp -u)
mkfifo "$FIFO"
trap 'rm -f "$FIFO"; kill "$CPID" 2>/dev/null' EXIT

while true; do
  saw_fatal=0
  # Run in a pty so stdout and stderr are merged in production order (avoids
  # reordering from different buffering when both are piped to the same FIFO).
  # Redirect script's stdio to /dev/null so we only print what we read from the FIFO (no duplicate output).
  script -q -c "./cjpm-run.sh" "$FIFO" </dev/null >/dev/null 2>&1 &
  CPID=$!

  while IFS= read -r line; do
    printf '%s\n' "$line"
    # Match exact phrase "INTERNAL ERROR" (space between words); segfault patterns are case-insensitive.
    if [[ "$line" == *"INTERNAL ERROR"* ]] ||
       [[ "$line" == *"Segmentation fault"* ]] ||
       [[ "$line" == *"segfault"* ]]; then
      saw_fatal=1
    fi
  done < "$FIFO"

  wait "$CPID" 2>/dev/null || true
  if (( saw_fatal )); then
    exit 1
  fi
  # Run ended without fatal error; loop and try again
done
