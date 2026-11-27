-- =============================================================================
-- slv_provincia
-- =============================================================================
-- Una fila por provincia (50, sin Ceuta ni Melilla) con sus dos nombres y su
-- CCAA. 2FN: un nombre por código, aunque cada fuente escriba distinto la
-- provincia (Vizcaya / Bizkaia). 3FN: la zona no está aquí, sino en la CCAA.
-- =============================================================================

WITH provincias AS (

    SELECT
        id_provincia,
        nombre_provincia,
        nombre_mivau,
        id_ccaa
    FROM {{ ref('seed_provincias') }}

)

SELECT
    CAST(id_provincia AS VARCHAR(2)) AS id_provincia,
    CAST(nombre_provincia AS VARCHAR(50)) AS nombre_provincia,
    CAST(nombre_mivau AS VARCHAR(50)) AS nombre_mivau,
    CAST(id_ccaa AS VARCHAR(2)) AS id_ccaa
FROM provincias