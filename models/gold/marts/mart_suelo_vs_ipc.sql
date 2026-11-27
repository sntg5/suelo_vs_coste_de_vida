-- =============================================================================
-- mart_suelo_vs_ipc
-- =============================================================================
-- Data Mart del caso 1: ¿el suelo sube más que el coste de vida?
-- Una fila por territorio y año en 4 niveles (provincia, CCAA, zona y
-- España = suma de las 50 provincias): 70 territorios × 8 años = 560 filas.
-- Los niveles se calculan con GROUPING SETS, así que los KPIs de cada nivel
-- salen de dbt y Power BI solo los muestra.
-- - precio_medio y precio_hipotetico: medias ponderadas con los mismos pesos
--   (transacciones con precio), para que la comparación sea homogénea.
-- - variacion_ipc_vs_2018: subida del precio hipotético. Por encima de la
--   provincia es el coste de vida ponderado por compraventas de suelo, no el
--   IPC oficial de la CCAA.
-- - es_buena_compra: el suelo cuesta menos que si hubiera subido como el IPC.
-- - es_buena_venta: la diferencia con el IPC mejora respecto al año anterior.
-- - Los dos KPIs son NULL en el año base, donde real e hipotético coinciden.
-- =============================================================================

WITH base AS (

    SELECT
        lugar.id_provincia,
        lugar.provincia,
        lugar.id_ccaa,
        lugar.ccaa,
        lugar.id_zona,
        lugar.zona,
        tiempo.anio,
        tiempo.id_etapa,
        suelo.transacciones_con_precio,
        suelo.precio_x_transacciones,
        suelo.hipotetico_x_transacciones,
        suelo.es_fiable
    FROM {{ ref('fct_suelo_trimestral') }} AS suelo
    INNER JOIN {{ ref('dim_lugar') }} AS lugar
        ON lugar.sk_lugar = suelo.sk_lugar
    INNER JOIN {{ ref('dim_tiempo') }} AS tiempo
        ON tiempo.id_mes = suelo.id_mes

),

por_territorio AS (

    SELECT
        CASE
            WHEN GROUPING(id_provincia) = 0 THEN 'Provincia'
            WHEN GROUPING(id_ccaa) = 0 THEN 'CCAA'
            WHEN GROUPING(id_zona) = 0 THEN 'Zona'
            ELSE 'España'
        END AS nivel,
        COALESCE(id_provincia, id_ccaa, id_zona, 'ES') AS id_territorio,
        COALESCE(provincia, ccaa, zona, 'España') AS territorio,
        id_ccaa,
        zona,
        anio,
        id_etapa,
        SUM(transacciones_con_precio) AS transacciones_con_precio,
        SUM(precio_x_transacciones) AS precio_x_transacciones,
        SUM(hipotetico_x_transacciones) AS hipotetico_x_transacciones,
        {{ media_ponderada('precio_x_transacciones', 'transacciones_con_precio') }} AS precio_medio,
        {{ media_ponderada('hipotetico_x_transacciones', 'transacciones_con_precio') }} AS precio_hipotetico,
        COUNT_IF(NOT es_fiable) AS trimestres_poco_fiables
    FROM base
    GROUP BY GROUPING SETS (
        (anio, id_etapa, id_provincia, provincia, id_ccaa, ccaa, id_zona, zona),
        (anio, id_etapa, id_ccaa, ccaa, id_zona, zona),
        (anio, id_etapa, id_zona, zona),
        (anio, id_etapa)
    )

),

con_referencias AS (

    SELECT
        *,
        precio_medio - precio_hipotetico AS diferencia,
        MAX(IFF(anio = {{ var('anio_base') }}, precio_medio, NULL)) OVER (
            PARTITION BY nivel, id_territorio
        ) AS precio_medio_base,
        MAX(IFF(anio = {{ var('anio_base') }}, precio_hipotetico, NULL)) OVER (
            PARTITION BY nivel, id_territorio
        ) AS precio_hipotetico_base,
        LAG(precio_medio) OVER (
            PARTITION BY nivel, id_territorio
            ORDER BY anio
        ) AS precio_medio_anio_anterior,
        LAG(precio_medio - precio_hipotetico) OVER (
            PARTITION BY nivel, id_territorio
            ORDER BY anio
        ) AS diferencia_anio_anterior
    FROM por_territorio

),

variaciones AS (

    SELECT
        *,
        {{ variacion_pct('precio_medio', 'precio_medio_base') }} AS variacion_precio_vs_2018,
        {{ variacion_pct('precio_hipotetico', 'precio_hipotetico_base') }} AS variacion_ipc_vs_2018,
        {{ variacion_pct('precio_medio', 'precio_medio_anio_anterior') }} AS variacion_interanual_precio
    FROM con_referencias

)

SELECT
    nivel,
    id_territorio,
    territorio,
    id_ccaa,
    zona,
    anio,
    id_etapa,
    transacciones_con_precio,
    precio_x_transacciones,
    hipotetico_x_transacciones,
    precio_medio,
    precio_hipotetico,
    diferencia,
    variacion_precio_vs_2018,
    variacion_ipc_vs_2018,
    {{ variacion_real('variacion_precio_vs_2018', 'variacion_ipc_vs_2018') }} AS variacion_real_vs_2018,
    variacion_interanual_precio,
    IFF(anio = {{ var('anio_base') }}, NULL, precio_medio < precio_hipotetico) AS es_buena_compra,
    IFF(anio = {{ var('anio_base') }}, NULL, diferencia > diferencia_anio_anterior) AS es_buena_venta,
    trimestres_poco_fiables
FROM variaciones