-- Completitud de slv_compraventa_vivienda_mensual: cada provincia y tipo de
-- vivienda tiene compraventas en todos los meses del periodo (50 × 96 × 4).
-- Devuelve las combinaciones de provincia y tipo a las que les falta algún mes.

WITH esperado AS (

    SELECT
        COUNT(*) AS num_meses
    FROM {{ ref('slv_mes') }}

),

real AS (

    SELECT
        id_provincia,
        id_tipo_vivienda,
        COUNT(num_compraventas) AS num_meses_con_dato
    FROM {{ ref('slv_compraventa_vivienda_mensual') }}
    GROUP BY
        id_provincia,
        id_tipo_vivienda

)

SELECT
    provincias.id_provincia,
    tipos.id_tipo_vivienda,
    COALESCE(real.num_meses_con_dato, 0) AS num_meses_con_dato,
    esperado.num_meses AS num_meses_esperados
FROM {{ ref('slv_provincia') }} AS provincias
CROSS JOIN {{ ref('slv_tipo_vivienda') }} AS tipos
CROSS JOIN esperado
LEFT JOIN real
    ON real.id_provincia = provincias.id_provincia
    AND real.id_tipo_vivienda = tipos.id_tipo_vivienda
WHERE COALESCE(real.num_meses_con_dato, 0) <> esperado.num_meses