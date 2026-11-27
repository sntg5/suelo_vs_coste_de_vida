-- =============================================================================
-- slv_trimestre
-- =============================================================================
-- Una fila por trimestre del periodo. Clave AAAAT (20202 = 2T 2020).
-- 3FN: el trimestre depende del año, pero no guarda la etapa (eso es del año).
-- =============================================================================

WITH trimestres AS (

    SELECT DISTINCT
        id_trimestre,
        anio,
        num_trimestre
    FROM {{ ref('int_calendario_mensual') }}

)

SELECT
    CAST(id_trimestre AS NUMBER(5, 0)) AS id_trimestre,
    CAST(anio AS NUMBER(4, 0)) AS anio,
    CAST(num_trimestre AS NUMBER(1, 0)) AS num_trimestre
FROM trimestres