#!/usr/bin/env bash
# Levanta el backend Ollama (CPU por defecto, IPEX con --ipex).
set -euo pipefail

cd "$(dirname "$0")/.."

VARIANT="cpu"
if [[ "${1:-}" == "--ipex" ]]; then
  VARIANT="ipex"
fi

case "$VARIANT" in
  cpu)
    docker compose -f compose/docker-compose.yml up -d
    ;;
  ipex)
    docker compose -f compose/docker-compose.ipex.yml up -d
    ;;
esac

echo
echo "Esperando a Ollama en http://localhost:11434 ..."
for i in $(seq 1 30); do
  if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "OK Ollama listo (variante: $VARIANT)"
    curl -s http://localhost:11434/api/tags | jq -r '.models[]? | "  - \(.name) [\(.size/1e9 | floor)GB]"' 2>/dev/null || true
    exit 0
  fi
  sleep 1
done
echo "AVISO: Ollama no respondio en 30s. Revisa: docker logs llmlocal-ollama"
exit 1
