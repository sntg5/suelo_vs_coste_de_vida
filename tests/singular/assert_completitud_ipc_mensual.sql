-- Completitud de slv_ipc_mensual: cada provincia y grupo de gasto tiene
-- índice en todos los meses del periodo (50 × 13 × 96).
-- Devuelve las combinaciones de provincia y grupo a las que les falta algún mes.

WITH esperado AS (

    SELECT
        COUNT(*) AS num_meses
    FROM {{ ref('slv_mes') }}

),

real AS (

    SELECT
        id_provincia,
        id_grupo,
        COUNT(indice) AS num_meses_con_dato
    FROM {{ ref('slv_ipc_mensual') }}
    GROUP BY
        id_provincia,
        id_grupo

)

SELECT
    provincias.id_provincia,
    grupos.id_grupo,
    COALESCE(real.num_meses_con_dato, 0) AS num_meses_con_dato,
    esperado.num_meses AS num_meses_esperados
FROM {{ ref('slv_provincia') }} AS provincias
CROSS JOIN {{ ref('slv_grupo_ipc') }} AS grupos
CROSS JOIN esperado
LEFT JOIN real
    ON real.id_provincia = provincias.id_provincia
    AND real.id_grupo = grupos.id_grupo
WHERE COALESCE(real.num_meses_con_dato, 0) <> esperado.num_meses