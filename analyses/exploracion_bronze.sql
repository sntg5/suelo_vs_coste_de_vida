-- =============================================================================
-- exploracion_bronze
-- =============================================================================
-- Análisis: valores reales de las columnas de texto de Bronze que deciden los
-- filtros, los CASE y los tests accepted_values de staging y Silver. Los
-- valores de los tests salen de los datos, no de la intuición.
-- - longitud ayuda a ver espacios sobrantes: los nombres del MIVAU llevan
--   espacios al final ('Almería           ').
-- - Los valores NULL son las celdas vacías (por ejemplo, la CCAA en las filas
--   nacionales de la tabla 6150 o las filas vacías de la hoja del MIVAU).
-- Un análisis se compila pero no se ejecuta en los jobs: se abre en Studio y
-- se ejecuta con Preview.
-- =============================================================================

WITH valores AS (

    SELECT
        'ine.ipc_provincial.tipo_de_dato' AS columna,
        tipo_de_dato AS valor
    FROM {{ source('ine', 'ipc_provincial') }}

    UNION ALL

    SELECT
        'ine.ipc_provincial.grupos_ecoicop' AS columna,
        grupos_ecoicop AS valor
    FROM {{ source('ine', 'ipc_provincial') }}

    UNION ALL

    SELECT
        'ine.compraventa_viviendas.regimen_y_estado' AS columna,
        regimen_y_estado AS valor
    FROM {{ source('ine', 'compraventa_viviendas') }}

    UNION ALL

    SELECT
        'ine.compraventa_viviendas.comunidades_y_ciudades_autonomas' AS columna,
        comunidades_y_ciudades_autonomas AS valor
    FROM {{ source('ine', 'compraventa_viviendas') }}

    UNION ALL

    SELECT
        'mivau.precio_suelo.col_b' AS columna,
        col_b AS valor
    FROM {{ source('mivau', 'precio_suelo') }}

    UNION ALL

    SELECT
        'mivau.transacciones_suelo.col_b' AS columna,
        col_b AS valor
    FROM {{ source('mivau', 'transacciones_suelo') }}

)

SELECT
    columna,
    valor,
    LENGTH(valor) AS longitud,
    COUNT(*) AS filas
FROM valores
GROUP BY
    columna,
    valor
ORDER BY
    columna,
    valor