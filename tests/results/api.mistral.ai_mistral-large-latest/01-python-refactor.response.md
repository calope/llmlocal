## Problemas detectados
- Uso de `time.sleep()` en código async bloquea el event loop
- Manejo de excepciones demasiado genérico (captura todas sin discriminar)
- Cache compartida como variable de clase (problemas de thread-safety en async)
- Falta de type hints completos en firma y variables internas
- Uso de `httpx.get()` síncrono en contexto async (debería ser `httpx.AsyncClient`)
- Modificación in-place de la respuesta (`o["fetched_at"]`) sin copia previa
- Timeout no se aplica correctamente al cliente HTTP
- Falta de validación de `user_id` y `fields`
- Posible fuga de memoria en cache sin límite de tamaño/tiempo

## Refactor propuesto
```python
from dataclasses import dataclass
from typing import Any, Optional, Sequence
import asyncio
import httpx
from datetime import datetime, timezone

@dataclass
class CachedOrders:
    data: list[dict[str, Any]]
    timestamp: float

class OrderService:
    def __init__(self, base_url: str, timeout: float = 10.0) -> None:
        self.base_url = base_url
        self.timeout = timeout
        self._cache: dict[str, CachedOrders] = {}
        self._client = httpx.AsyncClient(timeout=timeout)

    async def fetch_user_orders(
        self,
        user_id: str,
        fields: Optional[Sequence[str]] = None
    ) -> list[dict[str, Any]]:
        if not user_id or not isinstance(user_id, str):
            return []

        if fields is None:
            fields = []

        if cached := self._cache.get(user_id):
            if (datetime.now(timezone.utc).timestamp() - cached.timestamp) < 300:  # 5 min cache
                return self._filter_fields(cached.data.copy(), fields)

        try:
            await asyncio.sleep(0.5)  # rate limiter no bloqueante
            response = await self._client.get(f"{self.base_url}/users/{user_id}/orders")
            response.raise_for_status()

            data = response.json()
            if not isinstance(data, list):
                return []

            enriched_data = [
                {**order, "fetched_at": datetime.now(timezone.utc).timestamp()}
                for order in data
            ]

            self._cache[user_id] = CachedOrders(
                data=enriched_data,
                timestamp=datetime.now(timezone.utc).timestamp()
            )

            return self._filter_fields(enriched_data, fields)

        except (httpx.HTTPError, ValueError, TypeError):
            return []
        finally:
            await self._cleanup_cache()

    def _filter_fields(
        self,
        data: list[dict[str, Any]],
        fields: Sequence[str]
    ) -> list[dict[str, Any]]:
        if not fields:
            return data
        return [{k: v for k, v in item.items() if k in fields} for item in data]

    async def _cleanup_cache(self) -> None:
        """Elimina entradas de cache más antiguas que 1 hora"""
        now = datetime.now(timezone.utc).timestamp()
        self._cache = {
            k: v for k, v in self._cache.items()
            if (now - v.timestamp) < 3600
        }

    async def close(self) -> None:
        """Limpieza de recursos"""
        await self._client.aclose()
```

## Por qué
1. **Async nativo**: Reemplazamos `time.sleep()` por `asyncio.sleep()` y usamos `httpx.AsyncClient` para operaciones HTTP no bloqueantes
2. **Seguridad y tipado**: Añadimos type hints completos, validación de inputs y estructura de datos con `@dataclass` para la cache
3. **Manejo de errores**: Excepciones específicas para HTTP y parsing, con limpieza de recursos en `finally`
4. **Cache mejorada**: Implementamos límite de tiempo (5 min para datos frescos, 1 hora para limpieza) y copia de datos para evitar modificaciones in-place
5. **Separación de responsabilidades**: Métodos privados para filtrado y limpieza de cache, con manejo adecuado de recursos en `close()`