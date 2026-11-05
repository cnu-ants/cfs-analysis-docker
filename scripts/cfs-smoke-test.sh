#!/usr/bin/env bash
# Smoke test: run the unmodified cFS for a short time, require OPERATIONAL.
set -euo pipefail

cd /cFS/build-native_std/exe/cpu1
mkdir -p /reports
arch="$(dpkg --print-architecture)"
log="/reports/${arch}-smoke.log"
duration="${SMOKE_SECONDS:-15}"

printf '[smoke] arch=%s time_limit=%ss log=%s\n' "$arch" "$duration" "$log"
file ./core-cpu1

set +e
timeout --signal=TERM --kill-after=3s "${duration}s" \
  ./core-cpu1 >"$log" 2>&1
rc=$?
set -e

# 124 is expected because cFS normally runs until terminated.
if [[ "$rc" -ne 0 && "$rc" -ne 124 ]]; then
  printf '[smoke] FAIL: cFS unexpectedly exited with status %s\n' "$rc"
  tail -n 50 "$log"
  exit 1
fi
if ! grep -q 'CFE_ES_Main entering OPERATIONAL state' "$log"; then
  echo '[smoke] FAIL: OPERATIONAL state not reached'
  tail -n 70 "$log"
  exit 1
fi
if grep -Eq 'Application Init Failed|Error configuring stack|Cannot Create SB Pipe' "$log"; then
  echo '[smoke] FAIL: startup/task/queue error in output'
  grep -En 'Application Init Failed|Error configuring stack|Cannot Create SB Pipe' "$log" || true
  exit 1
fi

echo '[smoke] PASS: cFS reached OPERATIONAL; no known initialization errors detected'
echo '[smoke] NOTE: this does not verify scheduling privileges or all runtime features'
