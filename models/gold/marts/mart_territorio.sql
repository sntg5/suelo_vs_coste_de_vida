-- =============================================================================
-- mart_territorio
-- =============================================================================
-- Data Mart del caso 3: mapa del mercado. ¿Dónde es más caro el suelo y dónde
-- se mueve más la vivienda?
-- Una fila por territorio y año en 4 niveles (provincia, CCAA, zona y
-- España = suma de las 50 provincias): 70 territorios × 8 años = 560 filas.
-- Cruza dos hechos a través de las dimensiones conformadas (drill-across):
-- primero se agrega cada hecho por su cuenta a provincia × año (suelo desde
-- sus trimestres y vivienda desde sus meses) y después se unen por provincia
-- y año. Nunca se unen los hechos fila a fila.
-- Los niveles se calculan con GROUPING SETS, como en el caso 1. Cada ratio
-- lleva al lado su numerador y su denominador.
-- - precio_medio: media ponderada por las transacciones con precio.
-- - ranking_precio: posición por precio medio dentro de cada nivel y año
--   (1 = el más caro).
-- - cuota_nueva y cuota_protegida: parte del total de compraventas de vivienda.
-- - viviendas_por_compraventa_suelo: compraventas de vivienda por cada
--   compraventa de suelo.
-- - variacion_compraventas_vs_2018: crecimiento de la compraventa de vivienda
--   frente al año base.
-- =============================================================================

WITH suelo_anual AS (

    SELECT
        suelo.sk_lugar,
        tiempo.anio,
        SUM(suelo.num_transacciones) AS num_transacciones_suelo,
        SUM(suelo.transacciones_con_precio) AS transacciones_con_precio,
        SUM(suelo.precio_x_transacciones) AS precio_x_transacciones
    FROM {{ ref('fct_suelo_trimestral') }} AS suelo
    INNER JOIN {{ ref('dim_tiempo') }} AS tiempo
        ON tiempo.id_mes = suelo.id_mes
    GROUP BY
        suelo.sk_lugar,
        tiempo.anio

),

vivienda_anual AS (

    SELECT
        vivienda.sk_lugar,
        tiempo.anio,
        SUM(vivienda.num_total) AS num_compraventas_vivienda,
        SUM(vivienda.num_nueva) AS num_nueva,
        SUM(vivienda.num_protegida) AS num_protegida
    FROM {{ ref('fct_compraventa_vivienda_mensual') }} AS vivienda
    INNER JOIN {{ ref('dim_tiempo') }} AS tiempo
        ON tiempo.id_mes = vivienda.id_mes
    GROUP BY
        vivienda.sk_lugar,
        tiempo.anio

),

anios AS (

    SELECT DISTINCT
        anio
    FROM {{ ref('dim_tiempo') }}

),

provincia_anio AS (

    SELECT
        lugar.id_provincia,
        lugar.provincia,
        lugar.id_ccaa,
        lugar.ccaa,
        lugar.id_zona,
        lugar.zona,
        anios.anio,
        suelo_anual.num_transacciones_suelo,
        suelo_anual.transacciones_con_precio,
        suelo_anual.precio_x_transacciones,
        vivienda_anual.num_compraventas_vivienda,
        vivienda_anual.num_nueva,
        vivienda_anual.num_protegida
    FROM {{ ref('dim_lugar') }} AS lugar
    CROSS JOIN anios
    LEFT JOIN suelo_anual
        ON suelo_anual.sk_lugar = lugar.sk_lugar
        AND suelo_anual.anio = anios.anio
    LEFT JOIN vivienda_anual
        ON vivienda_anual.sk_lugar = lugar.sk_lugar
        AND vivienda_anual.anio = anios.anio

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
        SUM(precio_x_transacciones) AS precio_x_transacciones,
        SUM(transacciones_con_precio) AS transacciones_con_precio,
        {{ media_ponderada('precio_x_transacciones', 'transacciones_con_precio') }} AS precio_medio,
        SUM(num_transacciones_suelo) AS num_transacciones_suelo,
        SUM(num_compraventas_vivienda) AS num_compraventas_vivienda,
        SUM(num_nueva) AS num_nueva,
        SUM(num_protegida) AS num_protegida
    FROM provincia_anio
    GROUP BY GROUPING SETS (
        (anio, id_provincia, provincia, id_ccaa, ccaa, id_zona, zona),
        (anio, id_ccaa, ccaa, id_zona, zona),
        (anio, id_zona, zona),
        (anio)
    )

),

con_referencias AS (

    SELECT
        *,
        MAX(IFF(anio = {{ var('anio_base') }}, num_compraventas_vivienda, NULL)) OVER (
            PARTITION BY nivel, id_territorio
        ) AS num_compraventas_vivienda_base
    FROM por_territorio

)

SELECT
    nivel,
    id_territorio,
    territorio,
    id_ccaa,
    zona,
    anio,
    precio_x_transacciones,
    transacciones_con_precio,
    precio_medio,
    RANK() OVER (
        PARTITION BY nivel, anio
        ORDER BY precio_medio DESC
    ) AS ranking_precio,
    num_transacciones_suelo,
    num_compraventas_vivienda,
    num_nueva,
    num_protegida,
    {{ ratio('num_nueva', 'num_compraventas_vivienda') }} AS cuota_nueva,
    {{ ratio('num_protegida', 'num_compraventas_vivienda') }} AS cuota_protegida,
    {{ ratio('num_compraventas_vivienda', 'num_transacciones_suelo') }} AS viviendas_por_compraventa_suelo,
    {{ variacion_pct('num_compraventas_vivienda', 'num_compraventas_vivienda_base') }} AS variacion_compraventas_vs_2018
FROM con_referencias