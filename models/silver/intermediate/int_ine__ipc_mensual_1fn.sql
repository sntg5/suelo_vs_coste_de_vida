-- =============================================================================
-- int_ine__ipc_mensual_1fn
-- =============================================================================
-- Paso a 1FN de la tabla 50918 del INE: una fila por provincia, mes y grupo.
-- 1. Una columna con 4 significados: solo se queda el tipo de dato 'Índice';
--    las variaciones publicadas se pueden calcular a partir del índice.
-- 2. Dos datos en un campo: provincia y grupo se separan en código y nombre
--    con separar_codigo_nombre. 'Índice general' no trae código: es el '00'.
-- 3. Periodo como texto: el mes pasa a id_mes (AAAAMM).
-- 4. Niveles mezclados: solo quedan las 50 provincias del seed (fuera
--    Nacional, Ceuta y Melilla) y los meses de anio_inicio a anio_fin.
-- Todavía hay dependencias parciales (nombre_provincia_ine depende solo de
-- la provincia y nombre_grupo solo del grupo): las quita Silver (2FN).
-- =============================================================================

WITH ipc AS (

    SELECT
        {{ separar_codigo_nombre('provincia_ine', 'id_provincia', 'nombre_provincia_ine') }},
        {{ separar_codigo_nombre('grupo_ecoicop', 'id_grupo', 'nombre_grupo') }},
        YEAR(fecha_mes) * 100 + MONTH(fecha_mes) AS id_mes,
        YEAR(fecha_mes) AS anio,
        valor AS indice
    FROM {{ ref('stg_ine__ipc_provincial') }}
    WHERE tipo_dato = 'Índice'

),

provincias AS (

    SELECT
        id_provincia
    FROM {{ ref('seed_provincias') }}

),

ipc_1fn AS (

    SELECT
        ipc.id_provincia,
        ipc.nombre_provincia_ine,
        ipc.id_mes,
        COALESCE(ipc.id_grupo, '00') AS id_grupo,
        ipc.nombre_grupo,
        ipc.indice
    FROM ipc
    INNER JOIN provincias
        ON provincias.id_provincia = ipc.id_provincia
    WHERE ipc.anio BETWEEN {{ var('anio_inicio') }} AND {{ var('anio_fin') }}

)

SELECT *
FROM ipc_1fn