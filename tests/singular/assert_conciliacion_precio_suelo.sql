-- Conciliación del precio del suelo con el total oficial: en cada trimestre,
-- la media de las 50 provincias ponderada por sus transacciones (solo las que
-- tienen precio) debe quedar a menos de un 3 % del TOTAL NACIONAL de la
-- tabla 4 del MIVAU. Es un aviso: el ministerio calcula el total con sus
-- propios pesos e incluye Ceuta y Melilla.
-- Devuelve los trimestres que se alejan más de un 3 % o sin total.

{{ config(severity='warn', store_failures=true) }}

WITH hoja AS (

    SELECT *
    FROM {{ ref('stg_mivau__precio_suelo') }}
    WHERE _fila >= 14
        AND UPPER(territorio) = 'TOTAL NACIONAL'

),

filas AS (

    {{ unpivot_trimestres('hoja', 'precio_m2') }}

),

oficial AS (

    SELECT
        anio * 10 + num_trimestre AS id_trimestre,
        precio_m2 AS precio_total_nacional
    FROM filas
    WHERE anio BETWEEN {{ var('anio_inicio') }} AND {{ var('anio_fin') }}

),

provincias AS (

    SELECT
        id_trimestre,
        SUM(precio_m2 * num_transacciones)
            / NULLIF(SUM(IFF(precio_m2 IS NULL, 0, num_transacciones)), 0) AS precio_medio_ponderado
    FROM {{ ref('slv_suelo_trimestral') }}
    GROUP BY id_trimestre

),

comparacion AS (

    SELECT
        provincias.id_trimestre,
        provincias.precio_medio_ponderado,
        oficial.precio_total_nacional,
        provincias.precio_medio_ponderado / NULLIF(oficial.precio_total_nacional, 0) - 1 AS diferencia_relativa
    FROM provincias
    LEFT JOIN oficial
        ON oficial.id_trimestre = provincias.id_trimestre

)

SELECT *
FROM comparacion
WHERE precio_total_nacional IS NULL
    OR ABS(diferencia_relativa) > 0.03