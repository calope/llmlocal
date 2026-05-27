 ### Problema raíz
La query original tiene un plan de ejecución que realiza un escaneo completo del índice y luego operaciones adicionales en la tabla base, lo cual es ineficiente debido al uso intensivo de buffer gets. El costo estimado (CBO) está optimizado para una configuración específica que no coincide con la actual, resultando en un plan subóptimo.

### Refactor
A continuación se presenta una versión refactoreada de la query que mejora el plan de ejecución:

```sql
SELECT /*+ INDEX(p IDX_POLIZAS_VIVAS) */ p.id_pol, p.nombre, p.cif_nif
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

### Por qué el plan debería mejorar
La principal mejora en el plan se debe al uso del índice `IDX_POLIZAS_VIVAS`, que permite un acceso directo a las filas necesarias sin necesidad de escanear toda la tabla. Este cambio reduce significativamente los buffer gets y acelera la ejecución de la query. Además, el ordenamiento final (`ORDER BY`) se realiza al final del proceso, lo cual es eficiente en términos de E/S de disco.

Este refactor utiliza un hint de Oracle (`/*+ INDEX(p IDX_POLIZAS_VIVAS) */`) para sugerir al optimizador que utilice el índice especificado, mejorando así la eficiencia del plan de ejecución.
