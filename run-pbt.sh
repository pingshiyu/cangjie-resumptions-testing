#!/bin/bash
# Run PBT with increased stack size to avoid segfaults from stack exhaustion.
# Uses 64MB stack; adjust with ulimit -s <KB> if needed.
ulimit -s 65536
exec cjpm run "$@"
