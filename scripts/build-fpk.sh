#!/usr/bin/env bash
set -euo pipefail

die () {
  echo "ERROR: $*" >&2
  exit 1
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v act >/dev/null 2>&1 || die "missing act — install from https://github.com/nektos/act"

WORKFLOW=".github/workflows/build-fpk.yml"
[ -f "$WORKFLOW" ] || die "missing workflow: ${WORKFLOW}"
[ -d "${ROOT}/fpk" ] || die "missing fpk directory: ${ROOT}/fpk"
[ -f "${ROOT}/fpk/manifest" ] || die "missing manifest: ${ROOT}/fpk/manifest"

ARTIFACT_DIR="${ROOT}/.act-artifacts"
mkdir -p "$ARTIFACT_DIR"

ACT_CMD=(act workflow_dispatch -W "$WORKFLOW" --artifact-server-path "$ARTIFACT_DIR")

# act 在 Windows 上默认可能把 ubuntu-latest 映射到 node 镜像，导致缺 curl 等基础工具。
# 这里给一个默认 runner 镜像映射；用户若显式设置 ACT_EXTRA_ARGS 则完全尊重用户设置。
if [ -z "${ACT_EXTRA_ARGS:-}" ]; then
  ACT_EXTRA_ARGS="-P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-22.04"
fi

if [ -n "${ACT_EXTRA_ARGS:-}" ]; then
  # shellcheck disable=SC2206
  ACT_CMD+=(${ACT_EXTRA_ARGS})
fi

echo "== Build fpk via act (same workflow as GitHub Actions) =="
echo "app root: ${ROOT}"
echo "running: ${ACT_CMD[*]}"
echo

"${ACT_CMD[@]}"

echo
echo "OK: act finished. .fpk 产物应在 dist/ 下（与 CI 一致）。"
echo "act artifact 缓存目录: ${ARTIFACT_DIR}"
