-- Cada dato de slv_compraventa_vivienda_mensual (provincia, mes y tipo) tiene
-- exactamente una versión vigente en snp_compraventa_vivienda, la que tiene
-- dbt_valid_to NULL. Cero versiones vigentes indicaría que el snapshot no se
-- ha ejecutado; dos o más, que la clave del snapshot no es única.
-- Devuelve las claves con un número de versiones vigentes distinto de 1.

WITH vigentes AS (

    SELECT
        id_provincia,
        id_mes,
        id_tipo_vivienda,
        COUNT(*) AS versiones_vigentes
    FROM {{ ref('snp_compraventa_vivienda') }}
    WHERE dbt_valid_to IS NULL
    GROUP BY
        id_provincia,
        id_mes,
        id_tipo_vivienda

)

SELECT
    silver.id_provincia,
    silver.id_mes,
    silver.id_tipo_vivienda,
    COALESCE(vigentes.versiones_vigentes, 0) AS versiones_vigentes
FROM {{ ref('slv_compraventa_vivienda_mensual') }} AS silver
LEFT JOIN vigentes
    ON vigentes.id_provincia = silver.id_provincia
    AND vigentes.id_mes = silver.id_mes
    AND vigentes.id_tipo_vivienda = silver.id_tipo_vivienda
WHERE COALESCE(vigentes.versiones_vigentes, 0) <> 1