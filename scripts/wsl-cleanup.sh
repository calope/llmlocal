#!/usr/bin/env bash
# Limpieza segura para liberar espacio en el VHD de WSL y permitir que
# sparseVhd compacte tras `wsl --shutdown`.
#
# Uso: ./wsl-cleanup.sh           # DRY-RUN: muestra lo que haria, no borra nada
#      ./wsl-cleanup.sh --execute # Ejecuta de verdad
#
# Lo que limpia (en este orden):
#   1. Docker build cache no usada     (~16 GB)
#   2. Imagenes Docker no referenciadas (~21 GB)
#   3. Tags antiguos de tinerfe-ords/auth/jobs (mantiene :latest + 1 reciente)
#   4. Caches de paquetes user (apt/npm/pnpm/uv/bun) — solo cache, no datos
#   5. /tmp viejos (>7 dias)
#   6. logs Docker
#
# NO toca:
#   - Modelos LLM en ~/Workspace/llmlocal/models/
#   - Codigo en ~/Workspace/
#   - Dumps de tinerfe-db (deja al usuario decidir)
#   - Imagenes Docker en uso por containers actuales

set -euo pipefail

EXECUTE=false
[ "${1:-}" = "--execute" ] && EXECUTE=true

if $EXECUTE; then
  echo "MODO: EJECUCION REAL"
else
  echo "MODO: DRY-RUN — nada se borra. Anade --execute para ejecutar."
fi
echo

run() {
  echo ">> $*"
  $EXECUTE && eval "$@"
}

# Tamano antes (usamos df que es instantaneo, no du recursivo)
before=$(df --output=used / | tail -1)
echo "Disco / usado antes:  $(numfmt --to=iec $((before*1024)))"
echo "C: libre antes:       $(powershell.exe -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB,1)" 2>/dev/null | tr -d '\r') GB"
echo

# 1. Docker build cache
echo "[1] Docker builder prune -a -f"
run "docker builder prune -a -f"
echo

# 2. Docker image prune
echo "[2] Docker image prune -a -f (imagenes sin container que las use)"
run "docker image prune -a -f"
echo

# 3. Tags viejos tinerfe-ords / auth / jobs (deja :latest + el ultimo numerico)
echo "[3] Tags antiguos tinerfe-ords/auth/jobs (mantengo :latest)"
for repo in registry.gitlab.com/mutuatfe/tinerfe/rds \
            registry.gitlab.com/mutuatfe/tinerfe/rds/jobs \
            registry.gitlab.com/mutuatfe/tinerfe/tinerfe-auth \
            registry.gitlab.com/mutuatfe/tinerfe/tinerfe-db \
            registry.gitlab.com/mutuatfe/tinerfe/tinerfe-doc \
            registry.gitlab.com/mutuatfe/tinerfe/orasql; do
  tags=$(docker images "$repo" --format "{{.Tag}}" | grep -vE '^(latest|<none>)$' || true)
  for t in $tags; do
    run "docker rmi $repo:$t || true"
  done
done
echo

# 4. Caches de paquetes
echo "[4] Limpieza caches (sudo solo si no esta en sudoers)"
run "rm -rf /home/clp/.cache/pip/* 2>/dev/null"
run "rm -rf /home/clp/.npm/_cacache 2>/dev/null"
run "pnpm store prune 2>/dev/null || true"
run "bun pm cache rm 2>/dev/null || true"
run "uv cache clean 2>/dev/null || true"
run "sudo apt-get clean 2>/dev/null || true"
echo

# 5. /tmp viejos
echo "[5] /tmp viejos (>7 dias)"
run "find /tmp -mindepth 1 -mtime +7 -delete 2>/dev/null || true"
echo

# 6. Logs Docker (los rotamos a 0)
echo "[6] Logs Docker antiguos (rotacion a 0)"
run "find /var/lib/docker/containers -name '*.log' -mtime +7 -exec truncate -s 0 {} \; 2>/dev/null || true"
echo

# Tamano despues (df, no du)
after=$(df --output=used / | tail -1)
liberated=$(( (before - after) * 1024 ))
echo "============================================"
echo "Disco / usado antes:  $(numfmt --to=iec $((before*1024)))"
echo "Disco / usado ahora:  $(numfmt --to=iec $((after*1024)))"
echo "Liberado en /:        $(numfmt --to=iec $liberated)"
echo "C: libre ahora:       $(powershell.exe -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB,1)" 2>/dev/null | tr -d '\r') GB"
echo
echo "PASO FINAL (manual, desde PowerShell):"
echo "    wsl --shutdown"
echo
echo "Eso compacta el VHD gracias a sparseVhd=true en .wslconfig."
echo "Tras eso, mira C: libre. Deberia bajar el tamano del .vhdx en disco."
