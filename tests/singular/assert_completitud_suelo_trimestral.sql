-- Completitud de slv_suelo_trimestral: cada una de las 50 provincias tiene
-- transacciones en todos los trimestres del periodo (50 × 32).
-- Devuelve las provincias a las que les falta algún trimestre.

WITH esperado AS (

    SELECT
        COUNT(*) AS num_trimestres
    FROM {{ ref('slv_trimestre') }}

),

real AS (

    SELECT
        id_provincia,
        COUNT(num_transacciones) AS num_trimestres_con_dato
    FROM {{ ref('slv_suelo_trimestral') }}
    GROUP BY id_provincia

)

SELECT
    provincias.id_provincia,
    COALESCE(real.num_trimestres_con_dato, 0) AS num_trimestres_con_dato,
    esperado.num_trimestres AS num_trimestres_esperados
FROM {{ ref('slv_provincia') }} AS provincias
CROSS JOIN esperado
LEFT JOIN real
    ON real.id_provincia = provincias.id_provincia
WHERE COALESCE(real.num_trimestres_con_dato, 0) <> esperado.num_trimestres