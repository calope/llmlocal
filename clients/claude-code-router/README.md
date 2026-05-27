# claude-code-router

Permite usar el binario `claude` oficial pero enrutando las llamadas a Ollama local.

## Instalar

```bash
npm install -g @musistudio/claude-code-router
mkdir -p ~/.claude-code-router
ln -sf ~/Workspace/llmlocal/clients/claude-code-router/config.json \
       ~/.claude-code-router/config.json
```

## Usar

```bash
ccr code      # arranca claude code via el router
# dentro: /model ollama-local,qwen2.5-coder:14b-instruct-q4_K_M
```

## Cambiar el modelo por defecto

Edita `config.json` y cambia el valor de `Router.default`. Reinicia `ccr`.

## Notas

- `api_key` puede ser cualquier string; Ollama lo ignora.
- Si Claude Code da error de tool-use, prueba con un modelo que soporte
  function-calling bien: `qwen2.5-coder` o `llama3.1` con la variante instruct.
- Repo: https://github.com/musistudio/claude-code-router
