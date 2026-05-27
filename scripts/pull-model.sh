#!/usr/bin/env bash
# Descarga un modelo a Ollama. Uso: ./pull-model.sh qwen2.5-coder:7b
set -euo pipefail

MODEL="${1:-}"
if [[ -z "$MODEL" ]]; then
  echo "Uso: $0 <modelo>"
  echo ""
  echo "Sugerencias:"
  echo "  qwen2.5-coder:7b-instruct-q4_K_M         (dia a dia, 4.7 GB)"
  echo "  qwen2.5-coder:14b-instruct-q4_K_M        (mas razonamiento, 9 GB)"
  echo "  deepseek-coder-v2:16b-lite-instruct-q4_K_M (MoE rapido, 10 GB)"
  echo "  llama3.1:8b-instruct-q4_K_M              (generalista, 4.9 GB)"
  exit 1
fi

# Detecta si hay TTY: lo usa para barra de progreso interactiva,
# pero sin -t si nos lanzan desde un script/background (evita el error
# "the input device is not a TTY").
if [ -t 0 ] && [ -t 1 ]; then
  docker exec -it llmlocal-ollama ollama pull "$MODEL"
else
  docker exec -i llmlocal-ollama ollama pull "$MODEL"
fi
