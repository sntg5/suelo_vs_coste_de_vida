-- =============================================================================
-- slv_anio
-- =============================================================================
-- Una fila por año del periodo con su etapa. Los años salen del calendario
-- (no de los datos) y la etapa del rango de años de seed_etapas.
-- 3FN: la etapa depende del año, no del trimestre ni del mes; por eso el año
-- es una tabla propia. Si dos etapas se solaparan, un año saldría repetido y
-- el test unique lo detectaría.
-- =============================================================================

WITH anios AS (

    SELECT DISTINCT
        anio
    FROM {{ ref('int_calendario_mensual') }}

),

etapas AS (

    SELECT
        id_etapa,
        anio_desde,
        anio_hasta
    FROM {{ ref('seed_etapas') }}

)

SELECT
    CAST(anios.anio AS NUMBER(4, 0)) AS anio,
    CAST(etapas.id_etapa AS VARCHAR(3)) AS id_etapa
FROM anios
LEFT JOIN etapas
    ON anios.anio BETWEEN etapas.anio_desde AND etapas.anio_hasta