#!/usr/bin/env bash
# Mini benchmark: mide tokens/s con un prompt corto y otro largo.
# Uso: ./bench.sh qwen2.5-coder:7b
set -euo pipefail

MODEL="${1:?Uso: $0 <modelo>}"

bench() {
  local label="$1"
  local prompt="$2"
  echo
  echo "=== $label ==="
  curl -s http://localhost:11434/api/generate \
    -d "$(jq -nc --arg m "$MODEL" --arg p "$prompt" \
        '{model:$m, prompt:$p, stream:false, options:{num_predict:128}}')" \
    | jq -r '
        "  prompt eval:  \((.prompt_eval_count // 0)) tokens en \((.prompt_eval_duration // 0)/1e9 | . * 100 | floor / 100)s",
        "  eval:         \((.eval_count // 0)) tokens en \((.eval_duration // 0)/1e9 | . * 100 | floor / 100)s",
        "  tok/s eval:   \(if (.eval_duration // 0) > 0 then (.eval_count / (.eval_duration/1e9) | . * 10 | floor / 10) else 0 end)"
      '
}

echo "Modelo: $MODEL"
bench "prompt corto" "Explica en una frase que es la recursividad."
bench "prompt programacion" "Escribe una funcion Python que reciba un grafo (dict de adyacencia) y devuelva True si es ciclico. Solo el codigo, sin explicacion."
