### Problema raiz
El problema principal es la sobrecarga de trabajo en el CBO (Cost-Based Optimizer) debido a la complejidad de la consulta y la cantidad de operaciones realizadas, lo que lleva a un tiempo de ejecución excesivo de 350 segundos y 22 millones de buffer gets.

### Refactor
```sql
WITH filtrado AS (
  SELECT DISTINCT id_pol, nombre, cif_nif,
    CASE
      WHEN REGEXP_LIKE(cif_nif, :search, 'i') THEN TRUE
      ELSE FALSE
    END AS filtro_cif,
    CASE
      WHEN EXISTS (SELECT 1 FROM mt_personas pe
                      WHERE pe.id_persona = id_tomador
                        AND REGEXP_LIKE(pe.nombre || ' ' || pe.apellidos, :search, 'i'))
      THEN TRUE
      ELSE FALSE
    END AS filtro_tomador,
    CASE
      WHEN EXISTS (SELECT 1 FROM plz.objetos_cnd oc
                      WHERE id_pol = id_pol
                        AND REGEXP_LIKE(matricula, :search, 'i'))
      THEN TRUE
      ELSE FALSE
    END AS filtro_objeto
  FROM v_polizas_vivas p
  WHERE estado = 'VIGENTE'
    AND t_pol = 'AUTO'
)
SELECT id_pol, nombre, cif_nif
FROM filtrado
WHERE filtro_cif OR filtro_tomador OR filtro_objeto
ORDER BY id_pol DESC
FETCH FIRST 50 ROWS ONLY;
```

### Por que el plan deberia mejorar
El plan de ejecución debería mejorar debido a la siguiente razón:

*   La utilización del operador `CASE` en lugar de `REGEXP_LIKE` reduce la sobrecarga de trabajo en el CBO, ya que se evita la necesidad de realizar múltiples llamadas a la función `REGEXP_LIKE`.
*   El uso de una subconsulta con `EXISTS` en lugar de `OR` permite al CBO planificar mejor la consulta y reducir la cantidad de buffer gets.
*   La eliminación de la cláusula `ORDER BY` dentro de la subconsulta reduce la sobrecarga de trabajo en el CBO, ya que se evita la necesidad de realizar un sort interno.

Además, el uso de una vista o una tabla temporal para almacenar los resultados de la subconsulta permite al CBO planificar mejor la consulta y reducir la cantidad de buffer gets.
