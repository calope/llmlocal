## Problemas detectados

- `time.sleep(0.5)` bloquea el event loop dentro de funcion `async def` (debe ser `await asyncio.sleep`)
- `httpx.get(...)` es sincrono dentro de coroutine; bloquea el loop. Hay que usar `httpx.AsyncClient` con `await`
- Mutable default argument `fields=[]` se comparte entre llamadas (clasico bug Python); usar `fields: list[str] | None = None`
- `OrderService.cache = {}` es atributo de clase, compartido entre instancias y sin locking → race conditions con concurrencia async
- `except:` bare captura `KeyboardInterrupt`/`SystemExit` y oculta cualquier error; usar excepciones concretas y al menos `Exception`
- `from typing import *` contamina el namespace; en Python 3.12+ ni siquiera hace falta para `list[str]`, `dict[str, Any]`, etc.
- Tipos faltantes: `user_id`, `fields`, return type
- Mutacion del dict iterado con `del o[k]` mientras se itera; uso correcto: dict comprehension nuevo
- Errores silenciados sin log → debugging imposible; al menos `logger.warning(...)`
- Cache sin TTL ni limite; "fetched_at" sugiere intencion no implementada
- `httpx.Client` deberia reusarse (HTTP/2 + connection pool); abrir y cerrar por request es caro

## Refactor propuesto

```python
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from time import monotonic
from typing import Any

import httpx

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class _CacheEntry:
    data: list[dict[str, Any]]
    fetched_at: float


class OrderService:
    """Cliente async para /users/{id}/orders con cache TTL y rate limit."""

    def __init__(
        self,
        base_url: str,
        timeout: float = 10.0,
        *,
        cache_ttl_s: float = 60.0,
        rate_limit_s: float = 0.5,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base = base_url.rstrip("/")
        self._timeout = timeout
        self._ttl = cache_ttl_s
        self._rate_limit = rate_limit_s
        self._owns_client = client is None
        self._client = client or httpx.AsyncClient(timeout=timeout)
        self._cache: dict[str, _CacheEntry] = {}
        self._lock = asyncio.Lock()  # serializa rate-limit y mutacion de cache

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def fetch_user_orders(
        self,
        user_id: str,
        fields: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        # Lectura no bloqueante de la cache; si esta caliente, retornar sin lock
        entry = self._cache.get(user_id)
        if entry is not None and (monotonic() - entry.fetched_at) < self._ttl:
            return self._project(entry.data, fields)

        async with self._lock:
            # Doble check: otro coroutine puede haber rellenado la cache mientras esperabamos
            entry = self._cache.get(user_id)
            if entry is not None and (monotonic() - entry.fetched_at) < self._ttl:
                return self._project(entry.data, fields)

            await asyncio.sleep(self._rate_limit)
            try:
                r = await self._client.get(f"{self._base}/users/{user_id}/orders")
                r.raise_for_status()
                raw = r.json()
            except httpx.HTTPError as e:
                logger.warning("fetch_user_orders failed for %s: %s", user_id, e)
                return []

            now = monotonic()
            stamped = [{**o, "fetched_at": now} for o in raw]
            self._cache[user_id] = _CacheEntry(data=stamped, fetched_at=now)
            return self._project(stamped, fields)

    @staticmethod
    def _project(
        data: list[dict[str, Any]],
        fields: list[str] | None,
    ) -> list[dict[str, Any]]:
        if not fields:
            return data
        keep = set(fields)
        return [{k: v for k, v in o.items() if k in keep} for o in data]
```

## Por que

Tres cambios estructurales: (1) la cache pasa a ser **por instancia** con `asyncio.Lock` y patron double-checked locking, de modo que varios coroutines pidiendo el mismo `user_id` solo disparan una request HTTP; (2) httpx.AsyncClient se reusa (HTTP keep-alive + pool) y se cierra explicitamente en `close()`, asi que el caller puede gestionar el ciclo de vida o inyectar su propio cliente para tests; (3) el filtrado por `fields` se hace fuera del lock con dict comprehension sobre una copia, sin mutar la cache, evitando el bug de "del durante iteracion" y manteniendo coherencia si dos llamadas piden `fields` distintos sobre el mismo `user_id`.

Notas adicionales: el TTL usa `monotonic()` (inmune a saltos de reloj), `slots=True` en el dataclass reduce memoria con muchas entradas, y se respeta la firma publica `fetch_user_orders(user_id, fields)` aunque ahora `fields` admite `None` (Pythonico para "opcional").
