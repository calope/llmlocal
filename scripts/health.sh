#!/usr/bin/env bash
# Health check del stack: container healthy + endpoint + modelos + tuning activo.
set -euo pipefail

OK="OK"; KO="KO"

# 1. Container running + healthy
NAME=llmlocal-ollama
state=$(docker inspect --format '{{.State.Status}}' $NAME 2>/dev/null || echo "missing")
health=$(docker inspect --format '{{.State.Health.Status}}' $NAME 2>/dev/null || echo "n/a")

printf "[%s] Container       state=%s  health=%s\n" \
  "$([ "$state" = "running" ] && [ "$health" = "healthy" ] && echo "$OK" || echo "$KO")" \
  "$state" "$health"

# 2. Endpoint /api/tags responde
if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
  printf "[%s] HTTP endpoint   http://localhost:11434/api/tags\n" "$OK"
else
  printf "[%s] HTTP endpoint   no responde\n" "$KO"
  exit 1
fi

# 3. Modelos descargados
n=$(curl -s http://localhost:11434/api/tags | jq '.models | length')
printf "[%s] Modelos         %d descargado(s):\n" "$([ "$n" -gt 0 ] && echo "$OK" || echo "$KO")" "$n"
curl -s http://localhost:11434/api/tags | jq -r '.models[] | "                  - \(.name)  \((.size/1e9*10|floor)/10)GB"'

# 4. Tuning activo
echo
echo "Tuning aplicado:"
docker exec $NAME env 2>/dev/null | grep ^OLLAMA_ | sort | sed 's/^/  /'

# 5. Versiones
echo
echo "Versiones:"
echo "  ollama:        $(docker exec $NAME ollama --version 2>/dev/null | head -1)"
echo "  imagen:        $(docker inspect --format '{{.Image}}' $NAME 2>/dev/null | head -c 25)..."
echo "  recursos lim:  $(docker inspect --format 'mem={{.HostConfig.Memory}} bytes' $NAME 2>/dev/null)"
