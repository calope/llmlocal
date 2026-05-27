# Estado iGPU Intel en este equipo (Fase 3/4)

## Inventario detectado (2026-05-11)

- **Host Windows**: 11 25H2 (build 26200), 32 GB RAM
- **GPU host**: Intel(R) Graphics, driver 32.0.101.7076 (Arc Xe-LPG, Meteor Lake)
- **WSL**: Ubuntu, kernel 6.6.87.2 (WSLg activo, `libd3d12.so` presente)
- **Acceso GPU desde WSL**:
  - `/dev/dxg` presente (D3D12 paravirtualizacion) ✓
  - `/dev/dri` ausente ✗ (no hay pass-through DRM nativo)

Consecuencias:

- **Vulkan**: viable via DZN/D3D12, pero con [crashes conocidos en Arrow Lake con modelos grandes](https://github.com/ggml-org/llama.cpp/issues/19327).
- **SYCL/oneAPI**: viable instalando Intel Compute Runtime + Level Zero loader en WSL.
  Es el camino oficial Intel y el que [Intel documenta para Meteor Lake](https://www.intel.com/content/www/us/en/developer/articles/technical/run-llms-on-gpus-using-llama-cpp.html).
- **IPEX-LLM**: la via mas corta — Intel publica binarios precompilados de llama.cpp y
  Ollama parcheados para Intel GPU. Ver [ollama_portable_zip_quickstart](https://github.com/intel/ipex-llm/blob/main/docs/mddocs/Quickstart/ollama_portable_zip_quickstart.md).

## Numeros de referencia (publicados Intel/comunidad)

| Backend | Modelo | tok/s |
|---|---|---|
| CPU (AVX2+VNNI) | llama-2-7b Q4_0 | ~10-13 |
| SYCL iGPU MTL | llama-2-7b Q4_0 | ~16 (+23% tras opt 2025.2) |
| Vulkan iGPU MTL | llama-2-7b Q4_K_M | ~12-15 (variable) |

Esperar el mismo ratio en este equipo: **+30-60% vs CPU** en 7B Q4.

## Plan de habilitacion

### Opcion A — IPEX-LLM Ollama (mas simple)

```bash
# Compose ya preparado en compose/docker-compose.ipex.yml
./scripts/start.sh --ipex
```

Riesgo: la imagen `intelanalytics/ipex-llm-inference-cpp-xpu` pesa ~6-8 GB.

### Opcion B — llama.cpp compilado con SYCL (control fino)

Requisitos:
1. Intel oneAPI Base Toolkit en WSL (~5 GB).
2. Intel Compute Runtime + Level Zero (apt repos Intel).
3. Compilar `llama.cpp` con `-DGGML_SYCL=ON`.

Pasos detallados en `scripts/build-llama-sycl.sh` (a crear cuando demos luz verde).

## Decision recomendada

1. Validar primero Fase 1 (Ollama CPU) — funciona seguro, sin descargas grandes.
2. Si la velocidad CPU no convence, ir **directo a Opcion A** (IPEX-LLM Ollama).
3. Solo ir a Opcion B (compilar) si IPEX-LLM da problemas o quieres tunear mucho.
