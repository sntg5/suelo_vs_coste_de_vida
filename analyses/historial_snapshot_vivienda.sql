-- =============================================================================
-- historial_snapshot_vivienda
-- =============================================================================
-- Análisis: historial de revisiones de la compraventa de viviendas que guarda
-- snp_compraventa_vivienda. Muestra solo los datos (provincia, mes y tipo)
-- que tienen más de una versión, con su número de versión y su estado:
-- vigente (dbt_valid_to NULL) o cerrada.
-- Mientras el INE no revise ningún dato, no devuelve filas: cada dato tiene
-- una sola versión.
-- Un análisis se compila pero no se ejecuta en los jobs: se abre en Studio y
-- se ejecuta con Preview.
-- =============================================================================

WITH versiones AS (

    SELECT
        historial.id_provincia,
        provincias.nombre_provincia AS provincia,
        historial.id_mes,
        historial.id_tipo_vivienda,
        historial.num_compraventas,
        historial.dbt_valid_from,
        historial.dbt_valid_to
    FROM {{ ref('snp_compraventa_vivienda') }} AS historial
    INNER JOIN {{ ref('slv_provincia') }} AS provincias
        ON provincias.id_provincia = historial.id_provincia
    QUALIFY COUNT(*) OVER (
        PARTITION BY historial.id_provincia, historial.id_mes, historial.id_tipo_vivienda
    ) > 1

)

SELECT
    id_provincia,
    provincia,
    id_mes,
    id_tipo_vivienda,
    ROW_NUMBER() OVER (
        PARTITION BY id_provincia, id_mes, id_tipo_vivienda
        ORDER BY dbt_valid_from
    ) AS num_version,
    num_compraventas,
    dbt_valid_from,
    dbt_valid_to,
    IFF(dbt_valid_to IS NULL, 'vigente', 'cerrada') AS estado
FROM versiones
ORDER BY
    id_provincia,
    id_mes,
    id_tipo_vivienda,
    num_version