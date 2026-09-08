# llmlocal — Claude Code local con LLMs open source

Stack para ejecutar un "Claude Code-like" enteramente en local sobre el HW del portátil
(Intel Core 7 240H, 22 GB RAM WSL, iGPU Intel Arc Xe-LPG). Sin red, sin nube,
modelos intercambiables. Tres clientes apuntan al mismo backend Ollama:

```
                         ┌─────────────────────┐
                         │  modelos GGUF       │   ./models/ollama
                         └──────────┬──────────┘
                                    │
                ┌───────────────────▼───────────────────┐
                │  Ollama (Docker)  ::11434             │  Fase 1: CPU
                │  Backend OpenAI-compatible            │  Fase 4: IPEX-LLM iGPU
                └────────┬──────────┬──────────┬────────┘
                         │          │          │
                 ┌───────▼───┐  ┌───▼───┐  ┌───▼─────────┐
                 │ claude-   │  │ open- │  │ continue.dev│
                 │ code-     │  │ code  │  │ (VS Code)   │
                 │ router    │  │ (CLI) │  │             │
                 └───────────┘  └───────┘  └─────────────┘
```

Cambias modelo en Ollama una sola vez y los tres clientes lo ven.

## Estado actual (2026-05-11)

| Componente | Versión | Estado |
|---|---|---|
| Ollama (Docker) | 0.23.2 | ✓ tuneado (NUM_THREAD=12, FA, KV q8_0) |
| Modelo descargado | `qwen2.5-coder:7b-instruct-q4_K_M` | 4.7 GB, ~12 tok/s |
| claude-code-router | `ccr` | ✓ instalado + config symlinkeada |
| opencode | `opencode` | ✓ instalado + config symlinkeada |
| continue.dev | (extensión VS Code) | ⚠️ config symlinkeada, instalar extensión |

Bench actual: **~12 tok/s** generación, TTFT ~80 ms. Detalle en [docs/tuning.md](docs/tuning.md).

---

## 1. Operación del backend

```bash
cd ~/Workspace/llmlocal

# Backend
make up                            # arranca Ollama CPU
make down                          # para Ollama
make ps / make logs                # estado / logs en vivo

# Modelos
make list
make pull MODEL=qwen2.5-coder:7b-instruct-q4_K_M
make rm   MODEL=qwen2.5-coder:7b-instruct-q4_K_M

# Bench y diagnostico
make health                        # container + endpoint + tuning activo + modelos
make stats                         # CPU/RAM container + modelos en RAM + disco
make bench MODEL=...               # bench corto (2 prompts)
make bench-ext MODEL=... REPS=3    # bench serio (warm-up + N iters + min/max)
make demo                          # demo reproducible con un documento de ejemplo
```

Healthcheck del compose espera a que Ollama responda antes de devolver el control.
`make health` te dice de un vistazo si todo está bien.

---

## 2. Cómo probar — paso a paso por cliente

> **Pre-requisito**: `make up` y `make list` muestra al menos un modelo.

### 2.1 claude-code-router (`ccr`) — reusa el binario `claude` oficial

Este es el camino más cercano a "Claude Code, pero local": el router intercepta las
peticiones de Claude Code (formato Anthropic Messages API) y las traduce a Ollama.

**Verificar instalación y arranque:**

```bash
ccr --version
ccr status                # debería decir "Not Running" la primera vez
ccr start                 # arranca el server en puerto 3456
ccr status                # debería decir "Running"
```

**Test rápido sin Claude Code (curl directo):**

```bash
curl -s -X POST http://127.0.0.1:3456/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: test" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-3-haiku-20240307",
    "max_tokens": 64,
    "messages": [{"role":"user","content":"Hola, di OK y tu modelo real."}]
  }' | jq .
```

Devuelve formato Anthropic, pero el `model` en la respuesta será el modelo Ollama real.

**Uso real (sesión interactiva tipo Claude Code):**

```bash
cd ~/Workspace/algun-proyecto
ccr code                  # arranca claude code apuntado al router → Ollama
```

Dentro de la sesión:

- `/model ollama-local,qwen2.5-coder:7b-instruct-q4_K_M` cambia de modelo
- comandos slash habituales de Claude Code
- los archivos del proyecto se leen y mandan al modelo local

**Parar:**

```bash
ccr stop
```

### 2.2 opencode — CLI agéntico nativo

UX muy similar a Claude Code, sin depender del binario oficial. Mantenido por sst.

**Verificar instalación:**

```bash
opencode --version
opencode models           # lista todos los modelos visibles
                          # debes ver "ollama-local/qwen2.5-coder:7b-instruct-q4_K_M"
```

**Test rápido no-interactivo:**

```bash
opencode run --model 'ollama-local/qwen2.5-coder:7b-instruct-q4_K_M' \
  "Escribe una funcion Python que devuelva los primeros N numeros primos."
```

(la primera ejecución carga el modelo, puede tardar ~10-15 s extra. Las siguientes
arrancan instantáneas si entran dentro de `OLLAMA_KEEP_ALIVE=30m`.)

**Uso real (TUI):**

```bash
cd ~/Workspace/algun-proyecto
opencode                  # TUI similar a Claude Code
```

Dentro:

- `/model` para cambiar de modelo en runtime
- `@file.py` para añadir un archivo al contexto
- `/help` para todos los comandos

### 2.3 Continue.dev — integración VS Code

Asistente AI integrado en el editor (chat, edición inline, autocomplete).

**Instalar (una vez):**

1. En VS Code: extensiones → buscar **Continue** → publicador `Continue` → instalar
2. La config ya está symlinkeada en `~/.continue/config.json` apuntando a este proyecto
3. Recargar la ventana de VS Code

**Verificar:**

- Icono Continue en la barra lateral izquierda
- En el chat de Continue debería aparecer `Qwen2.5-Coder 7B (local)` como modelo

**Uso:**

- `Ctrl+L` abre el chat con el modelo
- `Ctrl+I` edita el código seleccionado in-line
- (tab autocomplete está **desactivado** en la config actual; se activa cuando hagas
  pull del modelo `qwen2.5-coder:7b-base-q4_K_M`, ver sección 4)

---

## 3. Cambiar de modelo

### 3.1 Modelos recomendados según uso

| Caso de uso | Modelo | Tamaño | Velocidad esperada |
|---|---|---|---|
| Día a día coding | `qwen2.5-coder:7b-instruct-q4_K_M` | 4.7 GB | ~12 tok/s ✓ ya descargado |
| Más razonamiento | `qwen2.5-coder:14b-instruct-q4_K_M` | 9 GB | ~5-7 tok/s |
| MoE rápido | `deepseek-coder-v2:16b-lite-instruct-q4_K_M` | 10 GB | ~18-25 tok/s |
| Generalista chat | `llama3.1:8b-instruct-q4_K_M` | 4.9 GB | ~10-13 tok/s |
| Autocomplete FIM (Continue) | `qwen2.5-coder:7b-base-q4_K_M` | 4.5 GB | usado por tab |
| Embeddings (Continue) | `nomic-embed-text` | 137 MB | indexar codebase |

### 3.2 Añadir un modelo

```bash
make pull MODEL=deepseek-coder-v2:16b-lite-instruct-q4_K_M
make bench MODEL=deepseek-coder-v2:16b-lite-instruct-q4_K_M
```

### 3.3 Hacer que los clientes lo vean

Añadir el nombre del modelo en los configs (ya están symlinkeados):

- `clients/claude-code-router/config.json` → array `Providers[0].models`
- `clients/opencode/opencode.json` → objeto `provider.ollama-local.models`
- `clients/continue/config.json` → array `models` (un objeto por modelo)

Tras editar, **recarga el cliente**:

- `ccr restart` para claude-code-router
- relanzar `opencode`
- recargar VS Code para Continue

### 3.4 Borrar un modelo

```bash
make rm MODEL=qwen2.5-coder:14b-instruct-q4_K_M
# El VHD de WSL no encoge solo. Tras borrar grandes:
#   wsl --shutdown      (desde PowerShell)
# Con sparseVhd=true en .wslconfig el disco se compacta al cerrar.
```

---

## 4. Tuning (qué está optimizado)

Resumen en [docs/tuning.md](docs/tuning.md). Lo importante:

- `OLLAMA_NUM_THREAD=12` (sweet-spot medido en este HW; 14 cae 25%, 7 cae 5%)
- `OLLAMA_FLASH_ATTENTION=1` y `OLLAMA_KV_CACHE_TYPE=q8_0`: KV cache 50% más pequeño,
  importante en contextos largos (`@file.py`, `@codebase`)
- `OLLAMA_CONTEXT_LENGTH=8192`: 4× el default Ollama (2048), absorbe varios archivos
  en una conversación
- `OLLAMA_NUM_PARALLEL=1`: una sesión a la vez evita fragmentar el KV cache
- `OLLAMA_KEEP_ALIVE=30m`: el modelo no se descarga hasta 30 min de inactividad

---

## 5. Estructura

```
llmlocal/
├── Makefile · README.md · .gitignore
├── compose/
│   ├── docker-compose.yml          Ollama CPU (Fase 1)  ← activo
│   └── docker-compose.ipex.yml     Ollama IPEX-LLM iGPU (Fase 4)
├── scripts/
│   ├── start.sh / stop.sh
│   ├── pull-model.sh / list-models.sh / rm-model.sh
│   ├── bench.sh                    bench corto (2 prompts)
│   └── bench-extended.sh           bench serio (warm-up + N iters + estadística)
├── clients/
│   ├── claude-code-router/         config.json + README
│   ├── opencode/                   opencode.json + README
│   └── continue/                   config.json + README
├── llamacpp-sycl/                  (vacío, reservado)
├── models/ollama/                  datos persistentes Ollama (gitignored)
└── docs/
    ├── intel-igpu-status.md        inventario GPU + plan habilitación iGPU
    └── tuning.md                   barrido + decisiones de tuning
```

---

## 6. Notas operativas

- **`.wslconfig`** ajustado a `memory=22GB / swap=16GB / sparseVhd=true` para soportar
  modelos hasta 16B Q4. Ya aplicado.
- **CA Fortinet corporativo** montado en el container (`/etc/ssl/certs/ca-certificates.crt`)
  para que `ollama pull` funcione tras MITM.
- **Disco**: modelos en `./models/ollama/` (WSL `/dev/sdd`, 727 GB libres). C: solo tiene
  15 GB libres → no usar Docker Desktop Windows ni rutas Windows.
- **Convivencia con otros containers**: Ollama limita su RAM a 16 GB (`deploy.resources.limits.memory`).
  Si arrancas Oracle XE + ORDS + builds tinerfe-plus a la vez, puedes ver swap activo; en
  ese caso baja el modelo a 3B o para Oracle XE temporalmente.

---

## 7. Fase 4 — iGPU Intel Arc (opcional, no aplicada)

Cuando quieras probar aceleración por iGPU:

```bash
make up-ipex          # arranca Ollama parcheado por Intel IPEX-LLM
                       # primera vez: descarga imagen ~6-8 GB
./scripts/bench-extended.sh qwen2.5-coder:7b-instruct-q4_K_M 3
                       # comparar con baseline CPU (~12 tok/s)
```

Esperado: +30-60% tok/s. Si la iGPU se satura, puedes ver lentitud puntual en el
escritorio Windows. Ver [docs/intel-igpu-status.md](docs/intel-igpu-status.md) para
los riesgos y prerequisitos.

Para volver a CPU: `make down && make up`.
