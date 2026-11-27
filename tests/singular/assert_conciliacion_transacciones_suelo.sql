-- Conciliación de las transacciones de suelo con el total oficial: en cada
-- trimestre, la suma de las 50 provincias más Ceuta y Melilla debe ser igual
-- al TOTAL NACIONAL de la tabla 1 del MIVAU. Las filas de nación y de Ceuta y
-- Melilla no están en Silver, así que se leen de staging con el mismo unpivot.
-- Devuelve los trimestres que no cuadran o en los que falta el total.

{{ config(store_failures=true) }}

WITH hoja AS (

    SELECT *
    FROM {{ ref('stg_mivau__transacciones_suelo') }}
    WHERE _fila >= 14
        AND UPPER(territorio) IN ('TOTAL NACIONAL', 'CEUTA Y MELILLA')

),

filas AS (

    {{ unpivot_trimestres('hoja', 'num_transacciones') }}

),

oficial AS (

    SELECT
        anio * 10 + num_trimestre AS id_trimestre,
        SUM(IFF(UPPER(territorio) = 'TOTAL NACIONAL', num_transacciones, 0)) AS total_nacional,
        SUM(IFF(UPPER(territorio) = 'CEUTA Y MELILLA', COALESCE(num_transacciones, 0), 0)) AS ceuta_y_melilla,
        COUNT_IF(UPPER(territorio) = 'TOTAL NACIONAL') AS filas_total
    FROM filas
    WHERE anio BETWEEN {{ var('anio_inicio') }} AND {{ var('anio_fin') }}
    GROUP BY anio * 10 + num_trimestre

),

provincias AS (

    SELECT
        id_trimestre,
        SUM(num_transacciones) AS suma_provincias
    FROM {{ ref('slv_suelo_trimestral') }}
    GROUP BY id_trimestre

)

SELECT
    provincias.id_trimestre,
    provincias.suma_provincias,
    oficial.ceuta_y_melilla,
    oficial.total_nacional
FROM provincias
LEFT JOIN oficial
    ON oficial.id_trimestre = provincias.id_trimestre
WHERE COALESCE(oficial.filas_total, 0) <> 1
    OR provincias.suma_provincias + oficial.ceuta_y_melilla <> oficial.total_nacional