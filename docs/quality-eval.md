# Evaluacion de calidad — qwen 7B vs DeepSeek 16B MoE

Suite de 3 tests representativos del trabajo real con MutuaTFE:

1. Refactor Python async con bugs sutiles (asyncio, mutable defaults, cache, errores)
2. Refactor SQL Oracle 19c (caso real OR-EXISTS-EXISTS)
3. Sintesis tecnica desde bullets (estilo documentacion tecnica)

Prompts y criterios en [`tests/eval/`](../tests/eval/). Respuestas guardadas en
[`tests/results/<modelo>/`](../tests/results/) reproducibles con `make qeval MODEL=...`.

## Tabla resumen

| Modelo | Test 1 (Python) | Test 2 (SQL) | Test 3 (Doc) | **TOTAL /75** | Velocidad |
|---|---:|---:|---:|---:|---:|
| qwen2.5-coder:7b Q4_K_M | 3 / 25 | 2 / 25 | 15 / 25 | **20 / 75** | 10.2 tok/s |
| deepseek-coder-v2:16b-lite Q4_K_M | 13 / 25 | 5 / 25 | 19 / 25 | **37 / 75** | 22.3 tok/s |
| Claude Opus 4.7 (referencia subjetiva) | ~24 / 25 | ~24 / 25 | ~23 / 25 | ~71 / 75 | n/a (nube) |

DeepSeek casi **duplica la puntuación** de qwen, y **además va 2× más rápido** por ser MoE
(16B totales, ~2.4B activos por token). Es el modelo ganador con diferencia.

## Metricas de ejecucion (suite completa)

| Modelo | Test 1 | Test 2 | Test 3 | Total |
|---|---|---|---|---|
| qwen 7B | 57.7 s · 10.5 tok/s | 71.5 s · 10.0 tok/s | 83.3 s · 10.2 tok/s | **3 min 32 s** |
| deepseek 16B MoE | 45.8 s · 23.1 tok/s | 32.4 s · 22.5 tok/s | 44.0 s · 21.2 tok/s | **2 min 02 s** |

## Test 1 — Refactor Python async

### qwen 7B: 3 / 25

| Categoria | Puntos | Comentario |
|---|---:|---|
| Correccion | 1 / 5 | Bug serio: `await httpx.get(...)` no compila (httpx.get es sincrono, no awaitable). Quita `import time` pero sigue usando `time.time()`. |
| Identificacion | 1 / 5 | 2 de 9 issues (time.sleep parcial, except bare). Ignora mutable defaults, cache shared, httpx sync, type hints, mutacion con del. |
| Calidad del fix | 0 / 5 | Mantiene cache shared, mutacion con del, `from typing import *`. El await sobre sync rompe el codigo. |
| Idiomatica | 1 / 5 | Mantiene `from typing import *`. Anade dataclass sin razon. |
| Claridad | 0 / 5 | Contradiccion entre "Por que" (menciona asyncio.sleep) y codigo (no lo usa). |

### DeepSeek 16B MoE: 13 / 25

| Categoria | Puntos | Comentario |
|---|---:|---|
| Correccion | 2 / 5 | Mismo bug `await httpx.get` y `fields: List[str] = []` (mutable default no resuelto). `__post_init__` mejor planteado pero usa atributo clase como instancia. |
| Identificacion | 2 / 5 | 3-4 issues de 9 (time.sleep, cache shared, except, parcial TTL). Mejor que qwen pero aun bajo. |
| Calidad del fix | 3 / 5 | Cache **por instancia** con `__post_init__` (resuelve shared state). **Dict comprehension** en vez de `del` (resuelve mutacion). except `httpx.RequestError` correcto. |
| Idiomatica | 3 / 5 | Import explicito (no `*`). `asyncio` importado. |
| Claridad | 3 / 5 | Explica bien aunque queda 1 inconsistencia en "Por que". |

**Conclusion test Python**: DeepSeek mejora claramente — identifica mas problemas y aplica
fixes reales (cache per-instance, dict comprehension). Pero **ninguno resuelve el problema
del cliente httpx sincrono**, lo cual es un fallo conceptual de async que solo un modelo
frontier captura sin dudas.

## Test 2 — Refactor SQL Oracle (OR-EXISTS-EXISTS)

### qwen 7B: 2 / 25

| Categoria | Puntos | Comentario |
|---|---:|---|
| Correccion | 2 / 5 | SQL valido pero **identico al original**. |
| Identificacion | 0 / 5 | No menciona OR-EXISTS-EXISTS. Generico "REGEXP_LIKE es costoso". |
| Calidad del fix | 0 / 5 | No hay refactor. Solo consejos de indices. |
| Idiomatica | 0 / 5 | Sugiere indice bitmap (anti-patron para alta cardinalidad). |
| Claridad | 0 / 5 | No refactoriza la query. |

### DeepSeek 16B MoE: 5 / 25

| Categoria | Puntos | Comentario |
|---|---:|---|
| Correccion | 1 / 5 | **Inventa indice** `IDX_POLIZAS_VIVAS` que no se sabe si existe. |
| Identificacion | 0 / 5 | No menciona OR-EXISTS-EXISTS ni que el CBO no puede push down por rama. |
| Calidad del fix | 1 / 5 | Query original + hint inventado. |
| Idiomatica | 2 / 5 | SQL sin acentos correcto. |
| Claridad | 1 / 5 | Justifica con explicacion incorrecta ("ORDER BY al final eficiente en E/S"). |

**Conclusion test SQL**: **AMBOS FALLAN**. La optimizacion CBO Oracle 19c requiere
razonar sobre planes de ejecucion y patrones disyuntivos que no estan bien aprendidos
en modelos coder ≤16B. Para SQL CBO complejo el modelo local **no sirve hoy** — hay que
llevarlo a Claude API o tener al humano (que ya lo hizo, ver `feedback_or_exists_kills_cbo`).

Para queries triviales (SELECT/JOIN/WHERE simple, ventanas, CTEs) ambos modelos funcionan.

## Test 3 — Sintesis tecnica desde bullets

### qwen 7B: 15 / 25

| Categoria | Puntos | Comentario |
|---|---:|---|
| Correccion | 4 / 5 | Info fiel a bullets, solo inventa 2 URLs en Referencias. |
| Identificacion | 3 / 5 | Distingue causa (CA bundle por imagen base) y sintoma. |
| Calidad del fix | 4 / 5 | 3 variantes (Debian/Alpine/Go). Falta verificacion. |
| Idiomatica | 2 / 5 | Sin admonition !!! tip, sin tabla comparativa. |
| Claridad | 2 / 5 | Resumen demasiado largo, no menciona el anti-patron. |

### DeepSeek 16B MoE: 19 / 25

| Categoria | Puntos | Comentario |
|---|---:|---|
| Correccion | 4 / 5 | Info fiel, URLs inventadas en Referencias. |
| Identificacion | 4 / 5 | Causa y sintoma claros, **menciona el anti-patron** ("sin configuracion adicional dentro de cada Dockerfile"). |
| Calidad del fix | 5 / 5 | 3 variantes + **seccion Verificacion con el `docker exec curl`**. |
| Idiomatica | 2 / 5 | Sin admonitions, sin tabla, H3 en lugar de H2. |
| Claridad | 4 / 5 | Conciso, accionable, resumen apropiado. |

**Conclusion test Doc**: Para sintesis tecnica desde bullets, DeepSeek genera un draft
casi listo para pulir. La unica intervencion humana real son los admonitions, la tabla
y bajar H3 a H2. Util para docs/changelogs/ADRs.

## Cuando usar cada uno

| Tipo de tarea | qwen 7B | DeepSeek 16B MoE | Claude Opus 4.7 |
|---|---|---|---|
| Renames, autocomplete, formateo | ✓ | ✓ | ✓ (caro para esto) |
| Doc/README/changelog desde bullets | ⚠️ borrador inicial | ✓ draft util | ✓ excelente |
| Refactor Python obvio | ✓ | ✓ | ✓ |
| Refactor Python con bugs sutiles | ✗ | ⚠️ parcial | ✓ |
| Query SQL CRUD/JOIN | ✓ | ✓ | ✓ |
| Optimizacion SQL CBO | ✗ | ✗ | ✓ |
| Razonar arquitectura | ✗ | ⚠️ | ✓ |
| Tool-use complejo (agente) | ✗ | ⚠️ | ✓ |

**Recomendacion final**:

- **Default de los 3 clientes (ccr, opencode, continue): DeepSeek 16B MoE**. Mejor calidad,
  doble de velocidad, mismo coste de memoria efectivo (MoE activa pocos params).
- **qwen 7B**: utilidad reducida ahora que tenemos DeepSeek. Dejarlo como **fallback
  rapido** para autocomplete tab o renames triviales si subes contexto a 16K.
- **Tareas no triviales**: seguir delegando a Claude API u otro modelo frontier. El gap
  con el local sigue siendo grande en razonamiento (especialmente SQL CBO y arquitectura).

## Reproducir

```bash
# Suite contra un modelo
make qeval MODEL=qwen2.5-coder:7b-instruct-q4_K_M
make qeval MODEL=deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Respuestas crudas en tests/results/<modelo>/
# Metricas en tests/results/_metrics.csv
```

Reaplicar la rubrica manualmente: leer las respuestas en `tests/results/<modelo>/*.response.md`
junto al `.criteria.md` correspondiente.
