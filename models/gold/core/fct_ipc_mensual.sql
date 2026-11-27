-- =============================================================================
-- fct_ipc_mensual
-- =============================================================================
-- Hecho de foto periódica: una fila por provincia, mes y grupo de gasto
-- (50 × 96 × 13 = 62.400 filas). Alimenta el caso 4 (mapa del coste de vida).
-- Se une a dim_lugar por sk_lugar, a dim_tiempo por id_mes y a dim_grupo_ipc
-- por sk_grupo_ipc. Las dos claves subrogadas se calculan con la misma
-- función y la misma columna que en su dimensión: el hash es determinista,
-- así que no hace falta unir con las dimensiones para obtenerlas.
-- Medida:
-- - indice: índice de precios de consumo, base 2021 = 100. No aditiva: los
--   índices no se suman ni se promedian entre provincias (no hay
--   ponderaciones del INE); se comparan sus variaciones.
-- =============================================================================

WITH ipc AS (

    SELECT
        id_provincia,
        id_mes,
        id_grupo,
        indice
    FROM {{ ref('slv_ipc_mensual') }}

)

SELECT
    CAST({{ dbt_utils.generate_surrogate_key(['id_provincia']) }} AS VARCHAR(32)) AS sk_lugar,
    CAST(id_mes AS NUMBER(6, 0)) AS id_mes,
    CAST({{ dbt_utils.generate_surrogate_key(['id_grupo']) }} AS VARCHAR(32)) AS sk_grupo_ipc,
    CAST(indice AS NUMBER(7, 3)) AS indice
FROM ipc