-- =============================================================================
-- slv_tipo_vivienda
-- =============================================================================
-- Una fila por tipo de vivienda (4): libre y protegida (criterio Régimen),
-- nueva y usada (criterio Estado). Sale de los datos del INE.
-- Los dos criterios son dos formas de repartir el mismo total: solo se suman
-- tipos del mismo criterio (libre + protegida = nueva + usada = total).
-- 2FN: en la tabla 1FN de compraventas el nombre y el criterio dependían solo
-- del tipo (dependencia parcial); aquí queda una fila por código.
-- =============================================================================

WITH tipos AS (

    SELECT DISTINCT
        id_tipo_vivienda,
        nombre_tipo,
        criterio
    FROM {{ ref('int_ine__compraventa_vivienda_1fn') }}

)

SELECT
    CAST(id_tipo_vivienda AS VARCHAR(10)) AS id_tipo_vivienda,
    CAST(nombre_tipo AS VARCHAR(30)) AS nombre_tipo,
    CAST(criterio AS VARCHAR(10)) AS criterio
FROM tipos