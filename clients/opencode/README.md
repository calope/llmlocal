# OpenCode (sst/opencode)

CLI agentico open source. UX muy similar a Claude Code, sin depender del binario oficial.

## Instalar

```bash
curl -fsSL https://opencode.ai/install | bash
# o: npm install -g opencode-ai
```

## Configurar

```bash
mkdir -p ~/.config/opencode
ln -sf ~/Workspace/llmlocal/clients/opencode/opencode.json \
       ~/.config/opencode/opencode.json
```

## Usar

```bash
cd ~/Workspace/cualquier-proyecto
opencode
```

Cambiar de modelo en runtime: `/model` dentro de la TUI.

## Notas

- Soporta cualquier provider OpenAI-compatible via `@ai-sdk/openai-compatible`.
- Si necesitas autenticacion con headers especiales, anade `headers` en `options`.
- Docs: https://opencode.ai/docs/
