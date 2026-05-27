# Criterios test 03 — sintesis tecnica

## Que debe aparecer

- H1 con el titulo dado
- Secciones H2: Contexto, Decision, Como aplicar (Debian/Ubuntu + Alpine + Go), Referencias (vacia ok, o con TODO)
- Tabla comparativa (al menos: imagen base → path destino) en "Como aplicar"
- Bloques de codigo bash o yaml para los mounts
- Acentos correctos: cómo, también, configuración (UTF-8 normal)
- Admonition !!! tip o !!! note al menos una vez si encaja
- Mencion anti-patron (CA dentro del Dockerfile)
- "## Resumen" final con 2-3 lineas accionables

## Rubrica

| Categoria | 5 | 3 | 0 |
|---|---|---|---|
| Correccion | toda la info real reflejada, sin alucinar comandos | algun comando ligeramente cambiado | inventa flags inexistentes |
| Identificacion del problema | distingue bien causa (CA bundle por imagen base) y sintoma | menciona ambos pero confuso | invierte causa/sintoma |
| Calidad del fix | mounts Debian + Alpine + Go env var todos correctos | falta alguna variante | da una unica solucion |
| Idiomatica | español con acentos, admonitions, tabla, bloques de codigo | falta admonition o tabla | sin estructura |
| Claridad | conciso, accionable | demasiado largo | demasiado breve, no util |
