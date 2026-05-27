#!/usr/bin/env bash
# Bench mas serio: warm-up + prompt largo + N repeticiones + promedio/min/max.
# Uso: ./bench-extended.sh <modelo> [reps]
set -euo pipefail

MODEL="${1:?Uso: $0 <modelo> [reps=3]}"
REPS="${2:-3}"
HOST="${OLLAMA_HOST:-http://localhost:11434}"

PROMPT_LONG='Eres un asistente de programacion senior. Vas a escribir una funcion Python idiomatica que dado un grafo dirigido (dict[str, list[str]]) devuelva el orden topologico usando el algoritmo de Kahn. La funcion debe lanzar ValueError si el grafo es ciclico, manejar nodos huerfanos, ser type-hinted y llevar docstring estilo NumPy. Incluye luego 3 ejemplos de uso comentados que cubran: grafo lineal, grafo en arbol, y grafo ciclico. NO uses librerias externas, solo collections. Empieza directamente con el codigo.'

call() {
  local n="$1"
  curl -fsS "$HOST/api/generate" \
    -d "$(jq -nc --arg m "$MODEL" --arg p "$PROMPT_LONG" --argjson n "$n" \
        '{model:$m, prompt:$p, stream:false, options:{num_predict:$n, temperature:0.2}}')"
}

stat_line() {
  # entrada: lista de tok/s separados por nueva linea
  awk '
    { sum+=$1; n++; if (NR==1 || $1<min) min=$1; if ($1>max) max=$1 }
    END { if (n>0) printf "media=%.2f tok/s  min=%.2f  max=%.2f  (n=%d)\n", sum/n, min, max, n }
  '
}

echo "Modelo: $MODEL"
echo "Host:   $HOST"
echo

echo "=== Warm-up (descartado) ==="
call 32 | jq -r '"  warmup tokens=\(.eval_count)"'
echo

echo "=== $REPS iteraciones (num_predict=256) ==="
tps_list=$(mktemp)
ttft_list=$(mktemp)
trap 'rm -f $tps_list $ttft_list' EXIT

for i in $(seq 1 "$REPS"); do
  resp=$(call 256)
  tps=$(jq -r '.eval_count / (.eval_duration / 1e9)' <<<"$resp")
  ttft=$(jq -r '.prompt_eval_duration / 1e9' <<<"$resp")
  ec=$(jq -r '.eval_count' <<<"$resp")
  ed=$(jq -r '(.eval_duration/1e9) | . * 100 | floor / 100' <<<"$resp")
  printf "  iter %d  tok/s=%6.2f  tokens=%3s  eval=%5ss  ttft(prompt_eval)=%5ss\n" \
    "$i" "$tps" "$ec" "$ed" "$ttft"
  echo "$tps" >> "$tps_list"
  echo "$ttft" >> "$ttft_list"
done

echo
echo "=== Resumen eval (generacion) ==="
echo -n "  "; cat "$tps_list" | stat_line
echo "=== Resumen TTFT (prompt eval) ==="
echo -n "  "; cat "$ttft_list" | stat_line
