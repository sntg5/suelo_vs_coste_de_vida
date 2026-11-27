-- =============================================================================
-- stg_mivau__precio_suelo
-- =============================================================================
-- Staging de la tabla 4 del MIVAU: precio medio del m² de suelo urbano (€/m²).
-- Relación 1:1 con Bronze: una fila por cada fila de la hoja, sin filtrar.
-- - territorio: COL_B sin espacios al principio ni al final.
-- - col_c ... col_cn: los 90 trimestres (1T 2004 a 2T 2026) convertidos a
--   número con FN_TEXTO_A_NUMERO ('n.s.', 'n.s' y '.' pasan a NULL). En las
--   filas de títulos y cabeceras salen NULL; las descarta el modelo int_.
-- - No se traen COL_A (siempre vacía) ni COL_CO y COL_CP (variaciones
--   publicadas, que se pueden calcular).
-- =============================================================================

{% set bronze_db = env_var('DBT_BRONZE_DB') %}

WITH source AS (

    SELECT *
    FROM {{ source('mivau', 'precio_suelo') }}

),

renamed AS (

    SELECT
        CAST(_fila AS NUMBER(6, 0)) AS _fila,
        NULLIF(TRIM(col_b), '') AS territorio,
        {%- for columna in columnas_trimestres_mivau() %}
        {{ bronze_db }}.UTILS.FN_TEXTO_A_NUMERO({{ columna }}) AS {{ columna }},
        {%- endfor %}
        _fichero,
        _loaded_at
    FROM source

)

SELECT *
FROM renamed