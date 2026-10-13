#!/usr/bin/env bash
# Probes each target, and posts to Discord only when one goes down or comes back.
# down.txt holds the names that were down last run; the workflow commits it when
# it changes, so an outage alerts once rather than every five minutes.
set -uo pipefail

# name|url — any answer but 200 counts as down.
TARGETS=(
  "api|https://api.fitbie.app/healthz"
  # Reads Postgres: /healthz answers "ok" with the database gone.
  "api-db|https://api.fitbie.app/v1/notifications/copy"
  "web|https://fitbie.app/"
)

probe() {
  # Three tries twenty seconds apart, so one dropped request isn't an outage.
  local url=$1 code
  for try in 1 2 3; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url")
    [[ $code == 200 ]] && { echo 200; return; }
    [[ $try -lt 3 ]] && sleep 20
  done
  echo "${code:-000}"
}

touch down.txt
was_down=$(cat down.txt)
now_down=""
declare -A codes
for t in "${TARGETS[@]}"; do
  name=${t%%|*} url=${t#*|}
  codes[$name]=$(probe "$url")
  echo "$name ${codes[$name]} $url"
  [[ ${codes[$name]} == 200 ]] || now_down+="$name"$'\n'
done

lines=""
for t in "${TARGETS[@]}"; do
  name=${t%%|*} url=${t#*|}
  before=$(grep -qx "$name" <<<"$was_down" && echo down || echo up)
  after=$([[ ${codes[$name]} == 200 ]] && echo up || echo down)
  [[ $before == up && $after == down ]] && lines+="🔴 **$name** down (${codes[$name]}) — $url"$'\n'
  [[ $before == down && $after == up ]] && lines+="🟢 **$name** back up — $url"$'\n'
done

printf '%s' "$now_down" > down.txt
[[ -z $lines ]] && exit 0

echo "$lines"
if [[ -z ${DISCORD_WEBHOOK_URL:-} ]]; then
  echo "::error::state changed but DISCORD_WEBHOOK_URL is not set"
  exit 1
fi
jq -n --arg c "$lines" '{content: $c}' |
  curl -sf --max-time 10 -H 'Content-Type: application/json' -d @- "$DISCORD_WEBHOOK_URL" >/dev/null ||
  { echo "::error::Discord post failed"; exit 1; }
