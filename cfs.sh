#!/usr/bin/env bash
# cFS builder + individual static-analysis containers under one Compose project.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  cat <<'HELP'
Usage: ./cfs.sh [--arch auto|arm64|amd64] COMMAND [SERVICE]

SERVICES: cfs | ikos | infer | all

  build [SERVICE]     Build images; default: cfs + ikos. 'all' also builds Infer.
  start [SERVICE]     Start containers; default: cfs + ikos. 'all' includes Infer.
  stop                Stop containers; keep source and analysis volumes.
  verify [SERVICE]    Check installed tools; default: cfs + ikos.
  shell [SERVICE]     Open interactive shell; default: cfs.
  prepare [SERVICE]   Make a writable copy of the shared cFS source; ikos/infer only.
  smoke               Run cFS smoke test (requires OPERATIONAL).
  unit                Run cFS unit tests with per-test timeout.
  run                 Run cFS flight software in foreground.
  status              Show image architectures and containers.
  analyze [args...]   Backward-compatible alias for 'shell ikos' or ikos command.

Examples:
  ./cfs.sh --arch arm64 build cfs
  ./cfs.sh --arch arm64 build ikos
  ./cfs.sh --arch arm64 build infer         # Infer image is always AMD64
  ./cfs.sh --arch arm64 start all
  ./cfs.sh --arch arm64 prepare ikos
  ./cfs.sh --arch arm64 shell ikos
  ./cfs.sh --arch arm64 shell infer
  ./cfs.sh --arch amd64 verify all
  ./cfs.sh --arch amd64 smoke

On ARM hosts, Infer's amd64 image requires binfmt/QEMU (and may be slow).
/cFS is the same shared source tree in all containers (read-only for analyzers).
/analysis-work is tool-private and writable; /results is host-backed.
HELP
}

requested="${CFS_ARCH:-auto}"
if [[ "${1:-}" == --arch ]]; then
  [[ $# -ge 2 ]] || { echo 'Missing --arch value' >&2; exit 2; }
  requested="$2"
  shift 2
fi
cmd="${1:-help}"
if [[ "$cmd" == help || "$cmd" == -h || "$cmd" == --help ]]; then usage; exit 0; fi
shift || true

command -v docker >/dev/null || { echo '[cfs] docker executable not found' >&2; exit 1; }
if [[ "$requested" == auto || -z "$requested" ]]; then
  requested="$(docker info --format '{{.Architecture}}')"
fi
case "$requested" in
  arm64|aarch64) arch=arm64 ;;
  amd64|x86_64) arch=amd64 ;;
  *) echo "Unsupported architecture: $requested" >&2; exit 2 ;;
esac
export CFS_ARCH="$arch"

compose() { docker compose -p "cfs-${arch}" "$@"; }
image_for() {
  case "$1" in
    cfs) echo "cfs:${arch}" ;;
    ikos) echo "cfs-ikos:${arch}" ;;
    infer) echo 'cfs-infer:amd64' ;;
    *) echo "Invalid service: $1" >&2; exit 2 ;;
  esac
}
needs_image() {
  local image
  image="$(image_for "$1")"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "[cfs] Missing $image; build it with: ./cfs.sh --arch $arch build $1" >&2
    exit 1
  fi
}
service_list() {
  local target="${1:-default}"
  case "$target" in
    default) printf '%s\n' cfs ikos ;;
    all) printf '%s\n' cfs ikos infer ;;
    cfs|ikos|infer) printf '%s\n' "$target" ;;
    *) echo "Unknown service: $target" >&2; exit 2 ;;
  esac
}
start_service() {
  local target="$1" service
  # Initializing cfs first populates the named volume from the prebuilt /cFS.
  needs_image cfs
  compose up -d --no-build cfs >/dev/null
  if [[ "$target" != cfs ]]; then
    needs_image "$target"
    compose up -d --no-build "$target" >/dev/null
  fi
}

printf '[cfs] source architecture linux/%s; Infer runtime linux/amd64\n' "$arch"
case "$cmd" in
  build)
    target="${1:-default}"
    case "$target" in default|all|cfs|ikos|infer) ;; *) echo "Unknown service: $target" >&2; exit 2 ;; esac
    while IFS= read -r service; do
      if [[ "$service" == infer && "$arch" == arm64 ]]; then
        echo '[cfs] Infer Linux binary is AMD64; QEMU/binfmt is needed on ARM hosts.'
      fi
      compose build "$service"
    done < <(service_list "$target")
    echo '[cfs] Built. Named volumes persist across rebuilds; see README before changing source/toolchain.'
    ;;
  start)
    target="${1:-default}"
    case "$target" in default|all|cfs|ikos|infer) ;; *) echo "Unknown service: $target" >&2; exit 2 ;; esac
    while IFS= read -r service; do start_service "$service"; done < <(service_list "$target")
    compose ps
    ;;
  stop) compose down ;;
  shell)
    target="${1:-cfs}"
    case "$target" in cfs|ikos|infer) ;; *) echo "Unknown service: $target" >&2; exit 2 ;; esac
    start_service "$target"
    compose exec "$target" bash
    ;;
  analyze)
    start_service ikos
    if [[ $# -eq 0 ]]; then compose exec ikos bash; else compose exec -T ikos "$@"; fi
    ;;
  prepare)
    target="${1:-ikos}"
    case "$target" in ikos|infer) ;; *) echo "Prepare accepts ikos or infer, not $target" >&2; exit 2 ;; esac
    start_service "$target"
    compose exec -T "$target" prepare-analysis.sh
    ;;
  verify)
    target="${1:-default}"
    case "$target" in default|all|cfs|ikos|infer) ;; *) echo "Unknown service: $target" >&2; exit 2 ;; esac
    while IFS= read -r service; do
      start_service "$service"
      case "$service" in
        cfs) compose exec -T cfs verify-toolchain.sh ;;
        ikos)
          compose exec -T ikos bash -lc 'set -e; \
            test "$(dpkg-query -W -f=\${Version} ikos)" = "$IKOS_EXPECTED_APT_VERSION"; \
            test "$(dpkg-query -W -f=\${Version} clang-14)" = "$LLVM14_EXPECTED_APT_VERSION"; \
            ikos --version; clang-14 --version | head -1; llvm-config-14 --version'
          ;;
        infer) compose exec -T infer bash -lc 'infer --version; test -x /opt/infer/bin/infer' ;;
      esac
    done < <(service_list "$target")
    ;;
  smoke) start_service cfs; compose exec -T cfs cfs-smoke-test.sh ;;
  unit) start_service cfs; compose exec -T cfs cfs-unit-tests.sh ;;
  run)
    start_service cfs
    compose exec cfs bash -lc 'cd /cFS/build-native_std/exe/cpu1 && exec ./core-cpu1'
    ;;
  status)
    for service in cfs ikos infer; do
      image="$(image_for "$service")"
      docker image inspect "$image" --format '{{.RepoTags}} {{.Architecture}}' 2>/dev/null || \
        echo "[cfs] image missing: $image"
    done
    compose ps
    ;;
  *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac
