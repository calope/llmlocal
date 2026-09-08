# Criterios test 02 — SQL Oracle refactor

Caso real documentado en feedback_or_exists_kills_cbo.md. Diagnostico:

**OR-EXISTS-EXISTS sobre tablas grandes** rompe el CBO 19c — no puede usar
indices por rama porque la condicion es disyuntiva. Plan resultante: FULL
SCAN gigante con NESTED LOOPS por cada fila → 22M gets.

## Fix esperado

`UNION ALL` con la query original repetida una vez por rama del OR, donde
cada rama es un SELECT especializado:

```sql
SELECT * FROM (
  SELECT p.id_pol, p.nombre, p.cif_nif, 1 AS prio FROM v_polizas_vivas p
   WHERE p.estado='VIGENTE' AND p.t_pol='AUTO'
     AND REGEXP_LIKE(p.cif_nif, :search, 'i')
  UNION ALL
  SELECT p.id_pol, p.nombre, p.cif_nif, 2 FROM v_polizas_vivas p
   WHERE p.estado='VIGENTE' AND p.t_pol='AUTO'
     AND EXISTS (SELECT 1 FROM mt_personas pe ...)
  UNION ALL
  SELECT p.id_pol, p.nombre, p.cif_nif, 3 FROM v_polizas_vivas p
   WHERE p.estado='VIGENTE' AND p.t_pol='AUTO'
     AND EXISTS (SELECT 1 FROM plz.objetos_cnd oc ...)
)
WHERE ROWNUM <= 50  -- o ordenado y FETCH FIRST si quitamos dups
ORDER BY id_pol DESC;
```

Lo importante: cada rama puede usar su propio indice. Plan = 3 UNION + cada
uno con NESTED LOOP / INDEX RANGE SCAN baratos. Pasa de 22M gets a <1000.

## Rubrica

| Categoria | 5 | 3 | 0 |
|---|---|---|---|
| Correccion | Oracle 19c valido, sin features 21c+, sin acentos | error sintaxis menor | inventa funcion / sintaxis no Oracle |
| Identificacion del problema | menciona OR-EXISTS imposibilita indice rama, CBO no puede push down | menciona "OR es lento" generico | dice "anade indice" sin entender el problema |
| Calidad del fix | UNION ALL por rama, semantica preservada | UNION pero pierde alguna rama o duplica | refactor no mejora el plan |
| Idiomatica | sin acentos, ALIAS claros, ordering al final, fetch correcto | acepta hints | usa NVL para todo, sintaxis Oracle 8i |
| Claridad | menciona FILTER/HASH JOIN/NESTED LOOP por nombre | OK pero generico | confunde operadores o no explica |

Bonus si:

- Menciona DISTINCT solo donde haga falta (UNION ALL es mas barato)
- Sugiere indices funcionales con UPPER() para mejorar REGEXP_LIKE 'i'
- Menciona hint /*+ INDEX */ por rama si el CBO falla
