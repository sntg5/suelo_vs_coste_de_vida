-- =============================================================================
-- stg_ine__ipc_provincial
-- =============================================================================
-- Staging de la tabla 50918 del INE: IPC provincial por grupos ECOICOP.
-- Relación 1:1 con Bronze: no filtra filas (siguen Nacional, los 4 tipos de
-- dato y los meses de 2002 a 2025).
-- - Los textos se recortan; código y nombre siguen juntos en el mismo campo
--   ('01 Araba/Álava'): los separa el modelo int_ con separar_codigo_nombre.
-- - fecha_mes: el periodo '2025M12' como fecha (2025-12-01), con
--   FN_PERIODO_INE_A_FECHA.
-- - valor: el número con coma decimal ('119,942') convertido con
--   FN_TEXTO_A_NUMERO. El tipo final lo fija el cast de Silver.
-- =============================================================================

{% set bronze_db = env_var('DBT_BRONZE_DB') %}

WITH source AS (

    SELECT *
    FROM {{ source('ine', 'ipc_provincial') }}

),

renamed AS (

    SELECT
        CAST(_fila AS NUMBER(9, 0)) AS _fila,
        TRIM(provincias) AS provincia_ine,
        TRIM(grupos_ecoicop) AS grupo_ecoicop,
        TRIM(tipo_de_dato) AS tipo_dato,
        TRIM(periodo) AS periodo,
        {{ bronze_db }}.UTILS.FN_PERIODO_INE_A_FECHA(TRIM(periodo)) AS fecha_mes,
        {{ bronze_db }}.UTILS.FN_TEXTO_A_NUMERO(total) AS valor,
        _fichero,
        _loaded_at
    FROM source

)

SELECT *
FROM renamed