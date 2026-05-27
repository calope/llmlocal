## Problemas detectados
- `cache = {}` como atributo de clase comparte estado entre todas las instancias (bug de diseño)
- `fields=[]` es mutable como argumento por defecto (bug clásico Python)
- `time.sleep(0.5)` bloquea el event loop en una corrutina async
- `httpx.get(...)` es síncrono; en contexto async debe usarse `httpx.AsyncClient`
- `from typing import *` importa todo el módulo sin necesidad; en Python 3.12+ la mayoría de tipos vive en `builtins`
- `except:` desnudo silencia cualquier excepción incluyendo `KeyboardInterrupt` y `SystemExit`
- No hay invalidación de caché ni TTL: los datos quedan obsoletos indefinidamente
- La mutación directa de los dicts de `data` produce efectos secundarios en el objeto cacheado
- Sin type hints en la firma ni en el retorno
- `base_url` y `timeout` sin anotación de tipo en `__init__`

## Refactor propuesto
```python
import asyncio
import time
from dataclasses import dataclass, field
from typing import Any

import httpx


@dataclass
class _CacheEntry:
    data: list[dict[str, Any]]
    fetched_at: float


class OrderService:
    def __init__(
        self,
        base_url: str,
        timeout: float = 10.0,
        cache_ttl: float = 60.0,
    ) -> None:
        self.base = base_url
        self.timeout = timeout
        self.cache_ttl = cache_ttl
        self._cache: dict[str, _CacheEntry] = {}

    def _is_cache_valid(self, entry: _CacheEntry) -> bool:
        return (time.monotonic() - entry.fetched_at) < self.cache_ttl

    async def fetch_user_orders(
        self,
        user_id: str,
        fields: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        cached = self._cache.get(user_id)
        if cached is not None and self._is_cache_valid(cached):
            orders = cached.data
        else:
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    r = await client.get(f"{self.base}/users/{user_id}/orders")
                    r.raise_for_status()
                    raw: list[dict[str, Any]] = r.json()
            except httpx.HTTPError:
                return []

            fetched_at = time.monotonic()
            orders = [
                {**o, "fetched_at": fetched_at}
                for o in raw
            ]
            self._cache[user_id] = _CacheEntry(data=orders, fetched_at=fetched_at)

        if fields:
            field_set = set(fields)
            return [{k: v for k, v in o.items() if k in field_set} for o in orders]

        return orders
```

## Por que
La caché se movio a instancia (`self._cache`) con TTL basado en `time.monotonic()` para evitar datos obsoletos y contaminacion entre instancias. El cliente HTTP se reemplaza por `httpx.AsyncClient` con `await` para no bloquear el event loop, eliminando ademas el `time.sleep` sincrono. La excepcion se acota a `httpx.HTTPError` y los dicts se construyen con comprension de copia en lugar de mutar los originales, evitando efectos secundarios sobre el objeto cacheado.
