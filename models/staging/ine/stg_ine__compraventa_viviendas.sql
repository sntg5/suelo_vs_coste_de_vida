-- =============================================================================
-- stg_ine__compraventa_viviendas
-- =============================================================================
-- Staging de la tabla 6150 del INE: compraventa de viviendas según régimen y
-- estado, mensual. Relación 1:1 con Bronze: siguen las filas de nación, CCAA
-- y provincia y los meses de 2007 a 2026.
-- - ccaa_ine y provincia_ine: código y nombre juntos ('09 Cataluña',
--   '09 Burgos'); vacíos (NULL) en los niveles superiores. El nivel de cada
--   fila se deduce de qué columnas vienen vacías.
-- - total_nacional no se trae: tiene siempre el mismo valor.
-- - fecha_mes: el periodo '2025M12' como fecha, con FN_PERIODO_INE_A_FECHA.
-- - num_compraventas: el número con punto de miles ('54.548') convertido
--   con FN_TEXTO_A_NUMERO.
-- =============================================================================

{% set bronze_db = env_var('DBT_BRONZE_DB') %}

WITH source AS (

    SELECT *
    FROM {{ source('ine', 'compraventa_viviendas') }}

),

renamed AS (

    SELECT
        CAST(_fila AS NUMBER(9, 0)) AS _fila,
        NULLIF(TRIM(comunidades_y_ciudades_autonomas), '') AS ccaa_ine,
        NULLIF(TRIM(provincias), '') AS provincia_ine,
        TRIM(regimen_y_estado) AS regimen_estado,
        TRIM(periodo) AS periodo,
        {{ bronze_db }}.UTILS.FN_PERIODO_INE_A_FECHA(TRIM(periodo)) AS fecha_mes,
        {{ bronze_db }}.UTILS.FN_TEXTO_A_NUMERO(total) AS num_compraventas,
        _fichero,
        _loaded_at
    FROM source

)

SELECT *
FROM renamed