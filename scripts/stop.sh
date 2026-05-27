#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f compose/docker-compose.yml down 2>/dev/null || true
docker compose -f compose/docker-compose.ipex.yml down 2>/dev/null || true
echo "OK Ollama parado"
