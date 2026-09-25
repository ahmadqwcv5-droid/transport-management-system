#!/usr/bin/env bash
set -euo pipefail

project="tms-s411-acceptance"
compose_file="compose.acceptance.yaml"
retained_volume="tms-smoke_postgres_data"
action="${1:-up}"

if docker-compose -f "$compose_file" -p "$project" config | grep -q "$retained_volume"; then
  printf 'Refusing to run: acceptance configuration references retained volume %s\n' "$retained_volume" >&2
  exit 41
fi

case "$action" in
  up)
    docker-compose -f "$compose_file" -p "$project" up -d --build
    postgres_id="$(docker-compose -f "$compose_file" -p "$project" ps -q postgres)"
    mounted="$(docker inspect "$postgres_id" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql"}}{{.Name}}{{end}}{{end}}')"
    if [[ "$mounted" == "$retained_volume" || "$mounted" != *"s411-acceptance"* ]]; then
      printf 'Acceptance environment failed closed: unexpected database volume %s\n' "$mounted" >&2
      exit 42
    fi
    printf 'Disposable acceptance project=%s database-volume=%s api=http://localhost:5180\n' "$project" "$mounted"
    ;;
  down)
    docker-compose -f "$compose_file" -p "$project" down -v
    ;;
  diagnose)
    docker-compose -f "$compose_file" -p "$project" ps
    ;;
  *)
    printf 'Usage: %s {up|down|diagnose}\n' "$0" >&2
    exit 2
    ;;
esac
