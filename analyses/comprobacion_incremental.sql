-- =============================================================================
-- comprobacion_incremental
-- =============================================================================
-- Análisis: estado de los dos modelos incrementales de vivienda, para
-- comparar antes y después de cargar una entrega nueva de la tabla 6150 del
-- INE y reconstruir con el selector entrega_vivienda.
-- Una fila por mes de julio a diciembre de 2025 con las compraventas de
-- Madrid (libre, usada y total) del hecho, y en todas las filas el número de
-- filas y el último mes de slv_compraventa_vivienda_mensual y de
-- fct_compraventa_vivienda_mensual.
-- Los meses salen de dim_tiempo: si el hecho todavía no tiene un mes, sus
-- compraventas salen NULL.
-- Un análisis se compila pero no se ejecuta en los jobs: se abre en Studio y
-- se ejecuta con Preview.
-- =============================================================================

WITH silver AS (

    SELECT
        COUNT(*) AS filas_silver,
        MAX(id_mes) AS ultimo_mes_silver
    FROM {{ ref('slv_compraventa_vivienda_mensual') }}

),

hecho AS (

    SELECT
        COUNT(*) AS filas_hecho,
        MAX(id_mes) AS ultimo_mes_hecho
    FROM {{ ref('fct_compraventa_vivienda_mensual') }}

),

madrid AS (

    SELECT
        sk_lugar,
        provincia
    FROM {{ ref('dim_lugar') }}
    WHERE id_provincia = '28'

),

meses AS (

    SELECT
        id_mes
    FROM {{ ref('dim_tiempo') }}
    WHERE id_mes BETWEEN 202507 AND 202512

),

compraventas_madrid AS (

    SELECT
        madrid.provincia,
        meses.id_mes,
        hechos.num_libre,
        hechos.num_usada,
        hechos.num_total
    FROM madrid
    CROSS JOIN meses
    LEFT JOIN {{ ref('fct_compraventa_vivienda_mensual') }} AS hechos
        ON hechos.sk_lugar = madrid.sk_lugar
        AND hechos.id_mes = meses.id_mes

)

SELECT
    compraventas_madrid.provincia,
    compraventas_madrid.id_mes,
    compraventas_madrid.num_libre,
    compraventas_madrid.num_usada,
    compraventas_madrid.num_total,
    silver.filas_silver,
    silver.ultimo_mes_silver,
    hecho.filas_hecho,
    hecho.ultimo_mes_hecho
FROM compraventas_madrid
CROSS JOIN silver
CROSS JOIN hecho
ORDER BY
    compraventas_madrid.id_mes