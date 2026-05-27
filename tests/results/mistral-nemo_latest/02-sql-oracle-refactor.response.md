### Problema raíz

El problema principal con la query original es que utiliza una expresión regular para filtrar el campo `cif_nif`, lo cual puede ser costoso en términos de rendimiento ya que requiere escanear todo el índice o la tabla. Además, hay dos subconsultas EXISTS que también pueden afectar negativamente el rendimiento.

### Refactor

```sql
SELECT p.id_pol, p.nombre, p.cif_nif
  FROM v_polizas_vivas p
 WHERE p.estado = 'VIGENTE'
   AND p.t_pol = 'AUTO'
   AND ( p.cif_nif LIKE :search
      OR EXISTS (SELECT 1 FROM mt_personas pe
                  WHERE pe.id_persona = p.id_tomador
                    AND pe.nombre || ' ' || pe.apellidos LIKE :search)
      OR EXISTS (SELECT 1 FROM plz.objetos_cnd oc
                  WHERE oc.id_pol = p.id_pol
                    AND oc.matricula LIKE :search)
       )
 ORDER BY p.id_pol DESC
 FETCH FIRST 50 ROWS ONLY;
```

### Por qué el plan debería mejorar

El cambio principal en la query refactorizada es que se reemplaza la función REGEXP_LIKE por LIKE, lo cual puede mejorar significativamente el rendimiento ya que LIKE es más rápido que REGEXP_LIKE. Además, se eliminan las mayúsculas y minúsculas con 'i' para hacer la búsqueda case-insensitive, lo cual también puede mejorar el rendimiento. En general, estos cambios deberían reducir el número de buffer gets necesarios para ejecutar la query y mejorar el tiempo de ejecución en general.
