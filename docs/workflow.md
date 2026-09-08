# Workflow: cuándo usar cuál

Stack final tras la decisión 2026-05-26: **dos clientes complementarios**, sin Continue.dev.

```
                         ┌─────────────────────────────┐
                         │       VS Code (terminal)    │
                         │                              │
                ┌────────┤   Claude Code (extension)   │
                │        │   →  Sonnet 4.6 / Opus 4.7  │
                │        │      via tu cuota Max        │
                │        │      (cuando lo pides)       │
                │        └─────────────────────────────┘
                │
                │        ┌─────────────────────────────┐
                ▼        │       Terminal / WSL         │
        ┌───────────┐    │                              │
        │  Tu       │◀───┤   opencode (CLI)            │
        │  workspace│    │   →  Ollama local           │
        │           │    │      DeepSeek 16B MoE        │
        └───────────┘    │      Qwen 7B (fallback)     │
                ▲        │   +  MCPs: K8s, mermaid,    │
                │        │      filesystem              │
                │        └─────────────────────────────┘
                │
                │        ┌─────────────────────────────┐
                └────────┤    Ollama (Docker)           │
                         │    :11434                    │
                         └─────────────────────────────┘
```

## Decisión rápida: ¿qué cliente uso?

| Tarea | Cliente |
|------|---------|
| Refactor multi-file, autocomplete contextual, edit obvio | **opencode** (local) |
| Crear archivo nuevo desde plantilla | **opencode** |
| Generar tests para una función | **opencode** |
| Resumir un doc, traducir, listar/buscar en codebase | **opencode** + filesystem MCP |
| `kubectl get pods`, ver logs, restart deployment | **opencode** + K8s MCP |
| Generar diagrama Mermaid/PlantUML | **opencode** + mermaid MCP |
| Refactor con cambios sutiles (async, locking, race conditions) | **Claude Code** |
| Optimización SQL Oracle CBO complejo | **Claude Code** |
| Arquitectura, decisiones de diseño | **Claude Code** |
| Revisión de seguridad / threat model | **Claude Code** |
| Cambio entre 5+ archivos donde la consistencia importa | **Claude Code** |

Regla simple: **opencode primero**. Si te da código roto o no entiende el problema, pasa la tarea a Claude Code.

## Comandos clave

```bash
cd ~/Workspace/llmlocal
make code         # arranca Ollama si hace falta + lanza opencode en el cwd actual
make check        # solo verificar estado, sin lanzar nada
```

Dentro de opencode:

- `/model` — cambiar de modelo en runtime (DeepSeek ↔ Qwen)
- `/mcp` — ver MCPs activos
- `/help` — todos los comandos
- `@file.py` — añade archivo al contexto
- `Ctrl+C` dos veces — salir

Claude Code se invoca con el panel lateral de VS Code o con `claude` desde terminal si está instalado.

## MCP servers configurados (11 activos)

### Core (sin auth externa)

| MCP | Estado | Para qué |
|-----|--------|----------|
| `filesystem` | ✓ | Lectura/escritura en ~/Workspace (sandbox) |
| `git` | ✓ | Operaciones git (log, diff, blame, branches, commit) vía API en lugar de bash |
| `fetch` | ✓ | Bajar URL como markdown/JSON. Útil para leer docs externas |
| `time` | ✓ | Fecha/hora actual (zona Atlantic/Canary), timestamps en docs |
| `sequential-thinking` | ✓ | Chain-of-thought estructurado para tareas complejas |
| `memory` | ✓ | Memoria persistente entre sesiones del agente |

### Diagramas y K8s

| MCP | Estado | Para qué |
|-----|--------|----------|
| `kubernetes` | ✓ | `kubectl` operations vía MCP. KUBECONFIG=~/.kube/config |
| `mermaid` | ✓ | Generar diagramas Mermaid desde lenguaje natural |
| `plantuml` | ✓ | Diagramas PlantUML/C4 para documentacion tecnica |

### Repositorios remotos

| MCP | Estado | Para qué |
|-----|--------|----------|
| `github` | ✓ | Issues, PRs, code search en github.com/calope. Token via gh CLI |
| `gitlab` | ✓ | Issues, MRs, pipelines en gitlab.com (org mutuatfe). Token UV_INDEX_* |
| `oracle` | ⏸ | Consulta esquemas/queries Oracle. Requiere Instant Client + DSN/user/pass |

### Tokens extraídos automáticamente

- **GITHUB_TOKEN** → de `gh auth token` (CLI ya autenticado como calope)
- **GITLAB_TOKEN** → de env var `UV_INDEX_GITLAB_TINERFE_PASSWORD` (PAT del registry uv)
- **GITLAB_API_URL** → `https://gitlab.com/api/v4` (confirmado funcional, `git.mutuatfe.es` no accesible)

Para activar uno: edita `clients/opencode/opencode.json`, pon `enabled: true`, define los secrets en `.env` y reinicia opencode.

## Casos de uso reales con MCPs

### Diagnóstico K8s con opencode

```text
> Lista pods con CrashLoopBackOff en namespace tinerfe-ords. Para cada uno, dame logs últimas 50 líneas y un diagnóstico.
```

opencode + K8s MCP → ejecuta `kubectl get pods -n tinerfe-ords --field-selector=status.phase=...`, luego `kubectl logs ...`, sintetiza diagnóstico.

### Generar diagrama de arquitectura

```text
> Genera un diagrama Mermaid que muestre el flujo: usuario → React-Admin → ORDS → Oracle, con auth JWT pasando por tinerfe-auth.
```

opencode + Mermaid MCP → devuelve diagrama renderizado.

### Refactor con búsqueda en codebase

```text
> Busca todos los handlers ORDS que llaman a STO.ORDS_EXPEDIENTES y muéstrame cuáles no validan el parámetro p_id_cliente.
```

opencode + filesystem MCP → grep semántico, lectura, análisis.

## Tareas que pasan a Claude Code

Si opencode te da código roto o no entiende:

1. Copia el prompt original
2. Pégalo en Claude Code (panel lateral VS Code)
3. Sonnet 4.6 lo resuelve en la mayoría de casos
4. Si Sonnet también falla, cambia a Opus 4.7 con `/model opus`

Esto sale de tu cuota Max (no de API key). El gap calidad medido (test 01 refactor Python):

| Modelo | Puntos /25 |
|--------|---:|
| DeepSeek 16B local (default opencode) | 13 |
| Mistral Large (no usado por defecto) | 21 |
| Claude Sonnet 4.6 (Claude Code default) | 24 |
| Claude Opus 4.7 (Claude Code premium) | 24 |

Ver detalle en [quality-eval.md](quality-eval.md) y memoria
`project_quality_eval_modelos_2026_05`.
