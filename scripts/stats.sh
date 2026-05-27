#!/usr/bin/env bash
# Estado de recursos del container Ollama.
set -euo pipefail

NAME=llmlocal-ollama

echo "=== docker stats (snapshot) ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}" $NAME

echo
echo "=== Modelos cargados en RAM ahora mismo ==="
curl -s http://localhost:11434/api/ps | jq -r '
  if (.models | length) == 0 then "  (ninguno - se cargaran on-demand)"
  else .models[] | "  - \(.name)  size=\((.size/1e9*10|floor)/10)GB  size_vram=\((.size_vram/1e9*10|floor)/10)GB  expires=\(.expires_at)"
  end'

echo
echo "=== Disco usado por modelos (host) ==="
du -sh /home/clp/Workspace/llmlocal/models/ollama/ 2>/dev/null | sed 's/^/  /'

echo
echo "=== RAM/swap WSL ==="
free -h | sed 's/^/  /'
