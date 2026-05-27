 ## Problemas detectados
- Uso de `time.sleep` que bloquea el evento loop async, lo cual es ineficiente y no aprovecha las capacidades asincronas de Python.
- El manejo de excepciones en la capa superior del código puede ser mejorado para proporcionar más detalles sobre los errores ocurridos.
- La caché se comparte entre todas las instancias de `OrderService`, lo cual puede no ser deseado si cada instancia debe tener su propia caché independiente.
- El manejo del tiempo y la limpieza de datos en la caché podría mejorarse para una mayor eficiencia y precisión.

## Refactor propuesto
```python
from typing import List, Dict, Any
import httpx
import asyncio
from dataclasses import dataclass

@dataclass
class OrderService:
    base_url: str
    timeout: int = 10
    cache: Dict[str, List[Dict[str, Any]]] = None

    def __post_init__(self):
        if self.cache is None:
            self.cache = {}

    async def fetch_user_orders(self, user_id: str, fields: List[str] = []) -> List[Dict[str, Any]]:
        if user_id in self.cache:
            return self.cache[user_id]
        
        try:
            r = await httpx.get(f"{self.base_url}/users/{user_id}/orders", timeout=self.timeout)
            data = r.json()
            orders_with_fields = []
            for order in data:
                if "fetched_at" not in order:
                    order["fetched_at"] = asyncio.get_running_loop().time()
                if fields:
                    order = {k: order[k] for k in fields if k in order}
                orders_with_fields.append(order)
            self.cache[user_id] = orders_with_fields
            return self.cache[user_id]
        except httpx.RequestError as e:
            print(f"An error occurred while fetching user orders: {e}")
            return []
```

## Por que
- Se reemplazó `time.sleep` por un await en una operación de red, permitiendo que el loop async continue ejecutando otras tareas mientras espera la respuesta del servidor.
- Se mejoró el manejo de excepciones para capturar y registrar detalles específicos sobre los errores ocurridos durante las solicitudes HTTP.
- Se agregaron type hints más detallados y se utilizó `dataclass` para manejar atributos de clase, asegurando una mayor claridad y mantenibilidad del código.
- La caché ahora es específica por instancia, evitando problemas potenciales de consistencia entre diferentes instancias de `OrderService`.
