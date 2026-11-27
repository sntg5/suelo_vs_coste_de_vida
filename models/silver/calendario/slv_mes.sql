-- =============================================================================
-- slv_mes
-- =============================================================================
-- Una fila por mes del periodo. Clave AAAAMM (202005 = mayo de 2020).
-- 3FN: el mes solo guarda su trimestre; el año está en el trimestre y la
-- etapa en el año (mes → trimestre → año → etapa).
-- =============================================================================

WITH meses AS (

    SELECT
        id_mes,
        id_trimestre,
        num_mes
    FROM {{ ref('int_calendario_mensual') }}

)

SELECT
    CAST(id_mes AS NUMBER(6, 0)) AS id_mes,
    CAST(id_trimestre AS NUMBER(5, 0)) AS id_trimestre,
    CAST(num_mes AS NUMBER(2, 0)) AS num_mes
FROM meses