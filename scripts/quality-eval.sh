#!/usr/bin/env bash
# Ejecuta los tests de tests/eval/*.txt contra un modelo y guarda respuestas
# en tests/results/<modelo-slug>/. Tambien produce un CSV con metricas.
# Uso: ./quality-eval.sh <modelo>
set -euo pipefail

MODEL="${1:?Uso: $0 <modelo>}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$DIR/tests/eval"
RES_DIR="$DIR/tests/results/$(echo "$MODEL" | tr ':/' '_')"
mkdir -p "$RES_DIR"

CSV="$DIR/tests/results/_metrics.csv"
[ -f "$CSV" ] || echo "test,model,prompt_tokens,gen_tokens,prompt_eval_s,gen_eval_s,gen_tok_s,total_s" > "$CSV"

echo
echo "=== Evaluacion de calidad: $MODEL ==="
echo "Resultados en: $RES_DIR"
echo

for f in "$TESTS_DIR"/*.txt; do
  base=$(basename "$f" .txt)
  echo "--- $base ---"
  req=$(mktemp); trap 'rm -f "$req"' RETURN

  jq -n --arg m "$MODEL" \
        --rawfile p "$f" \
        '{model:$m, prompt:$p, stream:false, options:{num_predict:2048, temperature:0.1}}' > "$req"

  start=$(date +%s.%N)
  resp_file="$RES_DIR/${base}.json"
  curl -fsS -o "$resp_file" http://localhost:11434/api/generate -d @"$req"
  end=$(date +%s.%N)
  wall=$(echo "$end-$start" | bc -l)

  jq -r '
    "  prompt_tokens=\(.prompt_eval_count)  gen_tokens=\(.eval_count)",
    "  prompt_eval=\((.prompt_eval_duration/1e9*100|floor)/100)s  gen_eval=\((.eval_duration/1e9*100|floor)/100)s  gen_tok/s=\((.eval_count/(.eval_duration/1e9))|.*10|floor/10)",
    "  total ollama=\((.total_duration/1e9*100|floor)/100)s"
    ' "$resp_file"
  printf "  wall-clock=%.2fs\n" "$wall"

  # Guardar texto de la respuesta aparte para revisar comodamente
  jq -r '.response' "$resp_file" > "$RES_DIR/${base}.response.md"

  # CSV
  jq -r --arg t "$base" --arg m "$MODEL" --arg w "$wall" '
    [
      $t, $m,
      (.prompt_eval_count // 0),
      (.eval_count // 0),
      ((.prompt_eval_duration/1e9*100|floor)/100),
      ((.eval_duration/1e9*100|floor)/100),
      ((.eval_count/(.eval_duration/1e9))|.*10|floor/10),
      $w
    ] | @csv' "$resp_file" >> "$CSV"
  echo
done

echo "Respuestas guardadas:"
ls -1 "$RES_DIR"/*.response.md | sed 's|^|  |'
echo
echo "Metricas CSV: $CSV"
