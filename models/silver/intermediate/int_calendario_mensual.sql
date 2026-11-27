-- =============================================================================
-- int_calendario_mensual
-- =============================================================================
-- Calendario del periodo de análisis a grano mes, generado con
-- dbt_utils.date_spine entre anio_inicio y anio_fin (96 meses). No sale de
-- los datos: si a una fuente le faltara un mes, el calendario lo seguiría
-- teniendo y los tests de completitud de Silver lo detectarían.
-- Es la base de slv_anio, slv_trimestre, slv_mes y dim_tiempo.
-- =============================================================================

WITH meses AS (

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="CAST('" ~ var('anio_inicio') ~ "-01-01' AS DATE)",
        end_date="CAST('" ~ (var('anio_fin') + 1) ~ "-01-01' AS DATE)"
    ) }}

),

calendario AS (

    SELECT
        CAST(date_month AS DATE) AS fecha_inicio_mes,
        YEAR(date_month) * 100 + MONTH(date_month) AS id_mes,
        MONTH(date_month) AS num_mes,
        YEAR(date_month) * 10 + QUARTER(date_month) AS id_trimestre,
        QUARTER(date_month) AS num_trimestre,
        YEAR(date_month) AS anio
    FROM meses

)

SELECT *
FROM calendario