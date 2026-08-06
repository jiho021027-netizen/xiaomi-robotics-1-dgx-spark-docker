#!/usr/bin/env bash
set -euo pipefail
mode="${1:-shell}"
if [[ $# -gt 0 ]]; then shift; fi
case "${mode}" in
  server) exec /opt/venvs/xr1-server/bin/python -u deploy/server.py --model "${MODEL_PATH}" --host "${SERVER_HOST:-0.0.0.0}" --port "${BASE_PORT}" ;;
  eval) export PYTHON=/opt/venvs/robocasa365-client/bin/python; exec bash scripts/launch_robocasa365.sh 1 /results "${MODEL_PATH}" "$@" ;;
  shell) exec /bin/bash "$@" ;;
  *) echo "Usage: server | eval [launcher args...] | shell [bash args...]" >&2; exit 2 ;;
esac
