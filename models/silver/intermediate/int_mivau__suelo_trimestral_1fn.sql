-- =============================================================================
-- int_mivau__suelo_trimestral_1fn
-- =============================================================================
-- Paso a 1FN de las tablas 1 y 4 del MIVAU: una fila por provincia y trimestre.
-- 1. Filas que no son datos: los títulos y la cabecera (filas 1 a 13 de
--    Excel) y las filas sin territorio se descartan al leer staging.
-- 2. Niveles mezclados en COL_B: solo quedan las 50 provincias del seed,
--    cruzando por nombre_mivau. El total nacional, las CCAA pluriprovinciales
--    y Ceuta y Melilla se quedan en staging para los tests de conciliación.
-- 3. Grupo repetitivo: las 90 columnas de trimestres pasan a filas con
--    unpivot_trimestres, que asigna el periodo por la posición de la columna.
-- 4. Periodo de análisis: de anio_inicio a anio_fin.
-- Cada tabla de staging se lee una sola vez (CTE _hoja) y el unpivot trabaja
-- sobre ese CTE: así la consulta se compila en segundos.
-- Precio y transacciones van juntos porque dependen de la misma clave
-- completa (provincia y trimestre), aunque vengan de dos ficheros.
-- =============================================================================

WITH provincias AS (

    SELECT
        id_provincia,
        nombre_mivau
    FROM {{ ref('seed_provincias') }}

),

precio_hoja AS (

    SELECT *
    FROM {{ ref('stg_mivau__precio_suelo') }}
    WHERE _fila >= 14
        AND territorio IN (SELECT nombre_mivau FROM provincias)

),

transacciones_hoja AS (

    SELECT *
    FROM {{ ref('stg_mivau__transacciones_suelo') }}
    WHERE _fila >= 14
        AND territorio IN (SELECT nombre_mivau FROM provincias)

),

precio AS (

    {{ unpivot_trimestres('precio_hoja', 'precio_m2') }}

),

transacciones AS (

    {{ unpivot_trimestres('transacciones_hoja', 'num_transacciones') }}

),

suelo AS (

    SELECT
        provincias.id_provincia,
        precio.anio * 10 + precio.num_trimestre AS id_trimestre,
        precio.anio,
        precio.num_trimestre,
        precio.precio_m2,
        transacciones.num_transacciones
    FROM provincias
    INNER JOIN precio
        ON precio.territorio = provincias.nombre_mivau
    INNER JOIN transacciones
        ON transacciones.territorio = provincias.nombre_mivau
        AND transacciones.anio = precio.anio
        AND transacciones.num_trimestre = precio.num_trimestre
    WHERE precio.anio BETWEEN {{ var('anio_inicio') }} AND {{ var('anio_fin') }}

)

SELECT *
FROM suelo