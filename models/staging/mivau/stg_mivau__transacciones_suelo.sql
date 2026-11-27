-- =============================================================================
-- stg_mivau__transacciones_suelo
-- =============================================================================
-- Staging de la tabla 1 del MIVAU: número de transacciones de suelo urbano.
-- Relación 1:1 con Bronze: una fila por cada fila de la hoja, sin filtrar.
-- - territorio: COL_B sin espacios al principio ni al final.
-- - col_c ... col_cn: los 90 trimestres (1T 2004 a 2T 2026) convertidos a
--   número con FN_TEXTO_A_NUMERO. La columna del 4T 2023 no tiene etiqueta
--   en la cabecera, pero sí datos: por eso el periodo se asigna por posición.
-- - No se traen COL_A (siempre vacía) ni COL_CO y COL_CP (variaciones).
-- =============================================================================

{% set bronze_db = env_var('DBT_BRONZE_DB') %}

WITH source AS (

    SELECT *
    FROM {{ source('mivau', 'transacciones_suelo') }}

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