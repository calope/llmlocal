#!/usr/bin/env bash
# Ejecuta la suite tests/eval/*.txt contra APIs externas:
#   - OpenAI-compatible (Mistral, xAI Grok, Groq, OpenAI, etc) via /v1/chat/completions
#   - Anthropic (Claude) via /v1/messages
#
# Uso:
#   ./quality-eval-api.sh --base-url <url> --api-key-env <ENVVAR> --model <model> [--format openai|anthropic] [--label <slug>]
#
# Ejemplos:
#   ./quality-eval-api.sh --base-url https://api.mistral.ai/v1   --api-key-env MISTRAL_API_KEY   --model codestral-latest
#   ./quality-eval-api.sh --base-url https://api.x.ai/v1         --api-key-env XAI_API_KEY       --model grok-3
#   ./quality-eval-api.sh --base-url https://api.groq.com/openai/v1 --api-key-env GROQ_API_KEY   --model llama-3.3-70b-versatile
#   ./quality-eval-api.sh --base-url https://api.anthropic.com/v1 --api-key-env ANTHROPIC_API_KEY --model claude-opus-4-7 --format anthropic
#
# Carga .env si existe (las keys NUNCA en shell history o git):
#   echo "MISTRAL_API_KEY=..."   >> .env
#   echo "XAI_API_KEY=..."       >> .env
#   echo "ANTHROPIC_API_KEY=..." >> .env
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$DIR/.env" ] && set -a && . "$DIR/.env" && set +a

BASE_URL=""
KEY_ENV=""
MODEL=""
LABEL=""
FORMAT="openai"
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base-url)    BASE_URL="$2"; shift 2 ;;
    --api-key-env) KEY_ENV="$2";  shift 2 ;;
    --model)       MODEL="$2";    shift 2 ;;
    --label)       LABEL="$2";    shift 2 ;;
    --format)      FORMAT="$2";   shift 2 ;;
    --only)        ONLY="$2";     shift 2 ;;
    *) echo "flag desconocida: $1"; exit 1 ;;
  esac
done

[ -n "$BASE_URL" ] || { echo "Falta --base-url"; exit 1; }
[ -n "$KEY_ENV" ]  || { echo "Falta --api-key-env"; exit 1; }
[ -n "$MODEL" ]    || { echo "Falta --model"; exit 1; }

API_KEY="${!KEY_ENV:-}"
[ -n "$API_KEY" ] || { echo "Variable $KEY_ENV vacia. Defínela en .env o exportala"; exit 1; }

[ -n "$LABEL" ] || LABEL="$(echo "$BASE_URL" | sed -E 's#https?://##; s#/.*##')_${MODEL}"
RES_DIR="$DIR/tests/results/$(echo "$LABEL" | tr ':/' '_')"
mkdir -p "$RES_DIR"

CSV="$DIR/tests/results/_metrics.csv"
[ -f "$CSV" ] || echo "test,model,prompt_tokens,gen_tokens,prompt_eval_s,gen_eval_s,gen_tok_s,total_s" > "$CSV"

echo
echo "=== Evaluacion API ==="
echo "  format:   $FORMAT"
echo "  endpoint: $BASE_URL"
echo "  model:    $MODEL"
echo "  label:    $LABEL"
echo

for f in "$DIR/tests/eval"/*.txt; do
  base=$(basename "$f" .txt)
  [ -n "$ONLY" ] && [ "$base" != "$ONLY" ] && continue
  echo "--- $base ---"
  req=$(mktemp); trap 'rm -f "$req"' RETURN
  resp_file="$RES_DIR/${base}.json"

  if [ "$FORMAT" = "anthropic" ]; then
    # Anthropic Messages API
    jq -n --arg m "$MODEL" \
          --rawfile p "$f" \
          '{
            model: $m,
            max_tokens: 2048,
            messages: [{role:"user", content:$p}]
          }' > "$req"
    start=$(date +%s.%N)
    http=$(curl -sS -o "$resp_file" -w "%{http_code}" \
      -H "x-api-key: $API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      "$BASE_URL/messages" -d @"$req")
    end=$(date +%s.%N)
  else
    # OpenAI-compatible
    jq -n --arg m "$MODEL" \
          --rawfile p "$f" \
          '{
            model: $m,
            messages: [{role:"user", content:$p}],
            temperature: 0.1,
            max_tokens: 2048
          }' > "$req"
    start=$(date +%s.%N)
    http=$(curl -sS -o "$resp_file" -w "%{http_code}" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      "$BASE_URL/chat/completions" -d @"$req")
    end=$(date +%s.%N)
  fi

  wall=$(echo "$end-$start" | bc -l)

  if [ "$http" != "200" ]; then
    echo "  HTTP $http — respuesta:"
    cat "$resp_file" | head -5
    echo
    continue
  fi

  # Parsing por formato
  if [ "$FORMAT" = "anthropic" ]; then
    prompt_t=$(jq -r '.usage.input_tokens // 0' "$resp_file")
    gen_t=$(jq -r '.usage.output_tokens // 0' "$resp_file")
    text=$(jq -r '.content[0].text' "$resp_file")
    stop=$(jq -r '.stop_reason // "?"' "$resp_file")
  else
    prompt_t=$(jq -r '.usage.prompt_tokens // 0' "$resp_file")
    gen_t=$(jq -r '.usage.completion_tokens // 0' "$resp_file")
    text=$(jq -r '.choices[0].message.content' "$resp_file")
    stop=$(jq -r '.choices[0].finish_reason // "?"' "$resp_file")
  fi

  echo "  prompt_tokens=$prompt_t  gen_tokens=$gen_t  stop=$stop"
  printf "  wall-clock=%.2fs   tok/s=%.2f\n" "$wall" "$(echo "scale=2; $gen_t / $wall" | bc -l)"

  printf '%s' "$text" > "$RES_DIR/${base}.response.md"

  tok_s=$(echo "scale=2; $gen_t / $wall" | bc -l)
  echo "$base,$LABEL,$prompt_t,$gen_t,0,0,$tok_s,$wall" >> "$CSV"
  echo
done

echo "Respuestas guardadas:"
ls -1 "$RES_DIR"/*.response.md | sed 's|^|  |'
echo
echo "Metricas: $CSV"
