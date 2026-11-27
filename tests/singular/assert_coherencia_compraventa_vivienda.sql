-- Coherencia de las compraventas de vivienda: en cada provincia y mes,
-- libre + protegida = nueva + usada = 'Viviendas: Total' del INE.
-- Los 4 tipos se leen de Silver y el total de staging, porque Silver no lo
-- guarda. Así se comprueba de punta a punta que las etiquetas del INE se han
-- traducido bien a los códigos de slv_tipo_vivienda.
-- Devuelve las provincias y meses que no cuadran o en los que falta el total.

{{ config(store_failures=true) }}

WITH total_ine AS (

    SELECT
        {{ separar_codigo_nombre('provincia_ine', 'id_provincia', 'nombre_provincia_ine') }},
        YEAR(fecha_mes) * 100 + MONTH(fecha_mes) AS id_mes,
        num_compraventas AS total_ine
    FROM {{ ref('stg_ine__compraventa_viviendas') }}
    WHERE provincia_ine IS NOT NULL
        AND regimen_estado = 'Viviendas: Total'
        AND YEAR(fecha_mes) BETWEEN {{ var('anio_inicio') }} AND {{ var('anio_fin') }}

),

tipos_silver AS (

    SELECT
        id_provincia,
        id_mes,
        SUM(IFF(id_tipo_vivienda = 'LIBRE', num_compraventas, 0)) AS num_libre,
        SUM(IFF(id_tipo_vivienda = 'PROTEGIDA', num_compraventas, 0)) AS num_protegida,
        SUM(IFF(id_tipo_vivienda = 'NUEVA', num_compraventas, 0)) AS num_nueva,
        SUM(IFF(id_tipo_vivienda = 'USADA', num_compraventas, 0)) AS num_usada
    FROM {{ ref('slv_compraventa_vivienda_mensual') }}
    GROUP BY
        id_provincia,
        id_mes

)

SELECT
    tipos_silver.id_provincia,
    tipos_silver.id_mes,
    tipos_silver.num_libre,
    tipos_silver.num_protegida,
    tipos_silver.num_nueva,
    tipos_silver.num_usada,
    total_ine.total_ine
FROM tipos_silver
LEFT JOIN total_ine
    ON total_ine.id_provincia = tipos_silver.id_provincia
    AND total_ine.id_mes = tipos_silver.id_mes
WHERE total_ine.total_ine IS NULL
    OR tipos_silver.num_libre + tipos_silver.num_protegida <> total_ine.total_ine
    OR tipos_silver.num_nueva + tipos_silver.num_usada <> total_ine.total_ine