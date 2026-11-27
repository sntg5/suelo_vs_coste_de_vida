-- =============================================================================
-- mart_pandemia
-- =============================================================================
-- Data Mart del caso 2: la pandemia, caída y rebote del suelo y la vivienda.
-- Una fila por territorio y mes en 2 niveles (provincia y España = suma de
-- las 50 provincias): 51 territorios × 96 meses = 4.896 filas.
-- Cruza dos hechos a través de las dimensiones conformadas (drill-across):
-- la base es provincia × mes (dim_lugar × dim_tiempo) y cada hecho se une
-- por su clave, sin unir nunca los hechos entre sí.
-- - Suelo: solo tiene valor en el primer mes de cada trimestre (enero, abril,
--   julio y octubre), igual que en fct_suelo_trimestral. El resto de meses
--   queda NULL: no se reparten trimestres en meses.
-- - Vivienda: un valor por mes.
-- - Variaciones interanuales: frente al mismo mes del año anterior (12 filas
--   antes en cada territorio). En el suelo equivale al mismo trimestre del año
--   anterior. NULL en el primer año del periodo.
-- Los niveles se calculan con GROUPING SETS, como en el caso 1.
-- =============================================================================

WITH base AS (

    SELECT
        lugar.sk_lugar,
        lugar.id_provincia,
        lugar.provincia,
        lugar.id_ccaa,
        tiempo.id_mes,
        tiempo.fecha_inicio_mes,
        tiempo.id_trimestre,
        tiempo.etiqueta_trimestre,
        tiempo.anio,
        tiempo.id_etapa,
        tiempo.etapa,
        tiempo.orden_etapa
    FROM {{ ref('dim_lugar') }} AS lugar
    CROSS JOIN {{ ref('dim_tiempo') }} AS tiempo

),

provincia_mes AS (

    SELECT
        base.*,
        suelo.num_transacciones AS num_transacciones_suelo,
        suelo.transacciones_con_precio,
        suelo.precio_x_transacciones,
        vivienda.num_total AS num_compraventas_vivienda
    FROM base
    LEFT JOIN {{ ref('fct_suelo_trimestral') }} AS suelo
        ON suelo.sk_lugar = base.sk_lugar
        AND suelo.id_mes = base.id_mes
    LEFT JOIN {{ ref('fct_compraventa_vivienda_mensual') }} AS vivienda
        ON vivienda.sk_lugar = base.sk_lugar
        AND vivienda.id_mes = base.id_mes

),

por_territorio AS (

    SELECT
        CASE
            WHEN GROUPING(id_provincia) = 0 THEN 'Provincia'
            ELSE 'España'
        END AS nivel,
        COALESCE(id_provincia, 'ES') AS id_territorio,
        COALESCE(provincia, 'España') AS territorio,
        id_ccaa,
        id_mes,
        fecha_inicio_mes,
        id_trimestre,
        etiqueta_trimestre,
        anio,
        id_etapa,
        etapa,
        orden_etapa,
        SUM(num_transacciones_suelo) AS num_transacciones_suelo,
        SUM(transacciones_con_precio) AS transacciones_con_precio,
        SUM(precio_x_transacciones) AS precio_x_transacciones,
        {{ media_ponderada('precio_x_transacciones', 'transacciones_con_precio') }} AS precio_medio,
        SUM(num_compraventas_vivienda) AS num_compraventas_vivienda
    FROM provincia_mes
    GROUP BY GROUPING SETS (
        (id_mes, fecha_inicio_mes, id_trimestre, etiqueta_trimestre, anio, id_etapa, etapa, orden_etapa, id_provincia, provincia, id_ccaa),
        (id_mes, fecha_inicio_mes, id_trimestre, etiqueta_trimestre, anio, id_etapa, etapa, orden_etapa)
    )

),

con_referencias AS (

    SELECT
        *,
        LAG(precio_medio, 12) OVER (
            PARTITION BY nivel, id_territorio
            ORDER BY id_mes
        ) AS precio_medio_anio_anterior,
        LAG(num_transacciones_suelo, 12) OVER (
            PARTITION BY nivel, id_territorio
            ORDER BY id_mes
        ) AS num_transacciones_suelo_anio_anterior,
        LAG(num_compraventas_vivienda, 12) OVER (
            PARTITION BY nivel, id_territorio
            ORDER BY id_mes
        ) AS num_compraventas_vivienda_anio_anterior
    FROM por_territorio

)

SELECT
    nivel,
    id_territorio,
    territorio,
    id_ccaa,
    id_mes,
    fecha_inicio_mes,
    id_trimestre,
    etiqueta_trimestre,
    anio,
    id_etapa,
    etapa,
    orden_etapa,
    num_transacciones_suelo,
    transacciones_con_precio,
    precio_x_transacciones,
    precio_medio,
    {{ variacion_pct('precio_medio', 'precio_medio_anio_anterior') }} AS variacion_interanual_precio,
    {{ variacion_pct('num_transacciones_suelo', 'num_transacciones_suelo_anio_anterior') }} AS variacion_interanual_transacciones_suelo,
    num_compraventas_vivienda,
    {{ variacion_pct('num_compraventas_vivienda', 'num_compraventas_vivienda_anio_anterior') }} AS variacion_interanual_compraventas_vivienda
FROM con_referencias