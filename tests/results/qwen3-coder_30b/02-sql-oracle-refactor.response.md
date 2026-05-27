### Problema raiz
La consulta original sufre de una mala distribución de filtros y el uso de `REGEXP_LIKE` en cláusulas `OR` con subconsultas correlacionadas, lo que impide que el CBO aplique eficientemente índices y genera un alto número de buffer gets.

### Refactor
```sql
SELECT /*+ FIRST_ROWS(50) */
       p.id_pol, p.nombre, p.cif_nif
  FROM v_polizas_vivas p
 WHERE p.estado = 'VIGENTE'
   AND p.t_pol = 'AUTO'
   AND ( :search IS NULL OR
         REGEXP_LIKE(p.cif_nif, :search, 'i') OR
         EXISTS (SELECT /*+ NO_UNNEST */ 1 FROM mt_personas pe
                  WHERE pe.id_persona = p.id_tomador
                    AND REGEXP_LIKE(pe.nombre || ' ' || pe.apellidos, :search, 'i')) OR
         EXISTS (SELECT /*+ NO_UNNEST */ 1 FROM plz.objetos_cnd oc
                  WHERE oc.id_pol = p.id_pol
                    AND REGEXP_LIKE(oc.matricula, :search, 'i'))
       )
 ORDER BY p.id_pol DESC
 FETCH FIRST 50 ROWS ONLY;
```

### Por que el plan deberia mejorar
El uso de `FIRST_ROWS(50)` permite al CBO optimizar para recuperar filas rápidamente en lugar de hacer un full scan. Además, el `NO_UNNEST` en las subconsultas evita que se materialicen de forma innecesaria, mejorando la eficiencia del plan. El operador `FILTER` se verá reemplazado por `HASH JOIN` o `NESTED LOOPS` más eficientes dependiendo de los datos.
