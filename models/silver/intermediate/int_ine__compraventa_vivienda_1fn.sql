-- =============================================================================
-- int_ine__compraventa_vivienda_1fn
-- =============================================================================
-- Paso a 1FN de la tabla 6150 del INE: una fila por provincia, mes y tipo de
-- vivienda.
-- 1. Niveles mezclados: la jerarquía viene aplanada en 3 columnas. Solo se
--    quedan las filas de provincia (provincia_ine relleno) y, de ellas, las
--    50 provincias del seed (fuera Ceuta y Melilla). Los códigos de CCAA y de
--    provincia se repiten ('09 Cataluña' / '09 Burgos'), así que el cruce se
--    hace solo con la columna de provincias.
-- 2. Dos datos en un campo: la provincia se separa en código y nombre con
--    separar_codigo_nombre, la misma macro que en el IPC.
-- 3. Dos clasificaciones en una columna: 'Régimen y estado' mezcla el
--    régimen (libre / protegida) y el estado (nueva / usada). Cada etiqueta
--    recibe su código y su criterio. 'Viviendas: Total' se descarta porque se
--    puede calcular (libre + protegida); se usa solo en el test de coherencia.
-- 4. Periodo como texto: el mes pasa a id_mes (AAAAMM), de anio_inicio a
--    anio_fin.
-- Todavía hay dependencias parciales (nombre_tipo y criterio dependen solo
-- del tipo): las quita Silver (2FN) con slv_tipo_vivienda.
-- =============================================================================

WITH compraventas AS (

    SELECT
        {{ separar_codigo_nombre('provincia_ine', 'id_provincia', 'nombre_provincia_ine') }},
        YEAR(fecha_mes) * 100 + MONTH(fecha_mes) AS id_mes,
        YEAR(fecha_mes) AS anio,
        regimen_estado AS nombre_tipo,
        CASE regimen_estado
            WHEN 'Vivienda libre' THEN 'LIBRE'
            WHEN 'Vivienda protegida' THEN 'PROTEGIDA'
            WHEN 'Vivienda nueva' THEN 'NUEVA'
            WHEN 'Vivienda usada' THEN 'USADA'
        END AS id_tipo_vivienda,
        CASE regimen_estado
            WHEN 'Vivienda libre' THEN 'Régimen'
            WHEN 'Vivienda protegida' THEN 'Régimen'
            WHEN 'Vivienda nueva' THEN 'Estado'
            WHEN 'Vivienda usada' THEN 'Estado'
        END AS criterio,
        num_compraventas
    FROM {{ ref('stg_ine__compraventa_viviendas') }}
    WHERE provincia_ine IS NOT NULL
        AND regimen_estado <> 'Viviendas: Total'

),

provincias AS (

    SELECT
        id_provincia
    FROM {{ ref('seed_provincias') }}

),

compraventas_1fn AS (

    SELECT
        compraventas.id_provincia,
        compraventas.nombre_provincia_ine,
        compraventas.id_mes,
        compraventas.id_tipo_vivienda,
        compraventas.nombre_tipo,
        compraventas.criterio,
        compraventas.num_compraventas
    FROM compraventas
    INNER JOIN provincias
        ON provincias.id_provincia = compraventas.id_provincia
    WHERE compraventas.anio BETWEEN {{ var('anio_inicio') }} AND {{ var('anio_fin') }}

)

SELECT *
FROM compraventas_1fn