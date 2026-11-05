#!/usr/bin/env bash
# Run the same generated native_std CTest test set with a PER-TEST timeout.
# Unlike 'make native_std.runtest', a stuck test cannot block the entire suite.
# Failures remain failures; no test is skipped unless explicitly requested.
set -euo pipefail

build_dir=/cFS/build-native_std/native/default_cpu1
arch="$(dpkg --print-architecture)"
limit="${CTEST_TIMEOUT:-45}"
mkdir -p /reports

if [[ ! -f "$build_dir/CTestTestfile.cmake" ]]; then
  echo "[unit] ERROR: no CTest test definition at $build_dir" >&2
  exit 2
fi

args=(--test-dir "$build_dir" --output-on-failure --timeout "$limit" -j 1
      --output-junit "/reports/${arch}-unit.xml")

# Optional: compare all remaining tests while recording the known ARM64
# bin-sem-timeout-test separately. This does NOT imply full-suite success.
if [[ "${SKIP_KNOWN_ARM64_STACK_TEST:-0}" == "1" ]]; then
  args+=(-E '^bin-sem-timeout-test$')
  echo '[unit] WARNING: bin-sem-timeout-test excluded at user request'
fi

printf '[unit] arch=%s per_test_timeout=%ss\n' "$arch" "$limit"
echo "[unit] log: /reports/${arch}-unit.log"
echo "[unit] junit: /reports/${arch}-unit.xml"

set +e
ctest "${args[@]}" 2>&1 | tee "/reports/${arch}-unit.log"
rc=${PIPESTATUS[0]}
set -e

if [[ "$rc" -eq 0 ]]; then
  echo '[unit] PASS: all SELECTED CTest tests passed'
else
  echo "[unit] FAIL: CTest returned $rc; inspect the log and JUnit report"
  if [[ "$arch" == "arm64" ]]; then
    echo '[unit] Note: ARM64 glibc rejects some original tests with small explicit pthread stacks'
  fi
fi
exit "$rc"
