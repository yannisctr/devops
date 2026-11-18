#!/usr/bin/env bash
set -euo pipefail

base=${1:-http://127.0.0.1:8080}
api="$base/api"
title="smoke-$(date +%s)-$$"
id=''
request() { curl --max-time 10 -fsS "$@"; }
cleanup() {
    if [[ -n $id ]]; then
        request -X DELETE "$api/tasks/$id" >/dev/null || true
    fi
}
trap cleanup EXIT

if ! page=$(request "$base/"); then
    echo "Frontend inaccessible à $base. Démarrer la pile DEV ou vérifier le port-forward." >&2
    exit 1
fi
if ! grep -F 'Liste de tâches' <<< "$page" >/dev/null; then
    echo "La page de l’application est introuvable à $base." >&2
    exit 1
fi
request "$api/health" | jq -e '.status == "ok"' >/dev/null
status=$(curl --max-time 10 -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d '{"title":""}' "$api/tasks")
[[ $status == 422 ]]
status=$(curl --max-time 10 -sS -o /dev/null -w '%{http_code}' -X PATCH "$api/tasks")
[[ $status == 405 ]]

created=$(request -H 'Content-Type: application/json' -d "{\"title\":\"$title\",\"priority\":\"high\",\"due_date\":\"2030-05-21\"}" "$api/tasks")
id=$(jq -er '.id | numbers' <<< "$created")
jq -e --arg title "$title" '.title == $title and .priority == "high" and .due_date == "2030-05-21" and .completed == false' <<< "$created" >/dev/null
if [[ -n ${SMOKE_RESTART_COMMAND:-} ]]; then
    bash -ec "$SMOKE_RESTART_COMMAND"
fi
request "$api/tasks" | jq -e --argjson id "$id" --arg title "$title" 'any(.[]; .id == $id and .title == $title and .priority == "high" and .due_date == "2030-05-21")' >/dev/null

if [[ -n ${SMOKE_PEER_URL:-} ]]; then
    request "$SMOKE_PEER_URL/api/tasks" | jq -e --arg title "$title" 'all(.[]; .title != $title)' >/dev/null
fi
request -X PUT -H 'Content-Type: application/json' -d "{\"title\":\"$title-updated\",\"completed\":true,\"priority\":\"low\",\"due_date\":null}" "$api/tasks/$id" |
    jq -e --arg title "$title-updated" '.title == $title and .completed and .priority == "low" and .due_date == null' >/dev/null
request "$api/tasks" | jq -e --argjson id "$id" --arg title "$title-updated" 'any(.[]; .id == $id and .title == $title and .completed and .priority == "low" and .due_date == null)' >/dev/null
request -X DELETE "$api/tasks/$id" >/dev/null
request "$api/tasks" | jq -e --argjson id "$id" 'all(.[]; .id != $id)' >/dev/null
id=''
echo "Smoke test OK ($base)"
