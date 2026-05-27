# Criterios test 01 — Python refactor

Issues que el modelo debe identificar (lista oculta para rubrica):

1. `time.sleep` bloqueante dentro de funcion `async def` (debe ser `await asyncio.sleep`)
2. `httpx.get` sincrono dentro de funcion `async` (debe ser `httpx.AsyncClient`)
3. Mutable default argument: `fields=[]` (peligroso, debe ser `None` con check)
4. Cache mutable de clase compartido sin lock (race condition entre coroutines)
5. `except:` bare (debe ser `except Exception` minimo, mejor especifico)
6. Tipos faltantes: `user_id`, `fields`, return type
7. `from typing import *` (mala practica, importar lo necesario)
8. Mutar `data` filtrando keys con `del o[k]` (mejor list comprehension nueva)
9. Cache sin TTL (la entry "fetched_at" sugiere intencion pero no se usa)

Bonus si menciona:
- Logging en lugar de silenciar errores
- Reusar httpx.AsyncClient (no abrir cliente nuevo por cada call)
- Limit cache size (LRU)

## Rubrica

| Categoria | 5 = excelente | 3 = aceptable | 0 = malo |
|---|---|---|---|
| Correccion (compila + APIs reales) | codigo Python 3.12+ valido, asyncio + httpx correctos | algun import sobrante o detalle menor | tipo error / API inventada |
| Identificacion del problema | detecta ≥7/9 issues | 4-6/9 | <4 issues |
| Calidad del fix | resuelve TODOS los detectados sin introducir bugs | resuelve el 70% | quedan bugs |
| Idiomatica | dataclass/protocol bien usado, no `from typing import *` | uso aceptable | hace cosas raras |
| Claridad | explicacion concisa y correcta | OK | confusa o inventa razones |
