-- =============================================================================
-- slv_grupo_ipc
-- =============================================================================
-- Una fila por grupo de gasto del IPC: el Índice general ('00', la cesta
-- completa) y los 12 grupos ECOICOP. Sale de los datos del INE.
-- 2FN: en la tabla 1FN del IPC el nombre del grupo dependía solo del grupo
-- (dependencia parcial); aquí queda un nombre por código.
-- El Índice general se guarda aunque sea un total: no se puede recalcular
-- porque el INE no publica las ponderaciones de los grupos.
-- =============================================================================

WITH grupos AS (

    SELECT DISTINCT
        id_grupo,
        nombre_grupo
    FROM {{ ref('int_ine__ipc_mensual_1fn') }}

)

SELECT
    CAST(id_grupo AS VARCHAR(2)) AS id_grupo,
    CAST(nombre_grupo AS VARCHAR(100)) AS nombre_grupo,
    CAST(id_grupo = '00' AS BOOLEAN) AS es_indice_general
FROM grupos