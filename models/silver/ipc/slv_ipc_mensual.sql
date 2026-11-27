-- =============================================================================
-- slv_ipc_mensual
-- =============================================================================
-- Una fila por provincia, mes y grupo de gasto: índice del IPC (INE tabla
-- 50918, base 2021 = 100).
-- Las filas salen de provincias × meses × grupos, no de los datos: si al INE
-- le faltara un dato, la fila existiría con indice NULL y los tests lo
-- detectarían. 2FN: aquí solo quedan claves y la medida; los nombres de
-- provincia y de grupo están en sus tablas.
-- =============================================================================

WITH provincias AS (

    SELECT
        id_provincia
    FROM {{ ref('slv_provincia') }}

),

meses AS (

    SELECT
        id_mes
    FROM {{ ref('slv_mes') }}

),

grupos AS (

    SELECT
        id_grupo
    FROM {{ ref('slv_grupo_ipc') }}

),

ipc AS (

    SELECT
        id_provincia,
        id_mes,
        id_grupo,
        indice
    FROM {{ ref('int_ine__ipc_mensual_1fn') }}

)

SELECT
    CAST(provincias.id_provincia AS VARCHAR(2)) AS id_provincia,
    CAST(meses.id_mes AS NUMBER(6, 0)) AS id_mes,
    CAST(grupos.id_grupo AS VARCHAR(2)) AS id_grupo,
    CAST(ipc.indice AS NUMBER(7, 3)) AS indice
FROM provincias
CROSS JOIN meses
CROSS JOIN grupos
LEFT JOIN ipc
    ON ipc.id_provincia = provincias.id_provincia
    AND ipc.id_mes = meses.id_mes
    AND ipc.id_grupo = grupos.id_grupo