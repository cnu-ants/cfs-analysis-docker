#!/usr/bin/env bash
# Verify exact Ubuntu package versions in either image; no cFS source changes.
set -euo pipefail
expected_gcc="${TOOLCHAIN_GCC_APT_VERSION:?missing expected GCC package version}"
expected_llvm="${TOOLCHAIN_LLVM_APT_VERSION:?missing expected LLVM package version}"

check_package() {
  local pkg="$1" want="$2" got
  got="$(dpkg-query -W -f='${Version}' "$pkg")"
  if [[ "$got" != "$want" ]]; then
    printf '[toolchain] ERROR %s: expected %s, installed %s\n' "$pkg" "$want" "$got" >&2
    return 1
  fi
  printf '[toolchain] %-15s %s\n' "$pkg" "$got"
}

check_package gcc-13 "$expected_gcc"
check_package g++-13 "$expected_gcc"
check_package clang-18 "$expected_llvm"
check_package llvm-18 "$expected_llvm"
[[ "$(gcc-13 -dumpfullversion)" == 13.3.0 ]] || { echo 'Unexpected GCC upstream version' >&2; exit 1; }
clang-18 --version | head -n 1
opt-18 --version | head -n 1
printf '[toolchain] verified for %s\n' "$(dpkg --print-architecture)"
