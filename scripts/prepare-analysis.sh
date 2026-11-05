#!/usr/bin/env bash
# Copy the exact cFS source snapshot to writable tool-local workspace.
# Do not touch the read-only original /cFS or its original build artifacts.
set -euo pipefail
source_dir=/cFS
work_dir=/analysis-work/cFS

if [[ ! -f "$source_dir/Makefile" || ! -d "$source_dir/.git" ]]; then
  echo '[prepare] No cFS source at /cFS. Start the cFS Compose service first.' >&2
  exit 2
fi

source_commit="$(git -C "$source_dir" rev-parse HEAD)"
if [[ -f "$work_dir/Makefile" ]]; then
  if [[ -d "$work_dir/.git" && "$(git -C "$work_dir" rev-parse HEAD)" == "$source_commit" ]]; then
    echo "[prepare] Existing source copy at $work_dir (commit $source_commit)"
    echo '[prepare] Not overwriting previous tool-local changes.'
    exit 0
  fi
  echo "[prepare] Existing $work_dir differs from source snapshot; refusing to overwrite." >&2
  echo '[prepare] Use a new analysis workspace or manually archive/clear the old copy.' >&2
  exit 3
fi

mkdir -p "$work_dir"
# Root-level native builds belong to the builder image; analyzers rebuild afresh.
rsync -a --exclude='/build-*/' --exclude='/build/' \
  "$source_dir/" "$work_dir/"
if [[ "$(git -C "$work_dir" rev-parse HEAD)" != "$source_commit" ]]; then
  echo '[prepare] ERROR: copied cFS commit differs from original' >&2
  exit 4
fi
printf '[prepare] Ready: %s at %s\n' "$source_commit" "$work_dir"
printf '[prepare] The analyzer may now build here without changing /cFS.\n'
