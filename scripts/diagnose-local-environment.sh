#!/usr/bin/env bash
set -euo pipefail

project="${TMS_COMPOSE_PROJECT:-tms-smoke}"
compose_command="${TMS_COMPOSE_COMMAND:-docker-compose}"

printf 'Compose project: %s\n' "$project"
printf 'Expected API environment: Development\n'
printf 'Expected database host/database: postgres/transport_management (or POSTGRES_DB override)\n'

postgres_id="$($compose_command -p "$project" ps -q postgres 2>/dev/null || true)"
api_id="$($compose_command -p "$project" ps -q api 2>/dev/null || true)"

if [[ -z "$postgres_id" ]]; then
  printf 'PostgreSQL container: not running for this project\n'
else
  printf 'PostgreSQL container: %s\n' "$postgres_id"
  docker inspect "$postgres_id" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql"}}Mounted PostgreSQL volume: {{.Name}} -> {{.Destination}}{{end}}{{end}}'
fi

if [[ -z "$api_id" ]]; then
  printf 'API container: not running for this project\n'
else
  docker inspect "$api_id" --format 'API container: {{.Name}}; environment={{range .Config.Env}}{{if eq . "ASPNETCORE_ENVIRONMENT=Development"}}Development{{else if eq . "ASPNETCORE_ENVIRONMENT=Testing"}}Testing{{else if eq . "ASPNETCORE_ENVIRONMENT=Production"}}Production{{end}}{{end}}'
fi

if [[ -n "${TMS_DIAGNOSTIC_ACCESS_TOKEN:-}" ]]; then
  printf 'Authenticated identity: '
  curl --fail --silent \
    -H "Authorization: Bearer ${TMS_DIAGNOSTIC_ACCESS_TOKEN}" \
    "${API_BASE_URL:-http://localhost:5080}/api/auth/me"
  printf '\n'
else
  printf 'Authenticated identity: set TMS_DIAGNOSTIC_ACCESS_TOKEN to query /api/auth/me (token is never printed)\n'
fi
