#!/usr/bin/env bash
set -euo pipefail

die () {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd () {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_FPK="${ROOT}/fpk"

if [ $# -lt 1 ]; then
  set -- "${DEFAULT_FPK}"
fi

APP_DIR="$1"
shift

HOST="192.168.2.15"
USER="junyo"
DEFAULT_VOLUME="vol4"
ENV_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --user) USER="$2"; shift 2 ;;
    --default-volume) DEFAULT_VOLUME="$2"; shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[ -d "$APP_DIR" ] || die "not a directory: $APP_DIR"
[ -f "${APP_DIR}/manifest" ] || die "missing manifest: ${APP_DIR}/manifest"

require_cmd fnpack
require_cmd ssh
require_cmd scp

if [ -n "$ENV_FILE" ] && [ ! -f "$ENV_FILE" ]; then
  die "env file not found: $ENV_FILE"
fi

echo "== Build + Test on fnOS =="
echo "app: ${APP_DIR}"
echo "nas: ${USER}@${HOST}"
echo "default volume: ${DEFAULT_VOLUME}"
if [ -n "$ENV_FILE" ]; then
  echo "env-file: ${ENV_FILE}"
fi
echo

echo "Step 1) build fpk"
fnpack build --directory "${APP_DIR}"

FPK_PATH="$(ls -1t ./*.fpk 2>/dev/null | head -n 1 || true)"
if [ -z "${FPK_PATH}" ]; then
  FPK_PATH="$(ls -1t "${APP_DIR}"/*.fpk 2>/dev/null | head -n 1 || true)"
fi
if [ -z "${FPK_PATH}" ]; then
  die "cannot find built .fpk. please locate the output and adjust this script accordingly."
fi

FPK_BASENAME="$(basename "${FPK_PATH}")"
REMOTE_DIR="/tmp/fn-app-factory"
REMOTE_FPK="${REMOTE_DIR}/${FPK_BASENAME}"

echo
echo "Step 2) upload fpk to NAS"
ssh "${USER}@${HOST}" "mkdir -p '${REMOTE_DIR}'"
scp "${FPK_PATH}" "${USER}@${HOST}:${REMOTE_FPK}"

if [ -n "$ENV_FILE" ]; then
  REMOTE_ENV="${REMOTE_DIR}/config.env"
  scp "${ENV_FILE}" "${USER}@${HOST}:${REMOTE_ENV}"
fi

echo
cat <<EOF
Step 3) run appcenter-cli on NAS

将执行（在 NAS 上）：
  - appcenter-cli default-volume
  - (可选) appcenter-cli default-volume ${DEFAULT_VOLUME}
  - appcenter-cli install-fpk ${REMOTE_FPK} [--env <file>]

注意：
- default-volume 是否接受名称/编号请以实机为准。
- 若 compose/wizard 未补齐，安装后可能无法正常启动。
EOF

read -r -p "确认继续执行上机安装/测试？[y/N] " CONFIRM
case "${CONFIRM:-}" in
  y|Y) ;;
  *) die "aborted by user" ;;
esac

REMOTE_ENV_ARG=""
if [ -n "$ENV_FILE" ]; then
  REMOTE_ENV_ARG="--env '${REMOTE_DIR}/config.env'"
fi

ssh -t "${USER}@${HOST}" bash -lc "set -euo pipefail
  echo '== appcenter-cli default-volume (current) =='
  sudo appcenter-cli default-volume || true
  echo
  echo '== set default-volume to: ${DEFAULT_VOLUME} =='
  sudo appcenter-cli default-volume '${DEFAULT_VOLUME}'
  echo
  echo '== install fpk =='
  sudo appcenter-cli install-fpk '${REMOTE_FPK}' ${REMOTE_ENV_ARG}
  echo
  echo '== list apps =='
  sudo appcenter-cli list || true
"

echo
echo "OK: install step executed."
