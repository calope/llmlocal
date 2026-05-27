#!/usr/bin/env bash
# Launcher unificado: asegura Ollama arriba, valida MCPs, lanza opencode.
# Uso:
#   ./code.sh              # opencode en el cwd
#   ./code.sh <dir>        # opencode en otro directorio
#   ./code.sh --check      # solo health check, no lanza nada
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_ONLY=false
TARGET="${1:-$PWD}"
[ "${1:-}" = "--check" ] && CHECK_ONLY=true && TARGET=$PWD

ok() { printf "\033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "\033[33m⚠\033[0m %s\n" "$1"; }
ko() { printf "\033[31m✗\033[0m %s\n" "$1"; }

echo
echo "=== llmlocal launcher ==="
echo

# 1. Ollama
if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
  ok "Ollama responde en :11434"
else
  warn "Ollama caido — arrancando..."
  (cd "$DIR" && make up >/dev/null) || { ko "no se pudo arrancar Ollama"; exit 1; }
  ok "Ollama arrancado"
fi

# 2. Modelos
echo
echo "Modelos disponibles:"
curl -s http://localhost:11434/api/tags | jq -r '.models[] | "  • \(.name)  \((.size/1e9*10|floor)/10)GB"'

# 3. Configs cliente
echo
echo "Configs:"
for f in ~/.config/opencode/opencode.json ~/.claude-code-router/config.json; do
  if [ -L "$f" ] && [ -f "$f" ]; then ok "$(basename "$(dirname "$f")")/$(basename "$f") -> $(readlink "$f")"
  elif [ -f "$f" ]; then warn "$(basename "$(dirname "$f")")/$(basename "$f") existe pero NO es symlink"
  else ko "$(basename "$(dirname "$f")")/$(basename "$f") no existe"
  fi
done

# 4. MCPs declarados
echo
echo "MCPs en opencode.json:"
jq -r '.mcp | to_entries[] | select(.value | type == "object") | "  \(if .value.enabled then "✓" else "·" end) \(.key)\(if .value.enabled then "" else " (deshabilitado)" end)"' \
  "$DIR/clients/opencode/opencode.json"

# 5. Secrets disponibles
echo
echo "Secrets en .env:"
if [ -f "$DIR/.env" ]; then
  grep -E '^[A-Z_]+=' "$DIR/.env" | awk -F= '{
    if ($2 == "") print "  · " $1 " (vacio)"
    else print "  ✓ " $1
  }'
else
  warn "no existe .env"
fi

if $CHECK_ONLY; then
  echo
  ok "Health check completo"
  exit 0
fi

# 6. Lanzar opencode
echo
echo "Lanzando opencode en: $TARGET"
echo "  (modelo default: deepseek-coder-v2 16b lite local)"
echo "  /model <nombre>     cambia de modelo en runtime"
echo "  /help               comandos disponibles"
echo "  Ctrl+C dos veces    salir"
echo

# Cargar .env para que las {env:VAR} de opencode.json se expandan
# (GITHUB_TOKEN, GITLAB_TOKEN, ORACLE_*, MISTRAL_API_KEY, etc.)
if [ -f "$DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$DIR/.env"
    set +a
fi

# Reset agresivo del TTY antes de exec opencode.
# Evita que residuos del scrollback (mouse SGR events, sudo prompts viejos,
# etc.) se pinten dentro de la TUI cuando Bubble Tea no consigue setRawMode.
# - printf '\033c'  : reset terminal hard (ESC c)
# - tput reset      : reset via terminfo
# - clear           : limpia pantalla y scrollback
# - stty sane       : restaura settings TTY a defaults
stty sane 2>/dev/null || true
printf '\033c' 2>/dev/null || true
tput reset 2>/dev/null || true
clear 2>/dev/null || true

cd "$TARGET" && exec opencode
