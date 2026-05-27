#!/usr/bin/env bash
# Test reproducible contra un doc real de luz: extraer datos de un informe en JSON.
# Mide tok/s con contexto real (~1K tokens) y muestra la respuesta.
# Uso: ./test-luz.sh [modelo]
set -euo pipefail

MODEL="${1:-qwen2.5-coder:7b-instruct-q4_K_M}"
FILE="${TEST_FILE:-/home/clp/Workspace/luz/docs/informes/comparativa-bun-pnpm.md}"

[ -f "$FILE" ] || { echo "Falta el doc: $FILE"; exit 1; }

PROMPT_PREFIX='Eres un asistente tecnico. Lee este documento y devuelve UNICAMENTE un JSON con esta estructura: {"decision":"...", "razon_principal":"...", "ganancia_bun_install_cached":"...x", "ganancia_bun_build":"...%", "recomendacion_revisar_cuando":"..."}. Nada mas, solo el JSON. Documento:

'

REQ=$(mktemp); RESP=$(mktemp); trap 'rm -f $REQ $RESP' EXIT

jq -n --arg m "$MODEL" \
      --arg pre "$PROMPT_PREFIX" \
      --rawfile doc "$FILE" \
      '{model:$m, prompt:($pre+$doc), stream:false, options:{num_predict:512, temperature:0}}' > "$REQ"

echo "Modelo:  $MODEL"
echo "Archivo: $FILE ($(wc -l < "$FILE") lineas, $(wc -c < "$FILE") bytes)"
echo

start=$(date +%s.%N)
curl -fsS -o "$RESP" http://localhost:11434/api/generate -d @"$REQ"
end=$(date +%s.%N)

echo "=== Metricas Ollama ==="
jq -r '
  "  prompt tokens:     \(.prompt_eval_count)",
  "  prompt eval:       \((.prompt_eval_duration/1e9*100|floor)/100)s   (\((.prompt_eval_count / (.prompt_eval_duration/1e9))|.*10|floor/10) tok/s)",
  "  generation tokens: \(.eval_count)",
  "  generation eval:   \((.eval_duration/1e9*100|floor)/100)s   (\((.eval_count / (.eval_duration/1e9))|.*10|floor/10) tok/s)",
  "  total ollama:      \((.total_duration/1e9*100|floor)/100)s",
  "  context size:      \(.context | length // "n/a") tokens en KV cache"
  ' "$RESP"

printf "  wall-clock curl:   %.2fs\n" "$(echo "$end-$start" | bc -l)"
echo
echo "=== Respuesta ==="
jq -r '.response' "$RESP"
