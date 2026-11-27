-- =============================================================================
-- slv_zona
-- =============================================================================
-- Una fila por zona (Norte y Sur, agrupación de comunidades autónomas).
-- 3FN: la zona depende de la CCAA y no de la provincia, así que sale del
-- seed a su propia tabla.
-- =============================================================================

WITH zonas AS (

    SELECT DISTINCT
        id_zona,
        nombre_zona
    FROM {{ ref('seed_provincias') }}

)

SELECT
    CAST(id_zona AS VARCHAR(3)) AS id_zona,
    CAST(nombre_zona AS VARCHAR(20)) AS nombre_zona
FROM zonas