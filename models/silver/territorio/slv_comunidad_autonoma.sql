-- =============================================================================
-- slv_comunidad_autonoma
-- =============================================================================
-- Una fila por comunidad autónoma con su zona.
-- 3FN: provincia → CCAA → zona es una dependencia transitiva; la CCAA y su
-- zona salen del seed a esta tabla. Si el seed tuviera una CCAA con dos
-- nombres o dos zonas, el test unique de id_ccaa lo detectaría.
-- =============================================================================

WITH comunidades AS (

    SELECT DISTINCT
        id_ccaa,
        nombre_ccaa,
        id_zona
    FROM {{ ref('seed_provincias') }}

)

SELECT
    CAST(id_ccaa AS VARCHAR(2)) AS id_ccaa,
    CAST(nombre_ccaa AS VARCHAR(50)) AS nombre_ccaa,
    CAST(id_zona AS VARCHAR(3)) AS id_zona
FROM comunidades