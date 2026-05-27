# Continue.dev (VS Code)

Asistente AI integrado en el editor. Soporta Ollama nativamente.

## Instalar

1. Extension en VS Code: `Continue.continue`
2. Symlink del config:
   ```bash
   mkdir -p ~/.continue
   ln -sf ~/Workspace/llmlocal/clients/continue/config.json ~/.continue/config.json
   ```
3. Modelos auxiliares en Ollama:
   ```bash
   ~/Workspace/llmlocal/scripts/pull-model.sh qwen2.5-coder:7b-base-q4_K_M  # autocomplete
   ~/Workspace/llmlocal/scripts/pull-model.sh nomic-embed-text              # embeddings
   ```

## Usar

- `Ctrl+L`: chat con el modelo
- `Ctrl+I`: edit en linea sobre seleccion
- `Tab` en codigo: autocomplete (modelo `base`, no `instruct`)

## Notas

- El modelo de autocomplete debe ser **base** (Fill-In-the-Middle), no instruct.
- Si no usas embeddings, comenta el bloque `embeddingsProvider`.
- Docs: https://docs.continue.dev/
