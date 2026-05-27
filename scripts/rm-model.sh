#!/usr/bin/env bash
# Borra un modelo de Ollama. Uso: ./rm-model.sh qwen2.5-coder:7b
set -euo pipefail
MODEL="${1:?Uso: $0 <modelo>}"
if [ -t 0 ] && [ -t 1 ]; then
  docker exec -it llmlocal-ollama ollama rm "$MODEL"
else
  docker exec -i llmlocal-ollama ollama rm "$MODEL"
fi
echo "Recuerda: el VHD de WSL no encoge solo. Con sparseVhd=true en .wslconfig"
echo "se compacta al apagar WSL (wsl --shutdown desde PowerShell)."
