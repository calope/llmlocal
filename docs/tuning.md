# Tuning Ollama en este equipo

Mediciones de 2026-05-11 sobre Intel Core 7 240H (Meteor Lake), 14 hilos, AVX_VNNI,
22 GB RAM WSL, modelo `qwen2.5-coder:7b-instruct-q4_K_M`.

## Configuracion final

```yaml
OLLAMA_NUM_THREAD: "12"
OLLAMA_NUM_PARALLEL: "1"
OLLAMA_FLASH_ATTENTION: "1"
OLLAMA_KV_CACHE_TYPE: "q8_0"
OLLAMA_CONTEXT_LENGTH: "8192"   # default Ollama es 2048, corto para sesiones con archivos
OLLAMA_KEEP_ALIVE: "30m"
OLLAMA_MAX_LOADED_MODELS: "2"
```

## Barrido NUM_THREAD (per-request, 3 iters / valor)

| threads | media tok/s | observacion |
|---|---|---|
| 7 | 11.90 | cores fisicos puros, infrabox |
| 10 | 12.04 | bien |
| **12** | **12.10** | **sweet-spot, deja 2 hilos al kernel** |
| 14 | 9.01 | -25%, contencion con el sistema |

Conclusion: la teoria "SMT no ayuda en LLM" no aplica aqui — el CPU es hibrido
P-cores + E-cores y WSL2 expone los 14 hilos como una mezcla. 12 hilos da el mejor
throughput sin saturar al scheduler.

## Bench extendido (3 iters, num_predict=256, contexto corto)

```
=== Resumen eval (generacion) ===
  media=12.07 tok/s  min=11.83  max=12.36  (n=3)
=== Resumen TTFT (prompt eval) ===
  media=0.08 s  min=0.08  max=0.08  (n=3)
```

TTFT (time to first token) ~80 ms → la conversacion arranca instantanea.
La sensacion lenta solo aparece cuando hay que generar respuestas largas.

## Por que FLASH_ATTENTION + KV_CACHE q8_0 si no se nota en este bench

El bench mide contexto corto (~80 tokens prompt + 256 generados). Las dos
optimizaciones ayudan en **contextos largos** (>4K tokens), tipico en sesiones
reales `ccr code` o `opencode` con varios archivos abiertos:

- **FLASH_ATTENTION=1**: attention con menor uso de memoria, mejora con secuencia larga.
- **KV_CACHE_TYPE=q8_0**: KV cache cuantizado a 8 bits. ~50% menos RAM con perdida de
  calidad practicamente imperceptible. Indispensable en contextos >16K.

En el dia a dia notarias el efecto cuando le pasas `@file.py` o `@codebase` a un
cliente — sin esto, el KV cache se dispara y empieza swap.

## Que NO ayuda en este HW

- Bajar a 7 threads (cores fisicos): teoria de SMT-off no aplica en hibrido P/E.
- Subir a 14 threads: contencion con kernel y resto del sistema, cae 25%.
- `OLLAMA_NUM_PARALLEL > 1` si trabajas solo: fragmenta el KV cache y baja el throughput
  por sesion. Solo subir si vas a tener varios clientes a la vez.

## Prueba real con doc de luz (`make demo`)

Archivo: `luz/docs/informes/comparativa-bun-pnpm.md` (84 lineas, 1023 tokens prompt).

| Estado | prompt eval | generation eval | total |
|---|---|---|---|
| Cold (primera tras recreate) | 42.4 s (24 tok/s) | 16.9 s (11 tok/s) | 64.3 s |
| Warm (modelo ya en RAM) | 0.08 s (~12K tok/s) | 17.0 s (11 tok/s) | 17.4 s |

Calidad: extrajo bien decision, razones y porcentajes. JSON valido. Sin alucinaciones.

Conclusion: una vez warm, en 17 s respondes con contexto real. El cold-load se evita
con `OLLAMA_KEEP_ALIVE=30m`.

## Que probar para subir tok/s

| Cambio | Ganancia esperada | Coste |
|---|---|---|
| Modelo MoE (DeepSeek-Coder-V2-Lite 16B) | +50-100% (es MoE, 2.4B activos) | 10 GB pull |
| Modelo mas pequeno (Qwen2.5-Coder 3B) | +80-100% pero peor calidad | 2 GB pull |
| Fase 4 IPEX-LLM iGPU | +30-60% | 6-8 GB imagen, drama Level Zero |
| llama.cpp compilado SYCL nativo | +30-60% | 5 GB oneAPI + horas de tuning |
