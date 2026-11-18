#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

compose=(docker compose)
case "${1:-}:$#" in
    :0) ;;
    --sudo:1) compose=(sudo docker compose) ;;
    *) echo "Usage: $0 [--sudo]" >&2; exit 2 ;;
esac

"${compose[@]}" up -d --build --wait
frontend_address=$("${compose[@]}" port frontend 80)
printf -v restart_command '%q ' "${compose[@]}" up -d --force-recreate --no-deps --wait database
SMOKE_RESTART_COMMAND="$restart_command" exec bash scripts/smoke-test.sh "http://$frontend_address"
