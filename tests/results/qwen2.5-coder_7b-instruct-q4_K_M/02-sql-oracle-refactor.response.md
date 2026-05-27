### Problema raiz
La query original realiza múltiples subconsultas y una función de expresión regular (`REGEXP_LIKE`) en cada fila, lo que puede ser muy costoso en términos de rendimiento. Además, el uso de `EXISTS` con subconsultas puede no aprovechar eficientemente los índices.

### Refactor
```sql
SELECT p.id_pol, p.nombre, p.cif_nif
  FROM v_polizas_vivas p
 WHERE p.estado = 'VIGENTE'
   AND p.t_pol = 'AUTO'
   AND ( REGEXP_LIKE(p.cif_nif, :search, 'i')
      OR EXISTS (SELECT 1 FROM mt_personas pe
                  WHERE pe.id_persona = p.id_tomador
                    AND REGEXP_LIKE(pe.nombre || ' ' || pe.apellidos, :search, 'i'))
      OR EXISTS (SELECT 1 FROM plz.objetos_cnd oc
                  WHERE oc.id_pol = p.id_pol
                    AND REGEXP_LIKE(oc.matricula, :search, 'i'))
       )
 ORDER BY p.id_pol DESC
 FETCH FIRST 50 ROWS ONLY;
```

### Por que el plan deberia mejorar
El refactor no cambia la estructura de la query original, pero puede ayudar a mejorar el rendimiento si se optimizan los índices y las estadísticas. Específicamente, asegúrate de que los siguientes índices estén presentes:

1. `v_polizas_vivas (estado, t_pol, id_pol)`
2. `mt_personas (id_persona)`
3. `plz.objetos_cnd (id_pol)`

Además, considera usar un índice compuesto en la columna concatenada de nombres y apellidos en `mt_personas` si es común realizar búsquedas por este campo.

### Notas adicionales
- Asegúrate de que las estadísticas de las tablas estén actualizadas.
- Considera el uso de `/*+ INDEX (table_name index_name) */` para sugerir índices específicos si el CBO no está seleccionando los índices óptimos.

Si el problema persiste, podrías considerar usar una vista materializada o un índice bitmap para mejorar el rendimiento en consultas con múltiples subconsultas y funciones de expresión regular.
